import Testing
import Foundation
@testable import WindyKnits

@MainActor
@Suite("CounterHistory")
struct CounterHistoryTests {

    @Test func storageKeyIsScopedByProject() {
        #expect(CounterHistory.storageKey(for: "p1") == "counter.p1.history")
        #expect(CounterHistory.storageKey(for: "abc") == "counter.abc.history")
    }

    @Test func decodeReturnsEmptyOnInvalidJSON() {
        #expect(CounterHistory.decode("not json at all").isEmpty)
        #expect(CounterHistory.decode("").isEmpty)
        #expect(CounterHistory.decode("{}").isEmpty)
    }

    @Test func decodeReturnsEntriesForValidJSON() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let rows = [CompletedRow(n: 1, timestamp: now, sts: 24),
                    CompletedRow(n: 2, timestamp: now.addingTimeInterval(10), sts: 24)]
        let data = try JSONEncoder().encode(rows)
        let json = String(data: data, encoding: .utf8)!
        let decoded = CounterHistory.decode(json)
        #expect(decoded.count == 2)
        #expect(decoded[0].n == 1)
        #expect(decoded[1].n == 2)
    }

    @Test func rowsThisWeekCountsOnlySameCalendarWeek() {
        let cal = Calendar.current
        let now = Date()
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else {
            Issue.record("Could not derive week start"); return
        }
        let inThisWeek = weekStart.addingTimeInterval(60)
        let lastWeek = weekStart.addingTimeInterval(-3600)
        let history = [
            CompletedRow(n: 1, timestamp: inThisWeek, sts: 0),
            CompletedRow(n: 2, timestamp: inThisWeek.addingTimeInterval(120), sts: 0),
            CompletedRow(n: 3, timestamp: lastWeek, sts: 0)
        ]
        #expect(CounterHistory.rowsThisWeek(history, now: now) == 2)
    }

    @Test func rowsThisWeekIsZeroForEmptyHistory() {
        #expect(CounterHistory.rowsThisWeek([]) == 0)
    }

    @Test func timeTodayCountsOnlySameDayEntries() {
        let now = Date()
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let history = [
            CompletedRow(n: 1, timestamp: yesterday, sts: 0),
            CompletedRow(n: 2, timestamp: yesterday.addingTimeInterval(120), sts: 0),
            CompletedRow(n: 3, timestamp: now, sts: 0)
        ]
        // The lone "today" entry forms a 1-row session, floored to 60s.
        #expect(CounterHistory.timeToday(history, now: now) == 60)
    }

    @Test func timeTodayIsZeroWhenNothingHappenedToday() {
        let now = Date()
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: now)!
        let history = [CompletedRow(n: 1, timestamp: yesterday, sts: 0)]
        #expect(CounterHistory.timeToday(history, now: now) == 0)
    }

    @Test func totalTimeFloorsSingleRowSessionsAtSixtySeconds() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        // A single completion can't have a measured duration, so the
        // session-collapser floors it at 60 seconds.
        #expect(CounterHistory.totalTime([CompletedRow(n: 1, timestamp: now, sts: 0)]) == 60)
    }

    @Test func totalTimeSplitsSessionsOnGapsOverFiveMinutes() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        // Session A: 4 rows over 3 minutes.
        let sessionA = (0..<4).map { i in
            CompletedRow(n: i, timestamp: t0.addingTimeInterval(Double(i) * 60), sts: 0)
        }
        // 10-minute gap, then Session B: 2 rows over 1 minute.
        let sessionB = (0..<2).map { i in
            CompletedRow(
                n: 100 + i,
                timestamp: t0.addingTimeInterval(180 + 600 + Double(i) * 60),
                sts: 0
            )
        }
        let total = CounterHistory.totalTime(sessionA + sessionB)
        // A = 180s (3 minutes between first and last). B = floor(60s).
        #expect(total == 180 + 60)
    }

    @Test func totalTimeKeepsRowsWithinFiveMinuteGapInSameSession() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let rows = [
            CompletedRow(n: 1, timestamp: t0, sts: 0),
            CompletedRow(n: 2, timestamp: t0.addingTimeInterval(200), sts: 0),  // 3:20 gap, < 5 min
            CompletedRow(n: 3, timestamp: t0.addingTimeInterval(400), sts: 0)   // another 3:20 gap
        ]
        #expect(CounterHistory.totalTime(rows) == 400)
    }

    @Test func totalTimeSortsUnorderedInputBeforeMeasuring() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let unordered = [
            CompletedRow(n: 3, timestamp: t0.addingTimeInterval(400), sts: 0),
            CompletedRow(n: 1, timestamp: t0, sts: 0),
            CompletedRow(n: 2, timestamp: t0.addingTimeInterval(200), sts: 0)
        ]
        #expect(CounterHistory.totalTime(unordered) == 400)
    }
}
