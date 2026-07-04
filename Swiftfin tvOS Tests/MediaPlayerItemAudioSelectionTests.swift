//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import JellyfinAPI
@testable import Swiftfin_tvOS
import XCTest

/// Regression tests for initial audio stream selection.
@MainActor
final class MediaPlayerItemAudioSelectionTests: XCTestCase {

    private let testURL = URL(string: "https://example.com/video")!

    private func makeStream(index: Int, type: MediaStreamType, language: String? = nil, displayTitle: String? = nil) -> MediaStream {
        var stream = MediaStream()
        stream.index = index
        stream.type = type
        stream.language = language
        stream.displayTitle = displayTitle
        return stream
    }

    private func makeMediaSource(defaultAudioStreamIndex: Int?, audioLanguages: [String]) -> MediaSourceInfo {
        var mediaStreams: [MediaStream] = [
            makeStream(index: 0, type: .video),
        ]

        for (offset, language) in audioLanguages.enumerated() {
            mediaStreams.append(
                makeStream(index: offset + 1, type: .audio, language: language, displayTitle: language)
            )
        }

        var mediaSource = MediaSourceInfo()
        mediaSource.transcodingURL = nil
        mediaSource.mediaStreams = mediaStreams
        mediaSource.defaultAudioStreamIndex = defaultAudioStreamIndex
        return mediaSource
    }

    private func makeItem(mediaSource: MediaSourceInfo) -> MediaPlayerItem {
        .init(
            baseItem: BaseItemDto(),
            mediaSource: mediaSource,
            playSessionID: "test-session",
            url: testURL
        )
    }

    func testSelectsFirstAudioWhenDefaultIsNil() {
        let originalPreferredLanguage = Defaults[.VideoPlayer.Audio.preferredLanguage]
        defer { Defaults[.VideoPlayer.Audio.preferredLanguage] = originalPreferredLanguage }
        Defaults[.VideoPlayer.Audio.preferredLanguage] = "zzz"

        let mediaSource = makeMediaSource(defaultAudioStreamIndex: nil, audioLanguages: ["eng", "spa"])
        let item = makeItem(mediaSource: mediaSource)

        XCTAssertEqual(item.audioStreams.count, 2)
        XCTAssertNotNil(item.selectedAudioStreamIndex)
        XCTAssertGreaterThanOrEqual(item.selectedAudioStreamIndex ?? -1, 0)
        XCTAssertEqual(item.selectedAudioStreamIndex, item.audioStreams.first?.index)
    }

    func testSelectsDefaultAudioWhenValid() {
        let originalPreferredLanguage = Defaults[.VideoPlayer.Audio.preferredLanguage]
        defer { Defaults[.VideoPlayer.Audio.preferredLanguage] = originalPreferredLanguage }
        Defaults[.VideoPlayer.Audio.preferredLanguage] = "zzz"

        let mediaSource = makeMediaSource(defaultAudioStreamIndex: 2, audioLanguages: ["eng", "spa"])
        let item = makeItem(mediaSource: mediaSource)

        XCTAssertEqual(item.audioStreams.count, 2)
        XCTAssertEqual(item.selectedAudioStreamIndex, 2)
    }

    func testSelectsPreferredLanguageOverDefault() {
        let originalPreferredLanguage = Defaults[.VideoPlayer.Audio.preferredLanguage]
        defer { Defaults[.VideoPlayer.Audio.preferredLanguage] = originalPreferredLanguage }
        Defaults[.VideoPlayer.Audio.preferredLanguage] = "spa"

        let mediaSource = makeMediaSource(defaultAudioStreamIndex: 1, audioLanguages: ["eng", "spa"])
        let item = makeItem(mediaSource: mediaSource)

        XCTAssertEqual(item.audioStreams.count, 2)
        XCTAssertEqual(item.selectedAudioStreamIndex, 2)
    }

    func testFallsBackWhenDefaultInvalid() {
        let originalPreferredLanguage = Defaults[.VideoPlayer.Audio.preferredLanguage]
        defer { Defaults[.VideoPlayer.Audio.preferredLanguage] = originalPreferredLanguage }
        Defaults[.VideoPlayer.Audio.preferredLanguage] = "zzz"

        let mediaSource = makeMediaSource(defaultAudioStreamIndex: 99, audioLanguages: ["eng", "spa"])
        let item = makeItem(mediaSource: mediaSource)

        XCTAssertEqual(item.audioStreams.count, 2)
        XCTAssertNotNil(item.selectedAudioStreamIndex)
        XCTAssertGreaterThanOrEqual(item.selectedAudioStreamIndex ?? -1, 0)
        XCTAssertEqual(item.selectedAudioStreamIndex, item.audioStreams.first?.index)
    }

    // MARK: audio-first containers (#61)

