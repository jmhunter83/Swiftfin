//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

extension VideoPlayer.PlaybackControls {

    /// Offers a skip out of an intro or out of the credits.
    ///
    /// Holds no focusable views, for the same reason as `UpNextCard`: while
    /// the overlay is hidden the container swallows presses, so select/play/
    /// menu are handled there against `containerState.activeSkipAction`.
    struct SkipPill: View {

        @Default(.accentColor)
        private var accentColor

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState
        @EnvironmentObject
        private var manager: MediaPlayerManager

        private func evaluate(seconds: Duration) {
            guard !containerState.isSkipDismissed,
                  !manager.isStopping,
                  manager.item.isLiveStream != true
            else {
                set(action: nil)
                return
            }

            let action = VideoPlayerSkipAction.resolve(
                at: seconds,
                runtime: manager.item.runtime,
                segments: manager.playbackItem?.mediaSegments ?? [],
                hasNextItem: manager.queue?.nextItem != nil,
                isUpNextPresented: containerState.isPresentingUpNext
            )

            set(action: action)
        }

        /// Guarded because this runs on every seconds tick, and an unguarded
        /// write republishes container state several times a second
        private func set(action: VideoPlayerSkipAction?) {
            if containerState.activeSkipAction != action {
                containerState.activeSkipAction = action
            }
        }

        @ViewBuilder
        private func pill(for action: VideoPlayerSkipAction) -> some View {
            HStack(spacing: 12) {
                Text(action.displayTitle)
                    .font(.callout)
                    .fontWeight(.semibold)

                Image(systemName: action.systemImage)
                    .font(.callout)
                    .foregroundStyle(accentColor)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }

        var body: some View {
            // Collapses to nothing when hidden so the controls below keep
            // their layout
            Group {
                if let action = containerState.activeSkipAction {
                    pill(for: action)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .animation(.easeInOut(duration: 0.3), value: containerState.activeSkipAction)
            .onReceive(manager.secondsBox.$value) { evaluate(seconds: $0) }
            .onReceive(manager.$playbackItem) { _ in
                containerState.isSkipDismissed = false
                set(action: nil)
            }
            .onDisappear {
                set(action: nil)
            }
        }
    }
}
