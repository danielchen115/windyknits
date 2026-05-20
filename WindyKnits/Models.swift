import SwiftUI

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

enum SampleData {
    static let projects: [Project] = [
        Project(
            id: "p1",
            title: "Marigold Cardigan",
            designer: "Petite Knit",
            swatchHex: 0xd49aa3,
            yarn: "Sandnes Sunday",
            color: "Dusty Rose",
            needles: "3.5 mm",
            rowsDone: 47,
            rowsTotal: 184,
            lastWorked: "Yesterday",
            notes: "Going up a size at the hips — added 4 stitches each side at row 38."
        ),
        Project(
            id: "p2",
            title: "Hay Socks",
            designer: "Pétur Ó.",
            swatchHex: 0xc8a7c4,
            yarn: "Rauma Finullgarn",
            color: "Oat / Heather",
            needles: "2.25 mm",
            rowsDone: 12,
            rowsTotal: 64,
            lastWorked: "3 days ago",
            notes: nil
        ),
        Project(
            id: "p3",
            title: "Linen Wash Cloth",
            designer: "Own design",
            swatchHex: 0xe2b5b1,
            yarn: "Quince & Co Sparrow",
            color: "Honey",
            needles: "4 mm",
            rowsDone: 28,
            rowsTotal: 30,
            lastWorked: "1 week ago",
            notes: nil
        )
    ]

    static func project(id: String) -> Project {
        projects.first(where: { $0.id == id }) ?? projects[0]
    }

    /// Default swatch hex used for freshly-imported patterns (Blossom primary).
    static let importedSwatchHex: UInt32 = 0xd49aa3

    static let patternSection = "Yoke"
    static let patternTotalRows = 48
    // Length of one chart repeat. The yoke is 4 vertical repeats of the 12-row
    // chart below — used by the counter to compute repeat number from row.
    static let rowsPerRepeat = 12
    static let pattern: [PatternRow] = [
        .init(n: 1,  rs: true,  text: "K2, * yo, k2tog; rep from * to last 2 sts, k2.",                 sts: 20),
        .init(n: 2,  rs: false, text: "Purl all sts.",                                                  sts: 20),
        .init(n: 3,  rs: true,  text: "K2, * k2tog, yo, k1, yo, ssk; rep from * to last 2 sts, k2.",    sts: 20),
        .init(n: 4,  rs: false, text: "Purl all sts.",                                                  sts: 20),
        .init(n: 5,  rs: true,  text: "K2, m1L, knit to last 2 sts, m1R, k2.",                          sts: 22),
        .init(n: 6,  rs: false, text: "Purl all sts.",                                                  sts: 22),
        .init(n: 7,  rs: true,  text: "K1, * yo, ssk, k2, k2tog, yo, k1; rep from * to end.",           sts: 22),
        .init(n: 8,  rs: false, text: "Purl all sts.",                                                  sts: 22),
        .init(n: 9,  rs: true,  text: "K2, m1L, knit to last 2 sts, m1R, k2.",                          sts: 24),
        .init(n: 10, rs: false, text: "Purl all sts.",                                                  sts: 24),
        .init(n: 11, rs: true,  text: "Knit, placing markers every 25 sts (4 markers total).",          sts: 24),
        .init(n: 12, rs: false, text: "Purl all sts.",                                                  sts: 24)
    ]

    static let abbreviations: [String: String] = [
        "k":     "knit",
        "p":     "purl",
        "k2tog": "knit two together",
        "ssk":   "slip slip knit",
        "yo":    "yarn over",
        "m1l":   "make one left-leaning",
        "m1r":   "make one right-leaning",
        "psso":  "pass slipped stitch over",
        "sl1":   "slip one",
        "wyif":  "with yarn in front",
        "wyib":  "with yarn in back",
        "rep":   "repeat",
        "rs":    "right side",
        "ws":    "wrong side"
    ]

    static let abbreviationChips = [
        "k","p","k2tog","ssk","yo","m1l","m1r","psso","sl1","wyif","wyib","rep","rs","ws"
    ]
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
