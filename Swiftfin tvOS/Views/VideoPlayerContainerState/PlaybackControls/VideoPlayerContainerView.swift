//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Combine
import SwiftUI

extension VideoPlayer {
    struct VideoPlayerContainerView<Player: View, PlaybackControls: View>: UIViewControllerRepresentable {

        private let containerState: VideoPlayerContainerState
        private let manager: MediaPlayerManager
        private let player: () -> Player
        private let playbackControls: () -> PlaybackControls

        init(
            containerState: VideoPlayerContainerState,
            manager: MediaPlayerManager,
            @ViewBuilder player: @escaping () -> Player,
            @ViewBuilder playbackControls: @escaping () -> PlaybackControls
        ) {
            self.containerState = containerState
            self.manager = manager
            self.player = player
            self.playbackControls = playbackControls
        }

        func makeUIViewController(context: Context) -> UIVideoPlayerContainerViewController {
            UIVideoPlayerContainerViewController(
                containerState: containerState,
                manager: manager,
                player: player().eraseToAnyView(),
                playbackControls: playbackControls().eraseToAnyView()
            )
        }

        func updateUIViewController(
            _ uiViewController: UIVideoPlayerContainerViewController,
            context: Context
        ) {}
    }

    // MARK: - UIVideoPlayerContainerViewController

    class UIVideoPlayerContainerViewController: UIViewController {

        private struct PlayerContainerView: View {

            @EnvironmentObject
            private var containerState: VideoPlayerContainerState

            let player: AnyView

            var body: some View {
                player
                    .overlay(Color.black.opacity(containerState.isPresentingPlaybackControls ? 0.3 : 0.0))
                    .animation(.linear(duration: 0.2), value: containerState.isPresentingPlaybackControls)
            }
        }

        private lazy var playerViewController: UIHostingController<AnyView> = {
            let controller = UIHostingController(
                rootView: PlayerContainerView(player: player)
                    .environmentObject(containerState)
                    .environmentObject(manager)
                    .eraseToAnyView()
            )
            controller.disableSafeArea()
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            return controller
        }()

        private lazy var playbackControlsViewController: UIHostingController<AnyView> = {
            let controller = UIHostingController(
                rootView: playbackControls
                    .environment(\.onPressEventPublisher, onPressEvent)
                    .environmentObject(containerState)
                    .environmentObject(containerState.scrubbedSeconds)
                    .environmentObject(focusGuide)
                    .environmentObject(manager)
                    .eraseToAnyView()
            )
            controller.disableSafeArea()
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            return controller
        }()

        private lazy var supplementContainerViewController: UIHostingController<AnyView> = {
            let content = SupplementContainerView()
                .environmentObject(containerState)
                .environmentObject(focusGuide)
                .environmentObject(manager)
                .eraseToAnyView()
            let controller = UIHostingController(rootView: content)
            controller.disableSafeArea()
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            return controller
        }()

        private var playerView: UIView {
            playerViewController.view
        }

        private var playbackControlsView: UIView {
            playbackControlsViewController.view
        }

        private var supplementContainerView: UIView {
            supplementContainerViewController.view
        }

        private var supplementRegularConstraints: [NSLayoutConstraint] = []
        private var playerRegularConstraints: [NSLayoutConstraint] = []
        private var playbackControlsConstraints: [NSLayoutConstraint] = []

        private var supplementHeightAnchor: NSLayoutConstraint!
        private var supplementBottomAnchor: NSLayoutConstraint!

        private let manager: MediaPlayerManager
        private let player: AnyView
        private let playbackControls: AnyView
        private let containerState: VideoPlayerContainerState

        let focusGuide = FocusGuide()
        let onPressEvent = OnPressEvent()

        private var cancellables: Set<AnyCancellable> = []

        private var isSwallowingMenuPress = false

        // MARK: - Focus Management

        override var preferredFocusEnvironments: [UIFocusEnvironment] {
            if containerState.isPresentingOverlay || containerState.isPresentingSupplement {
                return [playbackControlsViewController]
            }
            return []
        }

