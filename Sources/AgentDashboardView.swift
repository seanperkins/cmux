import SwiftUI

struct AgentDashboardView: View {
    @ObservedObject var tabManager: TabManager
    @Binding var isPresented: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(String(localized: "dashboard.title", defaultValue: "Agent Dashboard"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(String(localized: "dashboard.dismiss", defaultValue: "ESC to close"))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Workspace rows
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(tabManager.tabs, id: \.id) { workspace in
                        AgentDashboardRow(workspace: workspace, isSelected: workspace.id == tabManager.selectedTabId)
                            .onTapGesture {
                                tabManager.selectedTabId = workspace.id
                                isPresented = false
                            }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 600, height: min(CGFloat(tabManager.tabs.count) * 64 + 60, 500))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
    }
}

private struct AgentDashboardRow: View {
    @ObservedObject var workspace: Workspace
    let isSelected: Bool

    private var stateColor: Color {
        if let stateEntry = workspace.statusEntries["state"],
           let hex = stateEntry.color,
           let color = Color(hex: hex) {
            return color
        }
        return .secondary
    }

    private var stateText: String {
        workspace.statusEntries["state"]?.value ?? String(localized: "dashboard.state.idle", defaultValue: "idle")
    }

    var body: some View {
        HStack(spacing: 12) {
            // State indicator dot
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            // Title + breadcrumb
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.customTitle ?? workspace.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                if let breadcrumb = workspace.breadcrumb {
                    Text(breadcrumb.crumbs.suffix(4).joined(separator: " → "))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Rearview (last milestone)
            if let rearview = workspace.rearview, let latest = rearview.entries.first {
                Text("\(latest.icon) \(latest.text)")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 100, alignment: .trailing)
            }

            // Progress or state label
            if let progress = workspace.progress {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(progress.value * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                    if let eta = progress.etaLabel {
                        Text(eta)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 50)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule(style: .continuous)
                            .fill(Color.secondary.opacity(0.2))
                        Capsule(style: .continuous)
                            .fill(stateColor)
                            .frame(width: max(0, geo.size.width * CGFloat(progress.value)))
                    }
                }
                .frame(width: 60, height: 4)
            } else {
                Text(stateText)
                    .font(.system(size: 10))
                    .foregroundColor(stateColor)
                    .frame(width: 60, alignment: .trailing)
            }

            // Waveform sparkline
            if let waveform = workspace.waveform {
                Text(waveform.sparkline)
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.6))
                    .frame(width: 80, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(isSelected ? Color.primary.opacity(0.06) : Color.primary.opacity(0.02))
    }
}
