//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI

/// Native tvOS transport bar glass background
/// Uses Liquid Glass effect on tvOS 26+ with vibrancy fallback for older versions
struct TransportBarBackground: View {

    var body: some View {
        #if os(tvOS)
        if #available(tvOS 26.0, *) {
            // tvOS 26+ Liquid Glass effect
            // Use a fillable shape (not Color.clear) so the glass anchors to
            // the host view's frame instead of all available space.
            RoundedRectangle(cornerRadius: 24)
                .fill(.black.opacity(0.001))
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
        } else if #available(tvOS 18.0, *) {
            // tvOS 18-25 - lighter, more transparent background
            RoundedRectangle(cornerRadius: 24)
                .fill(.black.opacity(0.4))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.3), radius: 20, y: 8)
        } else {
            // tvOS 17 fallback - lighter
            RoundedRectangle(cornerRadius: 24)
                .fill(.black.opacity(0.4))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                }
        }
        #else
        EmptyView()
        #endif
    }
}
