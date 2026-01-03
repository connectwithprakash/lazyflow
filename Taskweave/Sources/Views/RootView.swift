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
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
                LoadingView(isFinished: !isLoading && persistenceController != nil)
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

            // Animate the transition
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.showContent = true
            }

            // Delay hiding the loading view for smooth overlap
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.isLoading = false
                }
            }
        }
    }
}

/// Branded loading view shown during Core Data initialization
/// Designed to seamlessly match LaunchScreen.storyboard and animate elegantly
private struct LoadingView: View {
    let isFinished: Bool

    @State private var phase: LoadingPhase = .initial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum LoadingPhase {
        case initial      // Logo only, matches launch screen exactly
        case revealing    // Logo moves up, text fades in
        case loading      // Full loading UI with spinner
    }

    // Logo size matches LaunchScreen.storyboard (120pt)
    private let logoSize: CGFloat = 120
    private let logoOffset: CGFloat = -40

    var body: some View {
        ZStack {
            Color("LaunchBackground")
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // App Logo - matches launch screen position initially
                Image("LaunchLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: logoSize, height: logoSize)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: .black.opacity(phase != .initial ? 0.15 : 0), radius: 20, y: 10)
                    .scaleEffect(phase == .initial ? 1.0 : (reduceMotion ? 1.0 : 1.02))
                    .offset(y: phase == .initial ? 0 : logoOffset)

                // App Name
                Text("Taskweave")
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                    .padding(.top, 24)
                    .opacity(phase == .initial ? 0 : 1)
                    .offset(y: phase == .initial ? 20 : 0)

                // Loading indicator section
                VStack(spacing: 16) {
                    Text("Loading your tasks...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    ProgressView()
                        .tint(Color("AccentColor"))
                        .scaleEffect(1.1)
                }
                .padding(.top, 32)
                .opacity(phase == .loading ? 1 : 0)
                .offset(y: phase == .loading ? 0 : 10)

                Spacer()
                Spacer()
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    private func startAnimationSequence() {
        // Phase 1 → 2: Reveal app name (after brief delay to match launch screen)
        let revealDelay = reduceMotion ? 0.1 : 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + revealDelay) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                phase = .revealing
            }
        }

        // Phase 2 → 3: Show loading indicator
        let loadingDelay = reduceMotion ? 0.3 : 0.7
        DispatchQueue.main.asyncAfter(deadline: .now() + loadingDelay) {
            withAnimation(.easeOut(duration: 0.4)) {
                phase = .loading
            }
        }
    }
}

#Preview("Loading View") {
    LoadingView(isFinished: false)
}

#Preview("Root View") {
    RootView()
}
