//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

extension LabelStyle where Self == TabItemLabelStyle {

    static func tabItem(title: String) -> TabItemLabelStyle {
        TabItemLabelStyle(title: title)
    }
}

/// Collapses a tab bar item down to its icon, revealing the title only while focused.
///
/// The tab bar hosts this label inside the system tab bar rather than the app's own
/// view hierarchy, so `isFocused` reaching here is not guaranteed by anything we control.
/// If the title stops appearing after an OS update, that propagation is the first suspect.
struct TabItemLabelStyle: LabelStyle {

    @Environment(\.isFocused)
    private var isFocused

    /// Carried separately from `configuration.title` so the tab still announces itself
    /// when the title view isn't in the hierarchy.
    let title: String

    func makeBody(configuration: Configuration) -> some View {
        Group {
            if isFocused {
                HStack(spacing: 8) {
                    configuration.icon

                    configuration.title
                }
            } else {
                configuration.icon
            }
        }
        .animation(.easeInOut(duration: 0.1), value: isFocused)
        .accessibilityLabel(title)
    }
}
