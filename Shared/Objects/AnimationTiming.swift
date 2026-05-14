//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

/// Centralized timing constants for animations and delays throughout the app.
/// Using named constants makes timing behavior consistent and easy to tune.
enum AnimationTiming {

    // MARK: - Focus Delays

    /// Short delay to allow UI to settle before focus changes (0.1s)
    /// Used in: EpisodeHStack, SeasonHStack, MediaChaptersSupplement, supplement dismiss flag
    static let quickFocusDelay: TimeInterval = 0.1

    /// Standard delay for focus-related updates (0.35s)
    /// Used in: VideoPlayerContainerView focus callbacks
    static let focusUpdateDelay: TimeInterval = 0.35

    // MARK: - Skip Indicator

    /// Delay before skip indicator resets after tap (0.4s)
    /// Used in: PlaybackControls skip indicator
    static let skipIndicatorResetDelay: TimeInterval = 0.4

    /// Delay before skip indicator auto-hides after hold-scrubbing (1.0s)
    /// Used in: VideoPlayerContainerState handleArrowPressEnded
    static let skipIndicatorAutoHideDelay: TimeInterval = 1.0
}
