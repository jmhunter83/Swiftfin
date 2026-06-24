//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import JellyfinAPI
import OrderedCollections
import SwiftUI

struct SelectUserView: View {

    typealias UserItem = (user: UserState, server: ServerState)

    // MARK: - Defaults

    @Default(.selectUserUseSplashscreen)
    private var selectUserUseSplashscreen
    @Default(.selectUserAllServersSplashscreen)
    private var selectUserAllServersSplashscreen
    @Default(.selectUserServerSelection)
    private var serverSelection

    // MARK: - State & Environment Objects

    @Router
    private var router

    // MARK: - Select User Variables

    @State
    private var isEditingUsers: Bool = false
    @State
    private var pin: String = ""
    @State
    private var scrollViewOffset: CGFloat = 0
    @State
    private var selectedUsers: Set<UserState> = []

    // MARK: - Dialog States

    @State
    private var isPresentingConfirmDeleteUsers = false
    @State
    private var isPresentingLocalPin: Bool = false
    @State
    private var didAttemptPendingReauthentication = false

    @StateObject
    private var viewModel = SelectUserViewModel()

    private var selectedServer: ServerState? {
        serverSelection.server(from: viewModel.servers.keys)
    }

    private var allUserItems: [UserItem] {
        viewModel.servers
            .flatMap { server, users in
                users.map { UserItem(user: $0, server: server) }
            }
    }

    private var splashScreenImageSources: [ImageSource] {
        switch (serverSelection, selectUserAllServersSplashscreen) {
        case (.all, .all):
            return viewModel
                .servers
                .keys
                .shuffled()
                .map(\.splashScreenImageSource)

        // need to evaluate server with id selection first
        case let (.server(id), _), let (.all, .server(id)):
            guard let server = viewModel
                .servers
                .keys
                .first(where: { $0.id == id }) else { return [] }

            return [server.splashScreenImageSource]
        }
    }

    private var userItems: [UserItem] {
        switch serverSelection {
        case .all:
            return allUserItems
                .sorted(using: \.user.username)
                .reversed()
                .map { $0 }
        case let .server(id: id):
            guard let server = viewModel.servers.keys.first(where: { server in server.id == id }) else {
                return []
            }

            return viewModel.servers[server]!
                .sorted(using: \.username)
                .map { UserItem(user: $0, server: server) }
        }
    }

    private func addUserSelected(server: ServerState) {
        router.route(to: .userSignIn(server: server))
    }

    private func delete(user: UserState) {
        selectedUsers.insert(user)
        isPresentingConfirmDeleteUsers = true
    }

    // MARK: - Select User(s)

    private func select(user: UserState, needsPin: Bool = true) {
        let identity = UserIdentity(user: user)
        let requiresReauthentication =
            user.accessToken.isEmpty ||
            Defaults[.pendingReauthenticationIdentity] == identity

        guard !requiresReauthentication else {
            routeToReauthentication(user: user)
            return
        }

        switch user.accessPolicy {
        case .requireDeviceAuthentication:
            // Do nothing, no device authentication on tvOS
            break
        case .requirePin:
            if needsPin {
                // PIN alert reads the user back via selectedUsers.first
                selectedUsers.insert(user)
                isPresentingLocalPin = true
                return
            }
        case .none: ()
        }

        viewModel.signIn(user, pin: pin)
    }

    private func routeToReauthentication(user: UserState) {
        guard let server = viewModel.servers.keys.first(where: { $0.id == user.serverID }) else { return }

        Defaults[.pendingReauthenticationIdentity] = UserIdentity(user: user)
        Defaults[.lastSessionExpiredUserID] = user.id

        router.route(
            to: .userSignIn(
                server: server,
                mode: .reauthenticate(user)
            )
        )
    }

