import Foundation
import SwiftData

/// A single podcast episode.
@Model
final class Episode {
    var id: UUID
    var title: String
    var episodeDescription: String
    var publishDate: Date
    var duration: TimeInterval
    var audioURL: String
    var isNew: Bool
    var isTranscribed: Bool
    var isSummarized: Bool

    // Stored as JSON-encoded Data so SwiftData can persist the arrays.
    var transcriptData: Data?
    var summaryData: Data?
    var highlightsData: Data?

    @Relationship(inverse: \Podcast.episodes)
    var podcast: Podcast?

    // MARK: Computed helpers

    var transcript: Transcript? {
        get {
            guard let data = transcriptData else { return nil }
            return try? JSONDecoder().decode(Transcript.self, from: data)
        }
        set {
            transcriptData = try? JSONEncoder().encode(newValue)
            isTranscribed = newValue != nil
        }
    }

    var summary: Summary? {
        get {
            guard let data = summaryData else { return nil }
            return try? JSONDecoder().decode(Summary.self, from: data)
        }
        set {
            summaryData = try? JSONEncoder().encode(newValue)
            isSummarized = newValue != nil
        }
    }

    var highlights: [Highlight] {
        get {
            guard let data = highlightsData else { return [] }
            return (try? JSONDecoder().decode([Highlight].self, from: data)) ?? []
        }
        set {
            highlightsData = try? JSONEncoder().encode(newValue)
        }
    }

    init(
        title: String,
        episodeDescription: String,
        publishDate: Date,
        duration: TimeInterval,
        audioURL: String
    ) {
        self.id = UUID()
        self.title = title
        self.episodeDescription = episodeDescription
        self.publishDate = publishDate
        self.duration = duration
        self.audioURL = audioURL
        self.isNew = true
        self.isTranscribed = false
        self.isSummarized = false
    }
}

// MARK: - Supporting value types

/// A single timed segment of speech.
struct TranscriptSegment: Codable, Identifiable {
    var id: UUID = UUID()
    let text: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let confidence: Float
}

/// The full on-device transcription of an episode.
struct Transcript: Codable {
    let segments: [TranscriptSegment]
    let language: String
    let createdAt: Date

    var fullText: String {
        segments.map(\.text).joined(separator: " ")
    }

    init(segments: [TranscriptSegment], language: String = "en-US") {
        self.segments = segments
        self.language = language
        self.createdAt = Date()
    }
}

/// A 30-second highlight clip pulled from an episode.
struct Highlight: Codable, Identifiable {
    var id: UUID = UUID()
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let type: HighlightType

    enum HighlightType: String, Codable {
        case keyMoment, quote, statistic
    }
}

/// An AI-generated summary of an episode.
struct Summary: Codable {
    let bulletPoints: [String]
    let keyTakeaways: [String]
    let shortParagraph: String
    var keywordMatches: [KeywordMatch]
    let createdAt: Date

    init(
        bulletPoints: [String],
        keyTakeaways: [String],
        shortParagraph: String,
        keywordMatches: [KeywordMatch] = []
    ) {
        self.bulletPoints = bulletPoints
        self.keyTakeaways = keyTakeaways
        self.shortParagraph = shortParagraph
        self.keywordMatches = keywordMatches
        self.createdAt = Date()
    }
}

/// A user-defined keyword found inside an episode.
struct KeywordMatch: Codable, Identifiable {
    var id: UUID = UUID()
    let keyword: String
    /// Two-sentence context around the keyword.
    let context: String
    /// Timestamp (seconds) where the keyword first appears.
    let timestamp: TimeInterval
}
