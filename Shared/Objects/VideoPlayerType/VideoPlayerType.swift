//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI

enum VideoPlayerType: String, CaseIterable, Displayable, Storable {

    case swiftfin

    var displayTitle: String {
        switch self {
        case .swiftfin:
            "Reefy"
        }
    }

    var directPlayProfiles: [DirectPlayProfile] {
        switch self {
        case .swiftfin:
            Self._swiftfinDirectPlayProfiles
        }
    }

    var transcodingProfiles: [TranscodingProfile] {
        switch self {
        case .swiftfin:
            Self._swiftfinTranscodingProfiles
        }
    }

    var subtitleProfiles: [SubtitleProfile] {
        switch self {
        case .swiftfin:
            Self._swiftfinSubtitleProfiles
        }
    }
}
