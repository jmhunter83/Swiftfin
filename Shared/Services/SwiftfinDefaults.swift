//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import Factory
import Foundation
import Logging
import SwiftUI
import UIKit

// TODO: organize
// TODO: all user settings could be moved to `StoredValues`?

// Note: Only use Defaults for basic single-value settings.
//       For larger data types and collections, use `StoredValue` instead.

// MARK: Error Handling

enum DefaultsError: LocalizedError {
    case suiteCreationFailed(suiteName: String)

    var errorDescription: String? {
        switch self {
        case let .suiteCreationFailed(suiteName):
            return "Failed to create UserDefaults suite '\(suiteName)'"
        }
    }

    var recoverySuggestion: String? {
        "Using standard defaults as fallback. Check storage and restart."
    }
}

private let logger = Logger.swiftfin()

// MARK: Suites

extension UserDefaults {

    // MARK: App

    /// Settings that should apply to the app
    static let appSuite: UserDefaults = {
        guard let suite = UserDefaults(suiteName: "swiftfinApp") else {
            logger.critical("Failed to create appSuite, falling back to .standard", metadata: ["suite": "swiftfinApp"])
            return .standard
        }
        return suite
    }()

    // MARK: Usser

    // TODO: the Factory resolver cannot be used because it would cause freezes, but
    //       the Defaults value should always be in sync with the latest user and what
    //       views properly expect. However, this feels like a hack and should be changed?
    static var currentUserSuite: UserDefaults {
        switch Defaults[.lastSignedInUserID] {
        case .signedOut:
            return userSuite(id: "default")
        case let .signedIn(userID):
            return userSuite(id: userID)
        }
    }

    static func userSuite(id: String) -> UserDefaults {
        guard let suite = UserDefaults(suiteName: id) else {
            logger.critical("Failed to create userSuite, falling back to .standard", metadata: ["suite": "\(id)"])
            return .standard
        }
        return suite
    }
}

private extension Defaults.Keys {

    static func AppKey<Value: Defaults.Serializable>(_ name: String) -> Key<Value?> {
        Key(name, suite: .appSuite)
    }

    static func AppKey<Value: Defaults.Serializable>(_ name: String, default: Value) -> Key<Value> {
        Key(name, default: `default`, suite: .appSuite)
    }

    static func UserKey<Value: Defaults.Serializable>(_ name: String, default: Value) -> Key<Value> {
        Key(name, default: `default`, suite: .currentUserSuite)
    }
}

// MARK: App

extension Defaults.Keys {

    /// The _real_ accent color key to be used.
    ///
    /// This is set externally whenever the app or user accent colors change,
    /// depending on the current app state.
    static var accentColor: Key<Color> = AppKey("accentColor", default: .jellyfinPurple)

    /// The _real_ appearance key to be used.
    ///
    /// This is set externally whenever the app or user appearances change,
    /// depending on the current app state.
    static let appearance: Key<AppAppearance> = AppKey("appearance", default: .system)

    /// The appearance default for non-user contexts.
    /// /// Only use for `set`, use `appearance` for `get`.
    static let appAppearance: Key<AppAppearance> = AppKey("appAppearance", default: .system)

    static let backgroundSignOutInterval: Key<TimeInterval> = AppKey("backgroundSignOutInterval", default: 3600)
    static let backgroundTimeStamp: Key<Date> = AppKey("backgroundTimeStamp", default: Date.now)
    static let lastSignedInUserID: Key<UserSignInState> = AppKey("lastSignedInUserID", default: .signedOut)

    static let selectUserDisplayType: Key<LibraryDisplayType> = AppKey("selectUserDisplayType", default: .grid)
    static let selectUserServerSelection: Key<SelectUserServerSelection> = AppKey("selectUserServerSelection", default: .all)
    static let selectUserAllServersSplashscreen: Key<SelectUserServerSelection> = AppKey("selectUserAllServersSplashscreen", default: .all)
    static let selectUserUseSplashscreen: Key<Bool> = AppKey("selectUserUseSplashscreen", default: true)

    static let signOutOnBackground: Key<Bool> = AppKey("signOutOnBackground", default: true)
    static let signOutOnClose: Key<Bool> = AppKey("signOutOnClose", default: false)
}

// MARK: User

extension Defaults.Keys {

    /// The accent color default for user contexts.
    /// Only use for `set`, use `accentColor` for `get`.
    static var userAccentColor: Key<Color> {
        UserKey("userAccentColor", default: .jellyfinPurple)
    }

    /// The appearance default for user contexts.
    /// /// Only use for `set`, use `appearance` for `get`.
    static var userAppearance: Key<AppAppearance> {
        UserKey("userAppearance", default: .system)
    }

    enum Customization {

        static let itemViewType: Key<ItemViewType> = UserKey("itemViewType", default: .compactLogo)

