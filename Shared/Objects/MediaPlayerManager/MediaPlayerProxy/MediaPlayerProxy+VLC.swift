//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import Foundation
import JellyfinAPI
import SwiftUI
import VLCUI

@MainActor
class VLCMediaPlayerProxy: VideoMediaPlayerProxy,
    MediaPlayerOffsetConfigurable,
    MediaPlayerSubtitleConfigurable
{

    let isBuffering: PublishedBox<Bool> = .init(initialValue: false)
    let videoSize: PublishedBox<CGSize> = .init(initialValue: .zero)
    let vlcUIProxy: VLCVideoPlayer.Proxy = .init()

    weak var manager: MediaPlayerManager? {
        didSet {
            for var o in observers {
                o.manager = manager
            }
        }
    }

    var observers: [any MediaPlayerObserver] = [
        NowPlayableObserver(),
    ]

    func play() {
        vlcUIProxy.play()
    }

    func pause() {
        vlcUIProxy.pause()
    }

    func stop() {
        vlcUIProxy.stop()
    }

    func jumpForward(_ seconds: Duration) {
        let target: Duration

        if let runtime = manager?.item.runtime, let current = manager?.seconds {
            let remaining = max(.zero, runtime - current)
            target = min(seconds, remaining)
        } else {
            target = seconds
        }

        guard target > .zero else { return }

        vlcUIProxy.jumpForward(target)
    }

    func jumpBackward(_ seconds: Duration) {
        vlcUIProxy.jumpBackward(seconds)
    }

    func setRate(_ rate: Float) {
        vlcUIProxy.setRate(.absolute(rate))
    }

    func setSeconds(_ seconds: Duration) {
        vlcUIProxy.setSeconds(seconds)
    }

    func setAudioStream(_ stream: MediaStream) {
        if let index = stream.index, index >= 0 {
            vlcUIProxy.setAudioTrack(.absolute(index))
        } else {
            vlcUIProxy.setAudioTrack(.auto)
        }
    }

    func setSubtitleStream(_ stream: MediaStream) {
        vlcUIProxy.setSubtitleTrack(.absolute(stream.index ?? -1))
    }

    func setAspectFill(_ aspectFill: Bool) {
        vlcUIProxy.aspectFill(aspectFill ? 1 : 0)
    }

    func setAudioOffset(_ seconds: Duration) {
        vlcUIProxy.setAudioDelay(seconds)
    }

    func setSubtitleOffset(_ seconds: Duration) {
        vlcUIProxy.setSubtitleDelay(seconds)
    }

    func setSubtitleColor(_ color: Color) {
        vlcUIProxy.setSubtitleColor(.absolute(color.uiColor))
    }

    func setSubtitleFontName(_ fontName: String) {
        vlcUIProxy.setSubtitleFont(fontName)
    }

    func setSubtitleFontSize(_ fontSize: Int) {
        vlcUIProxy.setSubtitleSize(.absolute(fontSize))
    }

    var videoPlayerBody: some View {
        VLCPlayerView()
            .environmentObject(vlcUIProxy)
    }
}

extension VLCMediaPlayerProxy {

    struct VLCPlayerView: View {

        @Default(.VideoPlayer.Subtitle.subtitleColor)
        private var subtitleColor
        @Default(.VideoPlayer.Subtitle.subtitleFontName)
        private var subtitleFontName
        @Default(.VideoPlayer.Subtitle.subtitleSize)
        private var subtitleSize

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState
        @EnvironmentObject
        private var manager: MediaPlayerManager
        @EnvironmentObject
        private var proxy: VLCVideoPlayer.Proxy

        /// State debouncing to prevent rapid play/pause toggles
        @State
        private var stateDebounceTask: Task<Void, Never>?
        @State
        private var lastReportedState: VLCUI.VLCVideoPlayer.State?

