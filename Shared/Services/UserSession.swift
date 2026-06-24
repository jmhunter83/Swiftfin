//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import CoreStore
import Defaults
import Factory
import Get
import JellyfinAPI
import Logging
import Pulse

enum SessionAuthorizationStatus: Equatable {
    case valid
    case unauthorized
    case inconclusive

    static func from(error: Error?) -> Self {
        guard let error else { return .valid }

        if case let .unacceptableStatusCode(statusCode) = error as? APIError,
           statusCode == 401
        {
            return .unauthorized
        }

        return .inconclusive
    }
}

final class UserSession {

    let client: JellyfinClient
    let id: UUID
    let identity: UserIdentity
    let server: ServerState
    let user: UserState

    var hasUsableAccessToken: Bool {
        accessToken.isNotEmpty
    }

    private let accessToken: String
    private let deviceID: String

    init(
        server: ServerState,
        user: UserState
    ) {
        let sessionID = UUID()
        let identity = UserIdentity(serverID: server.id, userID: user.id)
        let accessToken = user.accessToken
        let deviceID = user.deviceID

        self.id = sessionID
        self.identity = identity
        self.server = server
        self.user = user
        self.accessToken = accessToken
        self.deviceID = deviceID

        let client = JellyfinClient(
            configuration: .swiftfinConfiguration(
                url: server.currentURL,
                deviceID: deviceID,
                accessToken: accessToken
            ),
            delegate: SessionUnauthorizedDelegate(
                event: .init(
                    sessionID: sessionID,
                    identity: identity
                )
            ),
            sessionConfiguration: .swiftfin,
            sessionDelegate: URLSessionProxyDelegate(logger: NetworkLogger.swiftfin())
        )

        self.client = client
    }

    func confirmAuthorization() async -> SessionAuthorizationStatus {
        let validationClient = JellyfinClient(
            configuration: .swiftfinConfiguration(
                url: server.currentURL,
                deviceID: deviceID,
                accessToken: accessToken
            ),
            sessionConfiguration: .swiftfin,
            sessionDelegate: URLSessionProxyDelegate(logger: NetworkLogger.swiftfin())
        )

        do {
            _ = try await validationClient.send(Paths.getCurrentUser)
            return .valid
        } catch {
            return .from(error: error)
        }
    }
}

extension Container {

    // TODO: be parameterized, take user id
    //       - don't be optional
    //       - in `ViewModel`, don't be implicitly unwrapped
    //         and have idempotent default value
    var currentUserSession: Factory<UserSession?> {
        self {
            guard case let .signedIn(userId) = Defaults[.lastSignedInUserID] else { return nil }

            guard let user = try? SwiftfinStore.dataStack.fetchOne(
                From<UserModel>().where(\.$id == userId)
            ) else {
                // had last user ID but no saved user
                Defaults[.lastSignedInUserID] = .signedOut

                return nil
            }

            guard let server = user.server,
                  let _ = SwiftfinStore.dataStack.fetchExisting(server)
            else {
                // Orphaned user - sign out gracefully
                let logger = Logger.swiftfin()
                logger.error("No associated server for user \(userId). Signing out.")
                Defaults[.lastSignedInUserID] = .signedOut
                return nil
            }

            guard let userState = user.state else {
                let logger = Logger.swiftfin()
                logger.error("User \(userId) has no valid state. Signing out.")
                Defaults[.lastSignedInUserID] = .signedOut
                return nil
            }

            return .init(
                server: server.state,
                user: userState
            )
        }.cached
    }
}
