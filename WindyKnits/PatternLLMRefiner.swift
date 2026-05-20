import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Public types

struct SectionCandidate: Sendable, Hashable {
    /// Stable id assigned by the heuristic pass — what the dispatcher returns
    /// in the `kept` array so callers can map back to their candidate list.
    let id: Int
    let name: String
    /// ~200 chars of text immediately preceding this header.
    let contextBefore: String
    /// ~400 chars of text immediately following this header.
    let contextAfter: String
}

/// Returns the candidate ids that the refiner believes are real knitting
/// instructions. Returns nil if the refiner is unavailable or the call fails —
/// callers fall back to the heuristic in that case.
protocol PatternRefiner: Sendable {
    func filterSections(_ candidates: [SectionCandidate]) async -> [Int]?
}

// MARK: - Tier reporting

/// Which parsing engine produced the sections the user sees. Surfaced in the
/// import animation and on the review screen so a noisy result doesn't look
/// indistinguishable from a clean one.
enum ParseTier: Equatable, Sendable {
    case appleIntelligence
    case claude
    case basic(BasicReason)

    enum BasicReason: Equatable, Sendable {
        /// No on-device AI is available, and cloud parsing isn't configured
        /// (user opted out or no API key). This is the user's deliberate setup.
        case configured
        /// The LLM call was attempted and failed (network, schema, API error).
        case llmFailed(which: String)
    }

    nonisolated var shortLabel: String {
        switch self {
        case .appleIntelligence: return "Apple Intelligence"
        case .claude: return "Claude"
        case .basic: return "Basic detection"
        }
    }

    nonisolated var detailLabel: String {
        switch self {
        case .appleIntelligence: return "Detected with Apple Intelligence"
        case .claude: return "Detected with Claude"
        case .basic(.configured): return "Basic detection — on-device AI isn't available"
        case .basic(.llmFailed(let which)): return "Basic detection — \(which) didn't respond"
        }
    }

    nonisolated var sfSymbol: String {
        switch self {
        case .appleIntelligence: return "sparkles"
        case .claude: return "sparkles"
        case .basic(.configured): return "doc.text"
        case .basic(.llmFailed): return "exclamationmark.triangle"
        }
    }
}

struct RefinerResolution: Sendable {
    let refiner: (any PatternRefiner)?
    /// The tier the caller expects to use — i.e., what tier label to show
    /// during parsing. The actual tier may downgrade to `.basic(.llmFailed)`
    /// if the LLM call errors.
    let expectedTier: ParseTier
}

// MARK: - Dispatcher

enum PatternLLMRefiner {
    /// Resolve the best refiner the device can use right now, along with the
    /// tier label the UI should display.
    /// Tier 1 — Apple Intelligence (on-device, free, no consent)
    /// Tier 2 — Claude via the Anthropic API (off-device, opt-in)
    /// Tier 3 (refiner == nil) — caller uses the heuristic fallback
    @MainActor
    static func resolve(settings: WindyKnitsSettings) -> RefinerResolution {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), AppleRefiner.isAvailable {
            return RefinerResolution(refiner: AppleRefiner(), expectedTier: .appleIntelligence)
        }
        #endif
        if settings.canUseCloud, let key = settings.anthropicAPIKey {
            return RefinerResolution(refiner: ClaudeRefiner(apiKey: key), expectedTier: .claude)
        }
        return RefinerResolution(refiner: nil, expectedTier: .basic(.configured))
    }
}

// MARK: - Shared classification prompt

enum RefinerPrompts {
    static let systemPrompt = """
    You classify candidate headers from a knitting pattern PDF. For each \
    candidate, return isKnittingInstruction=true ONLY when the header \
    introduces work the knitter actually performs — cast on, knit rows, \
    increases, decreases, shaping, joining pieces, finishing, blocking.

    Return false for tables of contents, contributor credits, gauge specs, \
    yarn suggestions, needle lists, abbreviation glossaries, technique \
    explanations, photo captions, tips, notes, and page numbers.

    Return confidence in 0.0–1.0. Use 1-based indexing matching the input.
    """

    /// Encodes a batch of candidates into a user message.
    static func userMessage(_ batch: [SectionCandidate]) -> String {
        var s = "Classify each header below. Reply only via the submit_judgments tool / structured output.\n\n"
        for (i, c) in batch.enumerated() {
            s += "---\nIndex: \(i + 1)\nHeader: \(c.name)\nBefore: \(c.contextBefore)\nAfter: \(c.contextAfter)\n"
        }
        return s
    }

