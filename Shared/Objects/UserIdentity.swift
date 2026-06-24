//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation

struct UserIdentity: Codable, Hashable, Storable {

    let serverID: String
    let userID: String

    init(serverID: String, userID: String) {
        self.serverID = serverID
        self.userID = userID
    }

    init(user: UserState) {
        self.init(serverID: user.serverID, userID: user.id)
    }
}

struct SessionUnauthorizedEvent: Hashable {

    let sessionID: UUID
    let identity: UserIdentity

    func matches(sessionID: UUID, identity: UserIdentity) -> Bool {
        self.sessionID == sessionID && self.identity == identity
    }
}

struct SessionAuthorizationValidationTracker {

    private var validatingSessionIDs: Set<UUID> = []

    mutating func begin(
        event: SessionUnauthorizedEvent,
        activeSessionID: UUID,
        activeIdentity: UserIdentity
    ) -> Bool {
        guard event.matches(sessionID: activeSessionID, identity: activeIdentity) else {
            return false
        }

        return validatingSessionIDs.insert(activeSessionID).inserted
    }

    mutating func finish(sessionID: UUID) {
        validatingSessionIDs.remove(sessionID)
    }
}