        init(
            containerState: VideoPlayerContainerState,
            manager: MediaPlayerManager,
            player: AnyView,
            playbackControls: AnyView
        ) {
            self.containerState = containerState
            self.manager = manager
            self.player = player
            self.playbackControls = playbackControls

            super.init(nibName: nil, bundle: nil)

            containerState.containerView = self
            containerState.manager = manager
            containerState.observePlaybackStatus()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - didPresent

        func presentSupplementContainer(
            _ didPresent: Bool
        ) {
            let oldConstant = supplementBottomAnchor.constant
            if didPresent {
                self.supplementBottomAnchor.constant = -(500 + EdgeInsets.edgePadding * 2)
            } else {
                self.supplementBottomAnchor.constant = -(100 + EdgeInsets.edgePadding)
            }

            let newConstant = supplementBottomAnchor.constant
            print("🎯 Supplement positioning: \(didPresent ? "PRESENTING" : "DISMISSING") - constant: \(oldConstant) -> \(newConstant)")

            containerState.isPresentingPlaybackControls = !didPresent
            containerState.supplementOffset = supplementBottomAnchor.constant

            UIView.animate(
                withDuration: 0.75,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.4,
                options: .allowUserInteraction
            ) {
                self.view.layoutIfNeeded()
            } completion: { _ in
                print("✅ Supplement animation completed: final constant = \(self.supplementBottomAnchor.constant)")
            }
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            view.backgroundColor = .black

            setupViews()
            setupConstraints()
            setupFocusObserver()
            setupScenePhaseObserver()

            let gesture = UITapGestureRecognizer(target: self, action: #selector(ignorePress))
            gesture.allowedPressTypes = [NSNumber(value: UIPress.PressType.menu.rawValue)]
            view.addGestureRecognizer(gesture)
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            // Stop proxy immediately for instant audio cutoff
            manager.proxy?.stop()
            // Then clean up manager state
            manager.stop()
        }

        private func setupScenePhaseObserver() {
            NotificationCenter.default
                .publisher(for: UIScene.didEnterBackgroundNotification)
                .sink { [weak self] _ in
                    guard let self else { return }
                    Task { @MainActor in
                        guard self.manager.state == .loadingItem || self.manager.state == .playback else { return }

                        self.manager.logger.info("App entered background - stopping playback")

                        // Cut audio immediately, then clean up manager state.
                        self.manager.proxy?.stop()
                        self.manager.stop()
                    }
                }
                .store(in: &cancellables)
        }

        /// Request a focus update only when the view is still in the hierarchy.
        /// Guards against triggering UIKit's motion-effect applicator while views
        /// are being torn down, which can crash on tvOS 26.2 (FB: rdar://…).
        private func requestFocusUpdateIfSafe() {
            guard isViewLoaded, view.window != nil else { return }
            setNeedsFocusUpdate()
            updateFocusIfNeeded()
        }

        private func setupFocusObserver() {
            containerState.$overlayState
                .removeDuplicates()
                .sink { [weak self] (state: OverlayVisibility) in
                    guard let self else { return }
                    if state == .visible {
                        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.focusUpdateDelay) { [weak self] in
                            self?.requestFocusUpdateIfSafe()
                        }
                    }
                }
                .store(in: &cancellables)

            containerState.$supplementState
                .removeDuplicates()
                .sink { [weak self] (state: SupplementVisibility) in
                    guard let self else { return }
                    if state == .open {
                        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.focusUpdateDelay) { [weak self] in
                            self?.requestFocusUpdateIfSafe()
                        }
                    }
                }
                .store(in: &cancellables)
        }

