//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

/// Audio output mode for video playback.
///
/// Controls how surround sound content is handled when played through
/// devices with different speaker configurations.
enum AudioOutputMode: String, CaseIterable, Displayable, Storable {

    /// System Default - no override applied; VLC respects the Apple TV's
    /// audio output configuration. Recommended for most users.
    case systemDefault

    /// Automatic with forced downmix - disables passthrough so VLC
    /// software-decodes surround and mixes to stereo. Use if Atmos/AC3
    /// content isn't routing correctly to stereo speakers.
    case auto

    /// Force stereo - explicitly requests 2-channel output as a fallback
    /// if Auto mode doesn't work correctly
    case stereo

    /// Passthrough - send raw audio bitstream to receiver for decoding
    /// Only use if you have a receiver/soundbar that supports surround decoding
    case passthrough

    var displayTitle: String {
        switch self {
        case .systemDefault:
            return L10n.systemDefault
        case .auto:
            return L10n.auto
        case .stereo:
            return L10n.stereo
        case .passthrough:
            return L10n.passthrough
        }
    }

    var description: String {
        switch self {
        case .systemDefault:
            return "Use your Apple TV's audio settings (recommended)"
        case .auto:
            return "Force software downmix of surround to stereo"
        case .stereo:
            return "Force stereo output if Auto doesn't work"
        case .passthrough:
            return "Send raw audio to receiver (requires compatible hardware)"
        }
    }
}
