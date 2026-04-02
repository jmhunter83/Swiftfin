//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import CoreStore
import Defaults
import Factory
import Logging
import Nuke
import Pulse
import PulseLogHandler
import SwiftUI

@main
struct SwiftfinApp: App {

    init() {

        // Logging
        LoggingSystem.bootstrap { label in

            let handlers: [any LogHandler] = [PersistentLogHandler(label: label)]
            #if DEBUG
                .appending(SwiftfinConsoleHandler())
            #endif

            var multiplexHandler = MultiplexLogHandler(handlers)
            multiplexHandler.logLevel = .trace
            return multiplexHandler
        }

        // CoreStore

        CoreStoreDefaults.dataStack = SwiftfinStore.dataStack
        CoreStoreDefaults.logger = SwiftfinCorestoreLogger()

        // Nuke

        ImageCache.shared.costLimit = 1024 * 1024 * 200 // 200 MB
        ImageCache.shared.ttl = 300 // 5 min

        ImageDecoderRegistry.shared.register { context in
            guard let mimeType = context.urlResponse?.mimeType else { return nil }
            return mimeType.contains("svg") ? ImageDecoders.Empty() : nil
        }

        ImagePipeline.shared = .Swiftfin.posters

        // UIKit

        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: UIColor.label]

        // don't keep last user id
        if Defaults[.signOutOnClose] {
            Defaults[.lastSignedInUserID] = .signedOut
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onNotification(.applicationDidEnterBackground) {
                    Defaults[.backgroundTimeStamp] = Date.now

                    // Stop video playback when the app is backgrounded (e.g. Home button).
                    // Background audio playback is allowed, so only stop non-audio items.
                    let mediaPlayerManager = Container.shared.mediaPlayerManager()
                    let hasActivePlayback: Bool = {
                        switch mediaPlayerManager.state {
                        case .loadingItem:
                            // Item is in-flight; allow canceling even before a session is established.
                            return true
                        case .playback:
                            // Avoid treating the placeholder manager as "active playback".
                            return mediaPlayerManager.playbackItem?.playSessionID.isNotEmpty == true
                        default:
                            return false
                        }
                    }()
                    let isAudioItem = mediaPlayerManager.item.type == .audio || mediaPlayerManager.item.type == .audioBook

                    if hasActivePlayback, !isAudioItem {
                        // Snapshot position before teardown so the stop report captures it
                        // even if proxy.stop() resets the seconds value.
                        let capturedSeconds = mediaPlayerManager.seconds

                        mediaPlayerManager.proxy?.stop()

                        // Restore captured position so the observer's stop report reads it.
                        if capturedSeconds > .zero {
                            mediaPlayerManager.seconds = capturedSeconds
                        }

                        mediaPlayerManager.stop()
                    }
                }
                .onNotification(.applicationWillEnterForeground) {
                    let backgroundedInterval = Date.now.timeIntervalSince(Defaults[.backgroundTimeStamp])
                    let mediaPlayerManager = Container.shared.mediaPlayerManager()
                    let hasActivePlayback = (
                        mediaPlayerManager.state == .loadingItem ||
                            mediaPlayerManager.state == .playback
                    ) && mediaPlayerManager.item.type == .audio

                    if Defaults[.signOutOnBackground],
                       backgroundedInterval > Defaults[.backgroundSignOutInterval],
                       !hasActivePlayback
                    {
                        Defaults[.lastSignedInUserID] = .signedOut
                        Container.shared.currentUserSession.reset()
                        Notifications[.didSignOut].post()
                    } else {
                        // Refresh data after returning from background to pick up
                        // watch progress from other Jellyfin clients
                        Notifications[.didRequestGlobalRefresh].post()
                    }
                }
        }
    }
}
