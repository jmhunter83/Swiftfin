//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import Get
import JellyfinAPI
import UIKit

extension JellyfinClient.Configuration {

    /// A device ID for a new user, unique so each Jellyfin user gets a distinct
    /// device record and can reuse that record during future reauthentication.
    static func generateDeviceID() -> String {
        "\(UIDevice.platform)_\(UUID().uuidString)"
    }

    /// Configuration for server communication. Authenticated clients pass the
    /// user's stored device ID so the server keeps their device record and
    /// doesn't invalidate another user's token. Nil uses the install-wide base
    /// ID, which is only correct for public, unauthenticated endpoints.
    static func swiftfinConfiguration(
        url: URL,
        deviceID: String? = nil,
        accessToken: String? = nil
    ) -> Self {

        let client = "Swiftfin \(UIDevice.platform)"
        let deviceName = UIDevice.current.name
            .folding(options: .diacriticInsensitive, locale: .current)
            .unicodeScalars
            .filter { CharacterSet.urlQueryAllowed.contains($0) }
            .description
        let baseDeviceID = "\(UIDevice.platform)_\(UIDevice.vendorUUIDString)"
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.1"

        return .init(
            url: url,
            accessToken: accessToken,
            client: client,
            deviceName: deviceName,
            deviceID: deviceID ?? baseDeviceID,
            version: version
        )
    }
}
