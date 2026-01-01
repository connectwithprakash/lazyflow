import SwiftUI

/// Root view that handles Core Data async initialization
/// Shows a loading view while Core Data loads, then transitions to ContentView
struct RootView: View {
    @State private var persistenceController: PersistenceController?
    @State private var taskService: TaskService?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let controller = persistenceController,
               let service = taskService,
               !isLoading {
                ContentView()
                    .environment(\.managedObjectContext, controller.viewContext)
                    .environmentObject(service)
                    .onAppear {
                        WatchConnectivityService.shared.configure(with: service)
                    }
                    .task {
                        controller.createDefaultListsIfNeeded()
                    }
            } else {
                LoadingView()
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
            // Now create TaskService after Core Data is ready
            self.taskService = TaskService(persistenceController: controller)
            // Small delay for smooth transition
            withAnimation(.easeOut(duration: 0.2)) {
                self.isLoading = false
            }
        }
    }
}

/// Branded loading view shown during Core Data initialization
private struct LoadingView: View {
    @State private var showProgress = false

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // App icon placeholder
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Color("AccentColor"))

                if showProgress {
                    ProgressView()
                        .tint(.white.opacity(0.7))
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            // Show progress indicator after a brief delay
            // to avoid flashing for fast loads
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    showProgress = true
                }
            }
        }
    }
}

#Preview {
    RootView()
}
