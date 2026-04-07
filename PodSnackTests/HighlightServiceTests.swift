import XCTest
@testable import PodSnack

final class HighlightServiceTests: XCTestCase {

    private var service: HighlightService!

    override func setUp() {
        super.setUp()
        service = HighlightService()
    }

    // MARK: - Basic Extraction

    func testHighlightsExtractedFromTranscript() {
        let transcript = makeLongTranscript()
        let highlights = service.extractHighlights(from: transcript)
        XCTAssertFalse(highlights.isEmpty, "Expected highlights to be extracted")
    }

    func testHighlightCountRespectMaxCount() {
        let transcript = makeLongTranscript(segmentCount: 50)
        let highlights = service.extractHighlights(from: transcript, maxCount: 5)
        XCTAssertLessThanOrEqual(highlights.count, 5, "Highlight count should not exceed maxCount")
    }

    func testEmptyTranscriptReturnsNoHighlights() {
        let transcript = Transcript(segments: [])
        let highlights = service.extractHighlights(from: transcript)
        XCTAssertTrue(highlights.isEmpty, "Empty transcript should produce no highlights")
    }

    // MARK: - Duration constraint

    func testHighlightDurationDoesNotExceedMax() {
        let transcript = makeLongTranscript()
        let highlights = service.extractHighlights(from: transcript)
        for highlight in highlights {
            let duration = highlight.endTime - highlight.startTime
            XCTAssertLessThanOrEqual(
                duration,
                HighlightService.maxHighlightDuration + 1, // +1 for single segment overshoot
                "Highlight duration should not greatly exceed max"
            )
        }
    }

    // MARK: - Type Classification

    func testStatisticTypeForSegmentWithNumbers() {
        let segments = [
            TranscriptSegment(text: "Revenue grew by 42% year over year.", startTime: 0, endTime: 5, confidence: 1),
        ]
        let transcript = Transcript(segments: segments)
        let highlights = service.extractHighlights(from: transcript)
        XCTAssertEqual(highlights.first?.type, .statistic, "Expected statistic type for number-rich text")
    }

    func testQuoteTypeForSegmentWithSaidKeyword() {
        let segments = [
            TranscriptSegment(text: "The CEO said that margins would improve next quarter.", startTime: 0, endTime: 5, confidence: 1),
        ]
        let transcript = Transcript(segments: segments)
        let highlights = service.extractHighlights(from: transcript)
        XCTAssertEqual(highlights.first?.type, .quote, "Expected quote type for 'said' keyword")
    }

    // MARK: - Helpers

    private func makeLongTranscript(segmentCount: Int = 20) -> Transcript {
        var segments: [TranscriptSegment] = []
        let sampleTexts = [
            "Artificial intelligence is rapidly advancing.",
            "Companies are investing billions in AI research.",
            "The stock market rose 5% after the announcement.",
            "The CEO said the company expects record revenue this quarter.",
            "Climate change remains a pressing global issue.",
            "Renewable energy investments reached $300 billion last year.",
            "Experts argue that policy changes are necessary.",
            "The Federal Reserve said it would hold rates steady.",
            "Consumer spending increased by 2.3% in Q1.",
            "Inflation expectations remain anchored near 2%.",
        ]
        var time: TimeInterval = 0
        for i in 0..<segmentCount {
            let text = sampleTexts[i % sampleTexts.count]
            let duration: TimeInterval = 8
            segments.append(
                TranscriptSegment(text: text, startTime: time, endTime: time + duration, confidence: 0.9)
            )
            time += duration
        }
        return Transcript(segments: segments)
    }
}
