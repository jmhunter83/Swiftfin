//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import PreferencesView
import SwiftUI
import VLCUI

extension VideoPlayer {

    struct PlaybackControls: View {

        /// since this view ignores safe area, it must
        /// get safe area insets from parent views
        @Environment(\.safeAreaInsets)
        private var safeAreaInsets

        @EnvironmentObject
        private var containerState: VideoPlayerContainerState
        @EnvironmentObject
        private var focusGuide: FocusGuide
        @EnvironmentObject
        private var manager: MediaPlayerManager

        @OnPressEvent
        private var onPressEvent

        @Router
        private var router

        // MARK: - Multi-Click Skip State

        /// Skip amounts: [15s, 2min, 5min]
        private let skipAmounts: [Duration] = [
            .seconds(15),
            .seconds(120),
            .seconds(300),
        ]

        @State
        private var forwardClickCount: Int = 0
        @State
        private var backwardClickCount: Int = 0
        @State
        private var forwardResetTask: Task<Void, Never>?
        @State
        private var backwardResetTask: Task<Void, Never>?
        @State
        private var skipIndicatorResetTask: Task<Void, Never>?

        private var isPresentingOverlay: Bool {
            containerState.isPresentingOverlay
        }

        private var isPresentingSupplement: Bool {
            containerState.isPresentingSupplement
        }

        @ViewBuilder
        private var titleOverlay: some View {
            if !isPresentingSupplement {
                VStack(alignment: .leading, spacing: 8) {
                    if manager.item.type == .episode {
                        // Episode: Show S#E# • Series Name • Episode Title • Year
                        if let seasonEpisodeLabel = manager.item.seasonEpisodeLabel {
                            Text(seasonEpisodeLabel)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.5), radius: 8)
                        }

                        if let seriesName = manager.item.seriesName {
                            Text(seriesName)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.5), radius: 8)
                        }

