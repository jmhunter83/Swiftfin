//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
@testable import Swiftfin_tvOS
import XCTest

/// Tests for VideoPlayerContainerState
@MainActor
final class VideoPlayerContainerStateTests: XCTestCase {

    var sut: VideoPlayerContainerState!

    override func setUp() async throws {
        sut = VideoPlayerContainerState()
    }

    override func tearDown() async throws {
        sut = nil
    }

    // MARK: - Overlay State Tests

    func testInitialOverlayStateIsHidden() {
        XCTAssertEqual(sut.overlayState, .hidden)
        XCTAssertFalse(sut.isPresentingOverlay)
    }

    func testSettingIsPresentingOverlayUpdatesOverlayState() {
        sut.isPresentingOverlay = true

        XCTAssertEqual(sut.overlayState, .visible)
        XCTAssertTrue(sut.isPresentingOverlay)
    }

    func testSettingIsPresentingOverlayToFalseUpdatesOverlayState() {
        sut.isPresentingOverlay = true
        sut.isPresentingOverlay = false

        XCTAssertEqual(sut.overlayState, .hidden)
        XCTAssertFalse(sut.isPresentingOverlay)
    }

    func testGestureLockPreventsOverlayFromShowing() {
        sut.isGestureLocked = true
        sut.isPresentingOverlay = true // Should be ignored

        XCTAssertEqual(sut.overlayState, .locked)
        XCTAssertFalse(sut.isPresentingOverlay) // Still false because locked
    }

    func testUnlockingGestureResetsToHidden() {
        sut.isGestureLocked = true
        sut.isGestureLocked = false

        XCTAssertEqual(sut.overlayState, .hidden)
        XCTAssertFalse(sut.isGestureLocked)
    }

    // MARK: - Supplement State Tests

    func testInitialSupplementStateIsClosed() {
        XCTAssertEqual(sut.supplementState, .closed)
        XCTAssertFalse(sut.isPresentingSupplement)
    }

    func testPresentationControllerShouldDismissWhenSupplementClosed() {
        XCTAssertTrue(sut.presentationControllerShouldDismiss)
    }

    // MARK: - Scrub State Tests

    func testInitialScrubStateIsIdle() {
        XCTAssertEqual(sut.scrubState, .idle)
        XCTAssertFalse(sut.isScrubbing)
    }

    func testSettingIsScrubbingUpdatesScrubState() {
        sut.isScrubbing = true

        XCTAssertEqual(sut.scrubState, .scrubbing)
        XCTAssertTrue(sut.isScrubbing)
    }

    func testSettingIsScrubbingToFalseReturnsToIdle() {
        sut.isScrubbing = true
        sut.isScrubbing = false

        XCTAssertEqual(sut.scrubState, .idle)
        XCTAssertFalse(sut.isScrubbing)
    }

    // MARK: - Helper Method Tests

    func testSetOverlayVisibleTrue() {
        sut.setOverlayVisible(true, animated: false)

        XCTAssertEqual(sut.overlayState, .visible)
    }

    func testSetOverlayVisibleFalse() {
        sut.setOverlayVisible(true, animated: false)
        sut.setOverlayVisible(false, animated: false)

        XCTAssertEqual(sut.overlayState, .hidden)
    }

    func testSetOverlayVisibleIgnoredWhenLocked() {
        sut.isGestureLocked = true
        sut.setOverlayVisible(true, animated: false)

        XCTAssertEqual(sut.overlayState, .locked)
    }

    func testToggleOverlay() {
        sut.toggleOverlay()
        XCTAssertEqual(sut.overlayState, .visible)

        sut.toggleOverlay()
        XCTAssertEqual(sut.overlayState, .hidden)
    }

    // MARK: - Auto-Hide Timer Tests

    func testOverlayHidesAfterTimerFiresWhenVisible() {
        sut = VideoPlayerContainerState(timerInterval: 0.05)
        sut.setOverlayVisible(true, animated: false)

        let hidden = expectation(description: "overlay hides after timer fires")
        let cancellable = sut.$overlayState.sink { state in
            if state == .hidden {
                hidden.fulfill()
            }
        }

        wait(for: [hidden], timeout: 1)
        cancellable.cancel()
        XCTAssertEqual(sut.overlayState, .hidden)
    }

    func testUserDidInteractRearmsTimerWhenVisible() {
        sut = VideoPlayerContainerState(timerInterval: 0.05)
        sut.setOverlayVisible(true, animated: false)
        sut.userDidInteract()

        let fired = expectation(description: "timer fires after interaction")
        let cancellable = sut.timer.sink {
            fired.fulfill()
        }

        wait(for: [fired], timeout: 1)
        cancellable.cancel()
        XCTAssertEqual(sut.overlayState, .hidden)
    }

    func testUserDidInteractDoesNotShowHiddenOverlay() {
        sut = VideoPlayerContainerState(timerInterval: 0.05)
        sut.userDidInteract()

        let fired = expectation(description: "timer does not fire")
        fired.isInverted = true
        let cancellable = sut.timer.sink {
            fired.fulfill()
        }

        wait(for: [fired], timeout: 0.3)
        cancellable.cancel()
        XCTAssertEqual(sut.overlayState, .hidden)
    }

    func testUserDidInteractIgnoredWhenGestureLocked() {
        sut = VideoPlayerContainerState(timerInterval: 0.05)
        sut.isGestureLocked = true
        sut.userDidInteract()

        let fired = expectation(description: "timer does not fire")
        fired.isInverted = true
        let cancellable = sut.timer.sink {
            fired.fulfill()
        }

        wait(for: [fired], timeout: 0.3)
        cancellable.cancel()
        XCTAssertEqual(sut.overlayState, .locked)
    }

    func testUserDidInteractIgnoredWhileScrubbing() {
        sut = VideoPlayerContainerState(timerInterval: 0.05)
        sut.setOverlayVisible(true, animated: false)
        sut.isScrubbing = true
        sut.userDidInteract()

        let fired = expectation(description: "timer does not fire")
        fired.isInverted = true
        let cancellable = sut.timer.sink {
            fired.fulfill()
        }

        wait(for: [fired], timeout: 0.3)
        cancellable.cancel()
        XCTAssertEqual(sut.overlayState, .visible)
    }
}
