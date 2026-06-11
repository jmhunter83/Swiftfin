//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension VideoPlayer.PlaybackControls {

    struct PlaybackProgress: View {

        @Environment(\.isFocused)
        private var isFocused

        @EnvironmentObject
        private var manager: MediaPlayerManager
        @EnvironmentObject
        private var scrubbedSecondsBox: PublishedBox<Duration>

        private var progress: Double {
            guard let runtime = manager.item.runtime, runtime > .zero else { return 0 }
            let total = runtime.seconds
            return scrubbedSecondsBox.value.seconds / total
        }

        var body: some View {
            VStack(spacing: 12) {
                progressBar

                // Timestamps
                SplitTimeStamp()
            }
        }

        private var progressBar: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(isFocused ? 0.35 : 0.2))
                        .frame(height: 6)

                    // Progress fill
                    Capsule()
                        .fill(.white)
                        .frame(width: geometry.size.width * progress, height: 6)

                    // Current position indicator (circle), larger while the
                    // timeline holds focus
                    Circle()
                        .fill(.white)
                        .frame(width: isFocused ? 18 : 12, height: isFocused ? 18 : 12)
                        .offset(x: geometry.size.width * progress - (isFocused ? 9 : 6))
                        .shadow(color: .black.opacity(0.3), radius: isFocused ? 4 : 2)
                }
                .frame(height: 18)
            }
            .frame(height: 18)
            .animation(.spring(duration: 0.2), value: isFocused)
        }
    }
}
