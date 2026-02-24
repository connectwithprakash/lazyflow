import SwiftUI

/// Debug view for overriding feature flags during development.
/// Only available in DEBUG builds via Settings > Developer > Feature Flags.
struct FeatureFlagsDebugView: View {
    @ObservedObject private var flags = FeatureFlags.shared
    @State private var showResetConfirmation = false

    var body: some View {
        List {
            ForEach(FeatureFlags.groupedFlags, id: \.group) { group, groupFlags in
                Section(group.rawValue) {
                    ForEach(groupFlags) { flag in
                        FlagRow(flag: flag)
                    }
                }
            }

            Section {
                Button("Reset All to Defaults", role: .destructive) {
                    showResetConfirmation = true
                }
            } footer: {
                Text("Overrides are stored locally and persist across app launches. They do not affect other devices.")
            }
        }
        .navigationTitle("Feature Flags")
        .alert("Reset All Flags?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                flags.removeAllOverrides()
            }
        } message: {
            Text("All feature flags will revert to their compile-time defaults.")
        }
    }
}

// MARK: - Flag Row

private struct FlagRow: View {
    let flag: FeatureFlags.Flag
    @ObservedObject private var flags = FeatureFlags.shared

    private var isEnabled: Bool {
        flags.isEnabled(flag)
    }

    private var hasOverride: Bool {
        flags.hasOverride(flag)
    }

    var body: some View {
        Toggle(isOn: Binding(
            get: { isEnabled },
            set: { newValue in
                flags.setOverride(flag, enabled: newValue)
            }
        )) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(flag.displayName)
                        .foregroundColor(Color.Lazyflow.textPrimary)

                    if hasOverride {
                        Text("OVERRIDE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.Lazyflow.warning)
                            .cornerRadius(3)
                    }
                }

                Text(flag.description)
                    .font(DesignSystem.Typography.caption1)
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
        }
        .tint(Color.Lazyflow.accent)
        .swipeActions(edge: .trailing) {
            if hasOverride {
                Button("Reset") {
                    flags.removeOverride(flag)
                }
                .tint(Color.Lazyflow.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FeatureFlagsDebugView()
    }
}
