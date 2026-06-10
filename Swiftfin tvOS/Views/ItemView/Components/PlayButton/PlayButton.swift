//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import Logging
import SwiftUI

extension ItemView {

    struct PlayButton: View {

        @Router
        private var router

        @ObservedObject
        var viewModel: ItemViewModel

        @State
        private var selectedSubtitleStreamIndex: Int? = nil

        private let logger = Logger.swiftfin()

        // MARK: - Media Sources

        private var mediaSources: [MediaSourceInfo] {
            viewModel.playButtonItem?.mediaSources ?? []
        }

        // MARK: - Subtitle Streams

        private var subtitleStreams: [MediaStream] {
            viewModel.selectedMediaSource?.mediaStreams?.filter { $0.type == .subtitle } ?? []
        }

        // MARK: - Multiple Media Sources

        private var multipleVersions: Bool {
            mediaSources.count > 1
        }

        // MARK: - Validation

        private var isEnabled: Bool {
            viewModel.selectedMediaSource != nil
        }

        // MARK: - Title

        private var title: String {
            // Use the Season/Episode label for the Series ItemView
            if let seriesViewModel = viewModel as? SeriesItemViewModel,
               let seasonEpisodeLabel = seriesViewModel.playButtonItem?.seasonEpisodeLabel
            {
                return seasonEpisodeLabel

                // Use a Play/Resume label for single Media Source items that are not Series
            } else if let playButtonLabel = viewModel.playButtonItem?.playButtonLabel {
                return playButtonLabel

                // Fallback to a generic `Play` label
            } else {
                return L10n.play
            }
        }

        // MARK: - Media Source

        private var source: String? {
            guard let sourceLabel = viewModel.selectedMediaSource?.displayTitle,
                  viewModel.item.mediaSources?.count ?? 0 > 1
            else {
                return nil
            }

            return sourceLabel
        }

        // MARK: - Has Progress

        private var hasProgress: Bool {
            (viewModel.playButtonItem?.userData?.playbackPositionTicks ?? 0) > 0
        }

        // MARK: - Body

        var body: some View {
            HStack(spacing: 24) {
                playButton

                if multipleVersions {
                    VersionMenu(viewModel: viewModel, mediaSources: mediaSources)
                        .frame(width: 85, height: 85)
                }

                if subtitleStreams.isNotEmpty {
                    SubtitleMenu(
                        selectedSubtitleStreamIndex: $selectedSubtitleStreamIndex,
                        subtitleStreams: subtitleStreams
                    )
                    .frame(width: 85, height: 85)
                }

                if hasProgress {
                    startFromBeginningButton
                }
            }
            .frame(height: 85)
            .fontWeight(.semibold)
            .onChange(of: viewModel.selectedMediaSource) {
                selectedSubtitleStreamIndex = nil
            }
        }

        // MARK: - Play Button

        private var playButton: some View {
            Button {
                play()
            } label: {
                HStack(spacing: 20) {
                    Image(systemName: "play.fill")
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)

                        if let source {
                            Marquee(source, animateWhenFocused: true)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 10)
            }
            .buttonStyle(
                .tintedMaterial(
                    tint: .white,
                    foregroundColor: .black
                )
            )
            .contextMenu {
                if viewModel.playButtonItem?.userData?.playbackPositionTicks != 0 {
                    Button(L10n.playFromBeginning, systemImage: "gobackward") {
                        play(fromBeginning: true)
                    }
                }
            }
            .isSelected(true)
            .enabled(isEnabled)
        }

        // MARK: - Start from Beginning Button

        private var startFromBeginningButton: some View {
            Button {
                play(fromBeginning: true)
            } label: {
                Label(L10n.playFromBeginning, systemImage: "gobackward")
            }
            .buttonStyle(.tintedMaterial(tint: .secondary, foregroundColor: .white))
            .labelStyle(.iconOnly)
            .font(.title3)
            .fontWeight(.semibold)
            .frame(width: 85, height: 85)
            .enabled(isEnabled)
        }

        // MARK: - Play Content

        private func play(fromBeginning: Bool = false) {
            guard let playButtonItem = viewModel.playButtonItem,
                  let selectedMediaSource = viewModel.selectedMediaSource
            else {
                logger.error("Play selected with no item or media source")
                return
            }

            let queue: (any MediaPlayerQueue)? = {
                if playButtonItem.type == .episode {
                    return EpisodeMediaPlayerQueue(episode: playButtonItem)
                }
                return nil
            }()

            let subtitleStreamIndex = selectedSubtitleStreamIndex
            let provider = MediaPlayerItemProvider(item: playButtonItem) { item in
                try await MediaPlayerItem.build(
                    for: item,
                    mediaSource: selectedMediaSource,
                    selectedSubtitleStreamIndex: subtitleStreamIndex
                ) {
                    if fromBeginning {
                        $0.userData?.playbackPositionTicks = 0
                    }
                }
            }

            router.route(
                to: .videoPlayer(
                    provider: provider,
                    queue: queue
                )
            )
        }
    }
}
