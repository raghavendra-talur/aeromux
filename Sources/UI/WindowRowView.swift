import SwiftUI

struct WindowRowView: View {
    let item: WindowItem
    let isCompact: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Circle()
                .fill(item.isFocused ? Color.green : Color.clear)
                .overlay(
                    Circle()
                        .stroke(item.isFocused ? Color.green : Color.white.opacity(0.35), lineWidth: 1)
                )
                .frame(width: 8, height: 8)

            Text(item.appName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(item.isFocused ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
        )
    }
}
