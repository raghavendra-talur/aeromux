import SwiftUI

struct WorkspaceSectionView: View {
    let workspace: WorkspaceGroup
    let showsIcons: Bool
    let focusService: FocusService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(workspace.isFocused ? Color.green : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(workspace.isFocused ? Color.green : Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Task \(workspace.workspaceName)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("\(workspace.windows.count) window\(workspace.windows.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            if workspace.windows.isEmpty {
                Text("No windows in this workspace")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 20)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(workspace.windows) { item in
                        Button {
                            Task {
                                await focusService.focus(windowId: item.windowId)
                            }
                        } label: {
                            WindowRowView(item: item, showsIcon: showsIcons)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(workspace.isFocused ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(workspace.isFocused ? Color.green.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
        }
    }
}
