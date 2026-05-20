import Foundation
import PDFKit

/// Extracts raw text + metadata from a PDF, then parses it into a `ParsedPattern`.
///
/// The parser is intentionally heuristic: knitting patterns vary wildly in
/// layout, so we identify rows, sections, and abbreviations by matching against
/// well-known knitting conventions rather than relying on a single template.
///
/// All members are `nonisolated` so callers can invoke them from background
/// tasks without crossing the main actor.
enum PatternImporter {

    struct ExtractedText {
        let fullText: String
        let perPage: [String]
        let pageCount: Int
        let fileSizeBytes: Int
        let fileName: String
        let metaTitle: String?
        let metaAuthor: String?
    }

    enum ImportError: LocalizedError {
        case cannotOpenFile
        case emptyPDF
        case noTextContent

        var errorDescription: String? {
            switch self {
            case .cannotOpenFile: "Couldn't open that file."
            case .emptyPDF:       "That PDF has no pages."
            case .noTextContent:  "No readable text in that PDF — is it scanned?"
            }
        }
    }

    // MARK: - Extraction

    nonisolated static func extract(from url: URL) throws -> ExtractedText {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let doc = PDFDocument(url: url) else { throw ImportError.cannotOpenFile }
        guard doc.pageCount > 0 else { throw ImportError.emptyPDF }

        var pages: [String] = []
        pages.reserveCapacity(doc.pageCount)
        for i in 0..<doc.pageCount {
            pages.append(doc.page(at: i)?.string ?? "")
        }
        let joined = pages.joined(separator: "\n\n")
        guard !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.noTextContent
        }

        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0

        let title = doc.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
        let author = doc.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String

