import Foundation

/// Canonical knitting-abbreviation glossary used by the pattern viewer's
/// tap-to-define sheet and the manual editor's chip row. Covers every
/// abbreviation `PatternImporter.knownAbbreviations` can surface — keep the
/// two lists in sync or imported patterns will get an empty popover.
enum KnittingAbbreviations {
    static let dictionary: [String: String] = [
        // Knit / purl basics
        "k":     "knit",
        "p":     "purl",
        "st":    "stitch",
        "sts":   "stitches",

        // Decreases
        "k2tog": "knit two together",
        "p2tog": "purl two together",
        "k3tog": "knit three together",
        "p3tog": "purl three together",
        "ssk":   "slip slip knit",
        "ssp":   "slip slip purl",
        "sssk":  "slip slip slip knit",
        "psso":  "pass slipped stitch over",

        // Increases
        "kfb":   "knit front and back",
        "pfb":   "purl front and back",
        "m1":    "make one",
        "m1l":   "make one left-leaning",
        "m1r":   "make one right-leaning",

        // Yarn-overs
        "yo":    "yarn over",
        "yon":   "yarn over needle",
        "yrn":   "yarn round needle",

        // Slips / yarn position
        "sl":    "slip",
        "sl1":   "slip one",
        "wyif":  "with yarn in front",
        "wyib":  "with yarn in back",
        "tbl":   "through back loop",

        // Structure / direction
        "rep":   "repeat",
        "rnd":   "round",
        "rnds":  "rounds",
        "beg":   "beginning",
        "rem":   "remaining",
        "inc":   "increase",
        "dec":   "decrease",
        "rs":    "right side",
        "ws":    "wrong side",

        // Tools / markers
        "pm":    "place marker",
        "sm":    "slip marker",
        "cn":    "cable needle",
        "dpn":   "double-pointed needles",

        // Cast on / bind off
        "co":    "cast on",
        "bo":    "bind off"
    ]

    /// Quick-tap chips surfaced in the manual editor.
    static let chips: [String] = [
        "k", "p", "k2tog", "ssk", "yo", "m1l", "m1r", "psso",
        "sl1", "wyif", "wyib", "rep", "rs", "ws"
    ]
}
