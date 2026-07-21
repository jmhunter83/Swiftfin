//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Factory
import SwiftUI

// TODO: move popup to router
//       - or, make tab view environment object

// TODO: fix weird tvOS icon rendering
struct MainTabView: View {

    #if os(iOS)
    @StateObject
    private var tabCoordinator = TabCoordinator {
        TabItem.home
        TabItem.search
        TabItem.media
    }
    #else
    @StateObject
    private var tabCoordinator = TabCoordinator {
        TabItem.home
        TabItem.media
        TabItem.tv
        TabItem.library(
            title: L10n.movies,
            systemName: "film",
            filters: .init(itemTypes: [.movie])
        )
        TabItem.search
        TabItem.settings
    }
    #endif

    var body: some View {
        TabView(selection: $tabCoordinator.selectedTabID) {
            ForEach(tabCoordinator.tabs, id: \.item.id) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(
                            tab.item.title,
                            systemImage: tab.item.systemImage
                        )
                        .labelStyle(tab.item.labelStyle)
                        .symbolRenderingMode(.monochrome)
                        .eraseToAnyView()
                    }
                    .tag(tab.item.id)
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: TabCoordinator.TabData) -> some View {
        let content = NavigationInjectionView(
            coordinator: tab.coordinator
        ) {
            tab.item.content
        }
        .environmentObject(tabCoordinator)
        .environment(\.tabItemSelected, tab.publisher)

        #if os(tvOS)
        // Menu at a tab root otherwise falls through to the system and
        // suspends the app. Home keeps the system behavior so Menu can
        // still exit from the app root.
        content.if(tab.item.id != TabItem.home.id) { view in
            view.onExitCommand {
                tabCoordinator.selectedTabID = TabItem.home.id
            }
        }
        #else
        content
        #endif
    }
}
