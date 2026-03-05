import SwiftUI
import LazyflowCore

struct ListPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedListID: UUID?
    let lists: [TaskList]

    var body: some View {
        NavigationStack {
            List {
                // No List option
                Button {
                    selectedListID = nil
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "tray")
                            .foregroundColor(Color.Lazyflow.textTertiary)
                            .frame(width: 28)

                        Text("No List")
                            .foregroundColor(Color.Lazyflow.textPrimary)

                        Spacer()

                        if selectedListID == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(Color.Lazyflow.accent)
                        }
                    }
                }

                ForEach(lists) { list in
                    Button {
                        selectedListID = list.id
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: list.icon)
                                .foregroundColor(list.color)
                                .frame(width: 28)

                            Text(list.name)
                                .foregroundColor(Color.Lazyflow.textPrimary)

                            Spacer()

                            if selectedListID == list.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.Lazyflow.accent)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
