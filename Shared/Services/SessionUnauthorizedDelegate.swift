//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import Get

/// Watches an authenticated session client for repeated 401 responses. These
/// signal suspected expiry; the coordinator confirms the captured token with
/// the server before changing session state.
///
/// Two 401s within a short window are required so a single proxy blip can't
/// trigger validation. The counter resets after each emitted event.
///
/// Note: supplying a delegate replaces the SDK's default response validation,
/// so the 200..<300 check is replicated here. Auth headers are unaffected -
/// the SDK injects them before consulting this delegate.
final class SessionUnauthorizedDelegate: APIClientDelegate {

    private let event: SessionUnauthorizedEvent
    private let requiredCount: Int
    private let window: TimeInterval
    private let now: () -> Date
    private let onUnauthorized: (SessionUnauthorizedEvent) -> Void

    private var recent401s: [Date] = []
    private let lock = NSLock()

    init(
        event: SessionUnauthorizedEvent,
        requiredCount: Int = 2,
        window: TimeInterval = 10,
        now: @escaping () -> Date = Date.init,
        onUnauthorized: @escaping (SessionUnauthorizedEvent) -> Void = {
            Notifications[.didReceiveSessionUnauthorized].post($0)
        }
    ) {
        self.event = event
        self.requiredCount = requiredCount
        self.window = window
        self.now = now
        self.onUnauthorized = onUnauthorized
    }

    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        if response.statusCode == 401 {
            recordUnauthorized()
        }

        guard (200 ..< 300).contains(response.statusCode) else {
            throw APIError.unacceptableStatusCode(response.statusCode)
        }
    }

    func recordUnauthorized(at date: Date? = nil) {
        lock.lock()

        let currentDate = date ?? now()
        recent401s = recent401s.filter { currentDate.timeIntervalSince($0) < window }
        recent401s.append(currentDate)

        guard recent401s.count >= requiredCount else {
            lock.unlock()
            return
        }

        recent401s.removeAll()
        lock.unlock()

        onUnauthorized(event)
    }
}
