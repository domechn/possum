import AppKit

enum ExitMode {
    case instant
    case guarded
}

final class ExitMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var accumulator = MouseMoveAccumulator()
    private var escTracker = EscHoldTracker()
    private var progressTimer: Timer?
    private var onExit: (() -> Void)?
    private var onHint: (() -> Void)?
    private var onProgress: ((Double) -> Void)?
    private var mode: ExitMode = .instant

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

        let mask: NSEvent.EventTypeMask = [
            .mouseMoved, .leftMouseDragged, .rightMouseDragged,
            .leftMouseDown, .rightMouseDown, .otherMouseDown,
            .scrollWheel, .keyDown, .keyUp
        ]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            switch event.type {
            case .keyDown, .keyUp:
                return nil // swallow key events so the unhandled-key system beep never fires
            default:
                return event
            }
        }
    }

    func disarm() {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor) }
        globalMonitor = nil
        localMonitor = nil
        progressTimer?.invalidate()
        progressTimer = nil
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
            if accumulator.add(dx: event.deltaX, dy: event.deltaY) {
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
            if event.keyCode == 53 { // Esc — ignore key repeats so held Esc doesn't retrigger the hint
                if !event.isARepeat {
                    escTracker.keyDown(at: Date())
                    startProgressTimer()
                }
            } else {
                onHint?()
            }
        case .keyUp:
            if event.keyCode == 53 {
                escTracker.keyUp()
                stopProgressTimer()
                onProgress?(0)
            }
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged:
            onHint?()
        default:
            onHint?()
        }
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = Date()
            let progress = self.escTracker.progress(at: now)
            self.onProgress?(progress)
            if self.escTracker.isComplete(at: now) {
                self.fire()
            }
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
