import AppKit
import SwiftUI

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class ScreensaverOverlay {
    private var windows: [NSWindow] = []
    private var screenObserver: Any?
    private(set) var isShowing = false
    let hintState = HintState()
    private var cursorHidden = false
    private var hintObserver: AnyCancellable?

    func show() {
        guard !isShowing else { return }
        isShowing = true
        buildWindows()
        hideCursor()
        NSApp.activate(ignoringOtherApps: true)
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isShowing else { return }
                self.tearDownWindows()
                self.buildWindows()
            }
        }
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false
        if let observer = screenObserver {
            NotificationCenter.default.removeObserver(observer)
            screenObserver = nil
        }
        hintState.hideHint()
        tearDownWindows()
        showCursor()
    }

    private func buildWindows() {
        for (index, screen) in NSScreen.screens.enumerated() {
            let window = OverlayWindow(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isReleasedWhenClosed = false
            window.level = .screenSaver
            window.isOpaque = true
            window.backgroundColor = .black
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.contentView = NSHostingView(rootView: ScreensaverView().environmentObject(hintState))
            window.setFrame(screen.frame, display: true)
            if index == 0 {
                window.makeKeyAndOrderFront(nil)
            } else {
                window.orderFrontRegardless()
            }
            windows.append(window)
        }
    }

    private func tearDownWindows() {
        for window in windows {
            window.orderOut(nil)
        }
        windows.removeAll()
    }

    private func hideCursor() {
        if !cursorHidden {
            NSCursor.hide()
            cursorHidden = true
        }
    }

    func showCursor() {
        if cursorHidden {
            NSCursor.unhide()
            cursorHidden = false
        }
    }
}

import Combine