        static let showPosterLabels: Key<Bool> = UserKey("showPosterLabels", default: true)
        static let nextUpPosterType: Key<PosterDisplayType> = UserKey("nextUpPosterType", default: .portrait)
        static let recentlyAddedPosterType: Key<PosterDisplayType> = UserKey("recentlyAddedPosterType", default: .portrait)
        static let latestInLibraryPosterType: Key<PosterDisplayType> = UserKey("latestInLibraryPosterType", default: .portrait)
        static let shouldShowMissingSeasons: Key<Bool> = UserKey("shouldShowMissingSeasons", default: true)
        static let shouldShowMissingEpisodes: Key<Bool> = UserKey("shouldShowMissingEpisodes", default: true)
        static let similarPosterType: Key<PosterDisplayType> = UserKey("similarPosterType", default: .portrait)

        // TODO: have search poster type by types of items if applicable
        static let searchPosterType: Key<PosterDisplayType> = UserKey("searchPosterType", default: .portrait)

        enum CinematicItemViewType {

            static let usePrimaryImage: Key<Bool> = UserKey("cinematicItemViewTypeUsePrimaryImage", default: false)
        }

        enum Episodes {

            static let useSeriesLandscapeBackdrop: Key<Bool> = UserKey("useSeriesBackdrop", default: true)
        }

        enum Indicators {

            static let showFavorited: Key<Bool> = UserKey("showFavoritedIndicator", default: true)
            static let showProgress: Key<Bool> = UserKey("showProgressIndicator", default: true)
            static let showUnplayed: Key<Bool> = UserKey("showUnplayedIndicator", default: true)
            static let showPlayed: Key<Bool> = UserKey("showPlayedIndicator", default: true)
        }

        enum Library {

            static let cinematicBackground: Key<Bool> = UserKey("libraryCinematicBackground", default: true)
            static let enabledDrawerFilters: Key<[ItemFilterType]> = UserKey(
                "libraryEnabledDrawerFilters",
                default: ItemFilterType.allCases
            )
            static let letterPickerEnabled: Key<Bool> = UserKey("letterPickerEnabled", default: false)
            static let letterPickerOrientation: Key<LetterPickerOrientation> = .init(
                "letterPickerOrientation", default: .trailing
            )
            static let displayType: Key<LibraryDisplayType> = UserKey("libraryViewType", default: .grid)
            static let posterType: Key<PosterDisplayType> = UserKey("libraryPosterType", default: .portrait)
            static let listColumnCount: Key<Int> = UserKey("listColumnCount", default: 1)
            static let randomImage: Key<Bool> = UserKey("libraryRandomImage", default: true)
            static let showFavorites: Key<Bool> = UserKey("libraryShowFavorites", default: true)

            static let rememberLayout: Key<Bool> = UserKey("libraryRememberLayout", default: false)
            static let rememberSort: Key<Bool> = UserKey("libraryRememberSort", default: false)
        }

        enum Home {
            static let showRecentlyAdded: Key<Bool> = UserKey("showRecentlyAdded", default: true)
            static let resumeNextUp: Key<Bool> = UserKey("homeResumeNextUp", default: false)
            static let maxNextUp: Key<TimeInterval> = UserKey(
                "homeMaxNextUp",
                default: 366 * 86400
            )
        }

        enum Search {

            static let enabledDrawerFilters: Key<[ItemFilterType]> = UserKey(
                "searchEnabledDrawerFilters",
                default: ItemFilterType.allCases
            )
        }
    }

    enum VideoPlayer {

        static let appMaximumBitrate: Key<PlaybackBitrate> = UserKey("appMaximumBitrate", default: .max)
        static let appMaximumBitrateTest: Key<PlaybackBitrateTestSize> = UserKey("appMaximumBitrateTest", default: .regular)
        static let autoPlayEnabled: Key<Bool> = UserKey("autoPlayEnabled", default: true)
        static let barActionButtons: Key<[VideoPlayerActionButton]> = UserKey(
            "barActionButtons",
            default: VideoPlayerActionButton.defaultBarActionButtons
        )
        static let jumpBackwardInterval: Key<MediaJumpInterval> = UserKey("jumpBackwardLength", default: .fifteen)
        static let jumpForwardInterval: Key<MediaJumpInterval> = UserKey("jumpForwardLength", default: .fifteen)
        static let menuActionButtons: Key<[VideoPlayerActionButton]> = UserKey(
            "menuActionButtons",
            default: VideoPlayerActionButton.defaultMenuActionButtons
        )
        static let resumeOffset: Key<Int> = UserKey("resumeOffset", default: 0)

        // Audio/Subtitle sync offsets (milliseconds)
        static let audioOffset: Key<Int> = UserKey("audioOffset", default: 0)
        static let subtitleOffset: Key<Int> = UserKey("subtitleOffset", default: 0)

        static let videoPlayerType: Key<VideoPlayerType> = UserKey("videoPlayerType", default: .swiftfin)

