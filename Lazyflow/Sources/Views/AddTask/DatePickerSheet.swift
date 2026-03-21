import SwiftUI
import LazyflowCore
import LazyflowUI

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date?
    @Binding var hasDate: Bool

    var body: some View {
        NavigationStack {
            DatePicker(
                "Select Date",
                selection: Binding(
                    get: { selectedDate ?? Date() },
                    set: {
                        selectedDate = $0
                        hasDate = true
                    }
                ),
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if hasDate {
                        Button("Clear") {
                            selectedDate = nil
                            hasDate = false
                            dismiss()
                        }
                        .foregroundColor(Color.Lazyflow.error)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
    }
}
