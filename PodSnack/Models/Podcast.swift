import Foundation
import SwiftData

/// A podcast the user subscribes to.
@Model
final class Podcast {
    var id: UUID
    var title: String
    var author: String
    var podcastDescription: String
    var feedURL: String
    var artworkURL: String?
    var isSubscribed: Bool
    /// Keywords that trigger high-priority Smart Alert notifications.
    var alertKeywords: [String]

    @Relationship(deleteRule: .cascade)
    var episodes: [Episode]

    init(
        title: String,
        author: String,
        podcastDescription: String,
        feedURL: String,
        artworkURL: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.author = author
        self.podcastDescription = podcastDescription
        self.feedURL = feedURL
        self.artworkURL = artworkURL
        self.isSubscribed = true
        self.alertKeywords = []
        self.episodes = []
    }
}
