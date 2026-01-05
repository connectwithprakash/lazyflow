import SwiftUI

/// Root view that handles Core Data async initialization
/// Shows a loading view while Core Data loads, then transitions to ContentView
struct RootView: View {
    @State private var persistenceController: PersistenceController?
    @State private var taskService: TaskService?
    @State private var isLoading = true
    @State private var showContent = false
    @AppStorage("hasSeenOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        ZStack {
            if let controller = persistenceController,
               let service = taskService,
               showContent {
                if hasCompletedOnboarding {
                    ContentView()
                        .environment(\.managedObjectContext, controller.viewContext)
                        .environmentObject(service)
                        .transition(.opacity)
                        .onAppear {
                            WatchConnectivityService.shared.configure(with: service)
                        }
                        .task {
                            controller.createDefaultListsIfNeeded()
                        }
                } else {
                    OnboardingView()
                        .transition(.opacity)
                }
            }

            if isLoading {
                LoadingView()
                    .transition(.opacity)
            }
        }
        .task {
            await loadCoreData()
        }
    }

    private func loadCoreData() async {
        let controller = await PersistenceController.createAsync()
        await MainActor.run {
            self.persistenceController = controller
            self.taskService = TaskService(persistenceController: controller)

            withAnimation(.easeOut(duration: 0.2)) {
                self.showContent = true
                self.isLoading = false
            }
        }
    }
}

/// Loading view matching LaunchScreen - fullscreen gradient with spinner
/// Shows feedback immediately, fades out when content is ready
private struct LoadingView: View {
    var body: some View {
        ZStack {
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