    /// iTunes-style layout: audio is the first track in the container,
    /// so its server index is 0 and VLC numbers it 0.
    private func makeAudioFirstMediaSource(
        defaultAudioStreamIndex: Int? = 0,
        audioLanguages: [String] = ["eng"],
        transcodingURL: String? = nil
    ) -> MediaSourceInfo {
        var mediaStreams: [MediaStream] = []

        for (offset, language) in audioLanguages.enumerated() {
            mediaStreams.append(
                makeStream(index: offset, type: .audio, language: language, displayTitle: language)
            )
        }
        mediaStreams.append(makeStream(index: audioLanguages.count, type: .video))
        mediaStreams.append(makeStream(index: audioLanguages.count + 1, type: .subtitle))

        var mediaSource = MediaSourceInfo()
        mediaSource.transcodingURL = transcodingURL
        mediaSource.mediaStreams = mediaStreams
        mediaSource.defaultAudioStreamIndex = defaultAudioStreamIndex
        return mediaSource
    }

    func testVLCIndexMapsToContainerOrderForAudioFirstFile() {
        let originalPreferredLanguage = Defaults[.VideoPlayer.Audio.preferredLanguage]
        defer { Defaults[.VideoPlayer.Audio.preferredLanguage] = originalPreferredLanguage }
        Defaults[.VideoPlayer.Audio.preferredLanguage] = "zzz"

        let item = makeItem(mediaSource: makeAudioFirstMediaSource())

        // Adjusted space renumbers video-first, so the only audio stream is 1
        XCTAssertEqual(item.selectedAudioStreamIndex, 1)
        // VLC numbers by container order, where audio is track 0
        XCTAssertEqual(item.vlcAudioTrackIndex(forAdjustedIndex: item.selectedAudioStreamIndex), 0)
    }

    func testVLCIndexUnchangedForVideoFirstFile() {
        let originalPreferredLanguage = Defaults[.VideoPlayer.Audio.preferredLanguage]
        defer { Defaults[.VideoPlayer.Audio.preferredLanguage] = originalPreferredLanguage }
        Defaults[.VideoPlayer.Audio.preferredLanguage] = "zzz"

        let mediaSource = makeMediaSource(defaultAudioStreamIndex: 1, audioLanguages: ["eng", "spa"])
        let item = makeItem(mediaSource: mediaSource)

        XCTAssertEqual(item.vlcAudioTrackIndex(forAdjustedIndex: 1), 1)
        XCTAssertEqual(item.vlcAudioTrackIndex(forAdjustedIndex: 2), 2)
    }

    func testVLCIndexUnchangedForTranscode() {
        let originalPreferredLanguage = Defaults[.VideoPlayer.Audio.preferredLanguage]
        defer { Defaults[.VideoPlayer.Audio.preferredLanguage] = originalPreferredLanguage }
        Defaults[.VideoPlayer.Audio.preferredLanguage] = "zzz"

        // Server muxes the transcode video-first, so the adjusted index is
        // already what VLC sees regardless of source container order
        let mediaSource = makeAudioFirstMediaSource(transcodingURL: "https://example.com/transcode.m3u8")
        let item = makeItem(mediaSource: mediaSource)

        XCTAssertEqual(item.selectedAudioStreamIndex, 1)
        XCTAssertEqual(item.vlcAudioTrackIndex(forAdjustedIndex: item.selectedAudioStreamIndex), 1)
    }

    func testMultiAudioAudioFirstMapsSecondTrack() {
        let originalPreferredLanguage = Defaults[.VideoPlayer.Audio.preferredLanguage]
        defer { Defaults[.VideoPlayer.Audio.preferredLanguage] = originalPreferredLanguage }
        Defaults[.VideoPlayer.Audio.preferredLanguage] = "zzz"

        // Server default is the second audio track (index 1 in server space)
        let mediaSource = makeAudioFirstMediaSource(defaultAudioStreamIndex: 1, audioLanguages: ["eng", "spa"])
        let item = makeItem(mediaSource: mediaSource)

        // Selection maps the server default by position: spa is adjusted index 2
        XCTAssertEqual(item.selectedAudioStreamIndex, 2)
        XCTAssertEqual(
            item.audioStreams.first(where: { $0.index == item.selectedAudioStreamIndex })?.language,
            "spa"
        )
        // VLC's audio tracks are numbered [0, 1] in container order
        XCTAssertEqual(item.vlcAudioTrackIndex(forAdjustedIndex: 2), 1)
    }

    func testVLCIndexNilForNilSelection() {
        let mediaSource = makeMediaSource(defaultAudioStreamIndex: nil, audioLanguages: [])
        let item = makeItem(mediaSource: mediaSource)

        XCTAssertNil(item.vlcAudioTrackIndex(forAdjustedIndex: nil))
    }
}
