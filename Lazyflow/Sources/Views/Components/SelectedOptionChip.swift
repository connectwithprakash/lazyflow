import SwiftUI

struct SelectedOptionChip: View {
    let icon: String
    let title: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(title)
                .font(DesignSystem.Typography.caption1)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(DesignSystem.CornerRadius.full)
        .fixedSize(horizontal: true, vertical: false)
    }
}
