//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import Factory
import Logging
import SwiftUI

@MainActor
final class RootCoordinator: ObservableObject {

    @Published
    var root: RootItem = .appLoading

    private let logger = Logger.swiftfin()
    private var sessionUnauthorizedCancellable: AnyCancellable?
    private var sessionAuthorizationValidationTracker = SessionAuthorizationValidationTracker()

    init() {
        Task {
            do {
                try await SwiftfinStore.setupDataStack()

                var currentSession = Container.shared.currentUserSession()

                if let session = currentSession, !session.hasUsableAccessToken {
                    Defaults[.pendingReauthenticationIdentity] = session.identity
                    Defaults[.lastSessionExpiredUserID] = session.user.id
                    Defaults[.lastSignedInUserID] = .signedOut
                    Container.shared.currentUserSession.reset()
                    currentSession = nil
                }

                let hasPendingReauthentication =
                    Defaults[.pendingReauthenticationIdentity] != nil ||
                    Defaults[.lastSessionExpiredUserID] != nil

                if currentSession != nil,
                   !hasPendingReauthentication,
                   !Defaults[.signOutOnClose],
                   !Defaults[.selectUserOnLaunch]
                {
                    #if os(tvOS)
                    await MainActor.run {
                        root(.mainTab)
                    }
                    #else
                    await MainActor.run {
                        root(.serverCheck)
                    }
                    #endif
                } else {
                    await MainActor.run {
                        root(.selectUser)
                    }
                }

            } catch {
                await MainActor.run {
                    Notifications[.didFailMigration].post()
                }
            }
        }

        // Notification setup for state
        Notifications[.didSignIn].subscribe(self, selector: #selector(didSignIn))
        Notifications[.didSignOut].subscribe(self, selector: #selector(didSignOut))
        Notifications[.didChangeCurrentServerURL].subscribe(self, selector: #selector(didChangeCurrentServerURL(_:)))
        Notifications[.applicationDidEnterBackground].subscribe(self, selector: #selector(didEnterBackground))
        sessionUnauthorizedCancellable = Notifications[.didReceiveSessionUnauthorized]
            .publisher
            .sink { [weak self] event in
                Task { @MainActor in
                    await self?.didReceiveSessionUnauthorized(event)
                }
            }
    }

    func root(_ newRoot: RootItem) {
        root = newRoot
    }

    @objc
    private func didSignIn() {
        logger.info("Signed in")

        #if os(tvOS)
        root(.mainTab)
        #else
        root(.serverCheck)
        #endif
    }

    @objc
    private func didEnterBackground() {
        // The launch check in init only runs on a cold start; tvOS resumes
        // the suspended app, so re-arm the user picker while backgrounded.
        // The session stays signed in - picking a user routes through didSignIn.
        #if os(tvOS)
        let signedInRootID = RootItem.mainTab.id
        #else
        let signedInRootID = RootItem.serverCheck.id
        #endif

        guard Defaults[.selectUserOnLaunch], root.id == signedInRootID else { return }

        root(.selectUser)
    }

    private func didReceiveSessionUnauthorized(_ event: SessionUnauthorizedEvent) async {
        #if os(tvOS)
        let signedInRootID = RootItem.mainTab.id
        #else
        let signedInRootID = RootItem.serverCheck.id
        #endif

        guard root.id == signedInRootID,
              let session = Container.shared.currentUserSession(),
              sessionAuthorizationValidationTracker.begin(
                  event: event,
                  activeSessionID: session.id,
                  activeIdentity: session.identity
              )
        else { return }

        defer {
            sessionAuthorizationValidationTracker.finish(sessionID: session.id)
        }

        let status = await session.confirmAuthorization()

        guard let activeSession = Container.shared.currentUserSession(),
              event.matches(sessionID: activeSession.id, identity: activeSession.identity)
        else { return }

        switch status {
        case .valid:
            logger.info("Session token validation succeeded for user \(session.user.id)")
            return
        case .inconclusive:
            logger.warning("Session token validation was inconclusive for user \(session.user.id)")
            return
        case .unauthorized:
            logger.warning("Session token confirmed invalid for user \(session.user.id) - routing to re-authentication")
        }

        Defaults[.pendingReauthenticationIdentity] = session.identity
        Defaults[.lastSessionExpiredUserID] = session.user.id
        Defaults[.lastSignedInUserID] = .signedOut
        Container.shared.currentUserSession.reset()
        root(.selectUser)
    }

    @objc
    private func didSignOut() {
        logger.info("Signed out")

        root(.selectUser)
    }

    @objc
    func didChangeCurrentServerURL(_ notification: Notification) {

        guard Container.shared.currentUserSession() != nil else { return }

        Container.shared.currentUserSession.reset()
        Notifications[.didSignIn].post()
    }
}
