//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

// MARK: - TVTabView

/// Container view that combines TV Shows and Live TV into a single tab
/// with horizontal sub-navigation. This reduces main tab bar clutter.
struct TVTabView: View {

    // MARK: - Section Enum

    enum Section: String, CaseIterable, Identifiable {
        case tvShows
        case liveTV

        var id: String {
            rawValue
        }

        var displayTitle: String {
            switch self {
            case .tvShows:
                L10n.tvShows
            case .liveTV:
                L10n.liveTV
            }
        }

        var systemImage: String {
            switch self {
            case .tvShows:
                "tv"
            case .liveTV:
                "antenna.radiowaves.left.and.right"
            }
        }
    }

    // MARK: - State

    @State
    private var selectedSection: Section = .tvShows

    @FocusState
    private var focusedSection: Section?

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            sectionPicker
                .padding(.top, 20)
                .padding(.bottom, 30)

            contentView
                .focusSection()
        }
    }

    // MARK: - Section Picker

    /// Horizontal button row for switching between TV Shows and Live TV
    private var sectionPicker: some View {
        HStack(spacing: 20) {
            ForEach(Section.allCases) { section in
                sectionButton(for: section)
            }
        }
        .focusSection()
    }

    private func sectionButton(for section: Section) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 8) {
                Image(systemName: section.systemImage)
                Text(section.displayTitle)
            }
            .font(.headline)
            .fontWeight(.semibold)
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .if(selectedSection == section) { view in
                view
                    .background(.white)
                    .foregroundColor(.black)
            }
        }
        .buttonStyle(.card)
        .focused($focusedSection, equals: section)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch selectedSection {
        case .tvShows:
            tvShowsContent
        case .liveTV:
            liveContent
        }
    }

    // MARK: - TV Shows Content

    /// Displays the TV series library using the existing PagingLibraryView
    @ViewBuilder
    private var tvShowsContent: some View {
        let viewModel = ItemLibraryViewModel(
            filters: .init(itemTypes: [.series])
        )
        PagingLibraryView(viewModel: viewModel)
    }

    // MARK: - Live TV Content

    /// Placeholder view for Live TV (Coming Soon)
    private var liveContent: some View {
        VStack(spacing: 30) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 100))
                .foregroundColor(.secondary)

            Text(L10n.liveTV)
                .font(.title)
                .fontWeight(.bold)

            Text("Coming Soon")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
