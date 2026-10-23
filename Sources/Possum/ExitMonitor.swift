import AppKit

enum ExitMode {
    case instant
    case guarded
}

@MainActor
final class ExitMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var accumulator = MouseMoveAccumulator()
    private var escTracker = EscHoldTracker()
    private var progressTimer: Timer?
    private var lastHintTimestamp: TimeInterval = -.infinity
    private var onExit: (() -> Void)?
    private var onHint: (() -> Void)?
    private var onProgress: ((Double) -> Void)?
    private var mode: ExitMode = .instant

    private static let escKeyCode: UInt16 = 53
    private static let hintThrottle: TimeInterval = 0.25

    func arm(mode: ExitMode = .instant,
             onExit: @escaping () -> Void,
             onHint: (() -> Void)? = nil,
             onProgress: ((Double) -> Void)? = nil) {
        disarm()
        self.mode = mode
        self.onExit = onExit
        self.onHint = onHint
        self.onProgress = onProgress
        accumulator = MouseMoveAccumulator()
        escTracker = EscHoldTracker()
        lastHintTimestamp = -.infinity

        let mouseMask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .scrollWheel
        ]
        // Keys are only watched locally: global key monitoring needs Input Monitoring permission,
        // and the overlay keeps Possum frontmost (process switching disabled) so local suffices.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseMask) { [weak self] event in
            MainActor.assumeIsolated { _ = self?.handle(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseMask.union([.keyDown, .keyUp])) { [weak self] event in
            MainActor.assumeIsolated { _ = self?.handle(event) }
            switch event.type {
            case .keyDown, .keyUp:
                return nil // swallow key events so the unhandled-key system beep never fires
            default:
                return event
            }
        }
        // Losing focus mid-hold means the Esc keyUp never reaches us; drop the hold.
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.cancelEscHold() }
        }
    }

    func disarm() {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        if let observer = resignObserver { NotificationCenter.default.removeObserver(observer) }
        globalMonitor = nil
        localMonitor = nil
        resignObserver = nil
        stopProgressTimer()
        onExit = nil
        onHint = nil
        onProgress = nil
    }

    private func handle(_ event: NSEvent) {
        switch mode {
        case .instant:
            handleInstant(event)
        case .guarded:
            handleGuarded(event)
        }
    }

    // MARK: - Instant mode (original behavior)

    private func handleInstant(_ event: NSEvent) {
        switch event.type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            if accumulator.add(dx: event.deltaX, dy: event.deltaY, at: event.timestamp) {
                fire()
            }
        case .keyUp:
            break
        default:
            fire()
        }
    }

    // MARK: - Guarded mode

    private func handleGuarded(_ event: NSEvent) {
        switch event.type {
        case .keyDown:
            // Esc with modifiers (e.g. ⌘⌥Esc) is not an exit gesture.
            let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if event.keyCode == Self.escKeyCode && modifiers.isEmpty {
                // Ignore key repeats so held Esc doesn't restart the timer
                if !event.isARepeat {
                    escTracker.keyDown(at: Date())
                    startProgressTimer()
                }
            } else {
                requestHint(at: event.timestamp)
            }
        case .keyUp:
            if event.keyCode == Self.escKeyCode {
                cancelEscHold()
            }
        default:
            requestHint(at: event.timestamp)
        }
    }

    // Mouse moves arrive at display rate; refreshing the hint on each one is wasted work.
    private func requestHint(at timestamp: TimeInterval) {
        guard timestamp - lastHintTimestamp >= Self.hintThrottle else { return }
        lastHintTimestamp = timestamp
        onHint?()
    }

    private func cancelEscHold() {
        guard escTracker.startTime != nil else { return }
        escTracker.keyUp()
        stopProgressTimer()
        onProgress?(0)
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.tickProgress() }
        }
    }

    private func tickProgress() {
        let now = Date()
        onProgress?(escTracker.progress(at: now))
        if escTracker.isComplete(at: now) {
            fire()
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func fire() {
        let callback = onExit
        disarm()
        callback?()
    }
}
