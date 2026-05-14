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
import SwiftUI

struct SettingsView: View {

    @Router
    var router

    #if os(iOS)
    @Default(.userAppearance)
    private var appearance
    #endif

    @Default(.userAccentColor)
    private var accentColor

    @StateObject
    private var viewModel = SettingsViewModel()

    // MARK: - Body

    var body: some View {
        Form(image: .reefyLogo) {
            serverSection
            #if os(tvOS)
            librarySection
            #endif
            videoPlayerSection
            customizationSection
            diagnosticsSection
        }
        #if os(iOS)
        .navigationTitle(L10n.settings)
        .navigationBarCloseButton {
            router.dismiss()
        }
        #endif
    }

    // MARK: - Server Section

    @ViewBuilder
    private var serverSection: some View {
        if let session = viewModel.currentSession {
            Section {
                UserProfileRow(user: session.user.data) {
                    router.route(to: .userProfile(viewModel: viewModel))
                }

                ChevronButton(
                    L10n.server,
                    action: {
                        router.route(to: .editServer(server: session.server))
                    }
                ) {
                    EmptyView()
                } subtitle: {
                    Label {
                        Text(session.server.name)
                    } icon: {
                        if !session.server.isVersionCompatible {
                            Image(systemName: "exclamationmark.circle.fill")
                        }
                    }
                    .labelStyle(.sectionFooterWithImage(imageStyle: .orange))
                }

                #if os(iOS)
                if session.user.permissions.isAdministrator {
                    ChevronButton(L10n.dashboard) {
                        router.route(to: .adminDashboard)
                    }
                }
                #endif
            }
        }

        Section {
            Button(L10n.switchUser) {
                UIDevice.impact(.medium)
                viewModel.signOut()
                router.dismiss()
            }
            .buttonStyle(.primary)
            .foregroundStyle(accentColor.overlayColor, accentColor)
        }
    }

    // MARK: - Library Section

    #if os(tvOS)
    private var librarySection: some View {
        Section(L10n.library) {
            ChevronButton(L10n.media) {
                router.route(to: .media)
            }
        }
    }
    #endif

    // MARK: - Video Player Section

    private var videoPlayerSection: some View {
        Section(L10n.videoPlayer) {
            ChevronButton(L10n.videoPlayer) {
                router.route(to: .videoPlayerSettings)
            }

            ChevronButton(L10n.playbackQuality) {
                router.route(to: .playbackQualitySettings)
            }
        }
    }

    // MARK: - Customization Section

    @ViewBuilder
    private var customizationSection: some View {
        Section(L10n.accessibility) {
            #if os(iOS)
            Picker(L10n.appearance, selection: $appearance)
            #endif

            ChevronButton(L10n.customize) {
                router.route(to: .customizeViewsSettings)
            }
        }

        #if os(iOS)
        Section {
            ColorPicker(L10n.accentColor, selection: $accentColor, supportsOpacity: false)
        } footer: {
            Text(L10n.viewsMayRequireRestart)
        }
        #endif
    }

    // MARK: - Diagnostics Section

    private var diagnosticsSection: some View {
        Section {
            #if DEBUG || !os(tvOS)
            ChevronButton(L10n.logs) {
                router.route(to: .log)
            }
            #endif

            #if DEBUG && os(iOS)
            ChevronButton("Debug") {
                router.route(to: .debugSettings)
            }
            #endif
        }
    }
}
