//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

// TODO: get preview image for current manager seconds?
//       - would make scrubbing image possibly ready before scrubbing

@MainActor
class MediaPlayerItem: ViewModel, MediaPlayerObserver {

    typealias ThumbnailProvider = () async -> UIImage?

    @Published
    var selectedAudioStreamIndex: Int? = nil {
        didSet {
            // Use Task to avoid blocking main thread during track change
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let proxy = manager?.proxy as? any VideoMediaPlayerProxy {
                    proxy.setAudioStream(.init(index: selectedAudioStreamIndex))
                }
            }

            // Persist the selected language as the user's preference
            if let index = selectedAudioStreamIndex,
               let selectedStream = audioStreams.first(where: { $0.index == index }),
               let language = selectedStream.language
            {
                Defaults[.VideoPlayer.Audio.preferredLanguage] = language
            }
        }
    }

    @Published
    var selectedSubtitleStreamIndex: Int? = nil {
        didSet {
            // Defer VLC track change to next run loop to avoid blocking during UI updates
            let subtitleIndex = selectedSubtitleStreamIndex
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let proxy = self.manager?.proxy as? any VideoMediaPlayerProxy {
                    proxy.setSubtitleStream(.init(index: subtitleIndex))
                }
            }

            // Remember the choice for this series/movie. Doesn't fire for the
            // initial assignment in init since that bypasses didSet.
            if let index = selectedSubtitleStreamIndex {
                if index == -1 {
                    recordStickySubtitleLanguage("off")
                } else if let language = subtitleStreams.first(where: { $0.index == index })?.language {
                    recordStickySubtitleLanguage(language)
                }
            }
        }
    }

    weak var manager: MediaPlayerManager? {
        didSet {
            for var o in observers {
                o.manager = manager
            }
        }
    }

    var observers: [any MediaPlayerObserver] = []

    let baseItem: BaseItemDto
    let mediaSource: MediaSourceInfo
    let playSessionID: String
    let previewImageProvider: (any PreviewImageProvider)?
    let thumbnailProvider: ThumbnailProvider?
    let url: URL

    let audioStreams: [MediaStream]
    let subtitleStreams: [MediaStream]
    let videoStreams: [MediaStream]

    let requestedBitrate: PlaybackBitrate

    // MARK: init

    init(
        baseItem: BaseItemDto,
        mediaSource: MediaSourceInfo,
        playSessionID: String,
        url: URL,
        requestedBitrate: PlaybackBitrate = .max,
        preferredSubtitleStreamIndex: Int? = nil,
        previewImageProvider: (any PreviewImageProvider)? = nil,
        thumbnailProvider: ThumbnailProvider? = nil
    ) {
        self.baseItem = baseItem
        self.mediaSource = mediaSource
        self.playSessionID = playSessionID
        self.requestedBitrate = requestedBitrate
        self.previewImageProvider = previewImageProvider
        self.thumbnailProvider = thumbnailProvider
        self.url = url

        let adjustedMediaStreams = mediaSource.mediaStreams?.adjustedTrackIndexes(
            for: mediaSource.transcodingURL == nil ? .directPlay : .transcode,
            selectedAudioStreamIndex: mediaSource.defaultAudioStreamIndex ?? 0
        )

        let audioStreams = adjustedMediaStreams?.filter { $0.type == .audio } ?? []
        let subtitleStreams = adjustedMediaStreams?.filter { $0.type == .subtitle } ?? []
        let videoStreams = adjustedMediaStreams?.filter { $0.type == .video } ?? []

        self.audioStreams = audioStreams
        self.subtitleStreams = subtitleStreams
        self.videoStreams = videoStreams

        super.init()

        // Select audio stream based on user's preferred language, falling back to server default,
        // then first available audio track. Avoid using -1 for audio, as VLC treats it as disabled.
        // defaultAudioStreamIndex is in server index space; map by position within the audio
        // list like initialSubtitleStreamIndex does.
        let preferredLanguage = Defaults[.VideoPlayer.Audio.preferredLanguage]
        let originalAudioStreams = (mediaSource.mediaStreams ?? [])
            .filter { $0.type == .audio && !($0.isExternal ?? false) }

        if let preferredStream = audioStreams.first(where: { $0.language?.lowercased() == preferredLanguage.lowercased() }) {
            selectedAudioStreamIndex = preferredStream.index
        } else if let defaultIndex = mediaSource.defaultAudioStreamIndex,
                  defaultIndex >= 0,
                  let position = originalAudioStreams.firstIndex(where: { $0.index == defaultIndex }),
                  position < audioStreams.count
        {
            selectedAudioStreamIndex = audioStreams[position].index
        } else {
            selectedAudioStreamIndex = audioStreams.first?.index
        }

        // An explicit pre-play pick also updates the per-title memory. Resolve
        // against the original streams since `preferred` is in server index space.
        if let preferred = preferredSubtitleStreamIndex {
            if preferred == -1 {
                recordStickySubtitleLanguage("off")
            } else if let language = mediaSource.mediaStreams?
                .first(where: { $0.type == .subtitle && $0.index == preferred })?.language
            {
                recordStickySubtitleLanguage(language)
            }
        }

        selectedSubtitleStreamIndex = Self.initialSubtitleStreamIndex(
            preferred: preferredSubtitleStreamIndex,
            stickyLanguage: stickySubtitleLanguage,
            mediaSource: mediaSource,
            adjustedSubtitleStreams: subtitleStreams
        )

        observers.append(MediaProgressObserver(item: self))
    }

    deinit {
        observers.removeAll()
    }

    /// Resolves the initial subtitle track. `preferred` is in the original server index
    /// space; tracks are renumbered by `adjustedTrackIndexes`, so map by position within
    /// the subtitle list, which is order-preserving. `stickyLanguage` is the remembered
    /// per-title choice: a language code or "off".
    static func initialSubtitleStreamIndex(
        preferred: Int?,
        stickyLanguage: String? = nil,
        mediaSource: MediaSourceInfo,
        adjustedSubtitleStreams: [MediaStream]
    ) -> Int {
        if let preferred {
            guard preferred != -1 else { return -1 }

            let originalSubtitles = (mediaSource.mediaStreams ?? []).filter { $0.type == .subtitle }

            if let position = originalSubtitles.firstIndex(where: { $0.index == preferred }),
               position < adjustedSubtitleStreams.count
            {
                return adjustedSubtitleStreams[position].index ?? -1
            }
        }

        if let stickyLanguage, stickyLanguage.isNotEmpty {
            guard stickyLanguage != "off" else { return -1 }

            if let match = adjustedSubtitleStreams.first(where: { $0.language?.lowercased() == stickyLanguage.lowercased() }) {
                return match.index ?? -1
            }
        }

        return mediaSource.defaultSubtitleStreamIndex ?? -1
    }

    /// The VLC track index for an audio stream in the adjusted index space.
    ///
    /// VLC numbers tracks by container order, while `adjustedTrackIndexes`
    /// renumbers internal tracks video-first. Files with audio as the first
    /// track (common in iTunes-style MP4s) would otherwise request a track
    /// VLC doesn't have, which silently disables audio (#61). Transcoded
    /// streams are muxed video-first by the server, so the adjusted index
    /// already matches.
    func vlcAudioTrackIndex(forAdjustedIndex adjustedIndex: Int?) -> Int? {
        guard let adjustedIndex else { return nil }
        guard mediaSource.transcodingURL == nil else { return adjustedIndex }

        guard let position = audioStreams.firstIndex(where: { $0.index == adjustedIndex }) else {
            return adjustedIndex
        }

        let originalAudioStreams = (mediaSource.mediaStreams ?? [])
            .filter { $0.type == .audio && !($0.isExternal ?? false) }

        guard position < originalAudioStreams.count else { return adjustedIndex }

        return originalAudioStreams[position].index
    }

    /// The VLC track index for a subtitle stream in the adjusted index space.
    ///
    /// Internal subtitles map by position to their original container index,
    /// mirroring `vlcAudioTrackIndex(forAdjustedIndex:)`. External subtitles
    /// load as playback slaves, which VLC numbers after the container tracks,
    /// the same relative spot the adjusted space assigns them, so they pass
    /// through unchanged, as do -1 (off) and transcoded streams.
    func vlcSubtitleTrackIndex(forAdjustedIndex adjustedIndex: Int?) -> Int? {
        guard let adjustedIndex else { return nil }
        guard adjustedIndex >= 0 else { return adjustedIndex }
        guard mediaSource.transcodingURL == nil else { return adjustedIndex }

        guard let position = subtitleStreams.firstIndex(where: { $0.index == adjustedIndex }),
              !(subtitleStreams[position].isExternal ?? false)
        else { return adjustedIndex }

        let originalSubtitleStreams = (mediaSource.mediaStreams ?? [])
            .filter { $0.type == .subtitle && !($0.isExternal ?? false) }

        guard position < originalSubtitleStreams.count else { return adjustedIndex }

        return originalSubtitleStreams[position].index
    }

    // MARK: sticky subtitle selection

    /// Key for the remembered subtitle choice, shared by all episodes of a series.
    private var stickySubtitleKey: StoredValues.Key<String> {
        StoredValues.Keys.User.stickySubtitleLanguage(itemID: baseItem.seriesID ?? baseItem.id)
    }

    private var stickySubtitleLanguage: String? {
        let stored = StoredValues[stickySubtitleKey]
        return stored.isEmpty ? nil : stored
    }

    private func recordStickySubtitleLanguage(_ language: String) {
        StoredValues[stickySubtitleKey] = language.lowercased()
    }
}
