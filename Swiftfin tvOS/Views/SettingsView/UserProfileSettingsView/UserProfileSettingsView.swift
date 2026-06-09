//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

struct UserProfileSettingsView: View {

    @Router
    private var router

    @ObservedObject
    private var viewModel: SettingsViewModel

    @State
    private var isPresentingConfirmReset: Bool = false

    init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    private func profileImage(for session: UserSession) -> some View {
        UserProfileImage(
            userID: session.user.id,
            source: session.user.profileImageSource(
                client: session.client
            )
        )
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: 400)
    }

    var body: some View {
        if let session = viewModel.currentSession {
            content(for: session)
        } else {
            ErrorView(error: ErrorMessage(L10n.unauthorizedUser))
                .navigationTitle(L10n.user)
        }
    }

    private func content(for session: UserSession) -> some View {
        Form(content: {
            Section {
                ChevronButton(L10n.security) {
                    router.route(to: .localSecurity)
                }
            }

            // TODO: Do we want this option on tvOS?
//            Section {
//                // TODO: move under future "Storage" tab
//                //       when downloads implemented
//                Button(L10n.resetSettings) {
//                    isPresentingConfirmReset = true
//                }
//                .foregroundStyle(.red)
//            } footer: {
//                Text(L10n.resetSettingsDescription)
//            }
        }, image: { profileImage(for: session) })
            .navigationTitle(L10n.user)
            .confirmationDialog(
                L10n.resetSettings,
                isPresented: $isPresentingConfirmReset,
                titleVisibility: .visible
            ) {
                Button(L10n.reset, role: .destructive) {
                    guard let session = viewModel.currentSession else { return }
                    do {
                        try session.user.deleteSettings()
                    } catch {
                        viewModel.logger.error("Unable to reset user settings: \(error.localizedDescription)")
                    }
                }
            } message: {
                Text(L10n.resetSettingsMessage)
            }
    }
}
