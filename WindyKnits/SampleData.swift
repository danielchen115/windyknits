#if DEBUG
import Foundation

/// Curated demo data exposed only in Debug builds. The DevTools seeder copies
/// these projects into PatternStore as ordinary imported records, so once
/// loaded they behave identically to user-created projects — no special-case
/// branching anywhere in production code paths.
///
/// Release builds do not link this type. Tests run against Debug so the suite
/// can use it freely.
enum SampleData {
    /// Pre-built projects covering all three statuses. `p1` carries a real
    /// `ParsedPattern` (12-row yoke chart, 4 repeats) so counter/viewer
    /// screens have non-trivial content to render against.
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
            notes: "Going up a size at the hips — added 4 stitches each side at row 38.",
            pattern: yokePattern,
            patternType: "Top-down raglan",
            size: "S (34\" bust)",
            gauge: "22 sts × 30 rows / 10cm"
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
            notes: nil,
            patternType: "Toe-up sock",
            size: "Women's M",
            gauge: "32 sts × 44 rows / 10cm"
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
            notes: nil,
            patternType: "Garter square",
            size: "30 × 30 cm",
            gauge: nil
        ),
        // ── Queue ──
        Project(
            id: "q1",
            title: "Bjørn Sweater",
            designer: "PetiteKnit",
            swatchHex: 0xb6a4c4,
            yarn: "Sandnes Peer Gynt",
            color: "Stormy Lilac",
            needles: "4 mm",
            rowsDone: 0,
            rowsTotal: 220,
            lastWorked: "—",
            status: .queue,
            estWeeks: 6,
            yarnReady: true,
            addedOn: "May 12"
        ),
        Project(
            id: "q2",
            title: "Lavender Mittens",
            designer: "Erika Knight",
            swatchHex: 0xa795c4,
            yarn: "Rowan Felted Tweed",
            color: "Heath",
            needles: "3.25 mm",
            rowsDone: 0,
            rowsTotal: 96,
            lastWorked: "—",
            status: .queue,
            estWeeks: 2,
            yarnReady: false,
            addedOn: "Apr 28"
        ),
        // ── Finished ──
        Project(
            id: "f1",
            title: "Birch Beanie",
            designer: "Espace Tricot",
            swatchHex: 0xd7c9a8,
            yarn: "Brooklyn Tweed Shelter",
            color: "Birch",
            needles: "4.5 mm",
            rowsDone: 88,
            rowsTotal: 88,
            lastWorked: "Mar 14",
            status: .finished,
            finishedOn: "Mar 14, 2026",
            daysToFinish: 9
        ),
        Project(
            id: "f2",
            title: "Storm Cowl",
            designer: "Own design",
            swatchHex: 0x9aa9c7,
            yarn: "BC Garn Loch Lomond",
            color: "Slate",
            needles: "5 mm",
            rowsDone: 72,
            rowsTotal: 72,
            lastWorked: "Jan 06",
            status: .finished,
            finishedOn: "Jan 06, 2026",
            daysToFinish: 14
        )
    ]

    /// Per-project counter snapshot the seeder writes into the App Group so the
    /// demo screens read as mid-flow (Marigold Cardigan opens on row 5 of the
    /// yoke). Anything not listed here starts at 0.
    static let initialCounterState: [String: (rows: Int, stitches: Int)] = [
        "p1": (rows: 5, stitches: 34)
    ]

    /// The 12-row yoke chart shipped with the Marigold Cardigan sample. Four
    /// vertical repeats make up the yoke section (48 rows total).
    private static let yokePattern = ParsedPattern(
        fileName: "marigold-yoke.pdf",
        pageCount: 1,
        fileSizeBytes: 0,
        sections: [ParsedSection(name: "Yoke", rowCount: 48)],
        rows: yokeRows,
        abbreviations: Array(KnittingAbbreviations.dictionary.keys),
        rowsPerRepeat: 12
    )

    private static let yokeRows: [ParsedRow] = [
        ParsedRow(n: 1,  rs: true,  text: "K2, * yo, k2tog; rep from * to last 2 sts, k2.",              sts: 20),
        ParsedRow(n: 2,  rs: false, text: "Purl all sts.",                                               sts: 20),
        ParsedRow(n: 3,  rs: true,  text: "K2, * k2tog, yo, k1, yo, ssk; rep from * to last 2 sts, k2.", sts: 20),
        ParsedRow(n: 4,  rs: false, text: "Purl all sts.",                                               sts: 20),
        ParsedRow(n: 5,  rs: true,  text: "K2, m1L, knit to last 2 sts, m1R, k2.",                       sts: 22),
        ParsedRow(n: 6,  rs: false, text: "Purl all sts.",                                               sts: 22),
        ParsedRow(n: 7,  rs: true,  text: "K1, * yo, ssk, k2, k2tog, yo, k1; rep from * to end.",        sts: 22),
        ParsedRow(n: 8,  rs: false, text: "Purl all sts.",                                               sts: 22),
        ParsedRow(n: 9,  rs: true,  text: "K2, m1L, knit to last 2 sts, m1R, k2.",                       sts: 24),
        ParsedRow(n: 10, rs: false, text: "Purl all sts.",                                               sts: 24),
        ParsedRow(n: 11, rs: true,  text: "Knit, placing markers every 25 sts (4 markers total).",       sts: 24),
        ParsedRow(n: 12, rs: false, text: "Purl all sts.",                                               sts: 24)
    ]
}
#endif
