//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import JellyfinAPI
@testable import Swiftfin_tvOS
import XCTest

/// Tests for initial subtitle stream selection, including the mapping from
/// original server stream indexes to the adjusted index space.
@MainActor
final class MediaPlayerItemSubtitleSelectionTests: XCTestCase {

    private let testURL = URL(string: "https://example.com/video")!

    private func makeStream(index: Int, type: MediaStreamType, language: String? = nil) -> MediaStream {
        var stream = MediaStream()
        stream.index = index
        stream.type = type
        stream.language = language
        stream.displayTitle = language
        return stream
    }

    /// Streams ordered video, subtitles, audio so that direct-play
    /// renumbering (video, audio, subtitles) shifts subtitle indexes.
    private func makeMediaSource(
        defaultSubtitleStreamIndex: Int? = nil,
        transcoding: Bool = false
    ) -> MediaSourceInfo {
        var mediaSource = MediaSourceInfo()
        mediaSource.mediaStreams = [
            makeStream(index: 0, type: .video),
            makeStream(index: 1, type: .subtitle, language: "eng"),
            makeStream(index: 2, type: .subtitle, language: "spa"),
            makeStream(index: 3, type: .audio, language: "eng"),
            makeStream(index: 4, type: .audio, language: "spa"),
        ]
        mediaSource.defaultAudioStreamIndex = 3
        mediaSource.defaultSubtitleStreamIndex = defaultSubtitleStreamIndex
        mediaSource.transcodingURL = transcoding ? "/transcode" : nil
        return mediaSource
    }

    private func makeItem(mediaSource: MediaSourceInfo, preferred: Int?) -> MediaPlayerItem {
        .init(
            baseItem: BaseItemDto(),
            mediaSource: mediaSource,
            playSessionID: "test-session",
            url: testURL,
            preferredSubtitleStreamIndex: preferred
        )
    }

    func testNilPreferredUsesServerDefault() {
        // Pre-existing behavior: the server default passes through unmapped
        let mediaSource = makeMediaSource(defaultSubtitleStreamIndex: 1)
        let item = makeItem(mediaSource: mediaSource, preferred: nil)

        XCTAssertEqual(item.selectedSubtitleStreamIndex, 1)
    }

    func testNilPreferredAndNoDefaultIsOff() {
        let mediaSource = makeMediaSource()
        let item = makeItem(mediaSource: mediaSource, preferred: nil)

        XCTAssertEqual(item.selectedSubtitleStreamIndex, -1)
    }

    func testPreferredOffStaysOff() {
        let mediaSource = makeMediaSource(defaultSubtitleStreamIndex: 1)
        let item = makeItem(mediaSource: mediaSource, preferred: -1)

        XCTAssertEqual(item.selectedSubtitleStreamIndex, -1)
    }

    func testPreferredMapsToAdjustedIndexDirectPlay() {
        // Direct play reorders to video(0), audio(1, 2), subtitles(3, 4):
        // original subtitle index 2 ("spa", position 1) becomes adjusted index 4
        let mediaSource = makeMediaSource()
        let item = makeItem(mediaSource: mediaSource, preferred: 2)

        XCTAssertEqual(item.subtitleStreams.count, 2)
        XCTAssertEqual(item.selectedSubtitleStreamIndex, 4)
        XCTAssertEqual(item.subtitleStreams.last?.language, "spa")
    }

    func testPreferredMapsToAdjustedIndexTranscode() {
        // Transcode keeps video(0) + selected audio(1), then subtitles(2, 3):
        // original subtitle index 2 ("spa", position 1) becomes adjusted index 3
        let mediaSource = makeMediaSource(transcoding: true)
        let item = makeItem(mediaSource: mediaSource, preferred: 2)

        XCTAssertEqual(item.subtitleStreams.count, 2)
        XCTAssertEqual(item.selectedSubtitleStreamIndex, 3)
        XCTAssertEqual(item.subtitleStreams.last?.language, "spa")
    }

    func testBogusPreferredFallsBackToDefault() {
        let mediaSource = makeMediaSource(defaultSubtitleStreamIndex: 1)
        let item = makeItem(mediaSource: mediaSource, preferred: 99)

        XCTAssertEqual(item.selectedSubtitleStreamIndex, 1)
    }

    // MARK: sticky per-title selection

    private func adjustedSubtitleStreams(for mediaSource: MediaSourceInfo) -> [MediaStream] {
        let adjusted = mediaSource.mediaStreams?.adjustedTrackIndexes(
            for: mediaSource.transcodingURL == nil ? .directPlay : .transcode,
            selectedAudioStreamIndex: mediaSource.defaultAudioStreamIndex ?? 0
        )
        return adjusted?.filter { $0.type == .subtitle } ?? []
    }

    func testStickyLanguageSelectsMatchingStream() {
        // Direct play renumbers to video(0), audio(1, 2), subtitles(3 eng, 4 spa)
        let mediaSource = makeMediaSource()

        let index = MediaPlayerItem.initialSubtitleStreamIndex(
            preferred: nil,
            stickyLanguage: "spa",
            mediaSource: mediaSource,
            adjustedSubtitleStreams: adjustedSubtitleStreams(for: mediaSource)
        )

        XCTAssertEqual(index, 4)
    }

    func testStickyLanguageIsCaseInsensitive() {
        let mediaSource = makeMediaSource()

        let index = MediaPlayerItem.initialSubtitleStreamIndex(
            preferred: nil,
            stickyLanguage: "SPA",
            mediaSource: mediaSource,
            adjustedSubtitleStreams: adjustedSubtitleStreams(for: mediaSource)
        )

        XCTAssertEqual(index, 4)
    }

    func testStickyOffOverridesServerDefault() {
        let mediaSource = makeMediaSource(defaultSubtitleStreamIndex: 1)

        let index = MediaPlayerItem.initialSubtitleStreamIndex(
            preferred: nil,
            stickyLanguage: "off",
            mediaSource: mediaSource,
            adjustedSubtitleStreams: adjustedSubtitleStreams(for: mediaSource)
        )

        XCTAssertEqual(index, -1)
    }

    func testStickyUnmatchedLanguageFallsBackToDefault() {
        let mediaSource = makeMediaSource(defaultSubtitleStreamIndex: 1)

        let index = MediaPlayerItem.initialSubtitleStreamIndex(
            preferred: nil,
            stickyLanguage: "ger",
            mediaSource: mediaSource,
            adjustedSubtitleStreams: adjustedSubtitleStreams(for: mediaSource)
        )

        XCTAssertEqual(index, 1)
    }

    func testPreferredWinsOverSticky() {
        // Explicit pick of original index 1 ("eng", position 0) maps to adjusted index 3
        let mediaSource = makeMediaSource()

        let index = MediaPlayerItem.initialSubtitleStreamIndex(
            preferred: 1,
            stickyLanguage: "spa",
            mediaSource: mediaSource,
            adjustedSubtitleStreams: adjustedSubtitleStreams(for: mediaSource)
        )

        XCTAssertEqual(index, 3)
    }
}
