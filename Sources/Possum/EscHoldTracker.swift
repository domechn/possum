import Foundation

struct EscHoldTracker {
    let requiredDuration: TimeInterval
    private(set) var startTime: Date?

    init(requiredDuration: TimeInterval = 2.0) {
        self.requiredDuration = requiredDuration
    }

    mutating func keyDown(at time: Date) {
        if startTime == nil {
            startTime = time
        }
    }

    mutating func keyUp() {
        startTime = nil
    }

    func progress(at time: Date) -> Double {
        guard let start = startTime else { return 0 }
        return min(1.0, time.timeIntervalSince(start) / requiredDuration)
    }

    func isComplete(at time: Date) -> Bool {
        progress(at: time) >= 1.0
    }
}
