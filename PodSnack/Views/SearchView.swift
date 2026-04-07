import SwiftUI

/// Semantic search across all subscribed podcast transcripts.
/// Ask natural-language questions like "Which podcasts discussed AI regulation?"
struct SearchView: View {

    @EnvironmentObject private var repository: PodcastRepository
    @State private var query = ""
    @State private var results: [SemanticSearchService.SearchResult] = []
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            List {
                // Search results or placeholder
                if hasSearched && results.isEmpty {
                    noResultsView
                } else {
                    ForEach(results) { result in
                        NavigationLink {
                            EpisodeDetailView(
                                episode: result.episode,
                                podcast: result.podcast,
                                deepLinkTimestamp: result.matchingSegment?.startTime
                            )
                        } label: {
                            SearchResultRow(result: result)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Search My Podcasts")
            .searchable(text: $query, prompt: "e.g. "interest rate hike this week"")
            .onSubmit(of: .search) {
                performSearch()
            }
            .onChange(of: query) { _, newValue in
                if newValue.isEmpty {
                    results = []
                    hasSearched = false
                }
            }
            .overlay {
                if !hasSearched && query.isEmpty {
                    searchHint
                }
            }
        }
    }

    // MARK: - Search

    private func performSearch() {
        hasSearched = true
        results = repository.search(query: query)
    }

    // MARK: - Sub-views

    private var searchHint: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform.and.magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("Search Your Subscriptions")
                .font(.title2.bold())
            Text("Ask anything — PodSnack uses on-device semantic\nsearch to find the exact moment you're looking for.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    private var noResultsView: some View {
        ContentUnavailableView.search(text: query)
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {

    let result: SemanticSearchService.SearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Podcast + episode
            HStack(spacing: 8) {
                PodcastArtworkView(urlString: result.podcast.artworkURL, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.podcast.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(result.episode.title)
                        .font(.subheadline.bold())
                        .lineLimit(1)
                }
                Spacer()
                relevanceTag
            }

            // Matching excerpt
            if let segment = result.matchingSegment {
                Text(""…\(segment.text)…"")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)

                Label(
                    "Jump to \(formattedTimestamp(segment.startTime))",
                    systemImage: "arrow.up.right.circle"
                )
                .font(.caption)
                .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private var relevanceTag: some View {
        let pct = Int(result.score * 100)
        return Text("\(pct)% match")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tagBackground, in: Capsule())
            .foregroundStyle(tagForeground)
    }

    private var tagBackground: Color {
        result.score > 0.7 ? .green.opacity(0.15) :
        result.score > 0.4 ? .yellow.opacity(0.15) : .secondary.opacity(0.1)
    }

    private var tagForeground: Color {
        result.score > 0.7 ? .green :
        result.score > 0.4 ? .yellow : .secondary
    }

    private func formattedTimestamp(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
