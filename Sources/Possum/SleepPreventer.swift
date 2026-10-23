import Foundation
import IOKit.pwr_mgt

final class SleepPreventer {
    private var systemAssertionID: IOPMAssertionID = 0
    private var displayAssertionID: IOPMAssertionID = 0
    private(set) var isActive = false

    /// Returns false (holding no assertions) if either assertion could not be created.
    func start() -> Bool {
        guard !isActive else { return true }
        let reason = "Possum working mode" as CFString
        guard IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &systemAssertionID
        ) == kIOReturnSuccess else {
            systemAssertionID = 0
            return false
        }
        guard IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displayAssertionID
        ) == kIOReturnSuccess else {
            IOPMAssertionRelease(systemAssertionID)
            systemAssertionID = 0
            displayAssertionID = 0
            return false
        }
        isActive = true
        return true
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
