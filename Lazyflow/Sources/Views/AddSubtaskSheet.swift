import SwiftUI

/// Sheet for adding a new subtask
struct AddSubtaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    let parentTaskID: UUID
    let onAdd: (String) -> Void

    @State private var subtaskTitle = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.lg) {
                TextField("Subtask title", text: $subtaskTitle)
                    .font(DesignSystem.Typography.body)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(DesignSystem.CornerRadius.medium)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        addSubtask()
                    }

                Spacer()
            }
            .padding()
            .navigationTitle("Add Subtask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addSubtask()
                    }
                    .fontWeight(.semibold)
                    .disabled(subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }

    private func addSubtask() {
        let trimmedTitle = subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        onAdd(trimmedTitle)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AddSubtaskSheet(
        parentTaskID: UUID(),
        onAdd: { title in
            print("Added subtask: \(title)")
        }
    )
}