        private func setupViews() {
            addChild(playerViewController)
            view.addSubview(playerView)
            playerViewController.didMove(toParent: self)
            playerView.backgroundColor = .black
            // Prevent player view from participating in focus
            playerView.isUserInteractionEnabled = false

            addChild(playbackControlsViewController)
            view.addSubview(playbackControlsView)
            playbackControlsViewController.didMove(toParent: self)
            playbackControlsView.backgroundColor = .clear
            // Ensure controls can receive focus
            playbackControlsView.isUserInteractionEnabled = true

            addChild(supplementContainerViewController)
            view.addSubview(supplementContainerView)
            supplementContainerViewController.didMove(toParent: self)
            supplementContainerView.backgroundColor = .clear
        }

        private func setupConstraints() {
            playerRegularConstraints = [
                playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                playerView.topAnchor.constraint(equalTo: view.topAnchor),
                playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ]

            NSLayoutConstraint.activate(playerRegularConstraints)

            supplementBottomAnchor = supplementContainerView.topAnchor.constraint(
                equalTo: view.bottomAnchor,
                constant: -(100 + EdgeInsets.edgePadding)
            )
            // Defer to avoid "Publishing changes from within view updates" warning
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.containerState.supplementOffset = self.supplementBottomAnchor.constant
            }

            let constant = (500 + EdgeInsets.edgePadding * 2)
            supplementHeightAnchor = supplementContainerView.heightAnchor.constraint(equalToConstant: constant)

            supplementRegularConstraints = [
                supplementContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                supplementContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                supplementBottomAnchor,
                supplementHeightAnchor,
            ]

            NSLayoutConstraint.activate(supplementRegularConstraints)

            playbackControlsConstraints = [
                playbackControlsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                playbackControlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                playbackControlsView.topAnchor.constraint(equalTo: view.topAnchor),
                playbackControlsView.bottomAnchor.constraint(equalTo: supplementContainerView.topAnchor),
            ]

            NSLayoutConstraint.activate(playbackControlsConstraints)
        }

        @objc
        func ignorePress() {}

        override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            guard let buttonPress = presses.first else {
                super.pressesBegan(presses, with: event)
                return
            }

            // Send event to SwiftUI for overlay toggle handling
            onPressEvent.send((type: buttonPress.type, phase: .began))

            // For Menu button: swallow press when overlay/supplement is visible
            if buttonPress.type == .menu,
               containerState.isPresentingOverlay || containerState.isPresentingSupplement
            {
                isSwallowingMenuPress = true
                return
            }

            // Call super to allow UIKit focus navigation to work
            super.pressesBegan(presses, with: event)
        }

        override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            guard let buttonPress = presses.first else {
                super.pressesEnded(presses, with: event)
                return
            }

            // Send ended event to SwiftUI for hold detection
            onPressEvent.send((type: buttonPress.type, phase: .ended))

            // For Menu button: swallow press if we swallowed the began event
            if buttonPress.type == .menu, isSwallowingMenuPress {
                isSwallowingMenuPress = false
                return
            }

            // Call super to allow UIKit focus navigation to work
            super.pressesEnded(presses, with: event)
        }

        override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
            guard let buttonPress = presses.first else {
                super.pressesCancelled(presses, with: event)
                return
            }

            // Treat cancelled as ended for hold detection
            onPressEvent.send((type: buttonPress.type, phase: .cancelled))

            // For Menu button: swallow press if we swallowed the began event
            if buttonPress.type == .menu, isSwallowingMenuPress {
                isSwallowingMenuPress = false
                return
            }

            // Call super
            super.pressesCancelled(presses, with: event)
        }
    }
}

extension VideoPlayer.UIVideoPlayerContainerViewController {

    typealias PressEvent = (type: UIPress.PressType, phase: UIPress.Phase)
    typealias OnPressEvent = LegacyEventPublisher<PressEvent>
}

@propertyWrapper
struct OnPressEvent: DynamicProperty {

    @Environment(\.onPressEventPublisher)
    private var publisher

    var wrappedValue: VideoPlayer.UIVideoPlayerContainerViewController.OnPressEvent {
        publisher
    }
}

extension EnvironmentValues {

    @Entry
    var onPressEventPublisher: VideoPlayer.UIVideoPlayerContainerViewController.OnPressEvent = .init()
}
