import XCTest
@testable import Possum

final class EscHoldTrackerTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 0)

    func testNoProgressWithoutKeyDown() {
        let tracker = EscHoldTracker()
        XCTAssertEqual(tracker.progress(at: t0), 0)
        XCTAssertFalse(tracker.isComplete(at: t0))
    }

    func testProgressCompletesAfterRequiredDuration() {
        var tracker = EscHoldTracker(requiredDuration: 2)
        tracker.keyDown(at: t0)
        XCTAssertEqual(tracker.progress(at: t0 + 1), 0.5, accuracy: 0.0001)
        XCTAssertFalse(tracker.isComplete(at: t0 + 1.9))
        XCTAssertTrue(tracker.isComplete(at: t0 + 2))
        XCTAssertEqual(tracker.progress(at: t0 + 10), 1)
    }

    func testRepeatedKeyDownKeepsOriginalStart() {
        var tracker = EscHoldTracker(requiredDuration: 2)
        tracker.keyDown(at: t0)
        tracker.keyDown(at: t0 + 1.5)
        XCTAssertTrue(tracker.isComplete(at: t0 + 2))
    }

    func testKeyUpResets() {
        var tracker = EscHoldTracker(requiredDuration: 2)
        tracker.keyDown(at: t0)
        tracker.keyUp()
        XCTAssertNil(tracker.startTime)
        XCTAssertEqual(tracker.progress(at: t0 + 5), 0)
    }
}

final class MouseMoveAccumulatorTests: XCTestCase {
    func testAccumulatesUntilThreshold() {
        var acc = MouseMoveAccumulator(threshold: 10)
        XCTAssertFalse(acc.add(dx: 3, dy: 4, at: 0))   // 5 pt
        XCTAssertTrue(acc.add(dx: 3, dy: 4, at: 0.1))  // 10 pt
    }

    func testGapResetsAccumulation() {
        var acc = MouseMoveAccumulator(threshold: 10, resetInterval: 0.5)
        XCTAssertFalse(acc.add(dx: 3, dy: 4, at: 0))
        XCTAssertFalse(acc.add(dx: 3, dy: 4, at: 0.6))
        XCTAssertEqual(acc.accumulated, 5, accuracy: 0.0001)
    }

    func testGapAtExactlyResetIntervalKeepsAccumulation() {
        var acc = MouseMoveAccumulator(threshold: 10, resetInterval: 0.5)
        XCTAssertFalse(acc.add(dx: 3, dy: 4, at: 0))
        XCTAssertTrue(acc.add(dx: 3, dy: 4, at: 0.5))
    }
}

final class FormatterTests: XCTestCase {
    func testDurationFormatting() {
        XCTAssertEqual(DurationFormatter.string(from: 0), "不到 1 分钟")
        XCTAssertEqual(DurationFormatter.string(from: 59), "不到 1 分钟")
        XCTAssertEqual(DurationFormatter.string(from: 60), "1 分钟")
        XCTAssertEqual(DurationFormatter.string(from: 3599), "59 分钟")
        XCTAssertEqual(DurationFormatter.string(from: 3660), "1 小时 1 分钟")
    }

    private func localDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        let calendar = Calendar(identifier: .gregorian) // uses TimeZone.current, like the formatters
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    func testClockTimeIs24HourZeroPadded() {
        XCTAssertEqual(ClockFormatter.timeString(from: localDate(2026, 10, 23, 9, 5)), "09:05")
        XCTAssertEqual(ClockFormatter.timeString(from: localDate(2026, 10, 23, 21, 30)), "21:30")
    }

    func testClockDateIsChinese() {
        let s = ClockFormatter.dateString(from: localDate(2026, 10, 23, 12, 0)) // a Friday
        XCTAssertTrue(s.contains("10月23日"), s)
        XCTAssertTrue(s.contains("星期五"), s)
    }
}

// Only exercises the countdown; activating would create real windows and power assertions.
final class SessionControllerTests: XCTestCase {
    @MainActor
    func testCountdownTicksFromDeadlineAndCancels() {
        let session = SessionController()
        XCTAssertEqual(session.state, .idle)

        let start = Date()
        session.startWorkMode(delaySeconds: 5)
        XCTAssertEqual(session.state, .countingDown(remaining: 5))

        session.tickCountdown(now: start.addingTimeInterval(1.5))
        XCTAssertEqual(session.state, .countingDown(remaining: 4))
        session.tickCountdown(now: start.addingTimeInterval(4.5))
        XCTAssertEqual(session.state, .countingDown(remaining: 1))

        session.cancelCountdown()
        XCTAssertEqual(session.state, .idle)
    }

    @MainActor
    func testStartIsIgnoredWhileCountingDown() {
        let session = SessionController()
        session.startWorkMode(delaySeconds: 5)
        session.startWorkMode(delaySeconds: 20)
        XCTAssertEqual(session.state, .countingDown(remaining: 5))
        session.cancelCountdown()
    }

    @MainActor
    func testCancelAndTickAreNoOpsWhenIdle() {
        let session = SessionController()
        session.cancelCountdown()
        session.tickCountdown()
        XCTAssertEqual(session.state, .idle)
    }
}
