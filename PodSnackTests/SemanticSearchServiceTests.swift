import XCTest
@testable import PodSnack

final class SemanticSearchServiceTests: XCTestCase {

    private var searchService: SemanticSearchService!

    override func setUp() {
        super.setUp()
        searchService = SemanticSearchService()
    }

    // MARK: - Basic Search

    func testSearchReturnsResultsForMatchingQuery() {
        let podcasts = makeSamplePodcasts()
        let results = searchService.search(query: "interest rate", in: podcasts)
        XCTAssertFalse(results.isEmpty, "Expected at least one result for 'interest rate'")
    }

    func testSearchReturnsEmptyForEmptyQuery() {
        let podcasts = makeSamplePodcasts()
        let results = searchService.search(query: "", in: podcasts)
        XCTAssertTrue(results.isEmpty, "Empty query should return no results")
    }

    func testSearchReturnsEmptyForWhitespaceQuery() {
        let podcasts = makeSamplePodcasts()
        let results = searchService.search(query: "   ", in: podcasts)
        XCTAssertTrue(results.isEmpty, "Whitespace-only query should return no results")
    }

    func testSearchReturnsEmptyForPodcastsWithoutTranscripts() {
        let podcast = Podcast(
            title: "Tech Podcast",
            author: "Author",
            podcastDescription: "",
            feedURL: "https://example.com/feed.xml"
        )
        let episode = Episode(
            title: "Episode 1",
            episodeDescription: "",
            publishDate: Date(),
            duration: 3600,
            audioURL: "https://example.com/ep1.mp3"
        )
        episode.podcast = podcast
        podcast.episodes.append(episode)
        // No transcript set.

        let results = searchService.search(query: "interest rate", in: [podcast])
        XCTAssertTrue(results.isEmpty, "Podcast without transcripts should return no search results")
    }

    func testSearchLimitRespected() {
        let podcasts = makeSamplePodcasts(episodeCount: 20)
        let results = searchService.search(query: "economy", in: podcasts, limit: 3)
        XCTAssertLessThanOrEqual(results.count, 3, "Search results should not exceed the limit")
    }

    func testSearchResultsAreSortedByScoreDescending() {
        let podcasts = makeSamplePodcasts()
        let results = searchService.search(query: "interest rate", in: podcasts)
        if results.count > 1 {
            for i in 0..<(results.count - 1) {
                XCTAssertGreaterThanOrEqual(
                    results[i].score,
                    results[i + 1].score,
                    "Results should be sorted by score descending"
                )
            }
        }
    }

    // MARK: - Helpers

    private func makeSamplePodcasts(episodeCount: Int = 3) -> [Podcast] {
        let podcast = Podcast(
            title: "The Economics Show",
            author: "Jane Smith",
            podcastDescription: "Weekly economics roundup",
            feedURL: "https://example.com/economics.xml"
        )

        let texts = [
            "The Federal Reserve raised interest rates for the third time this year.",
            "Inflation continues to exceed the central bank's 2% target.",
            "The economy added 250,000 jobs in the latest report.",
            "Consumer confidence fell amid concerns about the housing market.",
            "Oil prices surged following geopolitical tensions in the Middle East.",
            "Tech stocks rebounded after strong earnings from major companies.",
        ]

        for i in 0..<episodeCount {
            let episode = Episode(
                title: "Episode \(i + 1)",
                episodeDescription: "",
                publishDate: Date().addingTimeInterval(TimeInterval(-i * 86400)),
                duration: 3600,
                audioURL: "https://example.com/ep\(i + 1).mp3"
            )
            let text = texts[i % texts.count]
            episode.transcript = Transcript(
                segments: [TranscriptSegment(text: text, startTime: 0, endTime: 30, confidence: 0.95)]
            )
            episode.podcast = podcast
            podcast.episodes.append(episode)
        }

        return [podcast]
    }
}
