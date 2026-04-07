import SwiftUI
import SwiftData

@main
struct PodSnackApp: App {

    @StateObject private var repository: PodcastRepository

    private let modelContainer: ModelContainer

    init() {
        let schema = Schema([Podcast.self, Episode.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            modelContainer = container
            _repository = StateObject(
                wrappedValue: PodcastRepository(modelContext: container.mainContext)
            )
        } catch {
            fatalError("SwiftData container could not be created: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(repository)
                .modelContainer(modelContainer)
                .task {
                    // Request notification permission at launch.
                    try? await repository.notificationService.requestAuthorization()
                }
        }
    }
}
