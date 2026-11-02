import AppKit
import Foundation
import SwiftUI

struct ModernCardView: View {
    @ObservedObject var vm: AgentManagerViewModel
    let item: DisplayItem
    @State private var showDeleteConfirm = false
    @State private var isHovered = false

    var body: some View {
        let isSelected = vm.selectedItemName == item.name
        let activeHere = item.targets
            .filter { vm.selectedAgent == nil || $0.target.agent == vm.selectedAgent }
            .contains { $0.status == "已有配置" || $0.status == "配置已启用" }

        VStack(alignment: .leading, spacing: 0) {
            Button {
                vm.selectItem(item)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(activeHere ? ManagerTheme.mint : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)

                        Text(item.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .topLeading)

                        CapabilityTypeBadge(label: item.typeLabel)

                        if item.hasGitSource {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 9, weight: .bold))
                                Text("Git")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .foregroundStyle(ManagerTheme.electricBlue)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(ManagerTheme.electricBlue.opacity(0.12), in: Capsule())
                            .overlay(
                                Capsule().stroke(ManagerTheme.electricBlue.opacity(0.28), lineWidth: 0.8)
                            )
                            .help(item.gitSource?.repo ?? "已关联 Git 仓库")
                            .fixedSize()
                        }

                        if item.hasContentDifferences {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 8.5, weight: .bold))
                                Text("不同版本")
                                    .font(.system(size: 10.5, weight: .bold))
                            }
                            .foregroundStyle(ManagerTheme.stopOrange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(ManagerTheme.amber.opacity(0.14), in: Capsule())
                            .overlay(
                                Capsule().stroke(ManagerTheme.amber.opacity(0.35), lineWidth: 0.8)
                            )
                            .help("各客户端同名配置内容不同，点击可比较各来源版本")
                            .fixedSize()
                        }

                        if !item.library && !item.isSystemService {
                            Text("待入库")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(ManagerTheme.amber)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ManagerTheme.amber.opacity(0.12), in: Capsule())
                                .fixedSize()
                        }

                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(displayDescription)
                            .font(.system(size: 12))
                            .foregroundStyle(isDescriptionPlaceholder ? ManagerTheme.secondaryText.opacity(0.55) : ManagerTheme.secondaryText)
                            .italic(isDescriptionPlaceholder)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 50, alignment: .top)
                    }
                    .padding(10)
                    .background(isHovered ? ManagerTheme.activePillBg.opacity(0.65) : ManagerTheme.insetBg,
                                in: RoundedRectangle(cornerRadius: 10))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)
                .padding(.vertical, 12)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if item.isSystemService {
                        Text("系统服务")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ManagerTheme.secondaryText)
                        Spacer()
                    } else if !item.library {
                        Text("发现 · \(item.installedCount) 处来源")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)

                        Spacer()

                        Button {
                            vm.adoptToLibrary(name: item.name)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 11, weight: .bold))
                                Text("选来源")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .frame(height: 30)
                            .background(ManagerTheme.indigo, in: Capsule())
                            .shadow(color: ManagerTheme.indigo.opacity(0.3), radius: 4, y: 2)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Interactive quick-toggle bar for all clients
                        HStack(spacing: 5) {
                            ForEach(item.targets) { row in
                                AgentCardButton(
                                    row: row,
                                    item: item,
                                    vm: vm,
                                    isSelectedAgent: vm.selectedAgent == row.target.agent,
                                    size: 28
                                )
                            }
                        }

                        let activeCount = item.targets.filter { $0.status == "已有配置" || $0.status == "配置已启用" }.count
                        if activeCount > 0 {
                            Text("\(activeCount) 处启用")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(ManagerTheme.mint)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(ManagerTheme.mint.opacity(0.12), in: Capsule())
                        }

                        Spacer()

                        if let git = item.gitSource, let branch = git.branch, !branch.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 9, weight: .bold))
                                Text(branch)
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            }
                            .foregroundStyle(ManagerTheme.electricBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(ManagerTheme.electricBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                            .help("Git 仓库: \(git.repo)\(git.branch.map { " (分支: \($0))" } ?? "")")
                        }

                        Menu {
                            Button {
                                vm.selectItem(item)
                            } label: {
                                Label("查看详情与部署矩阵", systemImage: "slider.horizontal.3")
                            }
                            Divider()
                            Button {
                                let url = item.isSkill
                                    ? ManagerStore.shared.skillsRoot.appendingPathComponent(item.name)
                                    : ManagerStore.shared.mcpRoot.appendingPathComponent(item.name + ".json")
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            } label: {
                                Label("在访达中显示", systemImage: "folder")
                            }
                            if let _ = item.rawSkill?.gitSource {
                                Button {
                                    Task {
                                        await vm.updateSkillFromGit(name: item.name)
                                    }
                                } label: {
                                    Label("从 Git 拉取最新更新", systemImage: "arrow.clockwise")
                                }
                            }
                            Divider()
                            Button(role: .destructive) { showDeleteConfirm = true } label: {
                                Label("移至废纸篓", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(ManagerTheme.secondaryText)
                                .frame(width: 26, height: 28)
                                .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .fixedSize()
                        .help("更多操作")
                    }
                }
            }
        }
        .padding(16)
        .background(isHovered ? Color(red: 0.955, green: 0.973, blue: 0.995) : Color.white,
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSelected ? ManagerTheme.electricBlue : isHovered ? ManagerTheme.electricBlue.opacity(0.45) : ManagerTheme.borderLine,
                    lineWidth: isSelected ? 2 : isHovered ? 1.5 : 1
                )
        )
        .shadow(
            color: isSelected ? ManagerTheme.electricBlue.opacity(0.18) : isHovered ? ManagerTheme.electricBlue.opacity(0.12) : Color.black.opacity(0.04),
            radius: isSelected || isHovered ? 12 : 8,
            y: isHovered ? 5 : 3
        )
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.18), value: isHovered)
        .contextMenu {
            Button {
                if item.isSkill {
                    let url = item.rawSkill?.url ?? ManagerStore.shared.skillsRoot.appendingPathComponent(item.name)
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } else {
                    let url = item.rawMCP?.source ?? ManagerStore.shared.mcpRoot.appendingPathComponent(item.name + ".json")
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            } label: {
                Label("在访达中显示", systemImage: "folder")
            }

            if let _ = item.rawSkill?.gitSource {
                Button {
                    Task {
                        await vm.updateSkillFromGit(name: item.name)
                    }
                } label: {
                    Label("从 Git 检查并拉取更新", systemImage: "arrow.clockwise")
                }
            }

            Divider()

            if item.library {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("从中央库删除 (移至废纸篓)", systemImage: "trash")
                }
            } else if !item.isSystemService {
                Button {
                    vm.adoptToLibrary(name: item.name)
                } label: {
                    Label("归档到中央库", systemImage: "plus.square")
                }
            }
        }
        .confirmationDialog("将“\(item.name)”移至废纸篓？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            if vm.managedDeploymentCount(name: item.name, isSkill: item.isSkill) == 0 {
                Button("移至废纸篓", role: .destructive) {
                    vm.deleteFromLibrary(name: item.name, isSkill: item.isSkill)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            let count = vm.managedDeploymentCount(name: item.name, isSkill: item.isSkill)
            Text(count == 0 ? "只移除中央库文件；可从 macOS 废纸篓恢复。" : "该条目仍在 \(count) 处启用。请先停用这些位置，再删除中央库文件。")
        }
    }


    private var displayDescription: String {
        let trimmed = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == ">-" || trimmed == "-" || trimmed == "无描述" || trimmed == "已停用的 Skill" {
            return "暂无详细描述"
        }
        return trimmed
    }

    private var isDescriptionPlaceholder: Bool {
        let trimmed = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == ">-" || trimmed == "-" || trimmed == "无描述" || trimmed == "已停用的 Skill"
    }
}
