import SwiftUI

/// Manage podcast subscriptions and per-podcast Smart Alert keywords.
struct SubscriptionsView: View {

    @EnvironmentObject private var repository: PodcastRepository
    @State private var showAddPodcast = false
    @State private var podcastToEdit: Podcast?

    var body: some View {
        NavigationStack {
            List {
                if repository.podcasts.isEmpty {
                    emptyState
                } else {
                    ForEach(repository.podcasts) { podcast in
                        NavigationLink {
                            PodcastDetailView(podcast: podcast)
                        } label: {
                            PodcastRow(podcast: podcast)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                repository.unsubscribe(podcast)
                            } label: {
                                Label("Unsubscribe", systemImage: "trash")
                            }
                            Button {
                                podcastToEdit = podcast
                            } label: {
                                Label("Keywords", systemImage: "bell.badge")
                            }
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("My Podcasts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddPodcast = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPodcast) {
                AddPodcastView()
            }
            .sheet(item: $podcastToEdit) { podcast in
                KeywordsEditorView(podcast: podcast)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Subscriptions")
                .font(.headline)
            Text("Tap + to add your first podcast.")
                .foregroundStyle(.secondary)
            Button("Add Podcast") { showAddPodcast = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .listRowSeparator(.hidden)
    }
}

// MARK: - Podcast Row

struct PodcastRow: View {
    let podcast: Podcast

    var body: some View {
        HStack(spacing: 12) {
            PodcastArtworkView(urlString: podcast.artworkURL, size: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(podcast.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(podcast.author.isEmpty ? "Unknown author" : podcast.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Image(systemName: "mic")
                        .font(.caption2)
                    Text("\(podcast.episodes.count) episodes")
                        .font(.caption)
                    if !podcast.alertKeywords.isEmpty {
                        Image(systemName: "bell.badge.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("\(podcast.alertKeywords.count) keywords")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Podcast Sheet

struct AddPodcastView: View {

    @EnvironmentObject private var repository: PodcastRepository
    @Environment(\.dismiss) private var dismiss

    @State private var feedURL = ""
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("RSS Feed URL", text: $feedURL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Podcast RSS Feed")
                } footer: {
                    Text("Enter the RSS feed URL of the podcast you want to subscribe to.")
                }
            }
            .navigationTitle("Add Podcast")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Subscribe") {
                        subscribe()
                    }
                    .disabled(feedURL.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .overlay {
                if isLoading {
                    ProgressView("Subscribing…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func subscribe() {
        isLoading = true
        Task {
            await repository.subscribe(feedURLString: feedURL.trimmingCharacters(in: .whitespaces))
            isLoading = false
            dismiss()
        }
    }
}

// MARK: - Keywords Editor Sheet

struct KeywordsEditorView: View {

    @EnvironmentObject private var repository: PodcastRepository
    @Environment(\.dismiss) private var dismiss

    let podcast: Podcast

    @State private var keywordsText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $keywordsText)
                        .frame(minHeight: 120)
                } header: {
                    Text("Smart Alert Keywords")
                } footer: {
                    Text("Enter one keyword per line. PodSnack will send a high-priority alert when any of these topics are mentioned in a new episode.")
                }
            }
            .navigationTitle(podcast.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveKeywords()
                        dismiss()
                    }
                }
            }
            .onAppear {
                keywordsText = podcast.alertKeywords.joined(separator: "\n")
            }
        }
    }

    private func saveKeywords() {
        let keywords = keywordsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        repository.setKeywords(keywords, for: podcast)
    }
}

// MARK: - Podcast Detail

struct PodcastDetailView: View {

    @EnvironmentObject private var repository: PodcastRepository
    let podcast: Podcast

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    PodcastArtworkView(urlString: podcast.artworkURL, size: 80)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(podcast.title)
                            .font(.title3.bold())
                        Text(podcast.author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Section("Episodes") {
                ForEach(podcast.episodes.sorted { $0.publishDate > $1.publishDate }) { episode in
                    NavigationLink {
                        EpisodeDetailView(episode: episode, podcast: podcast)
                    } label: {
                        EpisodeListRow(episode: episode)
                    }
                }
            }
        }
        .navigationTitle(podcast.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button("Refresh") {
                    Task { await repository.refreshPodcast(podcast) }
                }
            }
        }
    }
}

// MARK: - Episode List Row

struct EpisodeListRow: View {
    let episode: Episode

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(episode.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                Spacer()
                if episode.isNew {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                }
            }
            HStack(spacing: 8) {
                Text(episode.publishDate, style: .date)
                Text("·")
                Label(formattedDuration(episode.duration), systemImage: "clock")
                if episode.isSummarized {
                    Text("·")
                    Label("Summarised", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func formattedDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        return mins >= 60 ? "\(mins / 60)h \(mins % 60)m" : "\(mins)m"
    }
}