        /// Decode stall detection for VideoToolbox recovery
        @State
        private var consecutiveBufferingCount = 0
        @State
        private var lastPlayingTime: Date?
        @State
        private var stateChangeHistory: [(state: VLCUI.VLCVideoPlayer.State, time: Date)] = []

        private var isScrubbing: Bool {
            containerState.isScrubbing
        }

        private func vlcConfiguration(for item: MediaPlayerItem) -> VLCVideoPlayer.Configuration {
            let baseItem = item.baseItem
            let mediaSource = item.mediaSource

            var configuration = VLCVideoPlayer.Configuration(url: item.url)
            configuration.autoPlay = true

            let startSeconds = max(.zero, (baseItem.startSeconds ?? .zero) - Duration.seconds(Defaults[.VideoPlayer.resumeOffset]))

            if !baseItem.isLiveStream {
                configuration.startSeconds = startSeconds
                if let index = item.selectedAudioStreamIndex, index >= 0 {
                    configuration.audioIndex = .absolute(index)
                } else if let index = mediaSource.defaultAudioStreamIndex, index >= 0 {
                    configuration.audioIndex = .absolute(index)
                } else {
                    configuration.audioIndex = .auto
                }
                configuration.subtitleIndex = .absolute(mediaSource.defaultSubtitleStreamIndex ?? -1)
            }

            configuration.subtitleSize = .absolute(25 - Defaults[.VideoPlayer.Subtitle.subtitleSize])
            configuration.subtitleColor = .absolute(Defaults[.VideoPlayer.Subtitle.subtitleColor].uiColor)
            configuration.rate = .absolute(Defaults[.VideoPlayer.Playback.playbackRate])
            if let font = UIFont(name: Defaults[.VideoPlayer.Subtitle.subtitleFontName], size: 1) {
                configuration.subtitleFont = .absolute(font)
            }

            configuration.playbackChildren = item.subtitleStreams
                .filter { $0.deliveryMethod == .external }
                .compactMap(\.asVLCPlaybackChild)

            // Increase buffer size to reduce audio hiccups during track changes
            var options: [String: Any] = [
                "network-caching": 5000, // 5 seconds network buffer (default 1000ms)
                "file-caching": 5000, // 5 seconds file buffer
                "live-caching": 5000, // 5 seconds live stream buffer
                "clock-jitter": 0, // Disable clock jitter compensation
                "clock-synchro": 0, // Disable clock sync (reduces latency sensitivity)
            ]

            // Apply audio output mode settings
            switch Defaults[.VideoPlayer.Audio.outputMode] {
            case .systemDefault:
                // Set nothing — let VLC respect the system audio configuration.
                // Required for codecs (AAC, AC3, E-AC3) that fail under forced
                // software decode on some Apple TV configurations.
                break
            case .auto:
                // Disable passthrough so VLC can properly downmix surround to stereo
                // This fixes center channel only going to left speaker on stereo setups
                options["spdif"] = 0
            case .stereo:
                // Force stereo output with explicit 2-channel mode
                options["spdif"] = 0
                options["stereo-mode"] = 1 // Force stereo downmix
            case .passthrough:
                // Enable SPDIF passthrough for receivers that can decode surround
                options["spdif"] = 1
            }

            // Apply ReplayGain normalization for audio items
            if baseItem.type == .audio,
               Defaults[.VideoPlayer.Audio.replayGainEnabled],
               let normalizationGain = baseItem.normalizationGain
            {
                let finalGain = ReplayGainCalculator.calculateFinalGain(
                    normalizationGain: normalizationGain,
                    preAmp: Defaults[.VideoPlayer.Audio.replayGainPreAmp],
                    preventClipping: Defaults[.VideoPlayer.Audio.replayGainPreventClipping]
                )

                if finalGain != 0 {
                    // VLC gain option uses linear scale, convert from dB
                    options["gain"] = ReplayGainCalculator.dBToLinear(finalGain)
                }
            }

            configuration.options = options

            return configuration
        }

