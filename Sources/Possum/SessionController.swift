import AppKit
import Combine

@MainActor
final class SessionController: ObservableObject {
    enum State: Equatable {
        case idle
        case countingDown(remaining: Int)
        case active
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastSessionSummary: String?
    @Published var guardedExitEnabled: Bool {
        didSet { UserDefaults.standard.set(guardedExitEnabled, forKey: "guardedExitEnabled") }
    }

    private let sleepPreventer = SleepPreventer()
    private let overlay = ScreensaverOverlay()
    private let exitMonitor = ExitMonitor()
    private var countdownTimer: Timer?
    private var sessionStart: Date?
    private var exitNotificationObserver: Any?

    init() {
        guardedExitEnabled = UserDefaults.standard.bool(forKey: "guardedExitEnabled")
    }

    func startWorkMode(delaySeconds: Int) {
        guard state == .idle else { return }
        guard delaySeconds > 0 else {
            activate()
            return
        }
        state = .countingDown(remaining: delaySeconds)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self, case .countingDown(let remaining) = self.state else {
                    timer.invalidate()
                    return
                }
                if remaining <= 1 {
                    timer.invalidate()
                    self.activate()
                } else {
                    self.state = .countingDown(remaining: remaining - 1)
                }
            }
        }
    }

    func cancelCountdown() {
        guard case .countingDown = state else { return }
        countdownTimer?.invalidate()
        countdownTimer = nil
        state = .idle
    }

    private func activate() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        sessionStart = Date()
        sleepPreventer.start()
        overlay.show()

        let mode: ExitMode = guardedExitEnabled ? .guarded : .instant
        let hintState = overlay.hintState

        exitMonitor.arm(
            mode: mode,
            onExit: { [weak self] in
                Task { @MainActor in self?.deactivate() }
            },
            onHint: { [weak self] in
                Task { @MainActor in
                    hintState.showHint()
                    self?.overlay.showCursor()
                }
            },
            onProgress: { progress in
                Task { @MainActor in
                    hintState.updateProgress(progress)
                }
            }
        )

        exitNotificationObserver = NotificationCenter.default.addObserver(
            forName: .exitScreensaverRequested, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.deactivate() }
        }

        state = .active
    }

    private func deactivate() {
        guard state == .active else { return }
        if let observer = exitNotificationObserver {
            NotificationCenter.default.removeObserver(observer)
            exitNotificationObserver = nil
        }
        exitMonitor.disarm()
        overlay.hide()
        sleepPreventer.stop()
        if let start = sessionStart {
            let duration = DurationFormatter.string(from: Date().timeIntervalSince(start))
            lastSessionSummary = "已结束，本次持续 \(duration)"
        }
        sessionStart = nil
        state = .idle
    }
}
