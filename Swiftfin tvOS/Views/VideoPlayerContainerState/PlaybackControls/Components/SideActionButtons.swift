//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI
import VLCUI

extension VideoPlayer.PlaybackControls {

    /// Right-side vertical stack containing Audio and Subtitles buttons.
    /// Positioned at 45% from top so it doesn't block the lower portion of the screen.
    struct SideActionButtons: View {

        private static let sideButtonsRightOffset: CGFloat = 150

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState
        @EnvironmentObject
        private var manager: MediaPlayerManager
        @EnvironmentObject
        private var focusGuide: FocusGuide

        @FocusState
        private var focusedButton: SideButton?

        enum SideButton: Hashable {
            case audio
            case subtitles
            case episodes
        }

        var body: some View {
            GeometryReader { geometry in
                VStack(spacing: 24) {
                    if let playbackItem = manager.playbackItem {
                        AudioButton(playbackItem: playbackItem)
                            .focused($focusedButton, equals: .audio)

                        if !playbackItem.subtitleStreams.isEmpty {
                            SubtitlesButton(playbackItem: playbackItem)
                                .focused($focusedButton, equals: .subtitles)
                        }

                        if manager.item.type == .episode {
                            EpisodesButton()
                                .focused($focusedButton, equals: .episodes)
                        }
                    }
                }
                .focusSection()
                .padding(.vertical, 20)
                .padding(.horizontal, 24)
                .background { TransportBarBackground() }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.4), radius: 16)
                .position(
                    x: geometry.size.width - Self.sideButtonsRightOffset,
                    y: geometry.size.height * 0.45
                )
            }
            .focusGuide(
                focusGuide,
                tag: "sideButtons",
                onContentFocus: {
                    if manager.item.type == .episode {
                        focusedButton = .episodes
                    } else if let playbackItem = manager.playbackItem,
                              !playbackItem.subtitleStreams.isEmpty
                    {
                        focusedButton = .subtitles
                    } else {
                        focusedButton = .audio
                    }
                },
                bottom: "transportBar"
            )
            .isVisible(isScrubbing || isPresentingOverlay)
        }

        private var isScrubbing: Bool {
            containerState.isScrubbing
        }

        private var isPresentingOverlay: Bool {
            containerState.isPresentingOverlay
        }
    }

    struct AudioButton: View {

        @EnvironmentObject
        private var manager: MediaPlayerManager

        @State
        private var selectedAudioStreamIndex: Int?

        let playbackItem: MediaPlayerItem

        private var systemImage: String {
            "speaker.wave.2"
        }

        private var content: some View {
            ForEach(playbackItem.audioStreams, id: \.index) { stream in
                Button {
                    playbackItem.selectedAudioStreamIndex = stream.index ?? -1
                } label: {
                    if selectedAudioStreamIndex == stream.index {
                        Label(stream.formattedAudioTitle, systemImage: "checkmark")
                    } else {
                        Text(stream.formattedAudioTitle)
                    }
                }
            }
        }

        var body: some View {
            SidePanelMenu(L10n.audio) {
                Image(systemName: systemImage)
            } content: {
                Section(L10n.audio) {
                    content
                }
            }
            .assign(playbackItem.$selectedAudioStreamIndex, to: $selectedAudioStreamIndex)
        }
    }

    struct SubtitlesButton: View {

        @EnvironmentObject
        private var manager: MediaPlayerManager

        @State
        private var selectedSubtitleStreamIndex: Int?

        let playbackItem: MediaPlayerItem

        private var systemImage: String {
            if let index = playbackItem.selectedSubtitleStreamIndex, index != -1 {
                return "captions.bubble.fill"
            }
            return "captions.bubble"
        }

        @ViewBuilder
        private var content: some View {
            Button {
                playbackItem.selectedSubtitleStreamIndex = -1
            } label: {
                if selectedSubtitleStreamIndex == -1 || selectedSubtitleStreamIndex == nil {
                    Label(L10n.none, systemImage: "checkmark")
                } else {
                    Label(L10n.none, systemImage: "xmark.circle")
                }
            }

            Divider()

            ForEach(playbackItem.subtitleStreams, id: \.index) { stream in
                Button {
                    playbackItem.selectedSubtitleStreamIndex = stream.index ?? -1
                } label: {
                    if selectedSubtitleStreamIndex == stream.index {
                        Label(stream.formattedSubtitleTitle, systemImage: "checkmark")
                    } else {
                        Text(stream.formattedSubtitleTitle)
                    }
                }
            }
        }

        var body: some View {
            SidePanelMenu(L10n.subtitles) {
                Image(systemName: systemImage)
            } content: {
                Section(L10n.subtitles) {
                    content
                }
            }
            .assign(playbackItem.$selectedSubtitleStreamIndex, to: $selectedSubtitleStreamIndex)
        }
    }

    struct EpisodesButton: View {

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState

        @EnvironmentObject
        private var manager: MediaPlayerManager

        private var episodesSupplement: (any MediaPlayerSupplement)? {
            manager.supplements.first { $0.id == "EpisodeMediaPlayerQueue" }
        }

        var body: some View {
            Button {
                if let supplement = episodesSupplement {
                    containerState.select(supplement: supplement)
                }
            } label: {
                Image(systemName: "tv")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .focused($isFocused)
            .scaleEffect(isFocused ? 1.15 : 1.0)
            .animation(.spring(duration: 0.2), value: isFocused)
        }

        @FocusState
        private var isFocused: Bool
    }
}