    private func routePendingReauthenticationIfNeeded() {
        guard !didAttemptPendingReauthentication else { return }

        var identity = Defaults[.pendingReauthenticationIdentity]

        if identity == nil, let legacyUserID = Defaults[.lastSessionExpiredUserID] {
            identity = allUserItems
                .first(where: { $0.user.id == legacyUserID })
                .map { UserIdentity(user: $0.user) }

            if let identity {
                Defaults[.pendingReauthenticationIdentity] = identity
            }
        }

        guard let identity else { return }
        guard viewModel.servers.isNotEmpty else { return }

        guard let item = allUserItems.first(where: {
            $0.user.id == identity.userID && $0.server.id == identity.serverID
        }) else {
            Defaults[.pendingReauthenticationIdentity] = nil
            Defaults[.lastSessionExpiredUserID] = nil
            didAttemptPendingReauthentication = true
            return
        }

        didAttemptPendingReauthentication = true
        routeToReauthentication(user: item.user)
    }

    // MARK: - Grid Content View

    private var userGrid: some View {
        CenteredLazyVGrid(
            data: userItems,
            id: \.user.id,
            columns: 5,
            spacing: EdgeInsets.edgePadding
        ) { gridItem in
            let user = gridItem.user
            let server = gridItem.server

            UserGridButton(
                user: user,
                server: server,
                showServer: serverSelection == .all
            ) {
                if isEditingUsers {
                    selectedUsers.toggle(value: user)
                } else {
                    select(user: user)
                }
            } onDelete: {
                delete(user: user)
            }
            .isSelected(selectedUsers.contains(user))
        }
    }

    private var addUserButtonGrid: some View {
        CenteredLazyVGrid(
            data: [0],
            id: \.self,
            columns: 5
        ) { _ in
            AddUserGridButton(
                selectedServer: selectedServer,
                servers: viewModel.servers.keys
            ) { server in
                router.route(to: .userSignIn(server: server))
            }
        }
    }

    // MARK: - User View

