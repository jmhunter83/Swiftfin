//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Foundation
import Logging
import SwiftUI

private let logger = Logger.swiftfin()

// MARK: - State Enums

/// Overlay visibility state
enum OverlayVisibility: Hashable {
    case hidden
    case visible
    case locked // gestures locked, overlay hidden
}

/// Supplement panel state
enum SupplementVisibility: Hashable {
    case closed
    case open
}

/// Scrubbing state
enum ScrubState: Hashable {
    case idle
    case scrubbing
}

/// Direction for timeline scrubbing
enum ScrubDirection {
    case forward
    case backward

    var sign: Double {
        switch self {
        case .forward: return 1
        case .backward: return -1
        }
    }
}

@MainActor
class VideoPlayerContainerState: ObservableObject {

    // MARK: - Primary State (enum-based)

    @Published
    private(set) var overlayState: OverlayVisibility = .hidden {
        didSet {
            updatePlaybackControlsVisibility()

            // When overlay becomes visible (not locked), start auto-hide timer
            if overlayState == .visible, supplementState == .closed {
                timer.poke()
            }
        }
    }

    @Published
    private(set) var supplementState: SupplementVisibility = .closed {
        didSet {
            updatePlaybackControlsVisibility()
            presentationControllerShouldDismiss = supplementState == .closed

            switch supplementState {
            case .open:
                timer.stop()
            case .closed:
                isGuestSupplement = false
                timer.poke()
            }
        }
    }

    @Published
    private(set) var scrubState: ScrubState = .idle {
        didSet {
            switch scrubState {
            case .scrubbing:
                timer.stop()
            case .idle:
                timer.poke()
            }
        }
    }

    // MARK: - Computed Properties (backward compatibility)

    /// Whether the overlay is currently visible (not hidden or locked)
    var isPresentingOverlay: Bool {
        get { overlayState == .visible }
        set {
            if isGestureLocked {
                // When locked, ignore attempts to show overlay
                overlayState = .locked
            } else {
                overlayState = newValue ? .visible : .hidden
            }
        }
    }

    /// Whether the supplement panel is currently open
    var isPresentingSupplement: Bool {
        supplementState == .open
    }

    /// Whether the user is currently scrubbing the timeline
    var isScrubbing: Bool {
        get { scrubState == .scrubbing }
        set { scrubState = newValue ? .scrubbing : .idle }
    }

    /// Whether gestures are locked (overlay is hidden and cannot be shown)
    var isGestureLocked: Bool {
        get { overlayState == .locked }
        set {
            if newValue {
                overlayState = .locked
            } else {
                // When unlocking, go to hidden state
                overlayState = .hidden
            }
        }
    }

    // MARK: - Other Published State

    @Published
    var isAspectFilled: Bool = false

    @Published
    var isPresentingPlaybackControls: Bool = false

    @Published
    var isActionButtonsFocused: Bool = false

    @Published
    var isCompact: Bool = false {
        didSet {
            updatePlaybackControlsVisibility()
        }
    }

    @Published
    var isGuestSupplement: Bool = false

    @Published
    var presentationControllerShouldDismiss: Bool = true

    @Published
    var selectedSupplement: (any MediaPlayerSupplement)? = nil {
        didSet {
            supplementState = selectedSupplement != nil ? .open : .closed
        }
    }

    @Published
    var supplementOffset: CGFloat = 0.0

    @Published
    var centerOffset: CGFloat = 0.0

    /// Tracks when a supplement was recently dismissed to prevent immediate overlay hiding
    var supplementRecentlyDismissed = false

    // MARK: - Hold-to-Scrub State

    @Published
    var skipIndicatorText: String? = nil

    /// ID to track which skip indicator should be auto-hidden (prevents race conditions)
    private var skipIndicatorID: UUID = UUID()

    /// Current direction of hold-scrubbing (nil when not scrubbing)
    private var currentScrubDirection: ScrubDirection?

    /// Time when arrow press began (for acceleration calculation)
    private var arrowPressStartTime: Date?

    /// Timer for detecting hold vs tap
    private var holdTimer: Timer?

    /// Timer for accelerated scrubbing while holding
    private var accelerationTimer: Timer?