        return ExtractedText(
            fullText: joined,
            perPage: pages,
            pageCount: doc.pageCount,
            fileSizeBytes: size,
            fileName: url.lastPathComponent,
            metaTitle: title?.trimmedNonEmpty,
            metaAuthor: author?.trimmedNonEmpty
        )
    }

    // MARK: - Parsing

    struct ParseResult: Sendable {
        var name: String
        var designer: String
        var pattern: ParsedPattern
        /// Tier that produced the section list — for UI reporting.
        var tier: ParseTier
    }

    nonisolated static func parse(_ extracted: ExtractedText,
                                   refiner: (any PatternRefiner)? = nil,
                                   expectedTier: ParseTier = .basic(.configured)) async -> ParseResult {
        let lines = extracted.fullText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let coverPage = extracted.perPage.first
        let name = inferName(metaTitle: extracted.metaTitle,
                             fileName: extracted.fileName,
                             lines: lines,
                             coverPage: coverPage)
        let designer = inferDesigner(metaAuthor: extracted.metaAuthor,
                                      lines: lines,
                                      fullText: extracted.fullText)
        // PDFKit hard-wraps every line. To recover the original paragraphs,
        // glue non-structural lines back onto their preceding header. Row
        // parsing needs the joined version (so "(= 4 stitches decreased)" on a
        // continuation line is still part of Row 1); section parsing stays on
        // raw lines so a `Body:` header isn't lost into its own paragraph.
        let paragraphs = buildParagraphs(lines: lines)
        let rows = parseRows(paragraphs: paragraphs)
        let excludes: Set<String> = [designer.lowercased()].filter { !$0.isEmpty }.reduce(into: []) { $0.insert($1) }

        // Section detection runs in two phases. Phase 1 collects candidates
        // with the cheap structural filters applied. Phase 2 either asks the
        // LLM to classify them or falls back to the embedded-in-list heuristic.
        let candidates = candidateSections(lines: lines, excludes: excludes)
        let sections: [ParsedSection]
        var tier = expectedTier
        if let refiner {
            if let keptIds = await refiner.filterSections(buildLLMCandidates(candidates, lines: lines)) {
                let keptSet = Set(keptIds)
                sections = candidates.filter { keptSet.contains($0.id) }
                    .map { ParsedSection(name: $0.name) }
            } else {
                // LLM was attempted but failed — note the downgrade.
                sections = refineSectionsHeuristic(candidates: candidates, lines: lines, rows: rows)
                tier = .basic(.llmFailed(which: expectedTier.shortLabel))
            }
        } else {
            sections = refineSectionsHeuristic(candidates: candidates, lines: lines, rows: rows)
        }
        let abbreviations = parseAbbreviations(fullText: extracted.fullText)

        let pattern = ParsedPattern(
            fileName: extracted.fileName,
            pageCount: extracted.pageCount,
            fileSizeBytes: extracted.fileSizeBytes,
            sections: sections,
            rows: rows,
            abbreviations: abbreviations
        )
        return ParseResult(name: name, designer: designer, pattern: pattern, tier: tier)
    }

    // MARK: - Name / designer

    nonisolated private static func inferName(metaTitle: String?,
                                              fileName: String,
                                              lines: [String],
                                              coverPage: String?) -> String {
        if let meta = metaTitle, !looksGeneric(meta) { return meta }
        if let p = coverPage, let pageTitle = pickTitleFromCover(p) { return pageTitle }
        if let fromName = nameFromFilename(fileName) { return fromName }
        return lines.first { $0.count > 3 && $0.count < 80 } ?? "Untitled pattern"
    }

    /// Cover pages typically have the pattern name in a big short uppercase
    /// line, surrounded by SKU/size labels. We reject the labels and prefer the
    /// shortest all-caps candidate, title-cased.
    nonisolated private static func pickTitleFromCover(_ pageText: String) -> String? {
        let coverLines = pageText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let labelPrefix = try? NSRegularExpression(
            pattern: #"^(?:NO\.?|N°|NR\.?|SIZE[S]?|VERSION|VER\.|VOL\.|DESIGN(?:ED)?|PATTERN|PAGE)\b"#,
            options: [.caseInsensitive]
        )

        let candidates = coverLines.filter { line in
            guard line.count >= 2, line.count <= 40 else { return false }
            guard line.contains(where: { $0.isLetter }) else { return false }
            // 90%+ digits → SKU/page number.
            let digits = line.filter(\.isNumber).count
            if digits * 10 > line.count * 9 { return false }
            let r = NSRange(line.startIndex..<line.endIndex, in: line)
            if labelPrefix?.firstMatch(in: line, range: r) != nil { return false }
            return true
        }

        let allCaps = candidates.filter { $0.uppercased() == $0 }
        let best = allCaps.min(by: { ($0.count, $0) < ($1.count, $1) }) ?? candidates.first
        return best.map(titleCase)
    }

    /// Reject filenames that are a long contiguous run with no word boundaries
    /// (`SANDOKtopenglishupdatedapril20th2026.pdf` is unsalvageable).
    nonisolated private static func nameFromFilename(_ fileName: String) -> String? {
        let stem = (fileName as NSString).deletingPathExtension
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
        guard !stem.isEmpty else { return nil }
        if !stem.contains(" "), stem.count > 14 { return nil }
        return titleCase(stem)
    }

    nonisolated private static func titleCase(_ s: String) -> String {
        s.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }

    nonisolated private static func looksGeneric(_ s: String) -> Bool {
        let lower = s.lowercased()
        return lower.isEmpty
            || lower.contains("microsoft word")
            || lower.contains("untitled")
            || lower.hasSuffix(".pdf")
            || lower.hasSuffix(".doc")
            || lower.hasSuffix(".docx")
    }

    nonisolated private static func looksLikeSoftware(_ s: String) -> Bool {
        let lower = s.lowercased()
        let badWords = ["microsoft", "adobe", "indesign", "photoshop",
                        "illustrator", "acrobat", "preview", "pages",
                        "scribus", "affinity", "canva"]
        return badWords.contains { lower.contains($0) }
    }

    nonisolated private static func inferDesigner(metaAuthor: String?,
                                                  lines: [String],
                                                  fullText: String) -> String {
        if let a = metaAuthor, !a.isEmpty, !looksLikeSoftware(a) { return a }

        // Multi-line credit blocks: "Editor and designer:\nTuva Sandok".
        let creditBlock = #"(?:editor\s+and\s+designer|designed\s+by|pattern\s+by|designer)\s*:?\s*\n+\s*([\p{L}][\p{L}\.\-' ]{1,40})"#
        if let m = fullText.firstMatch(pattern: creditBlock, options: [.caseInsensitive]),
           let cap = m.captured(1)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !cap.isEmpty, !looksLikeSoftware(cap) {
            return cap.trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
        }

        // Single-line: "Designer: X", "by X", "Designed by X".
        let inline = [
            #"^(?:designed\s+by|design(?:er)?)\s*:?\s+(.+)$"#,
            #"^by\s+(.+)$"#,
            #"^pattern\s+by\s+(.+)$"#
        ]
        for line in lines.prefix(60) {
            for p in inline {
                if let m = line.firstMatch(pattern: p, options: [.caseInsensitive]),
                   let cap = m.captured(1), !cap.isEmpty, !looksLikeSoftware(cap) {
                    return cap.trimmingCharacters(in: .whitespacesAndNewlines)
                        .trimmingCharacters(in: CharacterSet(charactersIn: ".,;"))
                }
            }
        }
        return ""
    }

    // MARK: - Rows

    // Matches: "Row 1:", "Row 1.", "Rows 5-7:", "R12 (RS):", "Rnd 4:", etc.
    nonisolated private static let rowRegex = #"^(?:Row|Rows|R|Rnd|Rnds|Round|Rounds)\s*(\d+)(?:\s*[-–to]+\s*(\d+))?\s*(?:\(([^)]+)\))?\s*[:.\)]\s*(.+)$"#

    // Stitch counts come in several wrappers. Tried in order, first match wins.
    nonisolated private static let stsPatterns: [String] = [
        // "(= 48 stitches)", "(= 4 stitches decreased)", "(= 48 sts remaining)"
        #"\(\s*=\s*(\d+)\s*(?:sts?|stitches)\b[^)]*\)"#,
        // "= 48 sts", "= 48 stitches" trailing the line
        #"=\s*(\d+)\s*(?:sts?|stitches)\b"#,
        // "(48 sts)" / "[48 sts]" / "— 48 sts" at end of line
        #"(?:[\(\[—–-]\s*)(\d+)\s*(?:sts?|stitches)\s*[\)\]\.]?\s*$"#
    ]

    /// Walks `lines` and joins continuation lines into the preceding
    /// "structural" line so multi-line rows survive PDF soft-wrap. A line
    /// starts a new paragraph if it's a row opener, a short colon-ended header,
    /// an all-caps short heading, or a page number; otherwise it's appended to
    /// the current paragraph with a single space.
    nonisolated private static func buildParagraphs(lines: [String]) -> [String] {
        var paragraphs: [String] = []
        for line in lines {
            let isAllCapsShort = line.count <= 30
                && line == line.uppercased()
                && line.contains(where: { $0.isLetter })
            let isNumericOnly = !line.isEmpty
                && line.allSatisfy { $0.isNumber || $0.isWhitespace }
            let isStructural = isRowLine(line)
                || (line.hasSuffix(":") && line.count <= 50)
                || isAllCapsShort
                || isNumericOnly

            if isStructural || paragraphs.isEmpty {
                paragraphs.append(line)
            } else {
                paragraphs[paragraphs.count - 1] += " " + line
            }
        }
        return paragraphs
    }

    nonisolated private static func parseRows(paragraphs: [String]) -> [ParsedRow] {
        var out: [ParsedRow] = []
        for para in paragraphs {
            guard let m = para.firstMatch(pattern: rowRegex, options: [.caseInsensitive]) else {
                continue
            }
            guard let nStr = m.captured(1), let n = Int(nStr) else { continue }
            let nEnd = m.captured(2).flatMap(Int.init) ?? n
            let sideLabel = m.captured(3)?.lowercased() ?? ""
            let body = m.captured(4) ?? ""

            // Rounds are always worked from the right side; flat rows alternate.
            let isRound = para.range(of: #"^(?:Rnd|Rnds|Round|Rounds)"#,
                                      options: [.regularExpression, .caseInsensitive]) != nil

            let rs: Bool
            if isRound {
                rs = true
            } else if sideLabel.contains("rs") || sideLabel.contains("right") {
                rs = true
            } else if sideLabel.contains("ws") || sideLabel.contains("wrong") {
                rs = false
            } else {
                rs = !n.isMultiple(of: 2)
            }

            let sts = stsPatterns.lazy.compactMap { pattern in
                body.firstMatch(pattern: pattern, options: [.caseInsensitive])?
                    .captured(1).flatMap(Int.init)
            }.first

            // Expand "Rows 5-7" into individual entries with the same instructions.
            for num in n...max(n, nEnd) {
                let isRS = isRound
                    ? true
                    : (num.isMultiple(of: 2) ? !rs : rs)
                out.append(ParsedRow(n: num, rs: isRS, text: body, sts: sts))
            }
        }
        // De-duplicate by row number — first occurrence wins.
        var seen = Set<Int>()
        return out.filter { seen.insert($0.n).inserted }.sorted { $0.n < $1.n }
    }

    // MARK: - Sections

    /// Section names we recognise outright (case-insensitive substring match).
    nonisolated private static let knownSections: [String] = [
        "Materials", "Gauge", "Notes", "Abbreviations", "Sizing", "Schematic",
        "Cast on", "Setup", "Yoke", "Body", "Sleeves", "Sleeve", "Hem",
        "Ribbed hem", "Collar", "Neckline", "Neckband", "Cuffs", "Cuff",
        "Edging", "Border", "Finishing", "Blocking", "Toe", "Heel", "Leg",
        "Foot", "Gusset", "Chart", "Pattern notes",
        "Techniques", "Tips and tricks", "Contributors",
        "Sizes", "Measurements", "Sizes and measurements", "What you need",
        "Introduction", "Description"
    ]

    /// Words/phrases that look like sections but aren't pattern structure.
    nonisolated private static let sectionDenylist: Set<String> = [
        "note", "tip", "tips", "hot tip", "important", "warning",
        "editor", "editor and designer", "designer", "graphic design",
        "photography", "photographer", "credits", "tester", "testers",
        "row number", "chart key"
    ]

    /// Internal candidate carries extra metadata that the heuristic refinement
    /// step needs (`lineIndex` for lookahead, `matchesKnown`/`endsWithColon`
    /// for the strict accept/reject logic). The LLM tier only sees `id` and
    /// `name` plus context windows.
    struct SectionCandidateRecord: Sendable {
        let id: Int
        let name: String
        let lineIndex: Int
        let matchesKnown: Bool
        let endsWithColon: Bool
    }

    /// Phase 1 of section detection: produce candidates with cheap structural
    /// filtering only. The aggressive "is this really a section" judgment is
    /// deferred to Phase 2 (LLM or heuristic).
    nonisolated static func candidateSections(lines: [String],
                                               excludes: Set<String> = []) -> [SectionCandidateRecord] {
        var found: [SectionCandidateRecord] = []
        var seenLower = Set<String>()
        var nextId = 0

        // Histogram of repeated lines — bylines/footers spam the document.
        var lineCounts: [String: Int] = [:]
        for line in lines {
            lineCounts[line.lowercased(), default: 0] += 1
        }

        for (idx, line) in lines.enumerated() {
            if isRowLine(line) { continue }
            guard line.count <= 50 else { continue }
            guard let first = line.first, first.isUppercase || first.isNumber else { continue }

            let stripped = line.trimmingCharacters(in: CharacterSet(charactersIn: " :.-—–"))
            guard stripped.count >= 3 else { continue }
            guard stripped.contains(where: { $0.isLetter }) else { continue }
            let digits = stripped.filter(\.isNumber).count
            if digits * 2 > stripped.count { continue }

            let key = stripped.lowercased()
            if excludes.contains(key) { continue }
            if (lineCounts[line.lowercased()] ?? 0) >= 3 { continue }
            if sectionDenylist.contains(where: { key == $0 || key.hasPrefix($0 + " ") }) {
                continue
            }

            let matchesKnown = knownSections.first { known in
                let knownLower = known.lowercased()
                return key == knownLower
                    || key.hasPrefix(knownLower + " ")
                    || key.hasSuffix(" " + knownLower)
            }
            let endsWithColon = line.hasSuffix(":")
            let looksHeading = isLikelyHeading(stripped)
            guard matchesKnown != nil || endsWithColon || looksHeading else { continue }

            // Drop "Label:\n200 grams" sub-bullets up front — even the LLM
            // doesn't need to see these, they're trivially mechanical.
            if endsWithColon, idx + 1 < lines.count, isNumericSubBullet(lines[idx + 1]) {
                continue
            }

            if seenLower.insert(key).inserted {
                found.append(SectionCandidateRecord(
                    id: nextId,
                    name: stripped,
                    lineIndex: idx,
                    matchesKnown: matchesKnown != nil,
                    endsWithColon: endsWithColon
                ))
                nextId += 1
            }
        }
        return found
    }

    /// Phase 2 (fallback): the embedded-in-list filter that the heuristic uses
    /// to drop color-grid entries. Mirrors the original `parseSections` tail.
    nonisolated static func refineSectionsHeuristic(candidates: [SectionCandidateRecord],
                                                     lines: [String],
                                                     rows: [ParsedRow]) -> [ParsedSection] {
        var out: [ParsedSection] = []
        for c in candidates {
            if !c.matchesKnown, !c.endsWithColon,
               isEmbeddedInList(at: c.lineIndex, lines: lines) {
                continue
            }
            out.append(ParsedSection(name: c.name))
        }
        if out.isEmpty && !rows.isEmpty {
            out.append(ParsedSection(name: "Pattern", rowCount: rows.count))
        }
        return out
    }

    /// Build context windows around each candidate's source line for the LLM.
    nonisolated static func buildLLMCandidates(_ candidates: [SectionCandidateRecord],
                                                lines: [String]) -> [SectionCandidate] {
        candidates.map { c in
            let (before, after) = contextWindow(at: c.lineIndex, in: lines, beforeBudget: 200, afterBudget: 400)
            return SectionCandidate(id: c.id, name: c.name, contextBefore: before, contextAfter: after)
        }
    }

    nonisolated private static func contextWindow(at idx: Int,
                                                   in lines: [String],
                                                   beforeBudget: Int,
                                                   afterBudget: Int) -> (before: String, after: String) {
        var before = ""
        var i = idx - 1
        while i >= 0, before.count < beforeBudget {
            before = lines[i] + " " + before
            i -= 1
        }
        var after = ""
        var j = idx + 1
        while j < lines.count, after.count < afterBudget {
            after += lines[j] + " "
            j += 1
        }
        return (String(before.suffix(beforeBudget)),
                String(after.prefix(afterBudget)))
    }

    /// True when the line is short and >⅓ digits — yarn weights, page numbers,
    /// SKU codes that follow a label like `Double Sunday:`.
    nonisolated private static func isNumericSubBullet(_ s: String) -> Bool {
        guard s.count < 80 else { return false }
        let digits = s.filter(\.isNumber).count
        return digits * 3 > s.count
    }

    /// Candidate is surrounded by short lines (≥2 of the next 2-3 are <24
    /// chars). Real section headings introduce paragraphs; grid items don't.
    nonisolated private static func isEmbeddedInList(at idx: Int, lines: [String]) -> Bool {
        let remaining = min(3, lines.count - idx - 1)
        guard remaining >= 2 else { return false }
        let next = Array(lines[(idx + 1)...(idx + remaining)])
        return next.filter { $0.count < 24 }.count >= 2
    }

    nonisolated private static func isRowLine(_ s: String) -> Bool {
        s.range(of: rowRegex, options: [.regularExpression, .caseInsensitive]) != nil
    }

    nonisolated private static func isLikelyHeading(_ s: String) -> Bool {
        // All-caps short line, or Title Case with no terminal punctuation.
        if s == s.uppercased(), s.count >= 3, s.count <= 30 { return true }
        let words = s.split(separator: " ")
        guard words.count <= 5 else { return false }
        let titleCase = words.allSatisfy { w in
            guard let first = w.first else { return false }
            return first.isUppercase || w.allSatisfy(\.isNumber)
        }
        let endsCleanly = !s.hasSuffix(".") && !s.hasSuffix(",") && !s.hasSuffix(";")
        return titleCase && endsCleanly
    }

    // MARK: - Abbreviations

    /// Canonical knitting abbreviations to search for. Lowercase, longest-first
    /// so e.g. `k2tog` matches before `k`.
    nonisolated private static let knownAbbreviations: [String] = [
        "k2tog", "p2tog", "k3tog", "p3tog", "ssk", "ssp", "psso", "sssk",
        "kfb", "pfb", "m1l", "m1r", "m1",
        "wyif", "wyib", "sl1", "sl",
        "yo", "yon", "yrn",
        "rep", "rnd", "rnds", "beg", "rem", "inc", "dec",
        "tbl", "pm", "sm", "cn", "dpn",
        "co", "bo", "rs", "ws",
        "k", "p", "st", "sts"
    ]

    nonisolated private static func parseAbbreviations(fullText: String) -> [String] {
        let lower = fullText.lowercased()
        var hits: [String] = []
        var seen = Set<String>()
        for abbr in knownAbbreviations {
            // Boundary: not preceded/followed by another alphanumeric. `k2tog`
            // includes digits so we can't use `\b` directly — build a manual one.
            let escaped = NSRegularExpression.escapedPattern(for: abbr)
            let pattern = "(?<![a-z0-9])" + escaped + "(?![a-z0-9])"
            if lower.range(of: pattern, options: .regularExpression) != nil,
               seen.insert(abbr).inserted {
                hits.append(abbr)
            }
        }
        return hits
    }
}

// MARK: - Tiny regex helpers

private struct RegexMatch: Sendable {
    let ranges: [NSRange]
    let source: String
    nonisolated func captured(_ i: Int) -> String? {
        guard i < ranges.count else { return nil }
        let r = ranges[i]
        guard r.location != NSNotFound, let swift = Range(r, in: source) else { return nil }
        return String(source[swift])
    }
}

private extension String {
    nonisolated func firstMatch(pattern: String, options: NSRegularExpression.Options = []) -> RegexMatch? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        let range = NSRange(startIndex..<endIndex, in: self)
        guard let m = regex.firstMatch(in: self, range: range) else { return nil }
        var ranges: [NSRange] = []
        for i in 0..<m.numberOfRanges { ranges.append(m.range(at: i)) }
        return RegexMatch(ranges: ranges, source: self)
    }

    nonisolated var trimmedNonEmpty: String? {
        let t = trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}
