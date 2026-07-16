import Foundation

struct MouseMoveAccumulator {
    private(set) var accumulated: CGFloat = 0
    let threshold: CGFloat

    init(threshold: CGFloat = 10) {
        self.threshold = threshold
    }

    mutating func add(dx: CGFloat, dy: CGFloat) -> Bool {
        accumulated += (dx * dx + dy * dy).squareRoot()
        return accumulated >= threshold
    }
}
