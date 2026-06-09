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
        let preferredLanguage = Defaults[.VideoPlayer.Audio.preferredLanguage]
        if let preferredStream = audioStreams.first(where: { $0.language?.lowercased() == preferredLanguage.lowercased() }) {
            selectedAudioStreamIndex = preferredStream.index
        } else if let defaultIndex = mediaSource.defaultAudioStreamIndex,
                  defaultIndex >= 0,
                  audioStreams.contains(where: { $0.index == defaultIndex })
        {
            selectedAudioStreamIndex = defaultIndex
        } else {
            selectedAudioStreamIndex = audioStreams.first?.index
        }

        selectedSubtitleStreamIndex = Self.initialSubtitleStreamIndex(
            preferred: preferredSubtitleStreamIndex,
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
    /// the subtitle list, which is order-preserving.
    static func initialSubtitleStreamIndex(
        preferred: Int?,
        mediaSource: MediaSourceInfo,
        adjustedSubtitleStreams: [MediaStream]
    ) -> Int {
        guard let preferred else { return mediaSource.defaultSubtitleStreamIndex ?? -1 }
        guard preferred != -1 else { return -1 }

        let originalSubtitles = (mediaSource.mediaStreams ?? []).filter { $0.type == .subtitle }

        guard let position = originalSubtitles.firstIndex(where: { $0.index == preferred }),
              position < adjustedSubtitleStreams.count
        else { return mediaSource.defaultSubtitleStreamIndex ?? -1 }

        return adjustedSubtitleStreams[position].index ?? -1
    }
}
