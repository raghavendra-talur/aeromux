import SwiftUI

struct WorkspaceSectionView: View {
    let workspace: WorkspaceGroup
    let isCompact: Bool
    let focusService: FocusService
    let allWorkspaceNames: [String]
    let workspaceMemoryStore: WorkspaceMemoryStore
    let refreshCoordinator: RefreshCoordinator

    @State private var isEditorPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(workspace.isFocused ? Color.green : Color.clear)
                    .overlay(
                        Circle()
                            .stroke(workspace.isFocused ? Color.green : Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(workspace.displayTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .lineLimit(1)
                    if let metadataLine = workspace.metadataLine {
                        Text(metadataLine)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if let detailLine = workspace.detailLine {
                        Text(detailLine)
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    isEditorPresented = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Edit workspace title and description")
            }

            if workspace.windows.isEmpty {
                Text("No windows in this workspace")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 16)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(workspace.windows) { item in
                        Button {
                            Task {
                                await focusService.focus(windowId: item.windowId)
                            }
                        } label: {
                            WindowRowView(item: item, isCompact: isCompact)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(workspace.isFocused ? Color.white.opacity(0.1) : Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(workspace.isFocused ? Color.green.opacity(0.35) : Color.white.opacity(0.06), lineWidth: 1)
        }
        .sheet(isPresented: $isEditorPresented) {
            WorkspaceMetadataEditor(
                workspace: workspace,
                allWorkspaceNames: allWorkspaceNames,
                workspaceMemoryStore: workspaceMemoryStore,
                refreshCoordinator: refreshCoordinator
            )
        }
    }
}

private struct WorkspaceMetadataEditor: View {
    let workspace: WorkspaceGroup
    let allWorkspaceNames: [String]
    let workspaceMemoryStore: WorkspaceMemoryStore
    let refreshCoordinator: RefreshCoordinator

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var isSaving = false

    init(
        workspace: WorkspaceGroup,
        allWorkspaceNames: [String],
        workspaceMemoryStore: WorkspaceMemoryStore,
        refreshCoordinator: RefreshCoordinator
    ) {
        self.workspace = workspace
        self.allWorkspaceNames = allWorkspaceNames
        self.workspaceMemoryStore = workspaceMemoryStore
        self.refreshCoordinator = refreshCoordinator
        _title = State(initialValue: workspace.titleOverride ?? workspace.workspaceName)
        _description = State(initialValue: workspace.descriptionOverride ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Workspace")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 6) {
                Text("AeroSpace Workspace")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(workspace.workspaceName)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Title")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("Workspace title", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Description")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                TextField("Optional description", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer(minLength: 0)

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(isSaving ? "Saving..." : "Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isSaving)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func save() {
        isSaving = true
        Task {
            await workspaceMemoryStore.save(
                workspace: workspace.workspaceName,
                title: title,
                description: description,
                discoveredWorkspaces: allWorkspaceNames
            )
            await MainActor.run {
                refreshCoordinator.requestRefresh(reason: .manual)
                isSaving = false
                dismiss()
            }
        }
    }
}
