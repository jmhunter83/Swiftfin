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

    private func makeStream(index: Int, type: MediaStreamType, language: String? = nil, isExternal: Bool = false) -> MediaStream {
        var stream = MediaStream()
        stream.index = index
        stream.type = type
        stream.language = language
        stream.displayTitle = language
        stream.isExternal = isExternal
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

    /// Arbitrary stream layouts for container-order cases.
    private func makeMediaSource(
        streams: [MediaStream],
        defaultAudioStreamIndex: Int? = nil,
        transcoding: Bool = false
    ) -> MediaSourceInfo {
        var mediaSource = MediaSourceInfo()
        mediaSource.mediaStreams = streams
        mediaSource.defaultAudioStreamIndex = defaultAudioStreamIndex
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

    // MARK: container-order VLC mapping (#61)

    func testVLCSubtitleIndexMapsToContainerOrderDirectPlay() {
        // Container order is video(0), subtitles(1, 2), audio(3, 4), so the
        // adjusted subtitle indexes 3 and 4 are VLC tracks 1 and 2
        let item = makeItem(mediaSource: makeMediaSource(), preferred: nil)

        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 3), 1)
        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 4), 2)
    }

    func testVLCSubtitleIndexUnchangedWhenSubsLast() {
        // video(0), audio(1), subtitles(2, 3): adjusted order matches the container
        let mediaSource = makeMediaSource(
            streams: [
                makeStream(index: 0, type: .video),
                makeStream(index: 1, type: .audio, language: "eng"),
                makeStream(index: 2, type: .subtitle, language: "eng"),
                makeStream(index: 3, type: .subtitle, language: "spa"),
            ],
            defaultAudioStreamIndex: 1
        )
        let item = makeItem(mediaSource: mediaSource, preferred: nil)

        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 2), 2)
        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 3), 3)
    }

    func testVLCSubtitleIndexUnchangedForAudioFirstFileWithSubsLast() {
        // Audio-first shifts video and audio in the adjusted space, but the
        // subtitle track sits last in the container either way
        let mediaSource = makeMediaSource(
            streams: [
                makeStream(index: 0, type: .audio, language: "eng"),
                makeStream(index: 1, type: .video),
                makeStream(index: 2, type: .subtitle, language: "eng"),
            ],
            defaultAudioStreamIndex: 0
        )
        let item = makeItem(mediaSource: mediaSource, preferred: nil)

        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 2), 2)
    }

    func testVLCSubtitleIndexExternalPassesThrough() {
        // External subs load as playback slaves, which VLC numbers after the
        // container tracks - the same relative spot the adjusted space uses
        let mediaSource = makeMediaSource(
            streams: [
                makeStream(index: 0, type: .video),
                makeStream(index: 1, type: .subtitle, language: "eng"),
                makeStream(index: 2, type: .audio, language: "eng"),
                makeStream(index: 3, type: .subtitle, language: "spa", isExternal: true),
            ],
            defaultAudioStreamIndex: 2
        )
        let item = makeItem(mediaSource: mediaSource, preferred: nil)

        // Internal sub at adjusted 2 maps to container index 1; external stays put
        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 2), 1)
        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 3), 3)
    }

    func testVLCSubtitleIndexExternalPassesThroughAudioFirst() {
        let mediaSource = makeMediaSource(
            streams: [
                makeStream(index: 0, type: .audio, language: "eng"),
                makeStream(index: 1, type: .video),
                makeStream(index: 2, type: .subtitle, language: "eng"),
                makeStream(index: 3, type: .subtitle, language: "spa", isExternal: true),
            ],
            defaultAudioStreamIndex: 0
        )
        let item = makeItem(mediaSource: mediaSource, preferred: nil)

        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 2), 2)
        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 3), 3)
    }

    func testVLCSubtitleIndexOffAndNilPassThrough() {
        let item = makeItem(mediaSource: makeMediaSource(), preferred: nil)

        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: -1), -1)
        XCTAssertNil(item.vlcSubtitleTrackIndex(forAdjustedIndex: nil))
    }

    func testVLCSubtitleIndexUnchangedForTranscode() {
        // Transcoded subs arrive as extracted slaves aligned with the
        // adjusted order, so the index passes through like the audio path
        let item = makeItem(mediaSource: makeMediaSource(transcoding: true), preferred: nil)

        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 2), 2)
        XCTAssertEqual(item.vlcSubtitleTrackIndex(forAdjustedIndex: 3), 3)
    }

    // MARK: server-space reporting indexes

    func testServerSubtitleIndexReversesAdjustedDirectPlay() {
        let item = makeItem(mediaSource: makeMediaSource(), preferred: nil)

        XCTAssertEqual(item.serverSubtitleStreamIndex(forAdjustedIndex: 3), 1)
        XCTAssertEqual(item.serverSubtitleStreamIndex(forAdjustedIndex: 4), 2)
    }

    func testServerSubtitleIndexReversesAdjustedTranscode() {
        // Transcode renumbers to video(0), audio(1), subtitles(2, 3); the
        // server still knows those subs as indexes 1 and 2
        let item = makeItem(mediaSource: makeMediaSource(transcoding: true), preferred: nil)

        XCTAssertEqual(item.serverSubtitleStreamIndex(forAdjustedIndex: 2), 1)
        XCTAssertEqual(item.serverSubtitleStreamIndex(forAdjustedIndex: 3), 2)
    }

    func testServerSubtitleIndexSurvivesDroppedStreams() {
        // The embedded image stream is dropped from the adjusted space
        // entirely, shifting positions; server indexes must come from the
        // original streams, not from counting
        let mediaSource = makeMediaSource(
            streams: [
                makeStream(index: 0, type: .video),
                makeStream(index: 1, type: .audio, language: "eng"),
                makeStream(index: 2, type: .embeddedImage),
                makeStream(index: 3, type: .subtitle, language: "eng"),
                makeStream(index: 4, type: .subtitle, language: "spa", isExternal: true),
            ],
            defaultAudioStreamIndex: 1
        )
        let item = makeItem(mediaSource: mediaSource, preferred: nil)

        XCTAssertEqual(item.serverSubtitleStreamIndex(forAdjustedIndex: 2), 3)
        XCTAssertEqual(item.serverSubtitleStreamIndex(forAdjustedIndex: 3), 4)
    }

    func testServerSubtitleIndexOffAndNilPassThrough() {
        let item = makeItem(mediaSource: makeMediaSource(), preferred: nil)

        XCTAssertEqual(item.serverSubtitleStreamIndex(forAdjustedIndex: -1), -1)
        XCTAssertNil(item.serverSubtitleStreamIndex(forAdjustedIndex: nil))
    }
}
