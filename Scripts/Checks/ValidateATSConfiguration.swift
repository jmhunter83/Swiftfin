#!/usr/bin/env swift

//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Darwin
import Foundation

func fail(_ message: String) -> Never {
    fputs("ATS configuration validation failed: \(message)\n", stderr)
    exit(1)
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let infoPlistURL = repositoryRoot.appendingPathComponent("Swiftfin tvOS/Resources/Info.plist")

guard let plistData = try? Data(contentsOf: infoPlistURL) else {
    fail("Unable to read \(infoPlistURL.path)")
}

guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
    fail("Unable to parse Info.plist as a dictionary")
}

guard let ats = plist["NSAppTransportSecurity"] as? [String: Any] else {
    fail("Missing NSAppTransportSecurity dictionary")
}

let hasArbitraryLoads = (ats["NSAllowsArbitraryLoads"] as? Bool) == true
let hasLocalNetworkingKey = ats["NSAllowsLocalNetworking"] != nil

if !hasArbitraryLoads {
    fail("Expected NSAllowsArbitraryLoads to be true")
}

if hasLocalNetworkingKey {
    fail("NSAllowsLocalNetworking must not be present when using NSAllowsArbitraryLoads")
}

print("ATS configuration check passed")
