import SwiftUI

/// View showing all task lists and smart lists
struct ListsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var viewModel = ListsViewModel()
    @State private var showAddList = false

    var body: some View {
        if horizontalSizeClass == .regular {
            // iPad: No NavigationStack (provided by split view)
            listsContent
                .navigationTitle("Lists")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        addListButton
                    }
                }
                .sheet(isPresented: $showAddList) {
                    AddListSheet(viewModel: viewModel)
                }
        } else {
            // iPhone: Full NavigationStack
            NavigationStack {
                listsContent
                    .navigationTitle("Lists")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            addListButton
                        }
                    }
                    .sheet(isPresented: $showAddList) {
                        AddListSheet(viewModel: viewModel)
                    }
            }
        }
    }

    private var addListButton: some View {
        Button {
            showAddList = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundColor(Color.Lazyflow.accent)
        }
        .accessibilityLabel("Add list")
    }

    private var listsContent: some View {
        ZStack {
            Color.adaptiveBackground
                .ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.lg) {
                    // Smart Lists
                    smartListsSection

                    // Custom Lists
                    customListsSection

                    Spacer(minLength: 100)
                }
                .padding(.top)
            }
        }
    }

    // MARK: - Subviews

    private var smartListsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("Smart Lists")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)
                .padding(.horizontal)

            VStack(spacing: 1) {
                // Inbox
                if let inbox = viewModel.inboxList {
                    NavigationLink {
                        ListDetailView(list: inbox)
                    } label: {
                        SmartListRow(
                            icon: "tray.fill",
                            title: "Inbox",
                            count: viewModel.inboxTaskCount,
                            color: Color.Lazyflow.textTertiary
                        )
                    }
                }

                // Today
                NavigationLink {
                    TodayView()
                } label: {
                    SmartListRow(
                        icon: "star.fill",
                        title: "Today",
                        count: viewModel.todayTaskCount,
                        color: Color.Lazyflow.warning
                    )
                }

                // Upcoming
                NavigationLink {
                    UpcomingView()
                } label: {
                    SmartListRow(
                        icon: "calendar",
                        title: "Upcoming",
                        count: viewModel.upcomingTaskCount,
                        color: Color.Lazyflow.accent
                    )
                }
            }
            .background(Color.adaptiveSurface)
            .cornerRadius(DesignSystem.CornerRadius.large)
            .padding(.horizontal)
        }
    }

    private var customListsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("My Lists")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)

                Spacer()

                if !viewModel.customLists.isEmpty {
                    EditButton()
                        .font(DesignSystem.Typography.subheadline)
                        .foregroundColor(Color.Lazyflow.accent)
                }
            }
            .padding(.horizontal)

            if viewModel.customLists.isEmpty {
                emptyListsView
            } else {
                VStack(spacing: 1) {
                    ForEach(viewModel.customLists) { list in
                        NavigationLink {
                            ListDetailView(list: list)
                        } label: {
                            CustomListRow(
                                list: list,
                                taskCount: viewModel.getTaskCount(for: list)
                            )
                        }
                    }
                    .onMove(perform: viewModel.moveList)
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteList(viewModel.customLists[index])
                        }
                    }
                }
                .background(Color.adaptiveSurface)
                .cornerRadius(DesignSystem.CornerRadius.large)
                .padding(.horizontal)
            }
        }
    }

    private var emptyListsView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundColor(Color.Lazyflow.textTertiary)

            Text("No custom lists yet")
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(Color.Lazyflow.textSecondary)

            Button("Create List") {
                showAddList = true
            }
            .font(DesignSystem.Typography.subheadline)
            .foregroundColor(Color.Lazyflow.accent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxl)
        .background(Color.adaptiveSurface)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .padding(.horizontal)
    }
}

// MARK: - Smart List Row

struct SmartListRow: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 28)

            Text(title)
                .font(DesignSystem.Typography.body)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Custom List Row

struct CustomListRow: View {
    let list: TaskList
    let taskCount: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: list.icon)
                .font(.system(size: 18))
                .foregroundColor(list.color)
                .frame(width: 28)

            Text(list.name)
                .font(DesignSystem.Typography.body)
                .foregroundColor(Color.Lazyflow.textPrimary)

            Spacer()

            if taskCount > 0 {
                Text("\(taskCount)")
                    .font(DesignSystem.Typography.subheadline)
                    .foregroundColor(Color.Lazyflow.textSecondary)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color.Lazyflow.textTertiary)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .contentShape(Rectangle())
    }
}

// MARK: - Add List Sheet

struct AddListSheet: View {
    @ObservedObject var viewModel: ListsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List Name", text: $viewModel.newListName)
                }

                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(TaskList.availableColors, id: \.self) { colorHex in
                            Circle()
                                .fill(Color(hex: colorHex) ?? .gray)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Color.primary, lineWidth: viewModel.newListColor == colorHex ? 2 : 0)
                                        .padding(2)
                                )
                                .onTapGesture {
                                    viewModel.newListColor = colorHex
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(TaskList.availableIcons, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.system(size: 20))
                                .foregroundColor(
                                    viewModel.newListIcon == iconName
                                        ? Color(hex: viewModel.newListColor)
                                        : Color.Lazyflow.textSecondary
                                )
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle()
                                        .fill(
                                            viewModel.newListIcon == iconName
                                                ? Color(hex: viewModel.newListColor)?.opacity(0.2) ?? Color.clear
                                                : Color.clear
                                        )
                                )
                                .onTapGesture {
                                    viewModel.newListIcon = iconName
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        viewModel.createList()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canCreateList)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ListsView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
