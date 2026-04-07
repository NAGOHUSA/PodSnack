import SwiftUI

/// Root tab container.
struct ContentView: View {

    @EnvironmentObject private var repository: PodcastRepository

    var body: some View {
        TabView {
            MorningBriefView()
                .tabItem {
                    Label("Morning Brief", systemImage: "newspaper.fill")
                }

            SkimView()
                .tabItem {
                    Label("Skim", systemImage: "play.rectangle.fill")
                }

            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            SubscriptionsView()
                .tabItem {
                    Label("Podcasts", systemImage: "mic.fill")
                }
        }
        .tint(.accentColor)
    }
}
