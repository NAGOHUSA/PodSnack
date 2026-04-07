import SwiftUI
import AVKit

/// Scrollable feed of ~30-second "highlight" clips — like an Instagram
/// Reel but for podcast knowledge.
struct SkimView: View {

    @EnvironmentObject private var repository: PodcastRepository
    @State private var selectedIndex: Int = 0
    @State private var player: AVPlayer?
    @State private var isPlaying = false

    // Flat list of (highlight, episode, podcast) tuples.
    private var allHighlights: [(highlight: Highlight, episode: Episode, podcast: Podcast)] {
        repository.podcasts.flatMap { podcast in
            podcast.episodes.flatMap { episode in
                episode.highlights.map { (highlight: $0, episode: episode, podcast: podcast) }
            }
        }
        .sorted { $0.highlight.startTime < $1.highlight.startTime }
    }

    var body: some View {
        NavigationStack {
            Group {
                if allHighlights.isEmpty {
                    emptyState
                } else {
                    highlightFeed
                }
            }
            .navigationTitle("Skim")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Highlight Feed

    private var highlightFeed: some View {
        TabView(selection: $selectedIndex) {
            ForEach(allHighlights.indices, id: \.self) { index in
                let item = allHighlights[index]
                HighlightCard(
                    highlight: item.highlight,
                    episode: item.episode,
                    podcast: item.podcast,
                    onJump: { jumpToMoment(item.episode, at: item.highlight.startTime) }
                )
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
        .onChange(of: selectedIndex) { _, _ in
            stopPlayback()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No Highlights Yet")
                .font(.title2.bold())
            Text("Subscribe to podcasts and let PodSnack\nextract the best 30-second moments.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Playback

    private func stopPlayback() {
        player?.pause()
        player = nil
        isPlaying = false
    }

    private func jumpToMoment(_ episode: Episode, at timestamp: TimeInterval) {
        guard let url = URL(string: episode.audioURL) else { return }
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.seek(to: CMTime(seconds: timestamp, preferredTimescale: 600))
        newPlayer.play()
        player = newPlayer
        isPlaying = true
    }
}

// MARK: - Highlight Card

struct HighlightCard: View {

    let highlight: Highlight
    let episode: Episode
    let podcast: Podcast
    let onJump: () -> Void

    @State private var isExpanded = false

    var body: some View {
        ZStack {
            // Background gradient.
            LinearGradient(
                colors: [.indigo.opacity(0.8), .purple.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                // Type badge
                HStack {
                    Label(highlight.type.displayName, systemImage: highlight.type.systemImage)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                    Spacer()
                    Text(formattedTimestamp(highlight.startTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Quote text
                Text(""")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.white.opacity(0.3))
                    .offset(y: 30)

                Text(highlight.text)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(isExpanded ? nil : 6)
                    .onTapGesture { isExpanded.toggle() }

                Spacer()

                // Footer
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        PodcastArtworkView(urlString: podcast.artworkURL, size: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(episode.title)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text(podcast.title)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        Spacer()
                    }

                    NavigationLink {
                        EpisodeDetailView(episode: episode, podcast: podcast, deepLinkTimestamp: highlight.startTime)
                    } label: {
                        Label("Jump to this moment", systemImage: "arrow.up.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.white)
                    }
                    .simultaneousGesture(TapGesture().onEnded { onJump() })
                }
            }
            .padding()
        }
    }

    private func formattedTimestamp(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Highlight Type Helpers

extension Highlight.HighlightType {
    var displayName: String {
        switch self {
        case .keyMoment:  return "Key Moment"
        case .quote:      return "Quote"
        case .statistic:  return "Stat"
        }
    }

    var systemImage: String {
        switch self {
        case .keyMoment:  return "star.fill"
        case .quote:      return "quote.bubble.fill"
        case .statistic:  return "chart.bar.fill"
        }
    }
}
