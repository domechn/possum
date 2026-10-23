import Foundation

struct MouseMoveAccumulator {
    private(set) var accumulated: CGFloat = 0
    private var lastTimestamp: TimeInterval?
    let threshold: CGFloat
    let resetInterval: TimeInterval

    init(threshold: CGFloat = 10, resetInterval: TimeInterval = 0.5) {
        self.threshold = threshold
        self.resetInterval = resetInterval
    }

    /// `timestamp` is the event's `NSEvent.timestamp`; a pause longer than `resetInterval`
    /// starts a fresh gesture so slow desk vibrations never add up to an exit.
    mutating func add(dx: CGFloat, dy: CGFloat, at timestamp: TimeInterval) -> Bool {
        if let last = lastTimestamp, timestamp - last > resetInterval {
            accumulated = 0
        }
        lastTimestamp = timestamp
        accumulated += (dx * dx + dy * dy).squareRoot()
        return accumulated >= threshold
    }
}
