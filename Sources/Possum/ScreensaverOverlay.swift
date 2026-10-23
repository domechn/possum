import AppKit
import Combine
import SwiftUI

final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class ScreensaverOverlay {
    private var windows: [NSWindow] = []
    private var observers: [NSObjectProtocol] = []
    private(set) var isShowing = false
    let hintState = HintState()
    /// Called when the on-screen exit button is clicked.
    var onExitRequested: (() -> Void)?
    private var cursorHidden = false
    private var hintObserver: AnyCancellable?

    func show() {
        guard !isShowing else { return }
        isShowing = true
        buildWindows()
        NSApp.activate(ignoringOtherApps: true)
        // Keep the overlay frontmost: no Dock, menu bar, ⌘Tab or ⌘H while active. Force Quit still works.
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching, .disableHideApplication]
        // Cursor is visible only while the hint is (guarded mode), hidden otherwise.
        hintObserver = hintState.$visible.sink { [weak self] visible in
            if visible { self?.showCursor() } else { self?.hideCursor() }
        }
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard self.isShowing else { return }
                self.tearDownWindows()
                self.buildWindows()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.reclaimFocus() }
        })
    }

    func hide() {
        guard isShowing else { return }
        isShowing = false
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        hintObserver = nil
        hintState.hideHint()
        tearDownWindows()
        NSApp.presentationOptions = []
        showCursor()
    }

    private func reclaimFocus() {
        guard isShowing else { return }
        NSApp.activate(ignoringOtherApps: true)
        windows.first?.makeKeyAndOrderFront(nil)
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
            let view = ScreensaverView(onExitRequested: { [weak self] in self?.onExitRequested?() })
            window.contentView = NSHostingView(rootView: view.environmentObject(hintState))
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

    private func showCursor() {
        if cursorHidden {
            NSCursor.unhide()
            cursorHidden = false
        }
    }
}
