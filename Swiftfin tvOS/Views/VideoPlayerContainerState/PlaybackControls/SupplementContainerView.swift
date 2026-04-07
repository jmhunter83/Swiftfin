//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import IdentifiedCollections
import SwiftUI

struct SupplementContainerView: View {

    @EnvironmentObject
    private var containerState: VideoPlayerContainerState
    @EnvironmentObject
    private var focusGuide: FocusGuide

    @EnvironmentObject
    private var manager: MediaPlayerManager

    @FocusState
    private var focusedSupplementID: AnyMediaPlayerSupplement.ID?
    @FocusState
    private var isFocused: Bool
    @FocusState
    private var isTopBoundaryFocused: Bool

    @State
    private var currentSupplements: IdentifiedArrayOf<AnyMediaPlayerSupplement> = []

    private func supplementContainer(for supplement: some MediaPlayerSupplement) -> some View {
        AlternateLayoutView(alignment: .topLeading) {
            Color.clear
        } content: {
            supplement.videoPlayerBody
        }
    }

    var body: some View {
        VStack(spacing: EdgeInsets.edgePadding) {

            // Hidden top boundary for focus-based dismissal
            Color.clear
                .frame(height: 1)
                .focused($isTopBoundaryFocused)
                .focusable()

            HStack(spacing: 10) {
                if containerState.isGuestSupplement, let supplement = containerState.selectedSupplement {
                    Button(supplement.displayTitle) {
                        containerState.select(supplement: nil)
                    }
                    .focused($focusedSupplementID, equals: supplement.id)
                } else {
                    ForEach(currentSupplements) { supplement in
                        Button(supplement.displayTitle) {}
                            .focused($focusedSupplementID, equals: supplement.id)
                    }
                }
            }
            .buttonStyle(SupplementTitleButtonStyle())
            .padding(.leading, EdgeInsets.edgePadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 75)
            .focusGuide(focusGuide, tag: "supplementTitles", top: "playbackControls")

            ZStack {
                if let supplement = containerState.selectedSupplement {
                    supplementContainer(for: supplement)
                        .eraseToAnyView()
                }
            }
        }
        .isVisible(containerState.isPresentingOverlay)
        .animation(.linear(duration: 0.2), value: containerState.isPresentingOverlay)
        .focusSection()
        .focused($isFocused)
        .onReceive(manager.$supplements) { newValue in
            let newSupplements = IdentifiedArray(
                uniqueElements: newValue.map(AnyMediaPlayerSupplement.init)
            )
            currentSupplements = newSupplements
        }
        .onReceive(containerState.$selectedSupplement) { output in
            if focusedSupplementID != output?.id {
                focusedSupplementID = output?.id
            }
        }
        .onChange(of: isTopBoundaryFocused) { _, _ in
            containerState.select(supplement: nil)
        }
    }
}

struct SupplementTitleButtonStyle: PrimitiveButtonStyle {

    @FocusState
    private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(isFocused ? .black : .white)
            .padding(10)
            .padding(.horizontal, 10)
            .background {
                if isFocused {
                    Rectangle()
                        .foregroundStyle(.white)
                }
            }
            .overlay {
                if !isFocused {
                    RoundedRectangle(cornerRadius: 27)
                        .stroke(Color.white, lineWidth: 4)
                }
            }
            .mask {
                RoundedRectangle(cornerRadius: 27)
            }
            .scaleEffect(
                x: isFocused ? 1.1 : 1,
                y: isFocused ? 1.1 : 1,
                anchor: .init(x: 0.5, y: 0.5)
            )
            .animation(.bouncy(duration: 0.4), value: isFocused)
            .focusable()
            .focused($isFocused)
            .onChange(of: isFocused) { _, newValue in
                if newValue {
                    configuration.trigger()
                }
            }
    }
}
