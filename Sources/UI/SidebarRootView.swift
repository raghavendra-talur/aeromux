import SwiftUI

struct SidebarRootView: View {
    @ObservedObject var stateStore: SidebarStateStore
    @ObservedObject var settings: SettingsStore
    let focusService: FocusService

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                header
                if let integrationMessage = stateStore.state.integrationStatus.message {
                    integrationWarning(message: integrationMessage)
                }
                content
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .preferredColorScheme(settings.usesDarkAppearance ? .dark : .light)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 1)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text("Active: \(stateStore.state.workspaceName)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)

            HStack(spacing: 6) {
                Text("\(stateStore.state.visibleWorkspaceCount) task\(stateStore.state.visibleWorkspaceCount == 1 ? "" : "s")")
                Text("•")
                Text("\(stateStore.state.totalWindowCount) window\(stateStore.state.totalWindowCount == 1 ? "" : "s")")
                if let monitorName = stateStore.state.monitorName {
                    Text("•")
                    Text(monitorName)
                }
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch stateStore.state.status {
        case .loading:
            loadingView
        case .error(let message):
            stateView(title: "Unable to read AeroSpace state", message: message)
        case .empty:
            stateView(title: "No windows open", message: "Open a window in any AeroSpace workspace to populate the task rail.")
        case .ready:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(stateStore.state.workspaces) { workspace in
                        WorkspaceSectionView(
                            workspace: workspace,
                            showsIcons: settings.showsAppIcons,
                            focusService: focusService
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Refreshing workspace")
                .font(.system(size: 13, weight: .medium, design: .rounded))
        }
        .foregroundStyle(.secondary)
    }

    private func integrationWarning(message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AeroSpace Integration")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text(message)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Expected: `outer.left = [{ monitor.main = \(Int(settings.sidebarWidth)) }, 0]`")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        }
    }

    private func stateView(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(message)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }
}
