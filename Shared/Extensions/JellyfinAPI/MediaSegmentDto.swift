//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import JellyfinAPI

extension MediaSegmentDto {

    var startSeconds: Duration? {
        guard let startTicks else { return nil }
        return Duration.ticks(startTicks)
    }

    var endSeconds: Duration? {
        guard let endTicks else { return nil }
        return Duration.ticks(endTicks)
    }

    func contains(_ seconds: Duration) -> Bool {
        guard let startSeconds, let endSeconds, endSeconds > startSeconds else { return false }
        return seconds >= startSeconds && seconds < endSeconds
    }
}
