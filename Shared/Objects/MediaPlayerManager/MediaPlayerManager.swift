//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import Factory
import Foundation
import JellyfinAPI
import VLCUI

typealias MediaPlayerManagerPublisher = LegacyEventPublisher<MediaPlayerManager?>

extension Scope {
    static let session = Cached()
}

extension Container {

    var mediaPlayerManagerPublisher: Factory<MediaPlayerManagerPublisher> {
        self { MediaPlayerManagerPublisher() }
            .singleton
    }

    var mediaPlayerManager: Factory<MediaPlayerManager> {
        self { @MainActor in
            .init(initialState: .stopped)
        }
        .scope(.session)
    }
}

import StatefulMacros

@MainActor
@Stateful
final class MediaPlayerManager: ViewModel {

    @CasePathable
    enum Action {
        case ended
        case error(Error)
        case playNewItem(provider: MediaPlayerItemProvider)
        case setPlaybackRequestStatus(status: PlaybackRequestStatus)
        case setRate(rate: Float)
        case start
        case stop
        case togglePlayPause

        var transition: Transition {
            switch self {
            case .error:
                .to(.error)
                    .invalid(.stopped)
            case .playNewItem, .start:
                .to(.loadingItem, then: .playback)
                    .invalid(.stopped)
            case .stop:
                .to(.stopped)
            default:
                .none
                    .invalid(.stopped)
            }
        }
    }

    enum State {
        case error
        case initial
        case loadingItem
        case playback
        case stopped
    }

    /// A status indicating the player's request for media playback.
    enum PlaybackRequestStatus {

        /// The player requests media playback
        case playing

        /// The player is paused
        case paused
    }

    @Published
    var playbackItem: MediaPlayerItem? = nil {
        didSet {
            if let playbackItem {
                self.item = playbackItem.baseItem
                seconds = playbackItem.baseItem.startSeconds ?? .zero
                playbackItem.manager = self
                setSupplements()

                logger.info(
                    "Playing new item",
                    metadata: [
                        "itemID": .stringConvertible(playbackItem.baseItem.id ?? "Unknown"),
                        "itemTitle": .stringConvertible(playbackItem.baseItem.displayTitle),
                        "url": .stringConvertible(playbackItem.url.absoluteString),
                        "defaultAudioStreamIndex": .stringConvertible(playbackItem.mediaSource.defaultAudioStreamIndex ?? -1),
                        "selectedAudioStreamIndex": .stringConvertible(playbackItem.selectedAudioStreamIndex ?? -1),
                        "audioStreamsCount": .stringConvertible(playbackItem.audioStreams.count),
                    ]
                )

                Task { _ = await playbackItem.previewImageProvider?.image(for: seconds) }
            }
        }
    }

    @Published
    private(set) var item: BaseItemDto
    @Published
    private(set) var playbackError: Error? = nil
    @Published
    private(set) var playbackRequestStatus: PlaybackRequestStatus = .playing
    @Published
    var rate: Float = Defaults[.VideoPlayer.Playback.playbackRate] {
        didSet {
            Defaults[.VideoPlayer.Playback.playbackRate] = rate
        }
    }

    @Published
    var queue: AnyMediaPlayerQueue? = nil

    @Published
    var supplements: [any MediaPlayerSupplement] = []

    // TODO: replace with graph dependency package
    private func setSupplements() {
        var newSupplements: [any MediaPlayerSupplement] = []

        newSupplements.append(MediaInfoSupplement(item: item))

        if let chapters = item.fullChapterInfo, chapters.isNotEmpty {
            newSupplements.append(
                MediaChaptersSupplement(
                    chapters: chapters
                )
            )
        }

        if let queue {
            newSupplements.append(queue)
        }

        self.supplements = newSupplements
    }

    /// The current seconds media playback is set to.
    let secondsBox: PublishedBox<Duration> = .init(initialValue: .zero)

    var seconds: Duration {
        get { secondsBox.value }
        set { secondsBox.value = newValue }
    }

    /// Holds a weak reference to the current media player proxy.
    weak var proxy: (any MediaPlayerProxy)? {
        didSet {
            if var proxy {
                proxy.manager = self
            }
        }
    }

    private var itemBuildTask: AnyCancellable?

    private var initialMediaPlayerItemProvider: MediaPlayerItemProvider?

    // MARK: init

    init(initialState: _State = .stopped) {
        self.item = .init()
        self.state = initialState
        super.init()
    }

    init(
        item: BaseItemDto,
        queue: (any MediaPlayerQueue)? = nil,
        mediaPlayerItemProvider: @escaping MediaPlayerItemProviderFunction
    ) {
        self.item = item
        self.queue = queue.map { AnyMediaPlayerQueue($0) }
        self.state = .loadingItem
        self.initialMediaPlayerItemProvider = .init(
            item: item,
            function: mediaPlayerItemProvider
        )
        super.init()

        self.queue?.manager = self
    }

    init(
        playbackItem: MediaPlayerItem,
        queue: (any MediaPlayerQueue)? = nil
    ) {
        self.item = playbackItem.baseItem
        self.queue = queue.map { AnyMediaPlayerQueue($0) }
        self.state = .playback
        super.init()

        self.queue?.manager = self
        self.playbackItem = playbackItem
    }

