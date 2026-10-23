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
    @Published private(set) var errorMessage: String?
    @Published var guardedExitEnabled: Bool {
        didSet { UserDefaults.standard.set(guardedExitEnabled, forKey: "guardedExitEnabled") }
    }

    private let sleepPreventer = SleepPreventer()
    private let overlay = ScreensaverOverlay()
    private let exitMonitor = ExitMonitor()
    private var countdownTimer: Timer?
    private var countdownDeadline: Date?
    private var sessionStart: ContinuousClock.Instant?

    init() {
        guardedExitEnabled = UserDefaults.standard.bool(forKey: "guardedExitEnabled")
        overlay.onExitRequested = { [weak self] in self?.deactivate() }
    }

    func startWorkMode(delaySeconds: Int) {
        guard state == .idle else { return }
        errorMessage = nil
        guard delaySeconds > 0 else {
            activate()
            return
        }
        // Remaining time is derived from a deadline so late or coalesced timer fires don't stretch the countdown.
        countdownDeadline = Date().addingTimeInterval(TimeInterval(delaySeconds))
        state = .countingDown(remaining: delaySeconds)
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.tickCountdown() }
        }
        // .common so the countdown keeps running while a menu or control is being tracked.
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    func tickCountdown(now: Date = Date()) {
        guard case .countingDown = state, let deadline = countdownDeadline else { return }
        let remaining = Int(deadline.timeIntervalSince(now).rounded(.up))
        if remaining <= 0 {
            activate()
        } else if state != .countingDown(remaining: remaining) {
            state = .countingDown(remaining: remaining)
        }
    }

    func cancelCountdown() {
        guard case .countingDown = state else { return }
        stopCountdown()
        state = .idle
    }

    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownDeadline = nil
    }

    private func activate() {
        stopCountdown()
        guard sleepPreventer.start() else {
            errorMessage = "无法阻止系统休眠，工作模式未启动"
            state = .idle
            return
        }
        sessionStart = ContinuousClock.now
        overlay.show()

        let mode: ExitMode = guardedExitEnabled ? .guarded : .instant
        let hintState = overlay.hintState

        exitMonitor.arm(
            mode: mode,
            onExit: { [weak self] in self?.deactivate() },
            onHint: { hintState.showHint() },
            onProgress: { hintState.updateProgress($0) }
        )

        state = .active
    }

    private func deactivate() {
        guard state == .active else { return }
        exitMonitor.disarm()
        overlay.hide()
        sleepPreventer.stop()
        if let start = sessionStart {
            // ContinuousClock keeps counting across system sleep and ignores wall-clock changes.
            let seconds = start.duration(to: ContinuousClock.now).components.seconds
            lastSessionSummary = "已结束，本次持续 \(DurationFormatter.string(from: TimeInterval(seconds)))"
        }
        sessionStart = nil
        state = .idle
    }
}
