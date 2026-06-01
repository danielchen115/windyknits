import Testing
import Foundation
@testable import WindyKnits

@MainActor
@Suite("PatternImporter.parse")
struct PatternImporterParseTests {

    private func extractedText(_ text: String,
                                fileName: String = "pattern.pdf",
                                metaTitle: String? = nil,
                                metaAuthor: String? = nil,
                                includeCoverPage: Bool = false) -> PatternImporter.ExtractedText {
        // `includeCoverPage: false` keeps the perPage array empty so the
        // cover-page name-picker is skipped. Tests that want to exercise
        // the picker pass true (and craft a usable cover line themselves).
        PatternImporter.ExtractedText(
            fullText: text,
            perPage: includeCoverPage ? [text] : [],
            pageCount: includeCoverPage ? 1 : 0,
            fileSizeBytes: 1024,
            fileName: fileName,
            metaTitle: metaTitle,
            metaAuthor: metaAuthor
        )
    }

    @Test func parsesIndividuallyNumberedRows() async {
        // Each "Row N:" line is parsed as a separate single-row entry.
        // Alternation across separately-numbered single rows is handled
        // by the row-range expander below — `parseRows` does not attempt
        // to infer pairwise alternation between two consecutive `Row N:`
        // headers, so we only assert presence + ordering here.
        let text = """
        Row 1: K all.
        Row 2: P all.
        Row 3: K all.
        Row 4: P all.
        """
        let result = await PatternImporter.parse(extractedText(text))
        let rows = result.pattern.rows
        #expect(rows.count == 4)
        #expect(rows.map(\.n) == [1, 2, 3, 4])
    }

    @Test func alternatesSidesWithinAnExplicitRange() async {
        // "Rows 1-4" gives the parser a starting row + length, so it can
        // alternate RS/WS deterministically across the expansion.
        let text = "Rows 1-4: K all."
        let result = await PatternImporter.parse(extractedText(text))
        let rows = result.pattern.rows
        #expect(rows.count == 4)
        #expect(rows[0].rs == true,  "Row 1 is RS")
        #expect(rows[1].rs == false, "Row 2 is WS")
        #expect(rows[2].rs == true,  "Row 3 is RS")
        #expect(rows[3].rs == false, "Row 4 is WS")
    }

    @Test func honoursExplicitWsAnnotationOnLabeledRow() async {
        // A "(WS)" label on Row 1 must flip its side from the default RS.
        let text = "Row 1 (WS): P all."
        let result = await PatternImporter.parse(extractedText(text))
        #expect(result.pattern.rows.first?.rs == false)
    }

    @Test func honoursExplicitRsAnnotationOnLabeledRow() async {
        let text = "Row 1 (RS): K all."
        let result = await PatternImporter.parse(extractedText(text))
        #expect(result.pattern.rows.first?.rs == true)
    }

    @Test func roundsAreAlwaysRightSide() async {
        let text = """
        Rnd 1: K all.
        Rnd 2: K all.
        """
        let result = await PatternImporter.parse(extractedText(text))
        #expect(result.pattern.rows.allSatisfy { $0.rs == true })
    }

    @Test func expandsRowRanges() async {
        let text = "Rows 5-7: K all."
        let result = await PatternImporter.parse(extractedText(text))
        let nums = result.pattern.rows.map(\.n)
        #expect(nums == [5, 6, 7])
        // All three rows carry the same instruction body.
        #expect(result.pattern.rows.allSatisfy { $0.text == "K all." })
    }

    @Test func deduplicatesRepeatedRowNumbersKeepingFirst() async {
        let text = """
        Row 1: K all.
        Row 1: P all.
        """
        let result = await PatternImporter.parse(extractedText(text))
        #expect(result.pattern.rows.count == 1)
        #expect(result.pattern.rows[0].text == "K all.")
    }

    @Test func extractsStitchCountInParenthesesWithEquals() async {
        let text = "Row 1: K2tog around. (= 48 sts)"
        let result = await PatternImporter.parse(extractedText(text))
        #expect(result.pattern.rows.first?.sts == 48)
    }

    @Test func extractsStitchCountFromTrailingEqualsForm() async {
        let text = "Row 1: Knit all sts = 100 sts"
        let result = await PatternImporter.parse(extractedText(text))
        #expect(result.pattern.rows.first?.sts == 100)
    }

    @Test func extractsStitchCountFromBracketTrailer() async {
        let text = "Row 1: K all. [56 sts]"
        let result = await PatternImporter.parse(extractedText(text))
        #expect(result.pattern.rows.first?.sts == 56)
    }

