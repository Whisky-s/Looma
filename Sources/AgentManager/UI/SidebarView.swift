import AppKit
import Foundation
import SwiftUI

private struct SidebarRow: View {
    let title: String
    let icon: String?
    let customIcon: AnyView?
    let count: Int?
    let highlightCount: Bool
    let active: Bool
    let action: () -> Void

    @State private var isHovered = false

    init(
        title: String,
        icon: String? = nil,
        customIcon: AnyView? = nil,
        count: Int? = nil,
        highlightCount: Bool = false,
        active: Bool,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.customIcon = customIcon
        self.count = count
        self.highlightCount = highlightCount
        self.active = active
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .frame(width: 20)
                        .foregroundStyle(active ? ManagerTheme.activePillText : ManagerTheme.secondaryText)
                } else if let customIcon {
                    customIcon
                        .frame(width: 20)
                }

                Text(title)
                    .font(.system(size: 13, weight: active ? .bold : .medium))
                    .foregroundStyle(active ? ManagerTheme.activePillText : ManagerTheme.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(active ? ManagerTheme.activePillText : (highlightCount ? ManagerTheme.electricBlue : ManagerTheme.secondaryText))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(active ? Color.white.opacity(0.25) : (highlightCount ? ManagerTheme.electricBlue.opacity(0.12) : Color.black.opacity(0.05)))
                        )
                } else if active && customIcon != nil {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ManagerTheme.activePillText)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        active
                            ? ManagerTheme.activePillBg
                            : (isHovered ? Color.black.opacity(0.05) : Color.white.opacity(0.001))
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .onHover { h in
            isHovered = h
        }
    }
}

struct SidebarView: View {
    @ObservedObject var vm: AgentManagerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(nsImage: AgentArtwork.appIcon())
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Looma")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    Text("AI 能力控制台")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 46)
            .padding(.bottom, 24)

            sidebarSection("本地中央库")

            sidebarNav(
                "中央库 Skills",
                icon: "folder.fill",
                count: vm.librarySkillCount,
                highlightCount: vm.librarySkillCount > 0,
                active: vm.page == 0 && vm.sourceFilter == 1 && vm.selectedAgent == nil && vm.selectedProject == nil
            ) {
                vm.page = 0
                vm.sourceFilter = 1
                vm.selectedAgent = nil
                vm.selectedProject = nil
                vm.selectedItemName = nil
                vm.query = ""
                vm.statusFilter = 0
            }

            sidebarNav(
                "中央库 MCP",
                icon: "point.3.connected.trianglepath.dotted",
                count: vm.libraryMCPCount,
                highlightCount: vm.libraryMCPCount > 0,
                active: vm.page == 1 && vm.sourceFilter == 1 && vm.selectedAgent == nil && vm.selectedProject == nil
            ) {
                vm.page = 1
                vm.sourceFilter = 1
                vm.selectedAgent = nil
                vm.selectedProject = nil
                vm.selectedItemName = nil
                vm.query = ""
                vm.statusFilter = 0
            }

            sidebarNav(
                "预设组合",
                icon: "square.stack.3d.up.fill",
                count: nil,
                highlightCount: false,
                active: vm.page == 4
            ) {
                vm.page = 4
                vm.selectedAgent = nil
                vm.selectedProject = nil
                vm.selectedItemName = nil
            }

            Rectangle()
                .fill(ManagerTheme.borderLine.opacity(0.6))
                .frame(height: 1)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            sidebarSection("本机全部能力")

            sidebarNav(
                "全部能力总览",
                icon: "square.stack.3d.up",
                count: vm.page == 0 ? vm.totalSkillCount : vm.totalMCPCount,
                highlightCount: false,
                active: vm.page < 2 && vm.sourceFilter == 0 && vm.selectedAgent == nil && vm.selectedProject == nil
            ) {
                if vm.page >= 2 { vm.page = 0 }
                vm.sourceFilter = 0
                vm.selectedAgent = nil
                vm.selectedProject = nil
                vm.selectedItemName = nil
            }

            sidebarNav(
                "待入库外部发现",
                icon: "sparkles",
                count: vm.currentUnadoptedCount,
                highlightCount: vm.currentUnadoptedCount > 0,
                active: vm.page < 2 && vm.sourceFilter == 2 && vm.selectedAgent == nil && vm.selectedProject == nil
            ) {
                if vm.page >= 2 { vm.page = 0 }
                vm.sourceFilter = 2
                if vm.statusFilter == 3 { vm.statusFilter = 0 }
                vm.selectedAgent = nil
                vm.selectedProject = nil
                vm.selectedItemName = nil
            }

            Rectangle()
                .fill(ManagerTheme.borderLine.opacity(0.6))
                .frame(height: 1)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)

            sidebarSection("客户端全局能力")
            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(vm.availableAgents) { a in
                        agentNav(a)
                    }

                    Rectangle()
                        .fill(ManagerTheme.borderLine.opacity(0.6))
                        .frame(height: 1)
                        .padding(.vertical, 12)

                    sidebarSection("项目工作区")
                    ForEach(vm.projects, id: \.self) { p in
                        sidebarNav(
                            URL(fileURLWithPath: p).lastPathComponent,
                            icon: "folder",
                            count: nil,
                            highlightCount: false,
                            active: vm.selectedProject == p
                        ) {
                            vm.selectedProject = (vm.selectedProject == p ? nil : p)
                            vm.selectedAgent = nil
                            vm.page = 0
                            vm.selectedItemName = nil
                            vm.statusFilter = 0
                        }
                    }

                    sidebarNav(
                        "项目管理",
                        icon: "folder.badge.gearshape",
                        count: vm.projects.count,
                        highlightCount: false,
                        active: vm.page == 2
                    ) {
                        vm.page = 2
                        vm.selectedAgent = nil
                        vm.selectedProject = nil
                        vm.selectedItemName = nil
                    }
                }
            }

            Spacer(minLength: 6)

            Rectangle()
                .fill(ManagerTheme.borderLine.opacity(0.6))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 2) {
                sidebarNav(
                    "设置",
                    icon: "gearshape",
                    count: nil,
                    highlightCount: false,
                    active: vm.page == 3
                ) {
                    vm.page = 3
                    vm.selectedAgent = nil
                    vm.selectedProject = nil
                    vm.selectedItemName = nil
                }
            }
            .padding(.bottom, 6)

            HStack(spacing: 8) {
                Circle()
                    .fill(ManagerTheme.mint)
                    .frame(width: 8, height: 8)

                Text("本机扫描正常")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(ManagerTheme.primaryText)

                Spacer()

                Text("6 工具已接入")
                    .font(.system(size: 10.5))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(ManagerTheme.sidebarBg)
    }

    private func sidebarSection(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .tracking(1.0)
            .foregroundStyle(ManagerTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.bottom, 6)
    }

    private func sidebarNav(_ title: String, icon: String, count: Int?, highlightCount: Bool, active: Bool, action: @escaping () -> Void) -> some View {
        SidebarRow(
            title: title,
            icon: icon,
            count: count,
            highlightCount: highlightCount,
            active: active,
            action: action
        )
    }

    private func agentNav(_ value: Agent) -> some View {
        let isSelected = vm.selectedAgent == value && vm.selectedProject == nil
        return SidebarRow(
            title: value.rawValue,
            customIcon: AnyView(AgentLogo(agent: value, size: 18)),
            count: nil,
            highlightCount: false,
            active: isSelected
        ) {
            if isSelected {
                vm.selectedAgent = nil
            } else {
                vm.navigateToClient(value)
            }
        }
    }
}