    /// Whether currently in hold-scrubbing mode (vs just a tap)
    private var isHoldScrubbing: Bool = false

    /// Hold detection threshold (seconds)
    private let holdThreshold: TimeInterval = 0.3
    /// Acceleration tick interval (seconds)
    private let accelerationTickInterval: TimeInterval = 0.1

    // MARK: - Components

    let jumpProgressObserver: JumpProgressObserver = .init()
    let scrubbedSeconds: PublishedBox<Duration> = .init(initialValue: .zero)
    let timer: PokeIntervalTimer
    let toastProxy: ToastProxy = .init()

    weak var containerView: VideoPlayer.UIVideoPlayerContainerViewController?
    weak var manager: MediaPlayerManager?

    #if os(iOS)
    var panHandlingAction: (any _PanHandlingAction)?
    var didSwipe: Bool = false
    var lastTapLocation: CGPoint?
    #endif

    private var jumpProgressCancellable: AnyCancellable?
    private var timerCancellable: AnyCancellable?
    private var playbackStatusCancellable: AnyCancellable?

    // MARK: - Initialization

    init(timerInterval: TimeInterval = 5) {
        self.timer = PokeIntervalTimer(defaultInterval: timerInterval)

        timerCancellable = timer.sink { [weak self] in
            guard let self else { return }
            guard scrubState == .idle,
                  supplementState == .closed,
                  manager?.playbackRequestStatus != .paused
            else { return }

            withAnimation(.linear(duration: 0.25)) {
                self.overlayState = .hidden
            }
        }

        #if os(iOS)
        jumpProgressCancellable = jumpProgressObserver
            .timer
            .sink { [weak self] in
                self?.lastTapLocation = nil
            }
        #endif
    }

    /// Call this after manager is set to observe playback status
    func observePlaybackStatus() {
        guard let manager else { return }

        playbackStatusCancellable = manager.$playbackRequestStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }

