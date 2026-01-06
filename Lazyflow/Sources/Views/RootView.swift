import SwiftUI

/// Root view - shows UI immediately, no loading screen
struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasCompletedOnboarding = false

    init() {
        PersistenceController.log("📱 RootView.init started")
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                ContentView()
                    .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
                    .environmentObject(TaskService.shared)
                    .onAppear {
                        PersistenceController.log("📱 ContentView appeared")
                        WatchConnectivityService.shared.configure(with: TaskService.shared)
                        PersistenceController.shared.createDefaultListsIfNeeded()
                    }
            } else {
                OnboardingView()
                    .onAppear {
                        PersistenceController.log("📱 OnboardingView appeared")
                    }
            }
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
        .onAppear {
            PersistenceController.log("📱 RootView appeared")
        }
    }
}

/// Loading view matching LaunchScreen - fullscreen gradient with spinner
/// Shows feedback immediately, fades out when content is ready
private struct LoadingView: View {
    // Hardcoded to avoid asset loading delay
    private static let launchBackgroundColor = Color(red: 0.078, green: 0.329, blue: 0.337)

    var body: some View {
        ZStack {
            Self.launchBackgroundColor
                .ignoresSafeArea()

            Image("LaunchLogo")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
                .offset(y: 100)
        }
    }
}

#Preview("Loading View") {
    LoadingView()
}

#Preview("Root View") {
    RootView()
}