    private var contentView: some View {
        VStack {
            ZStack {
                Color.clear

                VStack(spacing: 0) {

                    Color.clear
                        .frame(height: 100)

                    Group {
                        if userItems.isEmpty {
                            addUserButtonGrid
                        } else {
                            userGrid
                        }
                    }
                    .focusSection()
                }
                .scrollIfLargerThanContainer(padding: 100)
                .scrollViewOffset($scrollViewOffset)
            }
            .isEditing(isEditingUsers)

            SelectUserBottomBar(
                isEditing: $isEditingUsers,
                serverSelection: $serverSelection,
                selectedServer: selectedServer,
                servers: viewModel.servers.keys,
                areUsersSelected: selectedUsers.isNotEmpty,
                hasUsers: userItems.isNotEmpty
            ) {
                isPresentingConfirmDeleteUsers = true
            } toggleAllUsersSelected: {
                if selectedUsers.isNotEmpty {
                    selectedUsers.removeAll()
                } else {
                    selectedUsers.insert(contentsOf: userItems.map(\.user))
                }
            }
            .focusSection()
        }
        .animation(.linear(duration: 0.1), value: scrollViewOffset)
        .environment(\.isOverComplexContent, true)
        .background {
            if selectUserUseSplashscreen, splashScreenImageSources.isNotEmpty {
                ZStack {
                    ImageView(splashScreenImageSources)
                        .pipeline(.Swiftfin.local)
                        .aspectRatio(contentMode: .fill)
                        .id(splashScreenImageSources)
                        .transition(.opacity)
                        .animation(.linear, value: splashScreenImageSources)

                    Color.black
                        .opacity(0.9)
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Connect to Server View

    private var connectToServerView: some View {
        VStack(spacing: 50) {
            Text(L10n.connectToJellyfinServerStart)
                .font(.body)
                .frame(minWidth: 50, maxWidth: 500)
                .multilineTextAlignment(.center)

            Button {
                router.route(to: .connectToServer)
            } label: {
                Text(L10n.connect)
                    .font(.callout)
                    .fontWeight(.bold)
                    .frame(width: 400, height: 75)
                    .background(Color.jellyfinPurple)
            }
            .buttonStyle(.card)
        }
    }

    // MARK: - Functions

    private func didDelete(_ server: ServerState) {
        viewModel.getServers()

        if case let SelectUserServerSelection.server(id: id) = serverSelection, server.id == id {
            if viewModel.servers.keys.count == 1, let first = viewModel.servers.keys.first {
                serverSelection = .server(id: first.id)
            } else {
                serverSelection = .all
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if viewModel.servers.isEmpty {
                connectToServerView
            } else {
                contentView
            }
        }
        .ignoresSafeArea()
        .navigationBarBranding()
        .onAppear {
            viewModel.getServers()
            routePendingReauthenticationIfNeeded()
        }
        .onChange(of: isEditingUsers) {
            guard !isEditingUsers else { return }
            selectedUsers.removeAll()
        }
        .onChange(of: isPresentingLocalPin) {
            if isPresentingLocalPin {
                pin = ""
            } else {
                selectedUsers.removeAll()
            }
        }
        .onChange(of: isPresentingConfirmDeleteUsers) {
            // Clear the user inserted by a context menu delete that was
            // cancelled; keep selections when cancelling in edit mode
            guard !isPresentingConfirmDeleteUsers, !isEditingUsers else { return }
            selectedUsers.removeAll()
        }
        .onChange(of: viewModel.servers.keys) {
            let newValue = viewModel.servers.keys

            if case let SelectUserServerSelection.server(id: id) = serverSelection,
               !newValue.contains(where: { $0.id == id })
            {
                if newValue.count == 1, let firstServer = newValue.first {
                    let newSelection = SelectUserServerSelection.server(id: firstServer.id)
                    serverSelection = newSelection
                    selectUserAllServersSplashscreen = newSelection
                } else {
                    serverSelection = .all
                    selectUserAllServersSplashscreen = .all
                }
            }

            routePendingReauthenticationIfNeeded()
        }
        .onReceive(viewModel.events) { event in
            switch event {
            case let .signedIn(user):
                Defaults[.lastSignedInUserID] = .signedIn(userID: user.id)
                Container.shared.currentUserSession.reset()
                selectedUsers.removeAll()
                Notifications[.didSignIn].post()
            }
        }
        .onNotification(.didConnectToServer) { server in
            viewModel.getServers()
            serverSelection = .server(id: server.id)
        }
        .onNotification(.didChangeCurrentServerURL) { _ in
            viewModel.getServers()
        }
        .onNotification(.didDeleteServer) { _ in
            viewModel.getServers()
        }
        .confirmationDialog(
            Text(L10n.deleteUser),
            isPresented: $isPresentingConfirmDeleteUsers
        ) {
            Button(L10n.delete, role: .destructive) {
                viewModel.deleteUsers(selectedUsers)
                isEditingUsers = false
                selectedUsers.removeAll()
            }
        } message: {
            if selectedUsers.count == 1, let first = selectedUsers.first {
                Text(L10n.deleteUserSingleConfirmation(first.username))
            } else {
                Text(L10n.deleteUserMultipleConfirmation(selectedUsers.count))
            }
        }
        .alert(L10n.signIn, isPresented: $isPresentingLocalPin) {

            Backport.textField(L10n.pin, text: $pin)
                .keyboardType(.numberPad)

            Button(L10n.signIn) {
                guard let user = selectedUsers.first else {
                    assertionFailure("User not selected")
                    return
                }
                select(user: user, needsPin: false)
            }

            Button(L10n.cancel, role: .cancel) {}
        } message: {
            if let user = selectedUsers.first, user.pinHint.isNotEmpty {
                Text(user.pinHint)
            } else {
                let username = selectedUsers.first?.username ?? .emptyDash

                Text(L10n.enterPinForUser(username))
            }
        }
        .errorMessage($viewModel.error)
    }
}
