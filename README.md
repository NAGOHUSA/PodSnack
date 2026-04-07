# PodSnack – The Morning Brief

> **AI-driven podcast summaries powered entirely by Apple Intelligence.**  
> Get a daily newspaper-style feed of your podcast subscriptions — no cloud fees, no privacy trade-offs.

---

## Overview

PodSnack ("The Morning Brief") transforms your podcast subscriptions from a wall of 2-hour audio files into a scannable daily brief. Every feature runs **on-device** using Apple's own Neural Engine and NLP frameworks — meaning zero cloud costs and complete user privacy.

| Feature | Apple Framework Used |
|---|---|
| On-device transcription | `Speech` (SFSpeechRecognizer) |
| AI summarization | `NaturalLanguage` (extractive) + Writing Tools API |
| Semantic search | `NLEmbedding` (word vectors) |
| Smart Alert notifications | `UserNotifications` |
| Data persistence | `SwiftData` |

---

## Features

### 📰 Morning Brief Feed
A Twitter/newspaper-style scrollable feed of today's new episodes from all your subscriptions. Each card shows:
- Episode artwork + podcast name
- Time since publication
- AI-generated short paragraph + bullet points
- Episode duration

### ⚡️ Skim View
A swipeable full-screen feed of 30-second "highlight" clips — the best moments from each episode, classified as **Key Moment**, **Quote**, or **Stat**. Each card has a "Jump to this moment" deep link.

### 🔍 Semantic Search
Ask natural-language questions like *"Which of my podcasts talked about the interest rate hike this week?"*  
Uses `NLEmbedding` cosine-similarity to rank episodes by semantic relevance and surface the exact matching segment with a timestamp deep link.

### 🔔 Smart Alerts
Set per-podcast keywords (e.g. "Bitcoin", "Apple Stock", "Climate Change"). When any keyword appears in a new episode, a high-priority notification is fired with a 2-sentence context summary. Tap **"Jump to this moment"** in the notification to open the exact timestamp.

### 🎙 Full Transcript + Deep Links
Every episode detail screen includes:
- **Summary tab** — overview paragraph, key takeaways, bullet points, and keyword match cards
- **Highlights tab** — ranked 30-second clips with jump buttons
- **Transcript tab** — word-level transcript with tappable timestamps that seek the audio player

---

## Architecture

```
PodSnack/
├── PodSnack.xcodeproj/
├── PodSnack/
│   ├── PodSnackApp.swift          # SwiftUI @main entry point + SwiftData setup
│   ├── ContentView.swift          # Root 4-tab container
│   ├── Models/
│   │   ├── Podcast.swift          # @Model: Podcast (SwiftData)
│   │   └── Episode.swift          # @Model: Episode + Transcript/Summary/Highlight value types
│   ├── Services/
│   │   ├── TranscriptionService.swift    # On-device SFSpeechRecognizer transcription
│   │   ├── SummarizationService.swift    # NL-based extractive summarization + keyword matching
│   │   ├── NotificationService.swift     # Smart Alert UNUserNotificationCenter integration
│   │   ├── PodcastFeedService.swift      # RSS 2.0 feed parser (XMLParserDelegate)
│   │   ├── SemanticSearchService.swift   # NLEmbedding cosine-similarity search
│   │   └── HighlightService.swift        # 30-second highlight extraction
│   ├── Repository/
│   │   └── PodcastRepository.swift       # Central coordinator: fetch → transcribe → summarize → notify
│   └── Views/
│       ├── MorningBriefView.swift         # Daily feed (newspaper style)
│       ├── SkimView.swift                 # Full-screen swipeable highlights
│       ├── SearchView.swift               # Semantic search UI
│       ├── EpisodeDetailView.swift        # Summary / Highlights / Transcript tabs + deep links
│       └── SubscriptionsView.swift        # Subscribe, manage keywords, view episodes
└── PodSnackTests/
    ├── SummarizationServiceTests.swift
    ├── HighlightServiceTests.swift
    ├── SemanticSearchServiceTests.swift
    └── PodcastFeedServiceTests.swift
```

---

## Requirements

| Requirement | Version |
|---|---|
| iOS | 18.0+ |
| Xcode | 16.0+ |
| Swift | 5.10+ |

> **Apple Intelligence** (on-device ML / Writing Tools) requires an iPhone 15 Pro or iPhone 16 / later running iOS 18 with Apple Intelligence enabled in Settings.

---

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/NAGOHUSA/PodSnack.git
   cd PodSnack
   ```

2. Open the project in Xcode:
   ```bash
   open PodSnack.xcodeproj
   ```

3. Select your development team in **Signing & Capabilities** for the `PodSnack` target.

4. Build & run on a physical device (iOS 18+) or the iOS 18 Simulator.

### Required Permissions

The app will request the following permissions at runtime:

| Permission | Usage |
|---|---|
| Speech Recognition | On-device transcription of episode audio |
| Microphone | Required by the Speech framework |
| Notifications | Smart Alert keyword notifications |

These are declared in `PodSnack/Resources/Info.plist`.

---

## Running the Tests

```bash
# In Xcode: ⌘U  (or Product → Test)
# Via xcodebuild:
xcodebuild test \
  -project PodSnack.xcodeproj \
  -scheme PodSnack \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

Test coverage includes:
- `SummarizationServiceTests` — bullet points, key takeaways, keyword matching, de-duplication
- `HighlightServiceTests` — extraction, duration constraints, type classification
- `SemanticSearchServiceTests` — relevance scoring, empty query handling, result limits
- `PodcastFeedServiceTests` — RSS parsing, duration format handling, URL validation

---

## The Business Case

1. **Near-zero costs** — All AI processing runs on the user's own Neural Engine (no OpenAI/Google API bills).
2. **Privacy first** — Audio and transcripts never leave the device.
3. **High perceived value** — Save listeners 10+ hours of audio per week for $4.99/month.
4. **FOMO solved** — Users subscribed to 50 podcasts but only listening to 2 now get a daily brief of everything they missed.

---

## Roadmap

- [ ] Writing Tools API integration (iOS 18 UIWritingToolsCoordinator) for richer AI summaries
- [ ] App Intents / Spotlight indexing for "Search My Podcasts" from the home screen
- [ ] Widget showing today's top 3 highlights
- [ ] Background episode processing via `BackgroundTasks` framework
- [ ] iCloud sync of summaries across devices
- [ ] CarPlay support for audio playback of highlights

---

## License

MIT 
