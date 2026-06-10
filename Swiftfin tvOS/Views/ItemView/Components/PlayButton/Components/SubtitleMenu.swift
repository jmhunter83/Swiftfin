//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
import SwiftUI

extension ItemView {

    struct SubtitleMenu: View {

        @Binding
        var selectedSubtitleStreamIndex: Int?

        let subtitleStreams: [MediaStream]

        var body: some View {
            Menu(L10n.subtitles, systemImage: "captions.bubble") {
                Picker(L10n.subtitles, selection: $selectedSubtitleStreamIndex) {
                    Text(L10n.auto)
                        .tag(nil as Int?)

                    Text(L10n.none)
                        .tag(-1 as Int?)

                    ForEach(subtitleStreams, id: \.index) { stream in
                        Text(stream.formattedSubtitleTitle)
                            .tag(stream.index)
                    }
                }
            }
            .labelStyle(.iconOnly)
            .font(.title3)
            .buttonStyle(.tintedMaterial(tint: .secondary, foregroundColor: .white))
        }
    }
}
