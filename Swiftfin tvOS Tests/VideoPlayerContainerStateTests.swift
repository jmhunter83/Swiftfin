//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import JellyfinAPI
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

    // MARK: - Pan-to-Scrub Tests

    private func makeManager(runTimeTicks: Int? = 36_000_000_000) async -> MediaPlayerManager {
        var baseItem = BaseItemDto()
        baseItem.runTimeTicks = runTimeTicks

        let playbackItem = MediaPlayerItem(
            baseItem: baseItem,
            mediaSource: MediaSourceInfo(),
            playSessionID: "test-session",
            url: URL(string: "https://example.com/video")!
        )

        // Drive the manager through the start action so the macro's core
        // reaches .playback; a direct state assignment gets overwritten
        // by the core's publisher
        let manager = MediaPlayerManager(item: baseItem) { _ in playbackItem }
        await manager.start()

        // The core's state lands on the class property via the main queue
        for _ in 0 ..< 100 where manager.state != .playback {
            await Task.yield()
        }

        return manager
    }

    func testCanPanScrubFalseWithoutManager() {
        XCTAssertFalse(sut.canPanScrub)
    }

    func testCanPanScrubFalseWhilePlaying() async {
        let manager = await makeManager()
        sut.manager = manager

        XCTAssertEqual(manager.playbackRequestStatus, .playing)
        XCTAssertFalse(sut.canPanScrub)
    }

    func testCanPanScrubTrueWhilePaused() async {
        let manager = await makeManager()
        sut.manager = manager

        await manager.setPlaybackRequestStatus(status: .paused)

        XCTAssertTrue(sut.canPanScrub)
    }

    func testCanPanScrubTrueWhenOverlayVisibleAndPaused() async {
        let manager = await makeManager()
        sut.manager = manager

        await manager.setPlaybackRequestStatus(status: .paused)
        sut.setOverlayVisible(true, animated: false)

        XCTAssertTrue(sut.canPanScrub)
    }

    func testCanPanScrubFalseWhenGestureLocked() async {
        let manager = await makeManager()
        sut.manager = manager

        await manager.setPlaybackRequestStatus(status: .paused)
        sut.isGestureLocked = true

        XCTAssertFalse(sut.canPanScrub)
    }

    func testCanPanScrubFalseWithoutRuntime() async {
        let manager = await makeManager(runTimeTicks: nil)
        sut.manager = manager

        await manager.setPlaybackRequestStatus(status: .paused)

        XCTAssertFalse(sut.canPanScrub)
    }

    func testPanScrubWhilePausedUpdatesAndCommits() async {
        let manager = await makeManager()
        sut.manager = manager

        await manager.setPlaybackRequestStatus(status: .paused)

        sut.beginPanScrub()
        XCTAssertEqual(sut.scrubState, .scrubbing)

        sut.updatePanScrub(translationX: 200, viewWidth: 1000)
        XCTAssertGreaterThan(sut.scrubbedSeconds.value, .zero)
        XCTAssertNotNil(sut.skipIndicatorText)

        sut.endPanScrub()
        XCTAssertEqual(sut.scrubState, .idle)
    }

    func testResumeCommitsActivePanScrub() async {
        let manager = await makeManager()
        sut.manager = manager
        sut.observePlaybackStatus()

        await manager.setPlaybackRequestStatus(status: .paused)

        sut.beginPanScrub()
        sut.updatePanScrub(translationX: 200, viewWidth: 1000)
        XCTAssertEqual(sut.scrubState, .scrubbing)

        await manager.setPlaybackRequestStatus(status: .playing)

        // The status observer delivers on the main queue, so the
        // scrub commit lands a hop after the await returns
        let idle = expectation(description: "scrub ends on resume")
        let cancellable = sut.$scrubState.sink { state in
            if state == .idle {
                idle.fulfill()
            }
        }

        await fulfillment(of: [idle], timeout: 1)
        cancellable.cancel()
        XCTAssertEqual(sut.scrubState, .idle)
    }

    func testBeginPanScrubNoOpsWhenUnavailable() {
        sut.beginPanScrub()

        XCTAssertEqual(sut.scrubState, .idle)
    }

    func testBeginPanScrubNoOpsWhilePlaying() async {
        let manager = await makeManager()
        sut.manager = manager

        sut.beginPanScrub()

        XCTAssertEqual(sut.scrubState, .idle)
    }

    func testUpdatePanScrubNoOpsWhenIdle() {
        sut.updatePanScrub(translationX: 100, viewWidth: 1920)

        XCTAssertEqual(sut.scrubbedSeconds.value, .zero)
        XCTAssertNil(sut.skipIndicatorText)
    }

    func testPanScrubHandlersIgnoreHoldScrub() {
        // A scrub started by arrow hold must not be ended or cancelled
        // by stray pan gesture callbacks
        sut.isScrubbing = true

        sut.endPanScrub()
        XCTAssertEqual(sut.scrubState, .scrubbing)

        sut.cancelPanScrub()
        XCTAssertEqual(sut.scrubState, .scrubbing)
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