                if status == .paused {
                    // When paused, show overlay and stop timer
                    if self.overlayState != .visible && !self.isGestureLocked {
                        withAnimation(.linear(duration: 0.25)) {
                            self.overlayState = .visible
                        }
                    }
                    self.timer.stop()
                } else if status == .playing {
                    // Resuming mid-pan commits the scrubbed position
                    self.endPanScrub()

                    // When playing, start the auto-hide timer
                    if self.overlayState == .visible && self.supplementState == .closed {
                        self.timer.poke()
                    }
                }
            }
    }

    // MARK: - State Mutations

    /// Show or hide the overlay with animation consideration
    func setOverlayVisible(_ visible: Bool, animated: Bool = true) {
        guard !isGestureLocked else { return }

        if animated {
            withAnimation(.linear(duration: 0.25)) {
                overlayState = visible ? .visible : .hidden
            }
        } else {
            overlayState = visible ? .visible : .hidden
        }
    }

    /// Toggle overlay visibility
    func toggleOverlay() {
        setOverlayVisible(overlayState != .visible)
    }

    /// Re-arm the auto-hide timer in response to user interaction (button press or focus move).
    /// Never shows a hidden overlay and never re-arms while scrubbing, paused, or in a supplement.
    func userDidInteract() {
        guard overlayState == .visible,
              supplementState == .closed,
              scrubState == .idle,
              manager?.playbackRequestStatus != .paused
        else { return }

        timer.poke()
    }

    // MARK: - Menu Keep-Alive

    /// Count of open transport menus. Menu popups render their content only
    /// while presented, so content appear/disappear is the open/close signal.
    /// Counted because a multi-child content builder fires once per child.
    private var openMenuCount = 0

    /// Whether any transport menu popup is currently open
    var isTransportMenuOpen: Bool {
        openMenuCount > 0
    }

    /// Call from a transport menu's content `onAppear`. Holds the overlay
    /// visible while the menu popup is open.
    func menuContentDidAppear() {
        openMenuCount += 1
        timer.stop()
    }

    /// Call from a transport menu's content `onDisappear`. Re-arms the
    /// auto-hide timer once the last open menu closes.
    func menuContentDidDisappear() {
        openMenuCount = max(0, openMenuCount - 1)
        if openMenuCount == 0 {
            timer.poke()
        }
    }

    /// Select a supplement panel to display
    func select(supplement: (any MediaPlayerSupplement)?, isGuest: Bool = false) {
        isGuestSupplement = isGuest

        if supplement?.id == selectedSupplement?.id {
            logger.trace("Dismissing supplement: \(selectedSupplement?.displayTitle ?? "none")")
            selectedSupplement = nil
            supplementRecentlyDismissed = true
            // Clear the flag after a short delay to allow Menu button logic to work properly
            DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.quickFocusDelay) {
                self.supplementRecentlyDismissed = false
            }
            containerView?.presentSupplementContainer(false)
        } else {
            logger
                .trace(
                    "Selecting supplement: \(supplement?.displayTitle ?? "none") (was: \(selectedSupplement?.displayTitle ?? "none"))"
                )
            selectedSupplement = supplement
            containerView?.presentSupplementContainer(supplement != nil)
        }
    }

    // MARK: - Private Helpers

    private func updatePlaybackControlsVisibility() {
        // Show playback controls when overlay is visible, regardless of supplement state
        // The transport bar positioning is handled by the container view constraints
        let oldValue = isPresentingPlaybackControls
        isPresentingPlaybackControls = overlayState == .visible
        if oldValue != isPresentingPlaybackControls {
            logger.trace(
                "Playback controls visibility: \(oldValue) -> \(isPresentingPlaybackControls) (overlay: \(overlayState), supplement: \(supplementState))"
            )
        }
    }

    // MARK: - Hold-to-Scrub Functions

    /// Called when arrow key press begins. Performs immediate skip and starts hold detection.
    func handleArrowPressBegan(direction: ScrubDirection, skipAmount: Duration) {
        // Defensive: clean up any orphaned timers from previous interactions
        holdTimer?.invalidate()
        accelerationTimer?.invalidate()

        arrowPressStartTime = Date()
        currentScrubDirection = direction

        // Immediate skip (tap behavior)
        performSkip(direction: direction, duration: skipAmount)

        // Start hold detection timer
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdThreshold, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.startAcceleratedScrubbing(direction: direction, baseSkipAmount: skipAmount)
            }
        }
    }

    /// Called when arrow key press ends. Commits seek if scrubbing, cleans up timers.
    func handleArrowPressEnded() {
        holdTimer?.invalidate()
        holdTimer = nil

        if isHoldScrubbing {
            // Was scrubbing - commit the seek
            accelerationTimer?.invalidate()
            accelerationTimer = nil
            isScrubbing = false
            isHoldScrubbing = false

            // Seek to the scrubbed position
            let scrubbedTime = scrubbedSeconds.value
            manager?.proxy?.setSeconds(scrubbedTime)
        }

        scheduleSkipIndicatorAutoHide()

        arrowPressStartTime = nil
        currentScrubDirection = nil
    }

    /// Auto-hide the skip indicator after a delay with cancellation support
    private func scheduleSkipIndicatorAutoHide() {
        let currentID = UUID()
        skipIndicatorID = currentID
        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.skipIndicatorAutoHideDelay) { [weak self] in
            guard let self, self.skipIndicatorID == currentID else { return }
            self.skipIndicatorText = nil
        }
    }

    /// Cleans up all scrubbing timers. Call when view disappears.
    func cleanupScrubbing() {
        holdTimer?.invalidate()
        holdTimer = nil
        accelerationTimer?.invalidate()
        accelerationTimer = nil

        if isHoldScrubbing {
            isScrubbing = false
            isHoldScrubbing = false
        }

        arrowPressStartTime = nil
        currentScrubDirection = nil
        skipIndicatorText = nil
    }

    /// Whether a scrub in the given direction is currently active
    func isScrubbing(direction: ScrubDirection) -> Bool {
        currentScrubDirection == direction
    }

    // MARK: - Pan-to-Scrub

    /// Touch-surface pan scrubbing is only available while paused, keeping
    /// taps-to-skip a playback-only gesture. Focus movement is vetoed by the
    /// container while a scrub is active, so the overlay may stay visible.
    var canPanScrub: Bool {
        overlayState != .locked &&
            supplementState == .closed &&
            scrubState == .idle &&
            manager?.state == .playback &&
            manager?.playbackRequestStatus == .paused &&
            (manager?.item.runtime ?? .zero) > .zero
    }

    /// Whether the current scrub was started by a touch-surface pan (vs arrow hold)
    private var isPanScrubbing: Bool = false

    func beginPanScrub() {
        guard canPanScrub, let manager else { return }

        logger.trace("Pan scrub began at \(manager.seconds)")
        isPanScrubbing = true
        isScrubbing = true
        scrubbedSeconds.value = manager.seconds
    }

    func updatePanScrub(translationX: CGFloat, viewWidth: CGFloat) {
        guard isPanScrubbing, scrubState == .scrubbing,
              let runtime = manager?.item.runtime, runtime > .zero,
              viewWidth > 0
        else { return }

        let total = runtime.seconds

        // Damped so a full-width swipe moves a fraction of the runtime,
        // with longer content damped harder
        let damping = max(5.0, min(15.0, total / 600))
        let delta = Double(translationX) / damping / Double(viewWidth) * total
        let newSeconds = max(0, min(total, scrubbedSeconds.value.seconds + delta))

        scrubbedSeconds.value = .seconds(newSeconds)

        let current = manager?.seconds.seconds ?? 0
        let sign = newSeconds >= current ? "+" : "−"
        skipIndicatorText = "\(sign)\(formatDuration(abs(newSeconds - current)))"
    }

    func endPanScrub() {
        guard isPanScrubbing, scrubState == .scrubbing else { return }

        logger.trace("Pan scrub ended, committing \(scrubbedSeconds.value) (proxy=\(manager?.proxy == nil ? "nil" : "set"))")
        isPanScrubbing = false
        isScrubbing = false
        manager?.proxy?.setSeconds(scrubbedSeconds.value)
        scheduleSkipIndicatorAutoHide()
    }

    func cancelPanScrub() {
        guard isPanScrubbing, scrubState == .scrubbing else { return }

        logger.trace("Pan scrub cancelled")
        // Revert before ending the scrub so the seek-on-scrub-end
        // observer sees no position delta and skips the commit
        scrubbedSeconds.value = manager?.seconds ?? .zero
        isPanScrubbing = false
        isScrubbing = false
        skipIndicatorText = nil
    }

    private func startAcceleratedScrubbing(direction: ScrubDirection, baseSkipAmount: Duration) {
        isHoldScrubbing = true
        isScrubbing = true

        // Initialize scrubbed position from current playback position
        if let manager {
            scrubbedSeconds.value = manager.seconds
        }

        accelerationTimer?.invalidate()
        accelerationTimer = Timer.scheduledTimer(withTimeInterval: accelerationTickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performAccelerationTick(direction: direction, baseSkipAmount: baseSkipAmount)
            }
        }
    }

    private func performAccelerationTick(direction: ScrubDirection, baseSkipAmount: Duration) {
        guard let startTime = arrowPressStartTime else { return }

        let holdDuration = Date().timeIntervalSince(startTime)
        // Acceleration: starts at 1x, ramps up to 10x over ~18 seconds
        let acceleration = min(10.0, 1.0 + holdDuration / 2.0)

        let skipAmount = baseSkipAmount.seconds * acceleration

        // Update scrubbed position
        let currentScrubbed = scrubbedSeconds.value.seconds
        var newScrubbed = currentScrubbed + (direction.sign * skipAmount)

        // Clamp to valid range
        if let runtime = manager?.item.runtime {
            let totalDuration = runtime.seconds
            newScrubbed = max(0, min(totalDuration, newScrubbed))
        }

        scrubbedSeconds.value = .seconds(newScrubbed)

        // Update indicator text to show delta from current position
        let sign = direction == .forward ? "+" : "−"
        let delta = abs(newScrubbed - (manager?.seconds.seconds ?? 0))
        skipIndicatorText = "\(sign)\(formatDuration(delta))"
    }

    private func performSkip(direction: ScrubDirection, duration: Duration) {
        switch direction {
        case .forward:
            manager?.proxy?.jumpForward(duration)
            skipIndicatorText = "+\(formatDuration(duration.seconds))"
        case .backward:
            manager?.proxy?.jumpBackward(duration)
            skipIndicatorText = "−\(formatDuration(duration.seconds))"
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return ":\(String(format: "%02d", secs))"
        }
    }
}
