import SwiftUI

@MainActor
final class HintState: ObservableObject {
    @Published var visible = false
    @Published var escProgress: Double = 0

    private var autoDismissTask: Task<Void, Never>?

    func showHint() {
        // Don't reset escProgress here: repeat/mouse events arriving mid-hold
        // would flicker the progress bar back to zero.
        visible = true
        scheduleAutoDismiss()
    }

    func updateProgress(_ progress: Double) {
        escProgress = progress
        if progress > 0 {
            visible = true
            scheduleAutoDismiss()
        }
    }

    func hideHint() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        visible = false
        escProgress = 0
    }

    private func scheduleAutoDismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if !Task.isCancelled {
                visible = false
                escProgress = 0
            }
        }
    }
}
