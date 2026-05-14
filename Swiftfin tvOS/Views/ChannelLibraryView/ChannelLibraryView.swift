//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import CollectionVGrid
import Foundation
import JellyfinAPI
import SwiftUI

struct ChannelLibraryView: View {

    @Router
    private var router

    @StateObject
    private var viewModel = ChannelLibraryViewModel()

    private var contentView: some View {
        CollectionVGrid(
            uniqueElements: viewModel.elements,
            layout: .columns(3, insets: .init(0), itemSpacing: 25, lineSpacing: 25)
        ) { channel in
            WideChannelGridItem(channel: channel)
                .onSelect {
                    guard channel.channel.mediaSources?.first != nil else { return }
                    guard let session = viewModel.currentSession else { return }
                    let provider = channel.channel.getPlaybackItemProvider(userSession: session)
                    router.route(to: .videoPlayer(provider: provider))
                }
        }
        .onReachedBottomEdge(offset: .offset(300)) {
            viewModel.send(.getNextPage)
        }
    }

    private var viewState: StateContainer<AnyView, EmptyStateView>.ViewState {
        switch viewModel.state {
        case .content:
            if viewModel.elements.isEmpty {
                return .empty
            }
            return .content
        case let .error(error):
            return .error(error)
        case .initial, .refreshing:
            return .loading
        }
    }

    var body: some View {
        StateContainer(
            state: viewState,
            emptyMessage: L10n.noResults,
            emptySystemImage: "tv"
        ) {
            contentView
                .eraseToAnyView()
        }
        .animation(.linear(duration: 0.1), value: viewModel.state)
        .ignoresSafeArea()
        .refreshable {
            viewModel.send(.refresh)
        }
        .onFirstAppear {
            if viewModel.state == .initial {
                viewModel.send(.refresh)
            }
        }
        .sinceLastDisappear { interval in
            // refresh after 3 hours
            if interval >= 10800 {
                viewModel.send(.refresh)
            }
        }
    }
}
