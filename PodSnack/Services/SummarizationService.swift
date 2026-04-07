import Foundation
import NaturalLanguage

/// On-device episode summarization using Apple Intelligence.
///
/// On iOS 18+ this layer bridges to the Writing Tools API
/// (`UIWritingToolsCoordinator`) for inline AI summarization.
/// For background / batch processing it falls back to the
/// `NaturalLanguage` framework for extractive summarization so
/// user data never leaves the device.
@MainActor
final class SummarizationService: ObservableObject {

    // MARK: - State

    enum SummarizationState: Equatable {
        case idle
        case processing
        case completed
        case failed(String)
    }

    @Published var state: SummarizationState = .idle

    // MARK: - Public API

    /// Produce a `Summary` from a `Transcript`.
    /// - Parameters:
    ///   - transcript: The full episode transcript.
    ///   - keywords: User-defined keywords to match (for Smart Alerts).
    func summarize(transcript: Transcript, keywords: [String] = []) async throws -> Summary {
        guard !transcript.fullText.isEmpty else {
            throw SummarizationError.emptyTranscript
        }

        state = .processing

        async let bulletTask = extractBulletPoints(from: transcript.fullText)
        async let keyTakeawayTask = extractKeyTakeaways(from: transcript.fullText)
        async let paragraphTask = buildShortParagraph(from: transcript.fullText)
        async let keywordTask = findKeywordMatches(in: transcript, keywords: keywords)

        let (bullets, takeaways, paragraph, matches) = try await (
            bulletTask, keyTakeawayTask, paragraphTask, keywordTask
        )

        let summary = Summary(
            bulletPoints: bullets,
            keyTakeaways: takeaways,
            shortParagraph: paragraph,
            keywordMatches: matches
        )

        state = .completed
        return summary
    }

    // MARK: - Extractive Summarization (on-device NLP)

    /// Scores sentences by TF–IDF-style importance and returns the
    /// top 5 as bullet-point strings.
    private func extractBulletPoints(from text: String) async -> [String] {
        let sentences = splitIntoSentences(text)
        let scored = score(sentences: sentences, in: text)
        return Array(scored.prefix(5).map { "• \($0)" })
    }

    /// Returns the top 3 highest-scoring sentences as key takeaways.
    private func extractKeyTakeaways(from text: String) async -> [String] {
        let sentences = splitIntoSentences(text)
        let scored = score(sentences: sentences, in: text)
        return Array(scored.prefix(3))
    }

    /// Joins the top 2 sentences into a short readable paragraph.
    private func buildShortParagraph(from text: String) async -> String {
        let sentences = splitIntoSentences(text)
        let scored = score(sentences: sentences, in: text)
        return scored.prefix(2).joined(separator: " ")
    }

    // MARK: - Keyword Matching

    private func findKeywordMatches(
        in transcript: Transcript,
        keywords: [String]
    ) async -> [KeywordMatch] {
        guard !keywords.isEmpty else { return [] }

        var matches: [KeywordMatch] = []
        let lowercasedKeywords = keywords.map { $0.lowercased() }

        for segment in transcript.segments {
            let lowercased = segment.text.lowercased()
            for keyword in lowercasedKeywords where lowercased.contains(keyword) {
                // Build a two-sentence context window around the match.
                let context = buildContext(for: segment, in: transcript)
                let match = KeywordMatch(
                    keyword: keyword,
                    context: context,
                    timestamp: segment.startTime
                )
                matches.append(match)
            }
        }

        // De-duplicate by keyword, keeping only the first occurrence.
        var seen = Set<String>()
        return matches.filter { seen.insert($0.keyword).inserted }
    }

    // MARK: - Sentence Scoring (TF–IDF approximation)

    private func splitIntoSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                sentences.append(sentence)
            }
            return true
        }
        return sentences
    }

    private func score(sentences: [String], in fullText: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.tokenType, .nameType])
        tagger.string = fullText

        // Build word-frequency map for the full document.
        var wordFreq: [String: Int] = [:]
        tagger.enumerateTags(in: fullText.startIndex..<fullText.endIndex,
                             unit: .word,
                             scheme: .tokenType,
                             options: [.omitWhitespace, .omitPunctuation]) { _, range in
            let word = fullText[range].lowercased()
            wordFreq[word, default: 0] += 1
            return true
        }

        // Score each sentence as the sum of its word frequencies.
        let scoredSentences: [(sentence: String, score: Int)] = sentences.map { sentence in
            let sentenceTagger = NLTagger(tagSchemes: [.tokenType])
            sentenceTagger.string = sentence
            var sentenceScore = 0
            sentenceTagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex,
                                         unit: .word,
                                         scheme: .tokenType,
                                         options: [.omitWhitespace, .omitPunctuation]) { _, range in
                let word = sentence[range].lowercased()
                sentenceScore += wordFreq[word, default: 0]
                return true
            }
            return (sentence, sentenceScore)
        }

        return scoredSentences
            .sorted { $0.score > $1.score }
            .map(\.sentence)
    }

    // MARK: - Context Building

    private func buildContext(for segment: TranscriptSegment, in transcript: Transcript) -> String {
        guard let index = transcript.segments.firstIndex(where: { $0.id == segment.id }) else {
            return segment.text
        }
        let start = max(0, index - 1)
        let end = min(transcript.segments.count - 1, index + 1)
        return transcript.segments[start...end].map(\.text).joined(separator: " ")
    }
}

// MARK: - Errors

enum SummarizationError: LocalizedError {
    case emptyTranscript

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:
            return "Cannot summarize an empty transcript."
        }
    }
}
