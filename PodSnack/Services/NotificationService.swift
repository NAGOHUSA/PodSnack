import Foundation
import UserNotifications

/// Sends high-priority Smart Alert notifications when a user-defined
/// keyword is detected in a freshly summarised episode.
@MainActor
final class NotificationService: ObservableObject {

    static let categoryIdentifier = "KEYWORD_ALERT"
    static let jumpActionIdentifier = "JUMP_TO_MOMENT"

    // MARK: - Authorisation

    /// Request notification permission and register the "Jump to moment" action.
    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        if granted {
            registerNotificationCategory()
        }
    }

    // MARK: - Sending Alerts

    /// Fire a Smart Alert for each keyword match found in a summary.
    /// - Parameters:
    ///   - episode:  The episode that was just summarised.
    ///   - podcast:  The podcast the episode belongs to.
    ///   - matches:  Keyword matches to alert the user about.
    func sendSmartAlerts(
        for episode: Episode,
        podcast: Podcast,
        matches: [KeywordMatch]
    ) async {
        for match in matches {
            await scheduleAlert(for: match, episode: episode, podcast: podcast)
        }
    }

    // MARK: - Private

    private func scheduleAlert(
        for match: KeywordMatch,
        episode: Episode,
        podcast: Podcast
    ) async {
        let content = UNMutableNotificationContent()
        content.title = ""\(match.keyword.capitalized)" mentioned in \(podcast.title)"
        content.body = match.context
        content.sound = .defaultCritical
        content.categoryIdentifier = Self.categoryIdentifier

        // Encode deep-link info so the notification can jump to the exact timestamp.
        content.userInfo = [
            "episodeID": episode.id.uuidString,
            "timestamp": match.timestamp,
            "keyword": match.keyword
        ]

        let identifier = "smartalert-\(episode.id)-\(match.keyword)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil   // deliver immediately
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("⚠️ PodSnack: Could not schedule notification — \(error.localizedDescription)")
        }
    }

    private func registerNotificationCategory() {
        let jumpAction = UNNotificationAction(
            identifier: Self.jumpActionIdentifier,
            title: "Jump to this moment",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [jumpAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
}