                        Text(manager.item.displayTitle)
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.5), radius: 8)

                        if let year = manager.item.premiereDateYear {
                            Text(year)
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.7))
                                .shadow(color: .black.opacity(0.5), radius: 8)
                        }
                    } else {
                        // Non-episode: Show Title • Year
                        Text(manager.item.displayTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 8)

                        if let year = manager.item.premiereDateYear {
                            Text(year)
                                .font(.title3)
                                .foregroundStyle(.white.opacity(0.8))
                                .shadow(color: .black.opacity(0.5), radius: 8)
                        }
                    }
                }
                .padding(.leading, 80)
                .padding(.top, 60)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .isVisible(isScrubbing || isPresentingOverlay)
            }
        }

        private var transportBarContent: some View {
            HStack(spacing: 20) {
                // Previous episode button
                NavigationBar.ActionButtons.PlayPreviousItem()

                Spacer()

                // Progress display
                PlaybackProgress()

                Spacer()

                // Next episode button
                NavigationBar.ActionButtons.PlayNextItem()
            }
            .focusGuide(focusGuide, tag: "transportBar", top: "sideButtons")
        }

        @ViewBuilder
        private var transportBar: some View {
            if !isPresentingSupplement {
                VStack(spacing: 8) {
                    transportBarContent
                        .padding(.horizontal, 60)
                        .padding(.vertical, 30)
                        .background {
                            TransportBarBackground()
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(color: .black.opacity(0.4), radius: 16)

                    // Skip explainer label
                    Text("← → Skip: 1×=15s  2×=2min  3×=5min")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 60)
                        .padding(.bottom, 20)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }

        // MARK: - Skip Indicator

        @ViewBuilder
        private var skipIndicator: some View {
            if let text = containerState.skipIndicatorText {
                Text(text)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10)
                    .transition(.scale.combined(with: .opacity))
            }
        }

        var body: some View {
            GeometryReader { _ in
                ZStack {
                    // Title in top-left
                    titleOverlay

                    // Skip indicator in center
                    skipIndicator
                        .animation(.easeOut(duration: 0.2), value: containerState.skipIndicatorText)

                    // Side action buttons (right edge, vertically stacked)
                    SideActionButtons()

                    // Transport bar pinned to bottom
                    VStack {
                        Spacer()

                        transportBar
                            .padding(.horizontal, 40)
                            .padding(.bottom, 60)
                            .opacity(isScrubbing || isPresentingOverlay ? 1 : 0)
                            .disabled(!(isScrubbing || isPresentingOverlay))
                    }
                }
            }
            .animation(.linear(duration: 0.1), value: isScrubbing)
            .animation(.bouncy(duration: 0.4), value: isPresentingSupplement)
            .animation(.bouncy(duration: 0.25), value: isPresentingOverlay)
            .onDisappear {
                // Clean up any active scrubbing timers when view disappears
                containerState.cleanupScrubbing()
                forwardResetTask?.cancel()
                backwardResetTask?.cancel()
                skipIndicatorResetTask?.cancel()
            }
            .onChange(of: isPresentingOverlay) { _, isPresenting in
                if isPresenting {
                    DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.skipIndicatorResetDelay) {
                        focusGuide.transition(to: "sideButtons")
                    }
                }
            }
            .onReceive(onPressEvent) { press in
                switch press {
                case (.playPause, .began):
                    // Show overlay and toggle play/pause
                    if !containerState.isPresentingOverlay {
                        withAnimation(.linear(duration: 0.25)) {
                            containerState.isPresentingOverlay = true
                        }
                    } else {
                        containerState.userDidInteract()
                    }
                    manager.togglePlayPause()

                case (.leftArrow, .began):
                    // Skip backward with multi-click
                    handleSkip(direction: .backward)

                case (.rightArrow, .began):
                    // Skip forward with multi-click
                    handleSkip(direction: .forward)

                case (.menu, .began):
                    if isPresentingSupplement {
                        containerState.select(supplement: nil)
                    } else if containerState.supplementRecentlyDismissed {
                        // Supplement was just dismissed - clear flag but keep overlay visible
                        containerState.supplementRecentlyDismissed = false
                    } else if isScrubbing {
                        // Menu during a touch-surface scrub cancels it instead of exiting
                        containerState.cancelPanScrub()
                    } else if isPresentingOverlay {
                        // First menu press hides overlay
                        withAnimation(.linear(duration: 0.25)) {
                            containerState.isPresentingOverlay = false
                        }
                    } else {
                        // Overlay hidden - exit playback
                        manager.proxy?.stop()
                        router.dismiss()
                    }

                case (.menu, .ended), (.menu, .cancelled):
                    // Explicitly ignore - prevent falling to default case which would re-show overlay
                    break

                default:
                    // Other buttons show overlay
                    if !containerState.isPresentingOverlay {
                        withAnimation(.linear(duration: 0.25)) {
                            containerState.isPresentingOverlay = true
                        }
                    } else {
                        containerState.userDidInteract()
                    }
                }
            }
        }

        private var isScrubbing: Bool {
            containerState.isScrubbing
        }

        // MARK: - Multi-Click Skip Logic

        private func handleSkip(direction: SkipDirection) {
            manager.logger.trace(
                "Skip \(direction): status=\(manager.playbackRequestStatus), scrub=\(containerState.scrubState), proxy=\(manager.proxy == nil ? "nil" : "set")"
            )

            // Tap-to-skip is a playback-only gesture; while paused the
            // touch surface scrubs instead. If skips ever go dead during
            // visible playback, the trace above shows which gate ate them
            // (suspect: VLC's transient paused report after a seek syncing
            // into playbackRequestStatus)
            guard manager.playbackRequestStatus == .playing else { return }

            // Show overlay if not visible
            if !containerState.isPresentingOverlay {
                withAnimation(.linear(duration: 0.25)) {
                    containerState.isPresentingOverlay = true
                }
            }
            containerState.userDidInteract()

            switch direction {
            case .forward:
                forwardResetTask?.cancel()
                forwardClickCount = min(forwardClickCount + 1, skipAmounts.count)

                let skipAmount = skipAmounts[forwardClickCount - 1]
                manager.proxy?.jumpForward(skipAmount)
                containerState.skipIndicatorText = "+\(formatDuration(skipAmount.seconds))"

                forwardResetTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    forwardClickCount = 0
                }

            case .backward:
                backwardResetTask?.cancel()
                backwardClickCount = min(backwardClickCount + 1, skipAmounts.count)

                let skipAmount = skipAmounts[backwardClickCount - 1]
                manager.proxy?.jumpBackward(skipAmount)
                containerState.skipIndicatorText = "−\(formatDuration(skipAmount.seconds))"

                backwardResetTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    backwardClickCount = 0
                }
            }

            // Auto-hide skip indicator after delay
            skipIndicatorResetTask?.cancel()
            skipIndicatorResetTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                containerState.skipIndicatorText = nil
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

        private enum SkipDirection {
            case forward
            case backward
        }
    }
}
