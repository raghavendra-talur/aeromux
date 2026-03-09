import SwiftUI

struct WindowRowView: View {
    let item: WindowItem
    let showsIcon: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(item.isFocused ? Color.green : Color.clear)
                .overlay(
                    Circle()
                        .stroke(item.isFocused ? Color.green : Color.white.opacity(0.35), lineWidth: 1)
                )
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            if showsIcon, let icon = item.resolvedIcon {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.appName)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(item.windowTitle.isEmpty ? "Untitled window" : item.windowTitle)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(item.isFocused ? Color.white.opacity(0.12) : Color.white.opacity(0.04))
        )
    }
}
