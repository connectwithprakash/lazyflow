import SwiftUI
import UIKit

/// Header row for expanding/collapsing subtasks in the flat list structure
struct SubtaskExpansionHeader: View {
    let task: Task
    let isExpanded: Bool
    let onToggle: () -> Void

    private let impactLight = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        Button {
            impactLight.impactOccurred()
            onToggle()
        } label: {
            HStack(spacing: DesignSystem.Spacing.xs) {
                // Left spacing for thread connector alignment (matches SubtaskRowView)
                Spacer()
                    .frame(width: 16 + DesignSystem.Spacing.sm)

                Text("\(task.completedSubtaskCount)/\(task.subtasks.count) subtasks")
                    .font(DesignSystem.Typography.caption2)
                    .foregroundColor(Color.Lazyflow.textTertiary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.Lazyflow.textTertiary)
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .padding(.trailing, DesignSystem.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .leading) {
            // Vertical thread line - matches SubtaskThreadConnector positioning
            Canvas { context, size in
                let xPos: CGFloat = 2
                var path = Path()
                path.move(to: CGPoint(x: xPos, y: 0))
                path.addLine(to: CGPoint(x: xPos, y: size.height))
                context.stroke(path, with: .color(Color.Lazyflow.textTertiary.opacity(0.4)), lineWidth: 1.5)
            }
            .frame(width: 16)
            .padding(.leading, DesignSystem.Spacing.sm)
        }
    }
}
