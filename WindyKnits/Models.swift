import SwiftUI

struct Project: Identifiable, Hashable {
    let id: String
    var title: String
    var designer: String
    var swatch: Color
    var yarn: String
    var color: String
    var needles: String
    var rowsDone: Int
    var rowsTotal: Int
    var lastWorked: String
    var notes: String?

    var progress: Double { Double(rowsDone) / Double(rowsTotal) }
    var percentLabel: String { "\(Int((progress * 100).rounded()))%" }
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
            swatch: Palette.primary,
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
            swatch: Palette.accent,
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
            swatch: Color(hex: 0xe2b5b1),
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

    static let patternSection = "Yoke"
    static let patternTotalRows = 48
    static let pattern: [PatternRow] = [
        .init(n: 1,  rs: true,  text: "K2, * yo, k2tog; rep from * to last 2 sts, k2.",                 sts: 96),
        .init(n: 2,  rs: false, text: "Purl all sts.",                                                  sts: 96),
        .init(n: 3,  rs: true,  text: "K2, * k2tog, yo, k1, yo, ssk; rep from * to last 2 sts, k2.",    sts: 96),
        .init(n: 4,  rs: false, text: "Purl all sts.",                                                  sts: 96),
        .init(n: 5,  rs: true,  text: "K2, m1L, knit to last 2 sts, m1R, k2.",                          sts: 98),
        .init(n: 6,  rs: false, text: "Purl all sts.",                                                  sts: 98),
        .init(n: 7,  rs: true,  text: "K1, * yo, ssk, k2, k2tog, yo, k1; rep from * to end.",           sts: 98),
        .init(n: 8,  rs: false, text: "Purl all sts.",                                                  sts: 98),
        .init(n: 9,  rs: true,  text: "K2, m1L, knit to last 2 sts, m1R, k2.",                          sts: 100),
        .init(n: 10, rs: false, text: "Purl all sts.",                                                  sts: 100),
        .init(n: 11, rs: true,  text: "Knit, placing markers every 25 sts (4 markers total).",          sts: 100),
        .init(n: 12, rs: false, text: "Purl all sts.",                                                  sts: 100)
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
