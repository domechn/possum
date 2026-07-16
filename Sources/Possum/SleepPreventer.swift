import Foundation
import IOKit.pwr_mgt

final class SleepPreventer {
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private(set) var isActive = false

    private nonisolated(unsafe) static let reason = "Possum working mode" as CFString

    func start() {
        guard !isActive else { return }
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            Self.reason,
            &systemAssertionID
        )
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            Self.reason,
            &displayAssertionID
        )
        isActive = true
    }

    func stop() {
        guard isActive else { return }
        IOPMAssertionRelease(systemAssertionID)
        IOPMAssertionRelease(displayAssertionID)
        systemAssertionID = 0
        displayAssertionID = 0
        isActive = false
    }

    deinit {
        stop()
    }
}
