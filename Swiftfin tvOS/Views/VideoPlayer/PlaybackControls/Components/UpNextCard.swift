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

extension VideoPlayer.PlaybackControls {

    /// Shown near the end of an episode, counting down into the next one.
    ///
    /// Holds no focusable views on purpose. While the overlay is hidden the
    /// container swallows presses to reveal it, so select/play/menu for this
    /// card are handled there against `containerState.isPresentingUpNext`.
    struct UpNextCard: View {

        /// How long before the end of the episode the card appears.
        static let leadTime: Duration = .seconds(30)

        @Default(.accentColor)
        private var accentColor

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState
        @EnvironmentObject
        private var manager: MediaPlayerManager

        @State
        private var hasTriggeredNext = false
        @State
        private var remainingSeconds: Int?

        private var nextEpisode: BaseItemDto? {
            manager.queue?.nextItem?.item
        }

        private var isAutoPlayEnabled: Bool {
            manager.userSession?.user.data.configuration?.enableNextEpisodeAutoPlay == true
        }

        // `evaluate` runs on every seconds tick, and `@Published` fires whether
        // or not the value changed. An unguarded write here republishes
        // `containerState` several times a second, re-rendering everything that
        // holds it - including an open Menu, which visibly flickers.
        private func show(remaining: Int) {
            if remainingSeconds != remaining {
                remainingSeconds = remaining
            }

            if !containerState.isPresentingUpNext {
                containerState.isPresentingUpNext = true
            }
        }

        private func hide() {
            if remainingSeconds != nil {
                remainingSeconds = nil
            }

            if containerState.isPresentingUpNext {
                containerState.isPresentingUpNext = false
            }
        }

        private func evaluate(seconds: Duration) {
            guard !manager.isAutoPlayCancelled,
                  !manager.isStopping,
                  isAutoPlayEnabled,
                  let nextItem = manager.queue?.nextItem,
                  manager.item.isLiveStream != true,
                  let runtime = manager.item.runtime
            else {
                hide()
                return
            }

            let remaining = runtime - seconds

            guard remaining <= Self.leadTime else {
                hide()
                return
            }

            // Drive the advance from here rather than waiting on the player's
            // own ended event, which VLC can send early or not at all.
            guard remaining > .zero else {
                guard !hasTriggeredNext else { return }

                hasTriggeredNext = true
                hide()
                manager.playNewItem(provider: nextItem)
                return
            }

            show(remaining: max(1, Int(remaining.seconds.rounded())))
        }

        @ViewBuilder
        private func card(for episode: BaseItemDto, remaining: Int) -> some View {
            HStack(alignment: .center, spacing: 24) {
                ImageView(episode.imageSource(.primary, environment: ImageSourceOptions(maxWidth: 400)))
                    .failure {
                        SystemImageContentView(systemName: episode.systemImage)
                    }
                    .posterStyle(.landscape)
                    .frame(width: 200)
                    .posterShadow()

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.nextUp)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(accentColor)

                    Text(episode.displayTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if let seasonEpisodeLabel = episode.seasonEpisodeLabel {
                        Text(seasonEpisodeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(L10n.upNextPlayingIn(remaining))
                        .font(.caption)
                        .fontWeight(.medium)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }

                Spacer(minLength: 0)
            }
            .padding(28)
            .frame(width: 700, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }

        var body: some View {
            // Collapses to nothing when hidden so the transport controls
            // below keep their layout
            Group {
                if let remainingSeconds, let nextEpisode {
                    card(for: nextEpisode, remaining: remainingSeconds)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .animation(.easeInOut(duration: 0.3), value: remainingSeconds == nil)
            .onReceive(manager.secondsBox.$value) { evaluate(seconds: $0) }
            .onReceive(manager.$playbackItem) { _ in
                hasTriggeredNext = false
                hide()
            }
            .onDisappear(perform: hide)
        }
    }
}
