//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import JellyfinAPI
@testable import Swiftfin_tvOS
import SwiftUI
import XCTest

/// Tests for MediaPlayerManager teardown behavior.
///
/// Exiting the player races the ended -> autoplay transition; these
/// tests pin down that stop wins: it fires the VLC stop once, blocks
/// autoplay, and discards an in-flight next item.
@MainActor
final class MediaPlayerManagerStopTests: XCTestCase {

    private var originalAutoPlay: Bool!

    override func setUp() async throws {
        originalAutoPlay = Defaults[.VideoPlayer.autoPlayEnabled]
        Defaults[.VideoPlayer.autoPlayEnabled] = true
    }

    override func tearDown() async throws {
        Defaults[.VideoPlayer.autoPlayEnabled] = originalAutoPlay
    }

    // MARK: - Mocks

    /// Counts stop calls so tests can assert teardown fires the
    /// underlying player stop exactly once
    private final class StopCountingProxy: MediaPlayerProxy {

        weak var manager: MediaPlayerManager?

        let isBuffering: PublishedBox<Bool> = .init(initialValue: false)

        private(set) var stopCallCount = 0

        func play() {}
        func pause() {}

        func stop() {
            stopCallCount += 1
        }

        func jumpForward(_ seconds: Duration) {}
        func jumpBackward(_ seconds: Duration) {}
        func setRate(_ rate: Float) {}
        func setSeconds(_ seconds: Duration) {}
    }

    private final class StaticQueue: MediaPlayerQueue {

        weak var manager: MediaPlayerManager?

        let displayTitle: String = "Test Queue"
        let id: String = "test-queue"

        @Published
        var hasNextItem: Bool = false
        @Published
        var hasPreviousItem: Bool = false
        @Published
        var nextItem: MediaPlayerItemProvider?
        @Published
        var previousItem: MediaPlayerItemProvider?

        lazy var hasNextItemPublisher: Published<Bool>.Publisher = $hasNextItem
        lazy var hasPreviousItemPublisher: Published<Bool>.Publisher = $hasPreviousItem
        lazy var nextItemPublisher: Published<MediaPlayerItemProvider?>.Publisher = $nextItem
        lazy var previousItemPublisher: Published<MediaPlayerItemProvider?>.Publisher = $previousItem

        var videoPlayerBody: some PlatformView {
            InlinePlatformView {
                EmptyView()
            } tvOSView: {
                EmptyView()
            }
        }
    }

    /// Holds a continuation so a test can suspend an item provider
    /// mid-flight and resume it after acting on the manager
    private final class Gate: @unchecked Sendable {

        private let lock = NSLock()
        private var continuation: CheckedContinuation<Void, Never>?

        var isArmed: Bool {
            lock.lock()
            defer { lock.unlock() }
            return continuation != nil
        }

        func store(_ continuation: CheckedContinuation<Void, Never>) {
            lock.lock()
            self.continuation = continuation
            lock.unlock()
        }

        func open() {
            lock.lock()
            continuation?.resume()
            continuation = nil
            lock.unlock()
        }
    }

    private final class InvocationCounter: @unchecked Sendable {

        private let lock = NSLock()
        private var _count = 0

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return _count
        }

        func increment() {
            lock.lock()
            _count += 1
            lock.unlock()
        }
    }

    // MARK: - Helpers

    private func makeItem(id: String, runTimeTicks: Int? = 36_000_000_000) -> (BaseItemDto, MediaPlayerItem) {
        var baseItem = BaseItemDto()
        baseItem.id = id
        baseItem.runTimeTicks = runTimeTicks

        let playbackItem = MediaPlayerItem(
            baseItem: baseItem,
            mediaSource: MediaSourceInfo(),
            playSessionID: "test-session-\(id)",
            url: URL(string: "https://example.com/\(id)")!
        )

        return (baseItem, playbackItem)
    }

    /// Drive the manager through the start action so the macro's core
    /// reaches .playback; a direct state assignment gets overwritten
    /// by the core's publisher
    private func makePlayingManager(
        queue: (any MediaPlayerQueue)? = nil
    ) async -> MediaPlayerManager {
        let (baseItem, playbackItem) = makeItem(id: "first")

        let manager = MediaPlayerManager(
            item: baseItem,
            queue: queue
        ) { _ in playbackItem }
        await manager.start()

        for _ in 0 ..< 100 where manager.state != .playback {
            await Task.yield()
        }

        return manager
    }

    private func settle(iterations: Int = 20) async {
        for _ in 0 ..< iterations {
            await Task.yield()
        }
    }

    // MARK: - Tests

    func testStopIsIdempotent() async {
        let manager = await makePlayingManager()
        let proxy = StopCountingProxy()
        manager.proxy = proxy

        await manager.stop()
        await settle()

        XCTAssertEqual(proxy.stopCallCount, 1)

        await manager.stop()
        await settle()

        XCTAssertEqual(proxy.stopCallCount, 1, "a second stop must not reach the underlying player")
    }

    func testEndedAfterStopDoesNotAutoplay() async {
        let queue = StaticQueue()
        let manager = await makePlayingManager(queue: queue)
        let proxy = StopCountingProxy()
        manager.proxy = proxy

        let (_, nextPlaybackItem) = makeItem(id: "next")
        let counter = InvocationCounter()
        queue.nextItem = MediaPlayerItemProvider(item: nextPlaybackItem.baseItem) { _ in
            counter.increment()
            return nextPlaybackItem
        }

        // Natural-end conditions: seconds near runtime so _ended treats
        // the event as a real ending rather than a spurious one
        manager.seconds = .seconds(3600)

        await manager.stop()
        await manager.ended()
        await settle()

        XCTAssertEqual(counter.count, 0, "autoplay must not fetch the next item after stop")
        XCTAssertEqual(manager.playbackItem?.baseItem.id, "first", "stop must win over a late ended event")
    }

    func testStopDuringPlayNewItemDiscardsItem() async {
        let manager = await makePlayingManager()
        let proxy = StopCountingProxy()
        manager.proxy = proxy

        let (nextBaseItem, nextPlaybackItem) = makeItem(id: "next")
        let gate = Gate()
        let provider = MediaPlayerItemProvider(item: nextBaseItem) { _ in
            await withCheckedContinuation { gate.store($0) }
            return nextPlaybackItem
        }

        let playNewItemTask = Task {
            await manager.playNewItem(provider: provider)
        }

        for _ in 0 ..< 200 where !gate.isArmed {
            await Task.yield()
        }
        XCTAssertTrue(gate.isArmed, "provider should be suspended mid-flight")

        await manager.stop()
        gate.open()
        await playNewItemTask.value
        await settle()

        XCTAssertNotEqual(
            manager.playbackItem?.baseItem.id,
            "next",
            "an item resolved after stop must be discarded, not played"
        )
    }
}
