import SwiftUI

/// Root view - shows UI immediately, no loading screen
struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasCompletedOnboarding = false

    /// Check if running in UI test mode - bypasses onboarding
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("UI_TESTING")
    }

    var body: some View {
        Group {
            if hasCompletedOnboarding || isUITesting {
                ContentView()
                    .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
                    .environmentObject(TaskService.shared)
                    .onAppear {
                        WatchConnectivityService.shared.configure(with: TaskService.shared)
                        PersistenceController.shared.createDefaultListsIfNeeded()
                    }
            } else {
                OnboardingView()
            }
        }
        .background(Color.adaptiveBackground.ignoresSafeArea())
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
