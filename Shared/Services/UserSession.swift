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
import JellyfinAPI
import Logging
import Pulse

final class UserSession {

    let client: JellyfinClient
    let server: ServerState
    let user: UserState

    init(
        server: ServerState,
        user: UserState
    ) {
        self.server = server
        self.user = user

        let client = JellyfinClient(
            configuration: .swiftfinConfiguration(
                url: server.currentURL,
                deviceID: user.deviceID,
                accessToken: user.accessToken
            ),
            sessionConfiguration: .swiftfin,
            sessionDelegate: URLSessionProxyDelegate(logger: NetworkLogger.swiftfin())
        )

        self.client = client
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
