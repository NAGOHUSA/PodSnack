import XCTest
@testable import PodSnack

final class SummarizationServiceTests: XCTestCase {

    private var service: SummarizationService!

    override func setUp() async throws {
        try await super.setUp()
        service = await SummarizationService()
    }

    // MARK: - Summarization

    func testSummarizeProducesBulletPoints() async throws {
        let transcript = makeSampleTranscript()
        let summary = try await service.summarize(transcript: transcript)
        XCTAssertFalse(summary.bulletPoints.isEmpty, "Expected at least one bullet point")
    }

    func testSummarizeProducesKeyTakeaways() async throws {
        let transcript = makeSampleTranscript()
        let summary = try await service.summarize(transcript: transcript)
        XCTAssertFalse(summary.keyTakeaways.isEmpty, "Expected at least one key takeaway")
    }

    func testSummarizeProducesShortParagraph() async throws {
        let transcript = makeSampleTranscript()
        let summary = try await service.summarize(transcript: transcript)
        XCTAssertFalse(summary.shortParagraph.isEmpty, "Expected a non-empty short paragraph")
    }

    func testSummarizeThrowsOnEmptyTranscript() async throws {
        let emptyTranscript = Transcript(segments: [])
        do {
            _ = try await service.summarize(transcript: emptyTranscript)
            XCTFail("Expected error to be thrown for empty transcript")
        } catch SummarizationError.emptyTranscript {
            // Pass
        }
    }

    // MARK: - Keyword Matching

    func testKeywordMatchFoundInTranscript() async throws {
        let transcript = makeSampleTranscript(text: "The Federal Reserve raised interest rates by 25 basis points.")
        let summary = try await service.summarize(transcript: transcript, keywords: ["interest rates"])
        XCTAssertFalse(summary.keywordMatches.isEmpty, "Expected keyword match for 'interest rates'")
        XCTAssertEqual(summary.keywordMatches.first?.keyword, "interest rates")
    }

    func testNoKeywordMatchWhenKeywordAbsent() async throws {
        let transcript = makeSampleTranscript(text: "Today we discuss the latest trends in renewable energy.")
        let summary = try await service.summarize(transcript: transcript, keywords: ["bitcoin"])
        XCTAssertTrue(summary.keywordMatches.isEmpty, "Expected no keyword match for 'bitcoin'")
    }

    func testMultipleKeywordsMatched() async throws {
        let transcript = makeSampleTranscript(
            text: "Bitcoin surged 10% as Tesla announced a new electric vehicle model."
        )
        let summary = try await service.summarize(
            transcript: transcript,
            keywords: ["bitcoin", "tesla", "electric vehicle"]
        )
        XCTAssertEqual(summary.keywordMatches.count, 3, "Expected 3 keyword matches")
    }

    func testDuplicateKeywordsDeduplicatedToFirstOccurrence() async throws {
        let segments = [
            TranscriptSegment(text: "Apple released a new iPhone.", startTime: 0, endTime: 5, confidence: 1),
            TranscriptSegment(text: "The Apple Watch also got an update.", startTime: 5, endTime: 10, confidence: 1),
        ]
        let transcript = Transcript(segments: segments)
        let summary = try await service.summarize(transcript: transcript, keywords: ["apple"])
        // De-duplication: only the first occurrence of "apple" should be returned.
        let appleMatches = summary.keywordMatches.filter { $0.keyword == "apple" }
        XCTAssertEqual(appleMatches.count, 1, "Expected de-duplicated keyword match")
    }

    // MARK: - Helpers

    private func makeSampleTranscript(
        text: String = "Artificial intelligence is transforming the tech industry. Companies are investing heavily in AI research. The implications for society are profound."
    ) -> Transcript {
        let words = text.components(separatedBy: ". ").filter { !$0.isEmpty }
        var segments: [TranscriptSegment] = []
        var time: TimeInterval = 0
        for sentence in words {
            let duration = TimeInterval(sentence.count) * 0.05
            segments.append(
                TranscriptSegment(text: sentence, startTime: time, endTime: time + duration, confidence: 0.95)
            )
            time += duration
        }
        return Transcript(segments: segments)
    }
}