    static let confidenceFloor: Double = 0.6
    static let batchSize = 8
}

// MARK: - Tier 1: Apple Foundation Models

#if canImport(FoundationModels)
@available(iOS 26.0, *)
struct AppleRefiner: PatternRefiner {
    static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    @Generable struct Batch {
        @Guide(description: "One judgment per input candidate in original order.")
        let judgments: [Judgment]
    }

    @Generable struct Judgment {
        @Guide(description: "1-based index from the input batch.")
        let index: Int
        @Guide(description: "True when the header introduces actual knitting work.")
        let isKnittingInstruction: Bool
        @Guide(description: "Model confidence between 0.0 and 1.0.")
        let confidence: Double
    }

    func filterSections(_ candidates: [SectionCandidate]) async -> [Int]? {
        guard !candidates.isEmpty else { return [] }
        do {
            let session = LanguageModelSession(instructions: RefinerPrompts.systemPrompt)
            var kept: [Int] = []
            for chunk in candidates.chunked(into: RefinerPrompts.batchSize) {
                let response = try await session.respond(
                    to: RefinerPrompts.userMessage(chunk),
                    generating: Batch.self
                )
                for j in response.content.judgments {
                    if j.isKnittingInstruction,
                       j.confidence >= RefinerPrompts.confidenceFloor,
                       j.index >= 1, j.index <= chunk.count {
                        kept.append(chunk[j.index - 1].id)
                    }
                }
            }
            return kept
        } catch {
            return nil
        }
    }
}
#endif

// MARK: - Tier 2: Claude via Anthropic API

struct ClaudeRefiner: PatternRefiner {
    let apiKey: String

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-haiku-4-5-20251001"

    func filterSections(_ candidates: [SectionCandidate]) async -> [Int]? {
        guard !candidates.isEmpty else { return [] }
        var kept: [Int] = []
        for chunk in candidates.chunked(into: RefinerPrompts.batchSize) {
            guard let batchKept = await runBatch(chunk) else { return nil }
            kept.append(contentsOf: batchKept)
        }
        return kept
    }

    private func runBatch(_ chunk: [SectionCandidate]) async -> [Int]? {
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 1024,
            "system": RefinerPrompts.systemPrompt,
            "messages": [
                ["role": "user", "content": RefinerPrompts.userMessage(chunk)]
            ],
            "tools": [Self.judgmentTool],
            "tool_choice": ["type": "tool", "name": "submit_judgments"]
        ]

        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 20

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return nil
            }
            return parseJudgments(data, chunk: chunk)
        } catch {
            return nil
        }
    }

    private func parseJudgments(_ data: Data, chunk: [SectionCandidate]) -> [Int]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]] else { return nil }
        let toolUse = content.first(where: { ($0["type"] as? String) == "tool_use" })
        guard let input = toolUse?["input"] as? [String: Any],
              let judgments = input["judgments"] as? [[String: Any]] else { return nil }

        var kept: [Int] = []
        for j in judgments {
            guard let idx = j["index"] as? Int,
                  let isKnit = j["isKnittingInstruction"] as? Bool,
                  let conf = j["confidence"] as? Double else { continue }
            if isKnit, conf >= RefinerPrompts.confidenceFloor,
               idx >= 1, idx <= chunk.count {
                kept.append(chunk[idx - 1].id)
            }
        }
        return kept
    }

    /// JSON-schema description of the structured response we force Claude to emit.
    private static let judgmentTool: [String: Any] = [
        "name": "submit_judgments",
        "description": "Submit one knitting-vs-metadata classification per candidate header.",
        "input_schema": [
            "type": "object",
            "properties": [
                "judgments": [
                    "type": "array",
                    "items": [
                        "type": "object",
                        "properties": [
                            "index": ["type": "integer", "description": "1-based index from the input"],
                            "isKnittingInstruction": ["type": "boolean"],
                            "confidence": ["type": "number", "description": "0.0 to 1.0"]
                        ],
                        "required": ["index", "isKnittingInstruction", "confidence"]
                    ]
                ]
            ],
            "required": ["judgments"]
        ]
    ]
}

// MARK: - Helpers

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
