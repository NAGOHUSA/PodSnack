import Foundation
import SwiftData

/// Central coordinator that processes new episodes:
/// transcribe → summarize → extract highlights → notify.
@MainActor
final class PodcastRepository: ObservableObject {

    // MARK: - Dependencies

    private let feedService = PodcastFeedService()
    private let transcriptionService: TranscriptionService
    private let summarizationService = SummarizationService()
    private let highlightService = HighlightService()
    let notificationService = NotificationService()
    let searchService = SemanticSearchService()

    // MARK: - Published State

    @Published var podcasts: [Podcast] = []
    @Published var isRefreshing = false
    @Published var errorMessage: String?

    // MARK: - SwiftData

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.transcriptionService = TranscriptionService()
        loadPodcasts()
    }

    // MARK: - Podcast Management

    /// Subscribe to a new podcast by RSS feed URL.
    func subscribe(feedURLString: String) async {
        guard !feedURLString.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        do {
            let episodes = try await feedService.fetchEpisodes(from: feedURLString)

            // Use the first episode's metadata to build the Podcast record.
            let podcast = Podcast(
                title: "Loading…",
                author: "",
                podcastDescription: "",
                feedURL: feedURLString
            )
            modelContext.insert(podcast)

            for episode in episodes {
                episode.podcast = podcast
                podcast.episodes.append(episode)
                modelContext.insert(episode)
            }

            try modelContext.save()
            loadPodcasts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unsubscribe(_ podcast: Podcast) {
        modelContext.delete(podcast)
        try? modelContext.save()
        loadPodcasts()
    }

    /// Update alert keywords for a podcast.
    func setKeywords(_ keywords: [String], for podcast: Podcast) {
        podcast.alertKeywords = keywords
        try? modelContext.save()
    }

    // MARK: - Refresh Feed

    /// Fetch new episodes for all subscribed podcasts and process them.
    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        for podcast in podcasts {
            await refreshPodcast(podcast)
        }
    }

    func refreshPodcast(_ podcast: Podcast) async {
        do {
            let fetched = try await feedService.fetchEpisodes(from: podcast.feedURL)
            let existingIDs = Set(podcast.episodes.map(\.audioURL))

            for episode in fetched where !existingIDs.contains(episode.audioURL) {
                episode.podcast = podcast
                podcast.episodes.append(episode)
                modelContext.insert(episode)
                await processEpisode(episode, podcast: podcast)
            }

            try? modelContext.save()
            loadPodcasts()
        } catch {
            errorMessage = "Could not refresh \(podcast.title): \(error.localizedDescription)"
        }
    }

    // MARK: - Episode Processing Pipeline

    func processEpisode(_ episode: Episode, podcast: Podcast) async {
        guard let audioURL = URL(string: episode.audioURL), !episode.isTranscribed else { return }

        do {
            // 1. Transcribe on-device.
            let transcript = try await transcriptionService.transcribe(audioURL: audioURL)
            episode.transcript = transcript

            // 2. Summarize with Apple Intelligence (NL-based on-device).
            let summary = try await summarizationService.summarize(
                transcript: transcript,
                keywords: podcast.alertKeywords
            )
            episode.summary = summary

            // 3. Extract 30-second highlights.
            episode.highlights = highlightService.extractHighlights(from: transcript)

            try? modelContext.save()

            // 4. Fire Smart Alerts for any matched keywords.
            if !summary.keywordMatches.isEmpty {
                await notificationService.sendSmartAlerts(
                    for: episode,
                    podcast: podcast,
                    matches: summary.keywordMatches
                )
            }
        } catch {
            errorMessage = "Processing failed for "\(episode.title)": \(error.localizedDescription)"
        }
    }

    // MARK: - Search

    func search(query: String) -> [SemanticSearchService.SearchResult] {
        searchService.search(query: query, in: podcasts)
    }

    // MARK: - Today's Feed

    /// Episodes published in the last 24 hours, sorted newest first.
    var todaysEpisodes: [(episode: Episode, podcast: Podcast)] {
        let cutoff = Date().addingTimeInterval(-86_400)
        var items: [(Episode, Podcast)] = []
        for podcast in podcasts {
            for episode in podcast.episodes where episode.publishDate >= cutoff {
                items.append((episode, podcast))
            }
        }
        return items.sorted { $0.0.publishDate > $1.0.publishDate }
    }

    // MARK: - Private

    private func loadPodcasts() {
        let descriptor = FetchDescriptor<Podcast>(
            sortBy: [SortDescriptor(\.title)]
        )
        podcasts = (try? modelContext.fetch(descriptor)) ?? []
    }
}