        enum Gesture {

            static let horizontalPanAction: Key<PanGestureAction> = UserKey("videoPlayerHorizontalPanGesture", default: .none)
            static let horizontalSwipeAction: Key<SwipeGestureAction> = UserKey("videoPlayerhorizontalSwipeAction", default: .none)
            static let longPressAction: Key<LongPressGestureAction> = UserKey("videoPlayerLongPressGesture", default: .gestureLock)
            static let multiTapGesture: Key<MultiTapGestureAction> = UserKey("videoPlayerMultiTapGesture", default: .none)
            static let doubleTouchGesture: Key<DoubleTouchGestureAction> = UserKey("videoPlayerDoubleTouchGesture", default: .none)
            static let pinchGesture: Key<PinchGestureAction> = UserKey("videoPlayerSwipeGesture", default: .aspectFill)
            static let verticalPanLeftAction: Key<PanGestureAction> = UserKey("videoPlayerverticalPanLeftAction", default: .none)
            static let verticalPanRightAction: Key<PanGestureAction> = UserKey("videoPlayerverticalPanRightAction", default: .none)
        }

        enum Overlay {

            static let chapterSlider: Key<Bool> = UserKey("chapterSlider", default: true)

            /// Timestamp
            static let trailingTimestampType: Key<TrailingTimestampType> = UserKey("trailingTimestamp", default: .timeLeft)
        }

        enum Playback {
            static let appMaximumBitrate: Key<PlaybackBitrate> = UserKey("appMaximumBitrate", default: .auto)
            static let appMaximumBitrateTest: Key<PlaybackBitrateTestSize> = UserKey("appMaximumBitrateTest", default: .regular)
            static let compatibilityMode: Key<PlaybackCompatibility> = UserKey("compatibilityMode", default: .auto)
            static let customDeviceProfileAction: Key<CustomDeviceProfileAction> = UserKey("customDeviceProfileAction", default: .add)
            static let rates: Key<[Float]> = UserKey("videoPlayerPlaybackRates", default: [0.5, 1.0, 1.25, 1.5, 2.0])
        }

        // TODO: transition into a SubtitleConfiguration instead of multiple types
        enum Subtitle {

            static let subtitleColor: Key<Color> = UserKey("subtitleColor", default: .white)
            static let subtitleFontName: Key<String> = UserKey("subtitleFontName", default: UIFont.systemFont(ofSize: 14).fontName)
            static let subtitleSize: Key<Int> = UserKey("subtitleSize", default: 9)
        }

        enum Audio {
            /// Preferred audio language code (ISO 639-2, e.g., "eng", "spa", "jpn")
            static let preferredLanguage: Key<String> = UserKey("preferredAudioLanguage", default: "eng")
            /// Audio output mode for handling surround sound on stereo devices
            static let outputMode: Key<AudioOutputMode> = UserKey("audioOutputMode", default: .systemDefault)

            // MARK: ReplayGain (Audio Normalization)

            /// Enable ReplayGain volume normalization for audio tracks
            static let replayGainEnabled: Key<Bool> = UserKey("replayGainEnabled", default: false)
            /// ReplayGain mode: track (per-track) or album (preserve album dynamics)
            static let replayGainMode: Key<ReplayGainMode> = UserKey("replayGainMode", default: .track)
            /// Pre-amplification adjustment in dB (-12 to +12), added to ReplayGain value
            static let replayGainPreAmp: Key<Float> = UserKey("replayGainPreAmp", default: 0.0)
            /// Prevent clipping by limiting positive gains to 0 dB
            static let replayGainPreventClipping: Key<Bool> = UserKey("replayGainPreventClipping", default: true)
        }

        enum Transition {
            static let pauseOnBackground: Key<Bool> = UserKey("playInBackground", default: true)
        }
    }

    /// Experimental settings
    enum Experimental {

        static let downloads: Key<Bool> = UserKey("experimentalDownloads", default: false)
    }

    // tvos specific
    static let downActionShowsMenu: Key<Bool> = UserKey("downActionShowsMenu", default: true)
    static let confirmClose: Key<Bool> = UserKey("confirmClose", default: false)
}

// MARK: Debug

#if DEBUG

extension UserDefaults {

    static let debugSuite: UserDefaults = {
        guard let suite = UserDefaults(suiteName: "swiftfinstore-debug-defaults") else {
            logger.critical("Failed to create debugSuite, falling back to .standard", metadata: ["suite": "swiftfinstore-debug-defaults"])
            return .standard
        }
        return suite
    }()
}

extension Defaults.Keys {

    static func DebugKey<Value: Defaults.Serializable>(_ name: String, default: Value) -> Key<Value> {
        Key(name, default: `default`, suite: .appSuite)
    }

    static let sendProgressReports: Key<Bool> = DebugKey("sendProgressReports", default: true)
}
#endif