    @Function(\Action.Cases.ended)
    private func _ended() async throws {
        // Capture the current item ID and next item at the time ended is called.
        // This MUST happen before any async operations because playNewItem()
        // will trigger queue updates that clear nextItem before we can use it.
        let endedItemID = item.id
        let nextItemProvider = queue?.nextItem // Capture next item early!

        // Verify we're still playing the same item (guards against race conditions
        // where item changed between VLC sending ended and us processing it)
        guard playbackItem?.baseItem.id == endedItemID else {
            logger.trace(
                "Ignoring ended event for different item",
                metadata: [
                    "expectedID": .stringConvertible(endedItemID ?? "nil"),
                    "currentID": .stringConvertible(playbackItem?.baseItem.id ?? "nil"),
                ]
            )
            return
        }

        // Ended should represent natural ending of playback, which
        // is verifiable by given seconds being near item runtime.
        // VLC proxy will send ended early.

        // For live streams, ignore ended events (should be filtered by proxy, but defensive)
        if item.isLiveStream ?? false {
            logger.trace("Ignoring ended event for live stream")
            return
        }

        // If runtime is available, verify this is a natural ending (near end of content).
        // VLC proxy can send ended early, so we need to verify.
        if let runtime = item.runtime {
            let isNearEnd = (runtime - seconds) <= .seconds(1)

            guard isNearEnd else {
                // If not near end, this is likely a spurious ended event - ignore it
                logger.trace(
                    "Ignoring ended event - not near end of content",
                    metadata: [
                        "currentSeconds": .stringConvertible(seconds.seconds),
                        "runtime": .stringConvertible(runtime.seconds),
                        "delta": .stringConvertible((runtime - seconds).seconds),
                    ]
                )
                return
            }
        } else {
            // No runtime metadata available (rare, but possible for malformed items)
            // Log a warning but proceed with queue/stop logic
            logger.warning(
                "Ended event for item without runtime metadata",
                metadata: [
                    "itemID": .stringConvertible(item.id ?? "nil"),
                    "itemTitle": .stringConvertible(item.displayTitle),
                    "itemType": .stringConvertible(item.type?.rawValue ?? "unknown"),
                ]
            )
        }

        // Attempt to play next item in queue if autoplay is enabled
        // Use captured nextItemProvider instead of queue?.nextItem because
        // the queue will clear nextItem when playbackItem changes.
        if let nextItem = nextItemProvider, Defaults[.VideoPlayer.autoPlayEnabled] {
            logger.info("Auto-playing next item in queue")
            await self.playNewItem(provider: nextItem)
        } else {
            logger.info("Stopping playback (no next item or autoplay disabled)")
            await self.stop()
        }
    }

    @Function(\Action.Cases.error)
    private func onError(_ error: Error) async throws {
        // Expose error to UI before stopping
        self.playbackError = error

        if let playbackItem {
            logger.error(
                "Error while playing item",
                metadata: [
                    "error": .stringConvertible(error.localizedDescription),
                    "itemID": .stringConvertible(playbackItem.baseItem.id ?? "Unknown"),
                    "itemTitle": .stringConvertible(playbackItem.baseItem.displayTitle),
                    "url": .stringConvertible(playbackItem.url.absoluteString),
                ]
            )
        } else {
            logger.error(
                "Error with no playback item",
                metadata: [
                    "error": .stringConvertible(error.localizedDescription),
                    "itemID": .stringConvertible(item.id ?? "Unknown"),
                    "itemTitle": .stringConvertible(item.displayTitle),
                ]
            )
        }

        proxy?.stop()
        Container.shared.mediaPlayerManager.reset()
    }

    @Function(\Action.Cases.playNewItem)
    private func _playNewItem(_ provider: MediaPlayerItemProvider) async throws {
        item = provider.item
        setSupplements()
        proxy?.stop()
        playbackItem = try await provider()
    }

    @Function(\Action.Cases.setPlaybackRequestStatus)
    private func set(_ status: PlaybackRequestStatus) {
        if self.playbackRequestStatus != status {
            self.playbackRequestStatus = status

            switch status {
            case .paused:
                proxy?.pause()
            case .playing:
                proxy?.play()
            }
        }
    }

    @Function(\Action.Cases.setRate)
    private func set(_ rate: Float) {
        if self.rate != rate {
            self.rate = rate
        }
    }

    @Function(\Action.Cases.start)
    private func _start() async throws {
        guard let initialMediaPlayerItemProvider else {
            await self.stop()
            return
        }
        self.initialMediaPlayerItemProvider = nil
        playbackItem = try await initialMediaPlayerItemProvider()
    }

    @Function(\Action.Cases.stop)
    private func _stop() async throws {
        await self.cancel()

        // TODO: remove playback item?
        //       - check that observers would respond correctly to stopping
        itemBuildTask?.cancel()
        proxy?.stop()
        Container.shared.mediaPlayerManager.reset()
    }

    @Function(\Action.Cases.togglePlayPause)
    private func _togglePlayPause() {
        switch playbackRequestStatus {
        case .playing:
            setPlaybackRequestStatus(status: .paused)
        case .paused:
            setPlaybackRequestStatus(status: .playing)
        }
    }
}
