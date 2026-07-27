//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

/// A skip offered to the viewer during playback, shown as a pill in the
/// bottom corner and taken by pressing select or play.
enum VideoPlayerSkipAction: Equatable {

    /// Inside an intro the server has tagged. Seeks to the end of it.
    case skipIntro(to: Duration)

    /// The credits are rolling and something is queued behind them.
    case nextEpisode

    var displayTitle: String {
        switch self {
        case .skipIntro:
            L10n.skipIntro
        case .nextEpisode:
            L10n.nextEpisode
        }
    }

    var systemImage: String {
        switch self {
        case .skipIntro:
            "forward.fill"
        case .nextEpisode:
            "forward.end.fill"
        }
    }
}

extension VideoPlayerSkipAction {

    /// How far before the end the credits are assumed to start when the
    /// server has no outro segment for the item.
    static let creditsFallbackLeadTime: Duration = .seconds(120)

    /// Decides which skip, if any, applies at a given point in playback.
    ///
    /// Kept free of view state so the windows can be tested directly.
    static func resolve(
        at seconds: Duration,
        runtime: Duration?,
        segments: [MediaSegmentDto],
        hasNextItem: Bool,
        isUpNextPresented: Bool
    ) -> VideoPlayerSkipAction? {

        // The up next card takes over from here and offers the same jump
        guard !isUpNextPresented else { return nil }

        if let intro = segments.first(where: { $0.type == .intro && $0.contains(seconds) }),
           let end = intro.endSeconds
        {
            return .skipIntro(to: end)
        }

        guard hasNextItem, let runtime, runtime > .zero else { return nil }

        let creditsStart = segments
            .first { $0.type == .outro }?
            .startSeconds
            ?? runtime - creditsFallbackLeadTime

        guard seconds >= creditsStart, seconds < runtime else { return nil }

        return .nextEpisode
    }
}
