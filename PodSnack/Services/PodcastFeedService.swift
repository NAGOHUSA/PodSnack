import Foundation

/// Parses a podcast RSS 2.0 feed and returns structured `Episode` objects.
final class PodcastFeedService {

    // MARK: - Public API

    /// Fetch and parse a podcast RSS feed from the given URL string.
    func fetchEpisodes(from feedURLString: String) async throws -> [Episode] {
        guard let url = URL(string: feedURLString) else {
            throw FeedError.invalidURL(feedURLString)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FeedError.badServerResponse
        }

        return try parse(data: data)
    }

    // MARK: - RSS Parsing

    private func parse(data: Data) throws -> [Episode] {
        let parser = RSSParser()
        return try parser.parse(data: data)
    }
}

// MARK: - RSS Parser

private final class RSSParser: NSObject, XMLParserDelegate {

    private var episodes: [Episode] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var currentDuration = ""
    private var currentEnclosureURL = ""
    private var isInsideItem = false
    private var parseError: Error?

    func parse(data: Data) throws -> [Episode] {
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.parse()

        if let error = parseError {
            throw error
        }
        return episodes
    }

    // MARK: XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName

        if elementName == "item" {
            isInsideItem = true
            // Reset accumulators for the next item.
            currentTitle = ""
            currentDescription = ""
            currentPubDate = ""
            currentDuration = ""
            currentEnclosureURL = ""
        }

        if isInsideItem, elementName == "enclosure" {
            currentEnclosureURL = attributeDict["url"] ?? ""
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        guard isInsideItem else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        switch currentElement {
        case "title":       currentTitle += trimmed
        case "description": currentDescription += trimmed
        case "pubDate":     currentPubDate += trimmed
        case "itunes:duration": currentDuration += trimmed
        default: break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item" {
            isInsideItem = false

            let date = parseDate(currentPubDate) ?? Date()
            let duration = parseDuration(currentDuration)

            let episode = Episode(
                title: currentTitle.isEmpty ? "Untitled" : currentTitle,
                episodeDescription: currentDescription,
                publishDate: date,
                duration: duration,
                audioURL: currentEnclosureURL
            )
            episodes.append(episode)
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError
    }

    // MARK: - Helpers

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // RFC 2822 format used by most RSS feeds.
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: string)
    }

    /// Converts "HH:MM:SS", "MM:SS", or plain seconds strings to `TimeInterval`.
    private func parseDuration(_ string: String) -> TimeInterval {
        let parts = string.split(separator: ":").compactMap { Double($0) }
        switch parts.count {
        case 1: return parts[0]
        case 2: return parts[0] * 60 + parts[1]
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default: return 0
        }
    }
}

// MARK: - Errors

enum FeedError: LocalizedError {
    case invalidURL(String)
    case badServerResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return ""\(url)" is not a valid URL."
        case .badServerResponse:
            return "The server returned an unexpected response."
        }
    }
}
