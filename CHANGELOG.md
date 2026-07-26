# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

---

## [1.0.0] - App Store Release

**App Store Release**: Reefy is now live on the Apple App Store in 175 countries.

**Version**: 1.0.0 (Build 81)
**Availability**: 175 countries worldwide
**Installation**: Search "Reefy Media Player" on Apple TV App Store

### Added

- **Audio Output Mode Setting**: New setting to control surround sound downmix behavior (`Settings → Video Player → Audio`)
  - **Auto** (default): Disables passthrough so VLC properly downmixes surround to stereo
  - **Stereo**: Force 2-channel output as fallback
  - **Passthrough**: Send raw audio to receiver (requires compatible hardware)
  - Fixes center channel going to left speaker only on stereo setups (#19)

- **Liquid Glass UI**: Applied tvOS 18 Liquid Glass effects to playback controls

- **iOS-Style Video Player Controls** (tvOS): Complete overhaul of video player controls adapted from upstream iOS Swiftfin:
  - **Center Playback Buttons**: Large play/pause and jump forward/backward buttons centered on screen
    - Native tvOS focus effects with spring animations
    - Liquid Glass backgrounds on tvOS 18+
    - Dynamically shown/hidden based on live stream status
  - **Info Button**: Opens MediaInfoSupplement panel showing poster, title, overview, ratings
  - **Episodes Button**: Opens episode selector for series content with season picker
  - **Chapter Track Mask**: iOS-style inverse mask technique for chapter dividers
  - **Button Grouping**: Organized action buttons into logical groups with visual spacing

- **NetworkError**: Restored typed network error handling with factory methods and `isRecoverable` property

- **MediaError**: New domain-specific error type for media playback with `isRetryable` property

- **Test Files** (pending Xcode target integration):
  - `VideoPlayerContainerStateTests.swift`, `NetworkErrorTests.swift`, `MediaErrorTests.swift`

### Fixed

- **Button Overlap**: Resolved movie detail view button overlap (#14)
- **Initial Focus**: Fixed initial focus not being set on TV Show detail view (#2)
- **Focus Loop**: Resolved action button focus loop issue
- **VLC Thread Safety**: Ensured VLC callbacks dispatch to main thread
- **Intro Skipper**: Temporarily disabled due to build conflicts (will revisit in dedicated sprint)

### Changed

- **VideoPlayerContainerState**: Migrated from dual boolean/enum state representation to enum-only source of truth with computed properties for backward compatibility. Enums (`OverlayVisibility`, `SupplementVisibility`, `ScrubState`) are now the canonical state representation.

### Removed

- Removed dual state sync code from `VideoPlayerContainerState` (`didSet` observers that synced booleans to enums)
- Removed commented-out legacy `NetworkError` implementation

---

## [Unreleased]

### Added

(empty - ready for future work)

### Fixed

(empty - ready for future work)

### Changed

(empty - ready for future work)

### Removed

(empty - ready for future work)

---

## [1.4.3] - 2026-06-24

### Fixed

- **Expired Jellyfin sessions (#59)**: Repeated 401s are now tied to the exact runtime user/server session and confirmed with Jellyfin before sign-out. Expired users enter a dedicated password or Quick Connect recovery flow while all stored tokens remain intact until replacement succeeds.
- **Subtitle persistence on autoplay**: The chosen subtitle track now carries over when the next episode auto-plays, instead of resetting to the server default until reselected.
- **tvOS Media menu**: Restored Media to the main tvOS tab bar and removed the temporary Settings shortcut.

---

## [1.4.0] - TestFlight

**Version**: 1.4.0 (Build 1)

### Added

- **System Default audio output mode**: New audio output option that lets VLC use the Apple TV's audio configuration without any override. Set as the default for fresh installs (#55)
- **Jump-to-end clamp**: Jump forward now respects remaining runtime so it never overshoots the end of an item (#49)
- **Persist playback speed**: User-selected playback speed survives across sessions (upstream port)

### Fixed

- **Audio regression on AC3/AAC**: Reefy was forcing `spdif = 0` for Auto and Stereo output modes, causing silent failures on some Apple TV configurations. New System Default mode bypasses the override entirely (#55)
- **TV section focus traversal**: Pressing Up from the top row of the TV Shows or Live TV library now returns focus to the section picker instead of getting stuck (#52)
- **AppLoadingView migration errors**: All six hardcoded English strings now route through L10n for translation
- **Authentication path force-unwraps**: Replaced `userSession!` and `authenticationAction!` force-unwraps with safe `requireSession()` and guard patterns across 25 files and 84 sites — no more crashes if state ever diverges
- **Per-user Jellyfin device records (#57)**: Each saved user now keeps a stable `DeviceID`, including across reauthentication, instead of sharing the install-wide identifier
- **Add Server hangs on duplicate / migration**: Connecting to a server that already exists in the app (same Jellyfin ID, e.g., after a server migration with a new URL) left the form stuck on "Connecting" forever. The view now resets to its idle state when the duplicate-server alert appears, so Dismiss and Add URL both behave cleanly
- **Two spinners on Add Server**: Two `ProgressView` instances were rendering from the same loading flag during a connect. Now one spinner

### Changed

- **Dependency**: TVVLCKit and MobileVLCKit pinned to 3.7.2 (was 3.7.0)
- **Logging**: `VideoPlayerContainerState` debug prints now route through Pulse logger
- **Stability**: `ItemEditorViewModel` abstract method stubs use `preconditionFailure` with named subclass+method, producing actionable crash reports if a subclass forgets to override
- **Stateful protocol**: Default `backgroundStates` for conformers without background states is now a quiet no-op instead of `assertionFailure` (which was silently elided in release anyway)

### Removed

- **Dead code**: `Shared/Extensions/JellyfinAPI/ServerTicks.swift` (95 lines, zero callers, fully superseded by `Duration.ticks`)
- **Cleanup pass**: Commented-out code blocks, dead AVKit/NativeVideoPlayer references, fully-commented PreferenceUIHosting files

---

## Previous Releases

See git history for changes prior to this changelog.
