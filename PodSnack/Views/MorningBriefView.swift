import SwiftUI

/// "The Morning Brief" — a newspaper / Twitter-like daily feed of
/// summaries for all subscribed podcasts.
struct MorningBriefView: View {

    @EnvironmentObject private var repository: PodcastRepository
    @State private var showAddPodcast = false

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                if repository.podcasts.isEmpty {
                    emptyState
                } else if repository.todaysEpisodes.isEmpty {
                    noNewEpisodesState
                } else {
                    feedList
                }
            }
            .navigationTitle("Morning Brief")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddPodcast = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Refresh") {
                        Task { await repository.refreshAll() }
                    }
                    .disabled(repository.isRefreshing)
                }
            }
            .refreshable {
                await repository.refreshAll()
            }
            .sheet(isPresented: $showAddPodcast) {
                AddPodcastView()
            }
            .overlay {
                if repository.isRefreshing {
                    ProgressView("Refreshing…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(repository.errorMessage ?? "")
            }
        }
    }

    // MARK: Sub-views

    private var feedList: some View {
        List {
            Section {
                Text(todayHeader)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
            }
            ForEach(repository.todaysEpisodes, id: \.episode.id) { item in
                NavigationLink {
                    EpisodeDetailView(episode: item.episode, podcast: item.podcast)
                } label: {
                    EpisodeFeedCard(episode: item.episode, podcast: item.podcast)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Podcasts Yet")
                .font(.title2.bold())
            Text("Tap **+** to subscribe to a podcast and\nget your daily brief.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Add Podcast") { showAddPodcast = true }
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var noNewEpisodesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("You're all caught up!")
                .font(.title2.bold())
            Text("No new episodes in the last 24 hours.\nPull down to refresh.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: Helpers

    private var todayHeader: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date()).uppercased()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { repository.errorMessage != nil },
            set: { if !$0 { repository.errorMessage = nil } }
        )
    }
}

// MARK: - Episode Feed Card

struct EpisodeFeedCard: View {

    let episode: Episode
    let podcast: Podcast

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                PodcastArtworkView(urlString: podcast.artworkURL, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(podcast.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(timeAgo(episode.publishDate))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                if episode.isNew {
                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                }
            }

            // Title
            Text(episode.title)
                .font(.headline)
                .lineLimit(2)

            // Summary content
            if let summary = episode.summary {
                summaryView(summary)
            } else if episode.isTranscribed {
                Text("Generating summary…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            } else {
                Text(episode.episodeDescription.isEmpty
                     ? "Tap to view details."
                     : episode.episodeDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            // Duration tag
            Label(formattedDuration(episode.duration), systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func summaryView(_ summary: Summary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.shortParagraph)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            if !summary.bulletPoints.isEmpty {
                Divider()
                ForEach(summary.bulletPoints.prefix(3), id: \.self) { bullet in
                    Text(bullet)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins >= 60 {
            return "\(mins / 60)h \(mins % 60)m"
        }
        return "\(mins)m"
    }
}

// MARK: - Podcast Artwork

struct PodcastArtworkView: View {

    let urlString: String?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: urlString.flatMap(URL.init)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure, .empty:
                Image(systemName: "mic.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            @unknown default:
                Color.secondary
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2))
    }
}
