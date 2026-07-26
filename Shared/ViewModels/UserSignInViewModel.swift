//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import FactoryKit
import Foundation
import Get
import JellyfinAPI
import KeychainSwift
import Logging
import OrderedCollections
import Pulse
import SwiftUI

// TODO: instead of just signing in duplicate user, send event for alert
//       to override existing user access token?
//       - won't require deleting and re-signing in user for password changes
//       - account for local device auth required
// TODO: ignore NSURLErrorDomain Code=-999 cancelled error on sign in
//       - need to make NSError wrappers anyways

@MainActor
@Stateful
final class UserSignInViewModel: ObservableObject {

    typealias AccessPolicyPair = (policy: LocalUserAccessPolicy, evaluated: any EvaluatedLocalUserAccessPolicy)
    typealias UserStateDataPair = (state: (state: UserState, accessToken: String, deviceID: String), data: UserDto)

    struct EvaluatedPolicyMap {
        let action: (any EvaluatedLocalUserAccessPolicy) -> any EvaluatedLocalUserAccessPolicy

        func callAsFunction(evaluatedPolicy: any EvaluatedLocalUserAccessPolicy) -> any EvaluatedLocalUserAccessPolicy {
            action(evaluatedPolicy)
        }
    }

    @CasePathable
    enum Action {
        case cancel
        case error
        case getPublicData
        case signIn(username: String, password: String)
        case signInQuickConnect(secret: String)

        case save(
            user: UserStateDataPair,
            authenticationAction: (action: LocalUserAuthenticationAction, accessPolicy: LocalUserAccessPolicy, reason: String?),
            evaluatedPolicyMap: EvaluatedPolicyMap
        )
        case saveExisting(
            user: UserStateDataPair,
            replaceForAccessToken: Bool,
            authenticationAction: (action: LocalUserAuthenticationAction, accessPolicy: LocalUserAccessPolicy, reason: String?),
            evaluatedPolicyMap: EvaluatedPolicyMap
        )

        var transition: Transition {
            switch self {
            case .cancel:
                .to(.initial)
            case .error, .save, .saveExisting:
                .none
            case .getPublicData:
                .background(.gettingPublicData)
            case .signIn, .signInQuickConnect:
                .loop(.signingIn)
            }
        }
    }

    enum BackgroundState {
        case gettingPublicData
    }

    enum Event {
        case connected(UserStateDataPair)
        case existingUser(UserStateDataPair)
        case saved(UserState)
    }

    enum State {
        case initial
        case signingIn
    }

    @Published
    private(set) var isQuickConnectEnabled = false
    @Published
    private(set) var publicUsers: [UserDto] = []
    @Published
    private(set) var serverDisclaimer: String? = nil

    private let logger = Logger.swiftfin()
    private var cancellables = Set<AnyCancellable>()

    let server: ServerState

    /// Device ID for the current sign-in attempt. Jellyfin binds the token it
    /// issues to the device ID that authenticated, so the same ID has to be
    /// used for the auth request and then stored for that user's session
    /// clients. Sharing one install-wide ID across users makes each new
    /// sign-in invalidate the previous user's token.
    private(set) var signInDeviceID: String = JellyfinClient.Configuration.generateDeviceID()
    private var signInClient: JellyfinClient?

    init(server: ServerState) {
        self.server = server
    }

    /// Builds the client for the next authentication attempt around a freshly
    /// generated device ID. Regenerated per attempt so two different users
    /// signing in through this view model never share a device server-side.
    ///
    /// Quick connect has to hand this same client to the initiate call, since
    /// the secret is redeemed against the device that started the exchange.
    @discardableResult
    func prepareSignInClient() -> JellyfinClient {
        signInDeviceID = JellyfinClient.Configuration.generateDeviceID()

        let client = JellyfinClient(
            configuration: .swiftfinConfiguration(
                url: server.effectiveServerURL,
                deviceID: signInDeviceID
            ),
            sessionConfiguration: .swiftfin,
            sessionDelegate: URLSessionProxyDelegate(logger: NetworkLogger.swiftfin())
        )

        signInClient = client
        return client
    }

    @Function(\Action.Cases.getPublicData)
    private func _getPublicData() async throws {
        async let isQuickConnectEnabled = try retrieveIsQuickConnectEnabled()
        async let publicUsers = try retrievePublicUsers()
        async let serverDisclaimer = try retrieveServerDisclaimer()

        self.isQuickConnectEnabled = try await isQuickConnectEnabled
        self.publicUsers = try await publicUsers
        self.serverDisclaimer = try await serverDisclaimer
    }

    @Function(\Action.Cases.signIn)
    private func _signIn(
        _ username: String,
        _ password: String
    ) async throws {
        let username = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .objectReplacement)