        var body: some View {
            if let playbackItem = manager.playbackItem, manager.state != .stopped {
                VLCVideoPlayer(configuration: vlcConfiguration(for: playbackItem))
                    .proxy(proxy)
                    .onSecondsUpdated { newSeconds, info in
                        Task { @MainActor in
                            if !isScrubbing {
                                containerState.scrubbedSeconds.value = newSeconds
                            }

                            manager.seconds = newSeconds

                            if let proxy = manager.proxy as? any VideoMediaPlayerProxy {
                                proxy.videoSize.value = info.videoSize
                            }
                        }
                    }
                    .onStateUpdated { state, info in
                        Task { @MainActor in
                            manager.logger.trace("VLC state updated: \(state)")

                            stateChangeHistory.append((state: state, time: Date()))
                            if stateChangeHistory.count > 10 {
                                stateChangeHistory.removeFirst()
                            }

                            stateDebounceTask?.cancel()
                            stateDebounceTask = Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(300))
                                guard !Task.isCancelled else { return }

                                guard state != lastReportedState else {
                                    manager.logger.trace("Skipping duplicate VLC state: \(state)")
                                    return
                                }

                                if state == .buffering && lastReportedState == .playing {
                                    consecutiveBufferingCount += 1

                                    if consecutiveBufferingCount >= 5,
                                       let lastPlaying = lastPlayingTime,
                                       Date().timeIntervalSince(lastPlaying) < 10
                                    {
                                        manager.logger.warning(
                                            "Detected decode stall (\(consecutiveBufferingCount) rapid buffering events), recreating player"
                                        )
                                        consecutiveBufferingCount = 0
                                        proxy.playNewMedia(vlcConfiguration(for: playbackItem))
                                        return
                                    }
                                }

                                lastReportedState = state

                                switch state {
                                case .buffering,
                                     .esAdded,
                                     .opening:
                                    manager.proxy?.isBuffering.value = true
                                case .ended:
                                    guard !playbackItem.baseItem.isLiveStream else { return }
                                    manager.proxy?.isBuffering.value = false
                                    await manager.ended()
                                case .stopped: ()
                                case .error:
                                    manager.proxy?.isBuffering.value = false
                                    await manager.error(ErrorMessage("VLC player is unable to perform playback"))
                                case .playing:
                                    consecutiveBufferingCount = 0
                                    lastPlayingTime = Date()
                                    manager.proxy?.isBuffering.value = false
                                    await manager.setPlaybackRequestStatus(status: .playing)
                                case .paused:
                                    await manager.setPlaybackRequestStatus(status: .paused)
                                }

                                if let proxy = manager.proxy as? any VideoMediaPlayerProxy {
                                    proxy.videoSize.value = info.videoSize
                                }
                            }
                        }
                    }
                    .onReceive(manager.$playbackItem) { playbackItem in
                        // Reset state tracking when item changes to prevent stale
                        // ended/stopped events from the old item from firing
                        lastReportedState = nil
                        stateDebounceTask?.cancel()
                        consecutiveBufferingCount = 0

                        guard let playbackItem else { return }
                        proxy.playNewMedia(vlcConfiguration(for: playbackItem))
                    }
                    .backport
                    .onChange(of: manager.rate) { _, newValue in
                        proxy.setRate(.absolute(newValue))
                    }
                    .backport
                    .onChange(of: subtitleColor) { _, newValue in
                        if let proxy = proxy as? MediaPlayerSubtitleConfigurable {
                            proxy.setSubtitleColor(newValue)
                        }
                    }
                    .backport
                    .onChange(of: subtitleFontName) { _, newValue in
                        if let proxy = proxy as? MediaPlayerSubtitleConfigurable {
                            proxy.setSubtitleFontName(newValue)
                        }
                    }
                    .backport
                    .onChange(of: subtitleSize) { _, newValue in
                        if let proxy = proxy as? MediaPlayerSubtitleConfigurable {
                            proxy.setSubtitleFontSize(25 - newValue)
                        }
                    }
            }
        }
    }
}
