import Foundation

/// Extracts ~30-second highlight clips from a full episode transcript.
///
/// Highlights are the highest-scoring segments (by sentence importance)
/// that are capped at 30 seconds each — surfaced in the Skim View.
final class HighlightService {

    // MARK: - Configuration

    /// Maximum duration of a single highlight (seconds).
    static let maxHighlightDuration: TimeInterval = 30

    // MARK: - Public API

    /// Extract up to `maxCount` highlights from a transcript.
    func extractHighlights(from transcript: Transcript, maxCount: Int = 10) -> [Highlight] {
        guard !transcript.segments.isEmpty else { return [] }

        // Group consecutive segments into clips ≤ maxHighlightDuration seconds.
        let clips = buildClips(from: transcript.segments)

        // Score each clip by the sum of word-frequency scores in its text.
        let wordFreq = wordFrequency(in: transcript.fullText)
        let scored = clips.map { clip -> (clip: SegmentClip, score: Double) in
            let score = scoreText(clip.text, wordFreq: wordFreq)
            return (clip, score)
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(maxCount)
            .map { item in
                Highlight(
                    startTime: item.clip.startTime,
                    endTime: item.clip.endTime,
                    text: item.clip.text,
                    type: classifyHighlight(item.clip.text)
                )
            }
    }

    // MARK: - Private

    private struct SegmentClip {
        var startTime: TimeInterval
        var endTime: TimeInterval
        var text: String
    }

    private func buildClips(from segments: [TranscriptSegment]) -> [SegmentClip] {
        var clips: [SegmentClip] = []
        var current: SegmentClip?

        for segment in segments {
            if var c = current {
                if segment.endTime - c.startTime <= Self.maxHighlightDuration {
                    // Extend the current clip.
                    c.endTime = segment.endTime
                    c.text += " " + segment.text
                    current = c
                } else {
                    // Save and start a new clip.
                    clips.append(c)
                    current = SegmentClip(
                        startTime: segment.startTime,
                        endTime: segment.endTime,
                        text: segment.text
                    )
                }
            } else {
                current = SegmentClip(
                    startTime: segment.startTime,
                    endTime: segment.endTime,
                    text: segment.text
                )
            }
        }

        if let last = current {
            clips.append(last)
        }

        return clips
    }

    private func wordFrequency(in text: String) -> [String: Int] {
        var freq: [String: Int] = [:]
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        for word in words where !word.isEmpty {
            freq[word, default: 0] += 1
        }
        return freq
    }

    private func scoreText(_ text: String, wordFreq: [String: Int]) -> Double {
        let words = text.lowercased().components(separatedBy: .whitespacesAndNewlines)
        let total = words.reduce(0) { $0 + (wordFreq[$1] ?? 0) }
        return Double(total) / Double(max(words.count, 1))
    }

    /// Simple heuristic classification of a highlight clip.
    private func classifyHighlight(_ text: String) -> Highlight.HighlightType {
        let lower = text.lowercased()

        // Check for statistic-like patterns (numbers, percentages).
        let hasNumbers = text.range(
            of: #"\d+(\.\d+)?[%$]?"#,
            options: .regularExpression
        ) != nil

        // Check for quote indicators.
        let hasQuote = lower.contains("said") || lower.contains("\"") || lower.contains("says")

        if hasNumbers { return .statistic }
        if hasQuote   { return .quote }
        return .keyMoment
    }
}