        let password = password
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .objectReplacement)

        let response = try await prepareSignInClient().signIn(username: username, password: password)

        guard let accessToken = response.accessToken,
              let userData = response.user,
              let id = userData.id,
              let username = userData.name
        else {
            logger.critical("Missing user data from network call")
            throw ErrorMessage(L10n.unknownError)
        }

        if let existingUser = existingUser(id: id) {
            events.send(.existingUser(((existingUser, accessToken, signInDeviceID), userData)))
        } else {
            let newUserState = UserState(
                id: id,
                serverID: server.id,
                username: username
            )

            events.send(.connected(((newUserState, accessToken, signInDeviceID), userData)))
        }
    }

    @Function(\Action.Cases.signInQuickConnect)
    private func _signInQuickConnect(
        _ secret: String
    ) async throws {
        // the same client that initiated the exchange, so the secret is
        // redeemed against the device the code was issued for
        let client = signInClient ?? prepareSignInClient()
        let response = try await client.signIn(quickConnectSecret: secret)

        guard let accessToken = response.accessToken,
              let userData = response.user,
              let id = userData.id,
              let username = userData.name
        else {
            logger.error("Missing user data from network call")
            throw ErrorMessage(L10n.unknownError)
        }

        if let existingUser = existingUser(id: id) {
            events.send(.existingUser(((existingUser, accessToken, signInDeviceID), userData)))
        } else {
            let newUserState = UserState(
                id: id,
                serverID: server.id,
                username: username
            )

            events.send(.connected(((newUserState, accessToken, signInDeviceID), userData)))
        }
    }

    private func existingUser(id: String) -> UserState? {
        StoredValues[.User.users]
            .first { $0.id == id }
    }

    @Function(\Action.Cases.save)
    private func _save(
        _ user: UserStateDataPair,
        _ authenticationAction: (action: LocalUserAuthenticationAction, accessPolicy: LocalUserAccessPolicy, reason: String?),
        _ evaluatedPolicyMap: EvaluatedPolicyMap
    ) async throws {

        let accessPolicy = authenticationAction.accessPolicy

        let evaluatedPolicy = try await evaluatedPolicyMap(
            evaluatedPolicy: authenticationAction.action(
                policy: accessPolicy,
                reason: authenticationAction.reason
            )
        )

        let userState = user.state.state

        let savedUserState = userState
        var users = StoredValues[.User.users]
        users.removeAll { $0.id == savedUserState.id }
        users.append(savedUserState)
        StoredValues[.User.users] = users

        var servers = StoredValues[.Server.servers]
        if let index = servers.firstIndex(where: { $0.id == savedUserState.serverID }) {
            let existingServer = servers[index]
            let userIDs = existingServer.userIDs.appending(savedUserState.id)

            servers[index] = ServerState(
                urls: existingServer.urls,
                currentURL: existingServer.currentURL,
                name: existingServer.name,
                id: existingServer.id,
                userIDs: userIDs
            )

            StoredValues[.Server.servers] = servers
        }

        savedUserState.accessPolicy = accessPolicy
        savedUserState.accessToken = user.state.accessToken
        savedUserState.deviceID = user.state.deviceID
        savedUserState.data = user.data

        if let evaluatedPinPolicy = evaluatedPolicy as? PinEvaluatedUserAccessPolicy {
            if let pinHint = evaluatedPinPolicy.pinHint {
                savedUserState.pinHint = pinHint
            }

            savedUserState.pin = evaluatedPinPolicy.pin
        }

        events.send(.saved(savedUserState))
    }

    @Function(\Action.Cases.saveExisting)
    private func _saveExisting(
        _ user: UserStateDataPair,
        _ replaceForAccessToken: Bool,
        _ authenticationAction: (action: LocalUserAuthenticationAction, accessPolicy: LocalUserAccessPolicy, reason: String?),
        _ evaluatedPolicyMap: EvaluatedPolicyMap
    ) async throws {

        let accessPolicy = authenticationAction.accessPolicy

        let evaluatedPolicy = try await evaluatedPolicyMap(
            evaluatedPolicy: authenticationAction.action(
                policy: accessPolicy,
                reason: authenticationAction.reason
            )
        )

        if let evaluatedPinPolicy = evaluatedPolicy as? PinEvaluatedUserAccessPolicy {
            guard user.state.state.pin == evaluatedPinPolicy.pin else {
                throw ErrorMessage(L10n.incorrectPinForUser(user.state.state.username))
            }
        }

        if replaceForAccessToken {
            // the device ID has to move with the token - the new one was issued
            // against the device that just authenticated, not the stored one
            user.state.state.accessToken = user.state.accessToken
            user.state.state.deviceID = user.state.deviceID
        }

        events.send(.saved(user.state.state))
    }

    private func retrievePublicUsers() async throws -> [UserDto] {
        let request = Paths.getPublicUsers
        let response = try await server.client.send(request)

        return response.value
    }

    private func retrieveServerDisclaimer() async throws -> String? {
        let request = Paths.getBrandingOptions
        let response = try await server.client.send(request)

        guard let disclaimer = response.value.loginDisclaimer, disclaimer.isNotEmpty else { return nil }

        return disclaimer
    }

    private func retrieveIsQuickConnectEnabled() async throws -> Bool {
        let request = Paths.getQuickConnectEnabled
        let response = try await server.client.send(request)

        let isEnabled = try? JSONDecoder().decode(Bool.self, from: response.value)
        return isEnabled ?? false
    }
}
