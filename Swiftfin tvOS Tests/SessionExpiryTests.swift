//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import Get
@testable import Swiftfin_tvOS
import XCTest

final class SessionExpiryTests: XCTestCase {

    private let identity = UserIdentity(serverID: "server-a", userID: "user-a")

    func testDelegateEmitsAfterTwoUnauthorizedResponses() {
        let event = SessionUnauthorizedEvent(sessionID: UUID(), identity: identity)
        var received: [SessionUnauthorizedEvent] = []
        let delegate = SessionUnauthorizedDelegate(event: event, onUnauthorized: {
            received.append($0)
        })
        let start = Date(timeIntervalSince1970: 1000)

        delegate.recordUnauthorized(at: start)
        XCTAssertTrue(received.isEmpty)

        delegate.recordUnauthorized(at: start.addingTimeInterval(1))
        XCTAssertEqual(received, [event])
    }

    func testDelegateResetsAfterEmitting() {
        let event = SessionUnauthorizedEvent(sessionID: UUID(), identity: identity)
        var received: [SessionUnauthorizedEvent] = []
        let delegate = SessionUnauthorizedDelegate(event: event, onUnauthorized: {
            received.append($0)
        })
        let start = Date(timeIntervalSince1970: 1000)

        delegate.recordUnauthorized(at: start)
        delegate.recordUnauthorized(at: start.addingTimeInterval(1))
        delegate.recordUnauthorized(at: start.addingTimeInterval(2))
        delegate.recordUnauthorized(at: start.addingTimeInterval(3))

        XCTAssertEqual(received, [event, event])
    }

    func testDelegateExpiresUnauthorizedResponsesOutsideWindow() {
        let event = SessionUnauthorizedEvent(sessionID: UUID(), identity: identity)
        var received: [SessionUnauthorizedEvent] = []
        let delegate = SessionUnauthorizedDelegate(event: event, onUnauthorized: {
            received.append($0)
        })
        let start = Date(timeIntervalSince1970: 1000)

        delegate.recordUnauthorized(at: start)
        delegate.recordUnauthorized(at: start.addingTimeInterval(11))
        XCTAssertTrue(received.isEmpty)

        delegate.recordUnauthorized(at: start.addingTimeInterval(12))
        XCTAssertEqual(received, [event])
    }

    func testUnauthorizedEventOnlyMatchesOriginatingSession() {
        let sessionID = UUID()
        let event = SessionUnauthorizedEvent(sessionID: sessionID, identity: identity)

        XCTAssertTrue(event.matches(sessionID: sessionID, identity: identity))
        XCTAssertFalse(event.matches(sessionID: UUID(), identity: identity))
        XCTAssertFalse(
            event.matches(
                sessionID: sessionID,
                identity: UserIdentity(serverID: "server-b", userID: "user-a")
            )
        )
    }

    func testValidationTrackerRejectsStaleAndDuplicateEvents() {
        let sessionA = UUID()
        let sessionB = UUID()
        let event = SessionUnauthorizedEvent(sessionID: sessionA, identity: identity)
        var tracker = SessionAuthorizationValidationTracker()

        XCTAssertFalse(
            tracker.begin(
                event: event,
                activeSessionID: sessionB,
                activeIdentity: identity
            )
        )
        XCTAssertTrue(
            tracker.begin(
                event: event,
                activeSessionID: sessionA,
                activeIdentity: identity
            )
        )
        XCTAssertFalse(
            tracker.begin(
                event: event,
                activeSessionID: sessionA,
                activeIdentity: identity
            )
        )

        tracker.finish(sessionID: sessionA)

        XCTAssertTrue(
            tracker.begin(
                event: event,
                activeSessionID: sessionA,
                activeIdentity: identity
            )
        )
    }

    func testAuthorizationStatusOnlyConfirmsUnauthorizedFor401() {
        XCTAssertEqual(SessionAuthorizationStatus.from(error: nil), .valid)
        XCTAssertEqual(
            SessionAuthorizationStatus.from(error: APIError.unacceptableStatusCode(401)),
            .unauthorized
        )
        XCTAssertEqual(
            SessionAuthorizationStatus.from(error: APIError.unacceptableStatusCode(403)),
            .inconclusive
        )
        XCTAssertEqual(
            SessionAuthorizationStatus.from(error: APIError.unacceptableStatusCode(500)),
            .inconclusive
        )
        XCTAssertEqual(
            SessionAuthorizationStatus.from(error: URLError(.notConnectedToInternet)),
            .inconclusive
        )
    }

    @MainActor
    func testReauthenticationRequiresMatchingServerAndUser() {
        let server = makeServer(userIDs: ["user-a"])
        let user = UserState(id: "user-a", serverID: server.id, username: "User")
        let viewModel = UserSignInViewModel(server: server, mode: .reauthenticate(user))

        XCTAssertTrue(viewModel.requiresAutomaticCredentialReplacement)
        XCTAssertNoThrow(
            try viewModel.validateReauthenticationResponse(
                serverID: server.id,
                userID: user.id
            )
        )
        XCTAssertThrowsError(
            try viewModel.validateReauthenticationResponse(
                serverID: "server-b",
                userID: user.id
            )
        )
        XCTAssertThrowsError(
            try viewModel.validateReauthenticationResponse(
                serverID: server.id,
                userID: "user-b"
            )
        )
    }

    @MainActor
    func testNormalSignInDoesNotForceCredentialReplacement() {
        let viewModel = UserSignInViewModel(server: makeServer())

        XCTAssertFalse(viewModel.requiresAutomaticCredentialReplacement)
    }

    func testPendingReauthenticationIdentityPersistsUntilCleared() {
        let previousIdentity = Defaults[.pendingReauthenticationIdentity]
        let previousLegacyUserID = Defaults[.lastSessionExpiredUserID]

        defer {
            Defaults[.pendingReauthenticationIdentity] = previousIdentity
            Defaults[.lastSessionExpiredUserID] = previousLegacyUserID
        }

        Defaults[.pendingReauthenticationIdentity] = identity
        Defaults[.lastSessionExpiredUserID] = identity.userID

        XCTAssertEqual(Defaults[.pendingReauthenticationIdentity], identity)
        XCTAssertEqual(Defaults[.lastSessionExpiredUserID], identity.userID)

        Defaults[.pendingReauthenticationIdentity] = nil
        Defaults[.lastSessionExpiredUserID] = nil

        XCTAssertNil(Defaults[.pendingReauthenticationIdentity])
        XCTAssertNil(Defaults[.lastSessionExpiredUserID])
    }

    private func makeServer(userIDs: [String] = []) -> ServerState {
        let url = URL(string: "https://example.com")!

        return ServerState(
            urls: [url],
            currentURL: url,
            name: "Server",
            id: "server-a",
            usersIDs: userIDs
        )
    }
}
