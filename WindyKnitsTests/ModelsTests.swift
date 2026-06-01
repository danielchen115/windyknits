import Testing
import Foundation
@testable import WindyKnits

@MainActor
@Suite("ProjectStatus")
struct ProjectStatusTests {
    @Test func labelsAreHumanReadable() {
        #expect(ProjectStatus.active.label   == "In progress")
        #expect(ProjectStatus.queue.label    == "Queue")
        #expect(ProjectStatus.finished.label == "Finished")
    }

    @Test func subDescriptionsAreNonEmpty() {
        for s in ProjectStatus.allCases {
            #expect(!s.sub.isEmpty)
        }
    }

    @Test func roundTripsThroughRawValue() {
        for s in ProjectStatus.allCases {
            #expect(ProjectStatus(rawValue: s.rawValue) == s)
        }
    }

    @Test func allCasesCoversThreeStates() {
        #expect(ProjectStatus.allCases.count == 3)
        #expect(Set(ProjectStatus.allCases) == [.active, .queue, .finished])
    }
}

@MainActor
@Suite("Project")
struct ProjectTests {
    private func project(rowsDone: Int = 0, rowsTotal: Int = 100) -> Project {
        Project(
            id: "test",
            title: "Test",
            designer: "Me",
            swatchHex: 0xff8800,
            yarn: "Cotton",
            color: "Pink",
            needles: "3mm",
            rowsDone: rowsDone,
            rowsTotal: rowsTotal,
            lastWorked: "Now"
        )
    }

    @Test func progressIsRowsDoneOverTotal() {
        #expect(project(rowsDone: 50, rowsTotal: 100).progress == 0.5)
        #expect(project(rowsDone: 0,  rowsTotal: 100).progress == 0)
        #expect(project(rowsDone: 100,rowsTotal: 100).progress == 1)
    }

    @Test func progressIsZeroWhenTotalIsZero() {
        #expect(project(rowsDone: 5, rowsTotal: 0).progress == 0)
    }

    @Test func percentLabelRoundsToWholeNumber() {
        #expect(project(rowsDone: 0,   rowsTotal: 100).percentLabel == "0%")
        #expect(project(rowsDone: 47,  rowsTotal: 184).percentLabel == "26%")
        #expect(project(rowsDone: 100, rowsTotal: 100).percentLabel == "100%")
        #expect(project(rowsDone: 1,   rowsTotal: 200).percentLabel == "1%")
    }

    @Test func defaultStatusIsActive() {
        #expect(project().status == .active)
    }

    @Test func codableRoundTripPreservesEveryField() throws {
        let original = Project(
            id: "p99",
            title: "Round Trip",
            designer: "Anonymous",
            swatchHex: 0xc8a7c4,
            yarn: "Wool",
            color: "Lilac",
            needles: "4.5 mm",
            rowsDone: 12,
            rowsTotal: 88,
            lastWorked: "Yesterday",
            notes: "Saved a row.",
            patternType: "Top-down",
            size: "M",
            gauge: "22sts",
            createdAt: Date(timeIntervalSince1970: 0),
            status: .queue,
            estWeeks: 4,
            yarnReady: true,
            addedOn: "May 1",
            finishedOn: nil,
            daysToFinish: nil
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Project.self, from: data)
        #expect(decoded == original)
    }
}

@MainActor
@Suite("ParsedPattern")
struct ParsedPatternTests {
    private func makePattern(bytes: Int, pages: Int) -> ParsedPattern {
        ParsedPattern(
            fileName: "p.pdf",
            pageCount: pages,
            fileSizeBytes: bytes,
            sections: [],
            rows: [],
            abbreviations: []
        )
    }

    @Test func fileSizeLabelUsesMegabytesAbovePoint1() {
        let half = makePattern(bytes: 500_000, pages: 1)
        #expect(half.fileSizeLabel == "0.5 MB")

        let oneAndAHalf = makePattern(bytes: 1_572_864, pages: 1) // 1.5 MB
        #expect(oneAndAHalf.fileSizeLabel == "1.5 MB")
    }

    @Test func fileSizeLabelUsesKilobytesBelowPoint1Megabytes() {
        // 50_000 bytes ≈ 0.0477 MB → falls under the 0.1 MB cutoff
        let small = makePattern(bytes: 50_000, pages: 1)
        #expect(small.fileSizeLabel.hasSuffix(" KB"))
        #expect(small.fileSizeLabel == "49 KB")
    }

    @Test func fileSizeLabelFloorsTinyFilesAtOneKB() {
        let tiny = makePattern(bytes: 1, pages: 1)
        #expect(tiny.fileSizeLabel == "1 KB")
    }

    @Test func pagesLabelIsSingularForOnePage() {
        #expect(makePattern(bytes: 0, pages: 1).pagesLabel == "1 page")
    }

    @Test func pagesLabelIsPluralForOther() {
        #expect(makePattern(bytes: 0, pages: 2).pagesLabel == "2 pages")
        #expect(makePattern(bytes: 0, pages: 0).pagesLabel == "0 pages")
    }
}

@MainActor
@Suite("Parsed types identity")
struct ParsedIdentityTests {
    @Test func parsedSectionGeneratesUniqueIDsByDefault() {
        let a = ParsedSection(name: "Yoke")
        let b = ParsedSection(name: "Yoke")
        #expect(a.id != b.id)
    }

    @Test func parsedSectionPreservesProvidedID() {
        let id = UUID()
        let s = ParsedSection(id: id, name: "Body", rowCount: 40)
        #expect(s.id == id)
        #expect(s.rowCount == 40)
    }

    @Test func parsedRowIdMirrorsRowNumber() {
        let r = ParsedRow(n: 7, rs: true, text: "Knit all", sts: 24)
        #expect(r.id == 7)
    }

    @Test func patternRowIdMirrorsRowNumber() {
        let r = PatternRow(n: 3, rs: false, text: "Purl", sts: 22)
        #expect(r.id == 3)
    }
}

@MainActor
@Suite("SampleData")
struct SampleDataTests {
    @Test func sampleProjectsHaveStableIDs() {
        let ids = SampleData.projects.map(\.id)
        #expect(Set(ids).count == ids.count, "Sample project IDs must be unique")
    }

    @Test func marigoldCarriesItsOwnYokeChart() {
        let p1 = SampleData.projects.first(where: { $0.id == "p1" })
        let pattern = p1?.pattern
        #expect(pattern != nil, "p1 should carry an embedded ParsedPattern")
        #expect(pattern?.rowsPerRepeat == 12)
        #expect(pattern?.rows.count == 12)
    }
}

@MainActor
@Suite("KnittingAbbreviations")
struct KnittingAbbreviationsTests {
    @Test func chipsAllHaveDefinitions() {
        for abbr in KnittingAbbreviations.chips {
            #expect(KnittingAbbreviations.dictionary[abbr] != nil,
                     "Chip '\(abbr)' has no entry in the dictionary")
        }
    }

    @Test func dictionaryKeysAreLowercase() {
        for key in KnittingAbbreviations.dictionary.keys {
            #expect(key == key.lowercased(),
                     "Abbreviation key '\(key)' must be lowercased for case-insensitive lookup")
        }
    }
}