    @Test func gluesContinuationLinesIntoPrecedingRow() async {
        // PDFKit-style hard wrap on the second physical line of Row 1.
        let text = """
        Row 1: K2, * yo, k2tog; rep from * to end.
        (= 60 sts)
        Row 2: P all.
        """
        let result = await PatternImporter.parse(extractedText(text))
        #expect(result.pattern.rows.first?.sts == 60)
    }

    @Test func findsKnownAbbreviationsWithWordBoundaries() async {
        // "k" must stand alone — boundary checks reject anything followed
        // by a digit or letter (so "K2" or "knit" don't count as bare k).
        let text = """
        Row 1: k, ssk, yo, k2tog, p.
        """
        let result = await PatternImporter.parse(extractedText(text))
        let abbrs = Set(result.pattern.abbreviations)
        #expect(abbrs.contains("k"))
        #expect(abbrs.contains("p"))
        #expect(abbrs.contains("ssk"))
        #expect(abbrs.contains("yo"))
        #expect(abbrs.contains("k2tog"))
    }

    @Test func abbreviationDetectionRespectsAlphanumericBoundaries() async {
        let text = "Row 1: knkn knot knit."
        let result = await PatternImporter.parse(extractedText(text))
        // None of those words is bare "k", "p", or any other knitting abbrev.
        let abbrs = Set(result.pattern.abbreviations)
        #expect(!abbrs.contains("k"))
        #expect(!abbrs.contains("p"))
    }

    @Test func usesMetaTitleWhenPresentAndNotGeneric() async {
        let text = "Row 1: K all."
        let result = await PatternImporter.parse(extractedText(text, metaTitle: "Marigold Cardigan"))
        #expect(result.name == "Marigold Cardigan")
    }

    @Test func rejectsGenericMetaTitlesFromMicrosoftWord() async {
        let text = "Row 1: K all."
        let result = await PatternImporter.parse(
            extractedText(text, fileName: "petite-knit.pdf", metaTitle: "Microsoft Word - draft.docx"))
        #expect(result.name != "Microsoft Word - draft.docx")
    }

    @Test func recoversNameFromFilenameWhenMetaIsMissing() async {
        let text = "Row 1: K all."
        let result = await PatternImporter.parse(extractedText(text, fileName: "hay_socks.pdf"))
        #expect(result.name == "Hay Socks")
    }

    @Test func rejectsLongUnseparatedFilenames() async {
        let text = "Row 1: K all."
        let result = await PatternImporter.parse(
            extractedText(text, fileName: "SANDOKtopenglishupdatedapril2026.pdf"))
        // Should fall back to first reasonable line of the document.
        #expect(result.name != "Sandoktopenglishupdatedapril2026")
    }

    @Test func usesAuthorMetaAsDesigner() async {
        let text = "Row 1: K all."
        let result = await PatternImporter.parse(
            extractedText(text, metaAuthor: "Petite Knit"))
        #expect(result.designer == "Petite Knit")
    }

    @Test func ignoresSoftwareMetaAuthor() async {
        let text = """
        Row 1: K all.
        Designed by Tuva Sandok
        """
        let result = await PatternImporter.parse(
            extractedText(text, metaAuthor: "Adobe InDesign"))
        // Inline credit should win over software-author metadata.
        #expect(result.designer == "Tuva Sandok")
    }

    @Test func parsesMultiLineCreditBlock() async {
        let text = """
        Editor and designer:
        Tuva Sandok

        Row 1: K all.
        """
        let result = await PatternImporter.parse(extractedText(text))
        #expect(result.designer == "Tuva Sandok")
    }

    @Test func parsesInlineByLine() async {
        let text = """
        by Erika Knight
        Row 1: K all.
        """
        let result = await PatternImporter.parse(extractedText(text))
        #expect(result.designer == "Erika Knight")
    }

    @Test func returnsBasicConfiguredTierWhenNoRefinerIsProvided() async {
        let result = await PatternImporter.parse(extractedText("Row 1: K all."))
        #expect(result.tier == .basic(.configured))
    }

    @Test func fallsBackToASinglePatternSectionWhenNoHeadersDetected() async {
        let text = "Row 1: K all."
        let result = await PatternImporter.parse(extractedText(text))
        // No headings in this text — heuristic should emit a synthetic
        // "Pattern" section so the UI shows something.
        let names = result.pattern.sections.map(\.name)
        #expect(names == ["Pattern"])
    }
}

@MainActor
@Suite("PatternImporter.candidateSections")
struct CandidateSectionsTests {

    @Test func finds_known_sections_case_insensitively() {
        let lines = ["Materials", "About this pattern", "Yoke", "Row 1: K all."]
        let candidates = PatternImporter.candidateSections(lines: lines)
        let names = candidates.map(\.name).map { $0.lowercased() }
        #expect(names.contains("materials"))
        #expect(names.contains("yoke"))
    }

