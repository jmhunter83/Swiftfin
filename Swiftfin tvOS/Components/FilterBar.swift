//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

/// Horizontal row of capsule buttons above a library grid, one per
/// enabled filter type; each pushes a FilterView for that type
struct FilterBar: View {

    @Default(.accentColor)
    private var accentColor
    @Default(.Customization.Library.enabledDrawerFilters)
    private var enabledDrawerFilters

    @ObservedObject
    private var viewModel: FilterViewModel

    @Router
    private var router

    init(viewModel: FilterViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(enabledDrawerFilters, id: \.self) { type in
                    filterButton(for: type)
                }
            }
        }
        .scrollClipDisabled()
        .scrollIndicators(.hidden)
        .focusSection()
    }

    private func filterButton(for type: ItemFilterType) -> some View {
        Button {
            router.route(to: .filter(type: type, viewModel: viewModel))
        } label: {
            HStack(spacing: 8) {
                Text(type.displayTitle)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 20)
            .if(viewModel.isFilterSelected(type: type)) { view in
                view
                    .background(accentColor)
                    .foregroundColor(accentColor.overlayColor)
            }
        }
        .buttonStyle(.card)
    }
}
