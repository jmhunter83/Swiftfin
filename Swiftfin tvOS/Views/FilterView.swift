//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
import SwiftUI

struct FilterView: View {

    @Default(.accentColor)
    private var accentColor

    @Binding
    private var selection: [AnyItemFilter]

    @ObservedObject
    private var viewModel: FilterViewModel

    private let type: ItemFilterType

    private init(
        selection: Binding<[AnyItemFilter]>,
        viewModel: FilterViewModel,
        type: ItemFilterType
    ) {
        self._selection = selection
        self.viewModel = viewModel
        self.type = type
    }

    private var filterSource: [AnyItemFilter] {
        viewModel.allFilters[keyPath: type.collectionAnyKeyPath]
    }

    private func isSelected(_ filter: AnyItemFilter) -> Bool {
        selection.contains(filter)
    }

    private func select(_ filter: AnyItemFilter) {
        switch type.selectorType {
        case .single:
            selection = [filter]
        case .multi:
            if let index = selection.firstIndex(of: filter) {
                selection.remove(at: index)
            } else {
                selection.append(filter)
            }
        }
    }

    var body: some View {
        Form(systemImage: type.systemImage) {
            Section {
                Button(L10n.reset) {
                    viewModel.send(.reset(type))
                }
                .disabled(!viewModel.isFilterSelected(type: type))
            }

            Section(type.displayTitle) {
                if filterSource.isEmpty {
                    Text(L10n.none)
                        .foregroundStyle(.secondary)
                }

                ForEach(filterSource, id: \.hashValue) { filter in
                    Button {
                        select(filter)
                    } label: {
                        HStack {
                            Text(filter.displayTitle)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if isSelected(filter) {
                                Image(systemName: "checkmark.circle.fill")
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(accentColor.overlayColor, accentColor)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(type.displayTitle)
    }
}

extension FilterView {

    init(
        viewModel: FilterViewModel,
        type: ItemFilterType
    ) {
        let selectionBinding: Binding<[AnyItemFilter]> = Binding {
            viewModel.currentFilters[keyPath: type.collectionAnyKeyPath]
        } set: { newValue in
            viewModel.send(.update(type, newValue))
        }

        self.init(
            selection: selectionBinding,
            viewModel: viewModel,
            type: type
        )
    }
}

extension ItemFilterType {

    var systemImage: String {
        switch self {
        case .genres:
            "theatermasks"
        case .letter:
            "textformat.abc"
        case .sortBy:
            "arrow.up.arrow.down"
        case .sortOrder:
            "arrow.up.arrow.down.circle"
        case .tags:
            "tag"
        case .traits:
            "line.3.horizontal.decrease.circle"
        case .years:
            "calendar"
        }
    }
}
