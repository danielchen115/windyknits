import Testing
import Foundation
@testable import WindyKnits

@MainActor
@Suite("ParseTier")
struct ParseTierTests {

    @Test func shortLabelsAreHumanReadable() {
        #expect(ParseTier.appleIntelligence.shortLabel == "Apple Intelligence")
        #expect(ParseTier.claude.shortLabel == "Claude")
        #expect(ParseTier.basic(.configured).shortLabel == "Basic detection")
        #expect(ParseTier.basic(.llmFailed(which: "Claude")).shortLabel == "Basic detection")
    }

    @Test func detailLabelExplainsWhyTheTierIsBasic() {
        #expect(ParseTier.basic(.configured).detailLabel
                == "Basic detection — on-device AI isn't available")
        #expect(ParseTier.basic(.llmFailed(which: "Claude")).detailLabel
                == "Basic detection — Claude didn't respond")
    }

    @Test func detailLabelForRealTiersIncludesEngineName() {
        #expect(ParseTier.appleIntelligence.detailLabel.contains("Apple Intelligence"))
        #expect(ParseTier.claude.detailLabel.contains("Claude"))
    }

    @Test func sfSymbolMatchesTier() {
        #expect(ParseTier.appleIntelligence.sfSymbol == "sparkles")
        #expect(ParseTier.claude.sfSymbol == "sparkles")
        #expect(ParseTier.basic(.configured).sfSymbol == "doc.text")
        #expect(ParseTier.basic(.llmFailed(which: "Claude")).sfSymbol
                == "exclamationmark.triangle")
    }

    @Test func basicReasonsCompareByCase() {
        #expect(ParseTier.basic(.configured) == .basic(.configured))
        #expect(ParseTier.basic(.configured) != .basic(.llmFailed(which: "Claude")))
        #expect(ParseTier.basic(.llmFailed(which: "Claude"))
                != .basic(.llmFailed(which: "Apple Intelligence")))
    }
}

@MainActor
@Suite("SectionCandidate")
struct SectionCandidateTests {

    @Test func equalsItselfWhenAllFieldsMatch() {
        let a = SectionCandidate(id: 1, name: "Yoke",
                                  contextBefore: "before",
                                  contextAfter: "after")
        let b = SectionCandidate(id: 1, name: "Yoke",
                                  contextBefore: "before",
                                  contextAfter: "after")
        #expect(a == b)
    }

    @Test func differentIdsMakeCandidatesUnequal() {
        let a = SectionCandidate(id: 1, name: "Yoke", contextBefore: "", contextAfter: "")
        let b = SectionCandidate(id: 2, name: "Yoke", contextBefore: "", contextAfter: "")
        #expect(a != b)
    }
}
