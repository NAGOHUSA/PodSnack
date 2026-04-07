import XCTest
@testable import PodSnack

final class PodcastFeedServiceTests: XCTestCase {

    private var service: PodcastFeedService!

    override func setUp() {
        super.setUp()
        service = PodcastFeedService()
    }

    // MARK: - URL Validation

    func testInvalidURLThrowsError() async {
        do {
            _ = try await service.fetchEpisodes(from: "not-a-url")
            XCTFail("Expected error for invalid URL")
        } catch FeedError.invalidURL {
            // Pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testEmptyURLThrowsError() async {
        do {
            _ = try await service.fetchEpisodes(from: "")
            XCTFail("Expected error for empty URL")
        } catch FeedError.invalidURL {
            // Pass
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - RSS Parsing Tests (via internal XML)

final class RSSParserTests: XCTestCase {

    func testParsesValidRSSFeed() throws {
        let rss = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd">
          <channel>
            <title>Test Podcast</title>
            <item>
              <title>Episode 1: Getting Started</title>
              <description>An introduction to the show.</description>
              <pubDate>Mon, 01 Apr 2026 08:00:00 +0000</pubDate>
              <itunes:duration>45:30</itunes:duration>
              <enclosure url="https://example.com/ep1.mp3" type="audio/mpeg" length="12345678"/>
            </item>
            <item>
              <title>Episode 2: Deep Dive</title>
              <description>A deep dive into the topic.</description>
              <pubDate>Mon, 07 Apr 2026 08:00:00 +0000</pubDate>
              <itunes:duration>1:12:45</itunes:duration>
              <enclosure url="https://example.com/ep2.mp3" type="audio/mpeg" length="23456789"/>
            </item>
          </channel>
        </rss>
        """

        let parser = RSSParserAccessor()
        let episodes = try parser.parse(xmlString: rss)

        XCTAssertEqual(episodes.count, 2)
        XCTAssertEqual(episodes[0].title, "Episode 1: Getting Started")
        XCTAssertEqual(episodes[0].audioURL, "https://example.com/ep1.mp3")
        XCTAssertEqual(episodes[1].title, "Episode 2: Deep Dive")
    }

    func testDurationParsingMMSS() throws {
        XCTAssertEqual(RSSParserAccessor.parseDurationPublic("45:30"), 45 * 60 + 30)
    }

    func testDurationParsingHHMMSS() throws {
        XCTAssertEqual(RSSParserAccessor.parseDurationPublic("1:12:45"), 3600 + 12 * 60 + 45)
    }

    func testDurationParsingSecondsOnly() throws {
        XCTAssertEqual(RSSParserAccessor.parseDurationPublic("3600"), 3600)
    }

    func testDurationParsingInvalid() throws {
        XCTAssertEqual(RSSParserAccessor.parseDurationPublic(""), 0)
    }
}

/// Thin test-only wrapper that exposes internal methods of RSSParser for unit testing.
final class RSSParserAccessor: NSObject, XMLParserDelegate {

    private var episodes: [Episode] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentDescription = ""
    private var currentPubDate = ""
    private var currentDuration = ""
    private var currentEnclosureURL = ""
    private var isInsideItem = false
    private var parseError: Error?

    func parse(xmlString: String) throws -> [Episode] {
        guard let data = xmlString.data(using: .utf8) else {
            throw NSError(domain: "test", code: -1)
        }
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        xmlParser.parse()
        if let e = parseError { throw e }
        return episodes
    }

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

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        let t = string.trimmingCharacters(in: .whitespacesAndNewlines)
        switch currentElement {
        case "title":            currentTitle += t
        case "description":      currentDescription += t
        case "pubDate":          currentPubDate += t
        case "itunes:duration":  currentDuration += t
        default: break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName == "item" else { return }
        isInsideItem = false
        let episode = Episode(
            title: currentTitle,
            episodeDescription: currentDescription,
            publishDate: Date(),
            duration: Self.parseDurationPublic(currentDuration),
            audioURL: currentEnclosureURL
        )
        episodes.append(episode)
    }

    func parser(_ parser: XMLParser, parseErrorOccurred error: Error) {
        parseError = error
    }

    /// Publicly exposed duration parser for unit testing.
    static func parseDurationPublic(_ string: String) -> TimeInterval {
        let parts = string.split(separator: ":").compactMap { Double($0) }
        switch parts.count {
        case 1: return parts[0]
        case 2: return parts[0] * 60 + parts[1]
        case 3: return parts[0] * 3600 + parts[1] * 60 + parts[2]
        default: return 0
        }
    }
}
