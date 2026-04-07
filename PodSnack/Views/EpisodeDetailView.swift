import SwiftUI
import AVKit

/// Full episode detail with transcript, summary, and deep-link playback.
struct EpisodeDetailView: View {

    let episode: Episode
    let podcast: Podcast
    /// When provided, the player will seek to this timestamp on appear.
    var deepLinkTimestamp: TimeInterval? = nil

    @EnvironmentObject private var repository: PodcastRepository
    @State private var player: AVPlayer?
    @State private var selectedTab: DetailTab = .summary
    @State private var showTranscript = false

    enum DetailTab: String, CaseIterable {
        case summary    = "Summary"
        case highlights = "Highlights"
        case transcript = "Transcript"
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerSection
                Divider().padding(.horizontal)
                tabBar
                tabContent
            }
        }
        .navigationTitle(episode.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !episode.isSummarized {
                    Button("Process") {
                        Task { await repository.processEpisode(episode, podcast: podcast) }
                    }
                }
            }
        }
        .onAppear(perform: setupPlayer)
        .onDisappear { player?.pause() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                PodcastArtworkView(urlString: podcast.artworkURL, size: 72)
                    .shadow(radius: 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(episode.title)
                        .font(.headline)
                        .lineLimit(3)
                    Text(podcast.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack {
                        Label(formattedDuration(episode.duration), systemImage: "clock")
                        Text("·")
                        Text(episode.publishDate, style: .date)
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }

            // Audio player
            if let p = player {
                VideoPlayer(player: p)
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Button {
                    setupPlayer()
                    player?.play()
                } label: {
                    Label("Play Episode", systemImage: "play.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(.white)
                }
            }

            // Processing status
            if !episode.isTranscribed {
                processingBanner
            }
        }
        .padding()
    }

    private var processingBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Transcribing & summarising on-device…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                                ? Color.accentColor.opacity(0.1)
                                : Color.clear
                        )
                }
                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
            }
        }
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .summary:
            summaryTab
        case .highlights:
            highlightsTab
        case .transcript:
            transcriptTab
        }
    }

    // MARK: Summary Tab

    private var summaryTab: some View {
        Group {
            if let summary = episode.summary {
                VStack(alignment: .leading, spacing: 20) {
                    // Short paragraph
                    sectionBlock(title: "Overview", icon: "text.alignleft") {
                        Text(summary.shortParagraph)
                            .font(.body)
                    }

                    // Key takeaways
                    if !summary.keyTakeaways.isEmpty {
                        sectionBlock(title: "Key Takeaways", icon: "lightbulb.fill") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(summary.keyTakeaways, id: \.self) { takeaway in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.caption)
                                            .padding(.top, 2)
                                        Text(takeaway)
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }
                    }

                    // Bullet points
                    if !summary.bulletPoints.isEmpty {
                        sectionBlock(title: "Bullet Points", icon: "list.bullet") {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(summary.bulletPoints, id: \.self) { bullet in
                                    Text(bullet)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }

                    // Keyword matches
                    if !summary.keywordMatches.isEmpty {
                        sectionBlock(title: "Keyword Alerts", icon: "bell.badge.fill") {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(summary.keywordMatches) { match in
                                    keywordMatchRow(match)
                                }
                            }
                        }
                    }
                }
                .padding()
            } else {
                noSummaryPlaceholder
            }
        }
    }

    private var noSummaryPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Summary Not Ready")
                .font(.headline)
            Text("Tap **Process** in the top right to transcribe\nand summarise this episode on-device.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }

    private func keywordMatchRow(_ match: KeywordMatch) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(match.keyword.capitalized)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                    .foregroundStyle(.orange)
                Spacer()
                // Deep-link button
                Button {
                    seekTo(match.timestamp)
                } label: {
                    Label(formattedTimestamp(match.timestamp), systemImage: "arrow.up.right.circle")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            Text(match.context)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(10)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Highlights Tab

    private var highlightsTab: some View {
        Group {
            if episode.highlights.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Highlights")
                        .font(.headline)
                    Text("Process the episode to extract highlights.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(episode.highlights) { highlight in
                        highlightRow(highlight)
                    }
                }
                .padding()
            }
        }
    }

    private func highlightRow(_ highlight: Highlight) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(highlight.type.displayName, systemImage: highlight.type.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    seekTo(highlight.startTime)
                } label: {
                    Label("Jump to \(formattedTimestamp(highlight.startTime))",
                          systemImage: "arrow.up.right.circle.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                        .foregroundStyle(.accentColor)
                }
            }
            Text(highlight.text)
                .font(.subheadline)
                .lineLimit(4)
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Transcript Tab

    private var transcriptTab: some View {
        Group {
            if let transcript = episode.transcript {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(transcript.segments) { segment in
                        transcriptSegmentRow(segment)
                    }
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Transcript")
                        .font(.headline)
                    Text("Process the episode to generate an on-device transcript.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            }
        }
    }

    private func transcriptSegmentRow(_ segment: TranscriptSegment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                seekTo(segment.startTime)
            } label: {
                Text(formattedTimestamp(segment.startTime))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.blue)
                    .frame(width: 44, alignment: .leading)
            }
            Text(segment.text)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Helpers

    private func setupPlayer() {
        guard let url = URL(string: episode.audioURL) else { return }
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        if let ts = deepLinkTimestamp {
            newPlayer.seek(to: CMTime(seconds: ts, preferredTimescale: 600))
        }
        player = newPlayer
    }

    private func seekTo(_ timestamp: TimeInterval) {
        if player == nil { setupPlayer() }
        player?.seek(to: CMTime(seconds: timestamp, preferredTimescale: 600))
        player?.play()
    }

    private func sectionBlock<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        return mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins)m"
    }

    private func formattedTimestamp(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
