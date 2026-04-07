import Foundation
import NaturalLanguage

/// Semantic search across all transcribed episodes in the user's subscriptions.
///
/// Uses `NLEmbedding` (on-device word embeddings) to rank episodes by
/// cosine similarity to the user's natural-language query.
final class SemanticSearchService {

    // MARK: - Results

    struct SearchResult: Identifiable {
        let id: UUID
        let episode: Episode
        let podcast: Podcast
        /// The transcript segment that best matches the query.
        let matchingSegment: TranscriptSegment?
        /// Similarity score in [0, 1]; higher = more relevant.
        let score: Double
    }

    // MARK: - Public API

    /// Search all episodes for those relevant to `query`.
    /// - Parameters:
    ///   - query: Natural-language search string, e.g. "interest rate hike".
    ///   - podcasts: All subscribed podcasts (with episodes & transcripts loaded).
    ///   - limit: Maximum number of results to return.
    func search(
        query: String,
        in podcasts: [Podcast],
        limit: Int = 20
    ) -> [SearchResult] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }

        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else {
            // Fallback: simple keyword search when embeddings are unavailable.
            return keywordFallback(query: query, in: podcasts, limit: limit)
        }

        let queryVector = sentenceVector(for: query, embedding: embedding)

        var results: [SearchResult] = []

        for podcast in podcasts {
            for episode in podcast.episodes {
                guard let transcript = episode.transcript else { continue }

                // Score each segment and keep the best one per episode.
                var bestSegment: TranscriptSegment?
                var bestScore: Double = -1

                for segment in transcript.segments {
                    let segVector = sentenceVector(for: segment.text, embedding: embedding)
                    let similarity = cosineSimilarity(queryVector, segVector)
                    if similarity > bestScore {
                        bestScore = similarity
                        bestSegment = segment
                    }
                }

                if bestScore > 0.3 {
                    results.append(
                        SearchResult(
                            id: episode.id,
                            episode: episode,
                            podcast: podcast,
                            matchingSegment: bestSegment,
                            score: bestScore
                        )
                    )
                }
            }
        }

        return results
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Vector Helpers

    private func sentenceVector(
        for text: String,
        embedding: NLEmbedding
    ) -> [Double] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var vectors: [[Double]] = []

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range])
            if let vector = embedding.vector(for: word) {
                vectors.append(vector)
            }
            return true
        }

        guard !vectors.isEmpty else { return [] }
        let dimension = vectors[0].count
        var sum = [Double](repeating: 0, count: dimension)
        for v in vectors {
            for i in 0..<dimension { sum[i] += v[i] }
        }
        let count = Double(vectors.count)
        return sum.map { $0 / count }
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        let dot = zip(a, b).reduce(0) { $0 + $1.0 * $1.1 }
        let normA = sqrt(a.reduce(0) { $0 + $1 * $1 })
        let normB = sqrt(b.reduce(0) { $0 + $1 * $1 })
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA * normB)
    }

    // MARK: - Keyword Fallback

    private func keywordFallback(
        query: String,
        in podcasts: [Podcast],
        limit: Int
    ) -> [SearchResult] {
        let queryWords = query
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }

        var results: [SearchResult] = []

        for podcast in podcasts {
            for episode in podcast.episodes {
                guard let transcript = episode.transcript else { continue }

                var bestSegment: TranscriptSegment?
                var bestMatchCount = 0

                for segment in transcript.segments {
                    let lowerText = segment.text.lowercased()
                    let matches = queryWords.filter { lowerText.contains($0) }.count
                    if matches > bestMatchCount {
                        bestMatchCount = matches
                        bestSegment = segment
                    }
                }

                let score = Double(bestMatchCount) / Double(max(queryWords.count, 1))
                if bestMatchCount > 0 {
                    results.append(
                        SearchResult(
                            id: episode.id,
                            episode: episode,
                            podcast: podcast,
                            matchingSegment: bestSegment,
                            score: score
                        )
                    )
                }
            }
        }

        return results
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }
}
