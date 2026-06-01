import SwiftUI

/// Where a project sits in the workflow. `active` is on the needles right
/// now; `queue` is saved for later (no rows knit yet); `finished` is cast
/// off. Finished is a terminal state — never offered at creation time, only
/// reached from `active`.
enum ProjectStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active, queue, finished

    var label: String {
        switch self {
        case .active:   return "In progress"
        case .queue:    return "Queue"
        case .finished: return "Finished"
        }
    }

    var sub: String {
        switch self {
        case .active:   return "Currently on the needles."
        case .queue:    return "Saved for later. Not started yet."
        case .finished: return "Cast off — knit again or admire."
        }
    }

    /// The dot/accent color that represents this status across badges, swipe
    /// actions, library cards, and the status sheet.
    var color: Color {
        switch self {
        case .active:   return Palette.primaryDark
        case .queue:    return Palette.walnutSoft
        case .finished: return Palette.accent
        }
    }
}

struct Project: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var title: String
    var designer: String
    /// Stored as a hex int so the project can be encoded; the rendered swatch
    /// uses the computed `swatch` property below.
    var swatchHex: UInt32
    var yarn: String
    var color: String
    var needles: String
    var rowsDone: Int
    var rowsTotal: Int
    var lastWorked: String
    var notes: String?
    /// Set when this project was created from an imported PDF.
    var pattern: ParsedPattern? = nil

    /// Optional metadata surfaced on the Overview tab. All nullable so older
    /// stored projects keep decoding and creation flows can omit them.
    var patternType: String? = nil
    var size: String? = nil
    var gauge: String? = nil
    var createdAt: Date? = nil

    var status: ProjectStatus = .active
    /// Queue-only — rough estimate shown on queue cards and detail.
    var estWeeks: Int? = nil
    /// Queue-only — whether the planned yarn has been bought.
    var yarnReady: Bool? = nil
    /// Queue-only — display string for when the project was queued.
    var addedOn: String? = nil
    /// Finished-only — formatted date this project was cast off.
    var finishedOn: String? = nil
    /// Finished-only — number of days from start to finish.
    var daysToFinish: Int? = nil

    var swatch: Color { Color(hex: swatchHex) }
    var progress: Double { rowsTotal > 0 ? Double(rowsDone) / Double(rowsTotal) : 0 }
    var percentLabel: String { "\(Int((progress * 100).rounded()))%" }
}

// MARK: - Imported pattern

struct ParsedPattern: Codable, Hashable, Sendable {
    var fileName: String
    var pageCount: Int
    var fileSizeBytes: Int
    var sections: [ParsedSection]
    var rows: [ParsedRow]
    var abbreviations: [String]
    /// Number of rows in one vertical chart repeat. Nil means "no repeat
    /// cadence" — the counter and viewer treat the whole pattern as one
    /// repeat. Optional so older encoded payloads keep decoding.
    var rowsPerRepeat: Int? = nil

    var fileSizeLabel: String {
        let mb = Double(fileSizeBytes) / 1_048_576
        if mb >= 0.1 { return String(format: "%.1f MB", mb) }
        let kb = max(1, Int((Double(fileSizeBytes) / 1024).rounded()))
        return "\(kb) KB"
    }

    var pagesLabel: String {
        pageCount == 1 ? "1 page" : "\(pageCount) pages"
    }
}

struct ParsedSection: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var rowCount: Int?
    nonisolated init(id: UUID = UUID(), name: String, rowCount: Int? = nil) {
        self.id = id; self.name = name; self.rowCount = rowCount
    }
}

struct ParsedRow: Codable, Hashable, Identifiable, Sendable {
    var id: Int { n }
    let n: Int
    let rs: Bool
    let text: String
    let sts: Int?
}

struct PatternRow: Identifiable, Hashable {
    var id: Int { n }
    let n: Int
    let rs: Bool
    let text: String
    let sts: Int
}

// MARK: - Row history

struct CompletedRow: Codable {
    let n: Int
    let timestamp: Date
    let sts: Int
}

enum CounterHistory {
    static func storageKey(for projectId: String) -> String {
        "counter.\(projectId).history"
    }

    static func decode(_ json: String) -> [CompletedRow] {
        guard let data = json.data(using: .utf8),
              let list = try? JSONDecoder().decode([CompletedRow].self, from: data)
        else { return [] }
        return list
    }

    /// Rows completed inside the current calendar week.
    static func rowsThisWeek(_ history: [CompletedRow], now: Date = Date()) -> Int {
        let cal = Calendar.current
        guard let start = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return 0 }
        return history.filter { $0.timestamp >= start }.count
    }

    /// Knit time today (sum of session durations whose stamps fall today).
    static func timeToday(_ history: [CompletedRow], now: Date = Date()) -> TimeInterval {
        let cal = Calendar.current
        let rows = history.filter { cal.isDate($0.timestamp, inSameDayAs: now) }
        return sessionDurations(rows).reduce(0, +)
    }

    /// Total knit time across all history.
    static func totalTime(_ history: [CompletedRow]) -> TimeInterval {
        sessionDurations(history).reduce(0, +)
    }

    // Splits completions into sessions (gaps > 5 min start a new session).
    // Each session is floored at 1 min so a single-row session still registers
    // — we only have completion timestamps, not start times, so the floor is
    // a deliberate undercount-guard rather than a precise measurement.
    private static func sessionDurations(_ rows: [CompletedRow],
                                          gapLimit: TimeInterval = 300,
                                          floor: TimeInterval = 60) -> [TimeInterval] {
        let sorted = rows.sorted { $0.timestamp < $1.timestamp }
        guard !sorted.isEmpty else { return [] }
        var out: [TimeInterval] = []
        var start = sorted[0].timestamp
        var last = sorted[0].timestamp
        for entry in sorted.dropFirst() {
            if entry.timestamp.timeIntervalSince(last) > gapLimit {
                out.append(max(last.timeIntervalSince(start), floor))
                start = entry.timestamp
            }
            last = entry.timestamp
        }
        out.append(max(last.timeIntervalSince(start), floor))
        return out
    }
}
