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
                // Non-interactive progress bar
                staticProgressBar

                // Timestamps
                SplitTimeStamp()
            }
        }

        private var staticProgressBar: some View {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 6)

                    // Progress fill
                    Capsule()
                        .fill(.white)
                        .frame(width: geometry.size.width * progress, height: 6)

                    // Current position indicator (circle)
                    Circle()
                        .fill(.white)
                        .frame(width: 12, height: 12)
                        .offset(x: geometry.size.width * progress - 6)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
            }
            .frame(height: 12)
        }
    }
}
