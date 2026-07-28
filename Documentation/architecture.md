# Architecture Overview

This document provides an overview of key architectural patterns used in Reefy.

---

## State Management

### VideoPlayerContainerState

The video player uses an enum-based state machine for UI visibility:

```swift
enum OverlayVisibility: Hashable {
    case hidden   // Overlay not visible
    case visible  // Overlay showing
    case locked   // Gestures locked, overlay hidden
}

enum SupplementVisibility: Hashable {
    case closed   // Panel closed
    case open     // Panel open (subtitles, chapters, etc.)
}

enum ScrubState: Hashable {
    case idle       // Normal playback
    case scrubbing  // User scrubbing timeline
}
```

**Usage:**
```swift
// Direct enum access (preferred for new code)
if containerState.overlayState == .visible { ... }

// Backward-compatible boolean accessors
if containerState.isPresentingOverlay { ... }

// Helper methods
containerState.setOverlayVisible(true, animated: true)
containerState.toggleOverlay()
```

---

## Error Handling

### NetworkError

Typed errors for network operations with factory methods:

```swift
// Create from URLError code
let error = NetworkError.from(urlErrorCode: -1001) // .timeout

// Create from HTTP status
let error = NetworkError.from(httpStatusCode: 401) // .unauthorized

// Check if user can retry
if error.isRecoverable {
    showRetryButton()
}
```

### MediaError

Domain-specific errors for media playback:

```swift
// Playback errors
MediaError.noPlayableSource
MediaError.transcodingFailed(reason: "Codec not supported")
MediaError.streamEnded

// Item errors
MediaError.itemNotFound(itemId: "abc123")
MediaError.notPlayable

// Check if retry makes sense
if error.isRetryable {
    showRetryOption()
}
```

---

## Dependency Injection

The app uses [Factory](https://github.com/hmlongco/Factory) for dependency injection:

```swift
// Definition
extension Container {
    var currentUserSession: Factory<UserSession?> {
        self { ... }.cached
    }
}

// Usage in ViewModels
@Injected(\.currentUserSession)
var userSession: UserSession!
```

---

## ViewModel Pattern

ViewModels follow the `Stateful` protocol for predictable state transitions:

```swift
protocol Stateful {
    associatedtype Action: Equatable
    associatedtype State: Hashable
    
    func respond(to action: Action) -> State
}

// Example
final class HomeViewModel: ViewModel, Stateful {
    enum Action {
        case refresh
        case backgroundRefresh
        case setIsPlayed(Bool, BaseItemDto)
    }
    
    enum State {
        case initial
        case refreshing
        case content
        case error(ErrorMessage)
    }
    
    func respond(to action: Action) -> State { ... }
}
```

---

## Notifications

Type-safe notifications with payload support:

```swift
// Post
Notifications[.itemMetadataDidChange].post(updatedItem)

// Subscribe
Notifications[.didSignIn].publisher
    .sink { ... }
    .store(in: &cancellables)
```

---

## Testing

Test files are located in `Swiftfin tvOS Tests/`:

| File | Coverage |
|------|----------|
| `VideoPlayerContainerStateTests.swift` | State transitions |
| `NetworkErrorTests.swift` | Error factories |
| `MediaErrorTests.swift` | Error properties |

To run tests, add a Unit Testing Bundle target in Xcode.