    @Test func dropsRowLinesAsCandidates() {
        let lines = ["Row 1: K all.", "Row 2: P all."]
        #expect(PatternImporter.candidateSections(lines: lines).isEmpty)
    }

    @Test func dropsDenylistedHeaders() {
        // "Note", "Tip", "Designer", etc. should never be classified as sections.
        let lines = ["Note", "Tip", "Designer", "Credits"]
        #expect(PatternImporter.candidateSections(lines: lines).isEmpty)
    }

    @Test func dropsLinesThatAreMostlyDigits() {
        let lines = ["12345 67890", "Page 3 of 10"]
        let candidates = PatternImporter.candidateSections(lines: lines)
        // Either nothing matches, or specifically the digit-heavy noise gets dropped.
        #expect(!candidates.contains(where: { $0.name.allSatisfy { $0.isNumber || $0.isWhitespace } }))
    }

    @Test func dropsRepeatedBoilerplateLines() {
        let line = "© 2026 Some Designer"
        let lines = Array(repeating: line, count: 4) + ["Yoke"]
        let candidates = PatternImporter.candidateSections(lines: lines)
        #expect(!candidates.contains(where: { $0.name == line }))
    }

    @Test func acceptsColonTerminatedShortHeaders() {
        let lines = ["Setup row:", "Row 1: K all."]
        let candidates = PatternImporter.candidateSections(lines: lines)
        #expect(candidates.contains(where: { $0.endsWithColon }))
    }

    @Test func excludesPassedInBlocklist() {
        let lines = ["Tuva Sandok", "Yoke"]
        let candidates = PatternImporter.candidateSections(
            lines: lines,
            excludes: ["tuva sandok"]
        )
        #expect(!candidates.contains(where: { $0.name == "Tuva Sandok" }))
    }
}

@MainActor
@Suite("PatternImporter.refineSectionsHeuristic")
struct RefineSectionsHeuristicTests {

    @Test func keepsKnownSections() {
        let candidates = [
            PatternImporter.SectionCandidateRecord(
                id: 0, name: "Yoke", lineIndex: 0, matchesKnown: true, endsWithColon: false
            )
        ]
        let rows = [ParsedRow(n: 1, rs: true, text: "K all", sts: nil)]
        let kept = PatternImporter.refineSectionsHeuristic(candidates: candidates, lines: [], rows: rows)
        #expect(kept.map(\.name) == ["Yoke"])
    }

    @Test func dropsUnknownColonlessCandidateSurroundedByShortLines() {
        let candidates = [
            PatternImporter.SectionCandidateRecord(
                id: 0, name: "Pink", lineIndex: 0, matchesKnown: false, endsWithColon: false
            )
        ]
        let lines = ["Pink", "x", "y", "z"]
        let kept = PatternImporter.refineSectionsHeuristic(
            candidates: candidates, lines: lines, rows: [])
        #expect(kept.isEmpty)
    }

    @Test func emitsSyntheticPatternSectionWhenNothingKeptButRowsExist() {
        let rows = [ParsedRow(n: 1, rs: true, text: "K all", sts: nil),
                    ParsedRow(n: 2, rs: false, text: "P all", sts: nil)]
        let kept = PatternImporter.refineSectionsHeuristic(
            candidates: [], lines: [], rows: rows)
        #expect(kept.count == 1)
        #expect(kept[0].name == "Pattern")
        #expect(kept[0].rowCount == 2)
    }

    @Test func emitsNothingWhenNoSectionsAndNoRows() {
        let kept = PatternImporter.refineSectionsHeuristic(
            candidates: [], lines: [], rows: [])
        #expect(kept.isEmpty)
    }
}

@MainActor
@Suite("PatternImporter.buildLLMCandidates")
struct BuildLLMCandidatesTests {

    @Test func attachesContextWindowAroundEachCandidate() {
        let lines = [
            "preamble line",
            "Yoke",
            "Row 1: K all.",
            "Row 2: P all.",
            "Row 3: K all."
        ]
        let candidates = [
            PatternImporter.SectionCandidateRecord(
                id: 7, name: "Yoke", lineIndex: 1, matchesKnown: true, endsWithColon: false
            )
        ]
        let built = PatternImporter.buildLLMCandidates(candidates, lines: lines)
        #expect(built.count == 1)
        #expect(built[0].id == 7)
        #expect(built[0].name == "Yoke")
        #expect(built[0].contextBefore.contains("preamble"))
        #expect(built[0].contextAfter.contains("Row 1"))
    }
}
