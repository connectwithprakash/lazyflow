import SwiftUI
import EventKit
import UserNotifications

/// Onboarding tutorial carousel for first-time users
struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var calendarPermissionGranted = false
    @State private var notificationPermissionGranted = false

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "checkmark.circle.fill",
            title: "Welcome to Lazyflow",
            description: "Your calendar-first task manager that helps you get things done.",
            accentColor: Color.Lazyflow.accent
        ),
        OnboardingPage(
            icon: "calendar.badge.clock",
            title: "Calendar Integration",
            description: "Seamlessly schedule tasks as time blocks on your calendar. See your tasks alongside meetings.",
            accentColor: .blue
        ),
        OnboardingPage(
            icon: "sparkles",
            title: "AI-Powered Suggestions",
            description: "Get smart recommendations on what to do next based on your priorities and schedule.",
            accentColor: .purple
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
                    // Skip button
                    HStack {
                        Spacer()
                        if currentPage < pages.count {
                            Button("Skip") {
                                completeOnboarding()
                            }
                            .font(.subheadline)
                            .foregroundColor(Color.Lazyflow.textSecondary)
                            .padding()
                        }
                    }

                    Spacer()

                    // Content
                    GeometryReader { geometry in
                        TabView(selection: $currentPage) {
                            ForEach(0..<pages.count, id: \.self) { index in
                                OnboardingPageView(page: pages[index])
                                    .tag(index)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                            }

                            // Final page: Permissions
                            PermissionsPageView(
                                calendarGranted: $calendarPermissionGranted,
                                notificationsGranted: $notificationPermissionGranted
                            )
                            .tag(pages.count)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                    // NOTE: Don't add .animation() here - it conflicts with UIPageViewController's
                    // built-in swipe animations and causes stuttering/freezing

                    Spacer()

                    // Page indicator
                    HStack(spacing: 8) {
                        ForEach(0...pages.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentPage ? Color.Lazyflow.accent : Color.Lazyflow.textTertiary.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .animation(.easeInOut, value: currentPage)
                        }
                    }
                    .padding(.bottom, 24)

                    // Action button
                    Button {
                        if currentPage < pages.count {
                            withAnimation {
                                currentPage += 1
                            }
                        } else {
                            completeOnboarding()
                        }
                    } label: {
                        Text(currentPage < pages.count ? "Continue" : "Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.Lazyflow.accent)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
        }
        .background(Color.adaptiveBackground)
    }

    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
        }
    }
}

// MARK: - Onboarding Page Model

private struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let accentColor: Color
}

// MARK: - Onboarding Page View

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.accentColor)
                .padding(.bottom, 16)

            // Title
            Text(page.title)
                .font(.title.bold())
                .foregroundColor(Color.Lazyflow.textPrimary)
                .multilineTextAlignment(.center)

            // Description
            Text(page.description)
                .font(.body)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

// MARK: - Permissions Page View

private struct PermissionsPageView: View {
    @Binding var calendarGranted: Bool
    @Binding var notificationsGranted: Bool
    @State private var hasCheckedPermissions = false

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)
                .padding(.bottom, 16)

            // Title
            Text("Stay on Track")
                .font(.title.bold())
                .foregroundColor(Color.Lazyflow.textPrimary)
                .multilineTextAlignment(.center)

            // Description
            Text("Enable permissions for the best experience.")
                .font(.body)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Permission buttons
            VStack(spacing: 16) {
                PermissionRow(
                    icon: "calendar",
                    title: "Calendar Access",
                    description: "Schedule tasks as time blocks",
                    isGranted: calendarGranted,
                    action: requestCalendarPermission
                )

                PermissionRow(
                    icon: "bell.fill",
                    title: "Notifications",
                    description: "Get reminded about tasks",
                    isGranted: notificationsGranted,
                    action: requestNotificationPermission
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .padding()
        .onAppear {
            // Only check permissions once to avoid lag when swiping back and forth
            guard !hasCheckedPermissions else { return }
            hasCheckedPermissions = true
            checkExistingPermissions()
        }
    }

    private func checkExistingPermissions() {
        // Check calendar (synchronous)
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        calendarGranted = calendarStatus == .fullAccess

        // Check notifications (async)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    private func requestCalendarPermission() {
        let eventStore = EKEventStore()
        eventStore.requestFullAccessToEvents { granted, _ in
            DispatchQueue.main.async {
                calendarGranted = granted
            }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                notificationsGranted = granted
            }
        }
    }
}

// MARK: - Permission Row

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(Color.Lazyflow.accent)
                .frame(width: 44, height: 44)
                .background(Color.Lazyflow.accent.opacity(0.1))
                .cornerRadius(10)

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(Color.Lazyflow.textPrimary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Spacer()

            // Status/Button
            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Color.Lazyflow.success)
                    .font(.title2)
            } else {
                Button("Enable") {
                    action()
                }
                .font(.subheadline.weight(.medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.Lazyflow.accent)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.adaptiveSurface)
        .cornerRadius(12)
    }
}

#Preview {
    OnboardingView()
}
