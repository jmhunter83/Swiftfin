//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import Get

/// Watches an authenticated session client for 401 responses. A 401 on a
/// client that holds a token means the token was revoked server-side, and
/// re-authentication is the only recovery since passwords aren't stored.
///
/// Two 401s within a short window are required so a single proxy blip can't
/// bounce anyone to the sign-in screen, and the notification fires once per
/// session instance.
///
/// Note: supplying a delegate replaces the SDK's default response validation,
/// so the 200..<300 check is replicated here. Auth headers are unaffected -
/// the SDK injects them before consulting this delegate.
final class SessionUnauthorizedDelegate: APIClientDelegate {

    private let requiredCount = 2
    private let window: TimeInterval = 10

    private var recent401s: [Date] = []
    private var hasFired = false
    private let lock = NSLock()

    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        if response.statusCode == 401 {
            registerUnauthorized()
        }

        guard (200 ..< 300).contains(response.statusCode) else {
            throw APIError.unacceptableStatusCode(response.statusCode)
        }
    }

    private func registerUnauthorized() {
        lock.lock()
        defer { lock.unlock() }

        guard !hasFired else { return }

        let now = Date()
        recent401s = recent401s.filter { now.timeIntervalSince($0) < window }
        recent401s.append(now)

        guard recent401s.count >= requiredCount else { return }

        hasFired = true
        DispatchQueue.main.async {
            Notifications[.didReceiveSessionUnauthorized].post()
        }
    }
}
