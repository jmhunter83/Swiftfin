//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import JellyfinAPI
import SwiftUI

// TODO: Represent all playback information
//       - jellyfin session doesn't give much anyways
// TODO: have proxies be a `PlaybackInformationProvider`
//       - be labeled pair information

class PlaybackInformationSupplement: ObservableObject, MediaPlayerSupplement {

    let displayTitle: String = L10n.session
    let itemID: String
    let provider: PlaybackInformationProvider

    var id: String {
        "PlaybackInformation-\(itemID)"
    }

    init(itemID: String) {
        self.itemID = itemID
        self.provider = .init(itemID: itemID)
    }

    var videoPlayerBody: some PlatformView {
        OverlayView(viewModel: provider)
    }
}

extension PlaybackInformationSupplement {

    private struct OverlayView: PlatformView {

        @ObservedObject
        var viewModel: PlaybackInformationProvider

        var iOSView: some View {
            VStack {
                if let session = viewModel.playbackSession {
                    Text(session.userName ?? "Unknown User")
                        .font(.caption)
                        .padding(6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding()
                }
            }
        }

        var tvOSView: some View {
            EmptyView()
        }
    }
}

class PlaybackInformationProvider: ViewModel, MediaPlayerObserver {

    @Published
    var playbackSession: SessionInfoDto? = nil

    weak var manager: MediaPlayerManager?

    private let itemID: String
    private let timer = PokeIntervalTimer()

    private var playbackSessionTask: AnyCancellable?

    init(itemID: String) {
        self.itemID = itemID
        super.init()

        timer.poke(interval: 5)
        timer.sink { [weak self] in
            self?.getCurrentSession()
            self?.timer.poke()
        }
        .store(in: &cancellables)
    }

    private func getCurrentSession() {
        playbackSessionTask?.cancel()

        playbackSessionTask = Task {
            let session = try requireSession()
            let parameters = Paths.GetSessionsParameters(
                deviceID: session.client.configuration.deviceID
            )
            let request = Paths.getSessions(
                parameters: parameters
            )

            let response = try await session.client.send(request)
            guard let matchingSession = response.value.first(where: {
                $0.nowPlayingItem?.id == itemID
            }) else {
                return
            }

            await MainActor.run {
                self.playbackSession = matchingSession
            }
        }
        .asAnyCancellable()
    }
}
