import AppKit
import Foundation
import SwiftUI

struct TableView: View {
    @ObservedObject var vm: AgentManagerViewModel
    let items: [DisplayItem]
    @State private var deletingItem: DisplayItem?
    @State private var hoveredItemID: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("能力名称").frame(width: 180, alignment: .leading)
                Text("归档与来源").frame(width: 150, alignment: .leading)
                Text("功能说明").frame(maxWidth: .infinity, alignment: .leading)
                Text("目标接入客户端").frame(width: 170, alignment: .leading)
                Text("操作").frame(width: 118, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(ManagerTheme.secondaryText)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(ManagerTheme.insetBg)

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            ForEach(items) { item in
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: item.isSkill ? "square.stack.3d.up.fill" : "point.3.connected.trianglepath.dotted")
                            .foregroundStyle(item.library ? ManagerTheme.indigo : ManagerTheme.amber)
                            .font(.system(size: 13))
                        Text(item.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                            .lineLimit(1)
                        CapabilityTypeBadge(label: item.typeLabel)
                    }
                    .frame(width: 180, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.isSystemService ? "系统服务" : item.library ? "中央库" : "待入库")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background((item.isSystemService ? ManagerTheme.secondaryText : item.library ? ManagerTheme.indigo : ManagerTheme.amber).opacity(0.12), in: Capsule())
                                .foregroundStyle(item.isSystemService ? ManagerTheme.secondaryText : item.library ? ManagerTheme.indigo : ManagerTheme.amber)

                            if let git = item.gitSource {
                                HStack(spacing: 3) {
                                    Image(systemName: "arrow.triangle.branch")
                                        .font(.system(size: 9, weight: .bold))
                                    Text(git.branch ?? "Git")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                }
                                .foregroundStyle(ManagerTheme.electricBlue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(ManagerTheme.electricBlue.opacity(0.1), in: Capsule())
                                .overlay(Capsule().stroke(ManagerTheme.electricBlue.opacity(0.2), lineWidth: 0.8))
                                .help("Git 仓库: \(git.repo)")
                            }
                        }

                        if item.hasRuntimeOriginSummary {
                            CapabilityOriginLine(item: item)
                        }
                        if item.hasContentDifferences {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 8, weight: .bold))
                                Text("不同版本")
                                    .font(.system(size: 9.5, weight: .bold))
                            }
                            .foregroundStyle(ManagerTheme.stopOrange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ManagerTheme.amber.opacity(0.14), in: Capsule())
                            .overlay(Capsule().stroke(ManagerTheme.amber.opacity(0.3), lineWidth: 0.7))
                        }
                    }
                    .frame(width: 150, alignment: .leading)

                    Text(item.detail)
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 5) {
                        ForEach(item.targets) { row in
                            AgentCardButton(
                                row: row,
                                item: item,
                                vm: vm,
                                isSelectedAgent: vm.selectedAgent == row.target.agent,
                                size: 22
                            )
                        }
                    }
                    .frame(width: 170, alignment: .leading)

                    HStack {
                        if item.isSystemService {
                            Text("系统服务")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(ManagerTheme.secondaryText)
                        } else if !item.library {
                            Button {
                                vm.adoptToLibrary(name: item.name)
                            } label: {
                                Text("选来源")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .frame(height: 26)
                                    .background(ManagerTheme.indigo, in: Capsule())
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                vm.selectItem(item)
                            } label: {
                                Text("详情")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(ManagerTheme.primaryText)
                                    .padding(.horizontal, 12)
                                    .frame(height: 26)
                                    .background(ManagerTheme.insetBg, in: Capsule())
                                    .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 1))
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)

                            Menu {
                                Button(role: .destructive) { deletingItem = item } label: {
                                    Label("移至废纸篓", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                                    .frame(width: 26, height: 26)
                                    .contentShape(Rectangle())
                            }
                            .menuStyle(.borderlessButton)
                            .menuIndicator(.hidden)
                            .fixedSize()
                            .help("更多操作")
                        }
                    }
                    .frame(width: 118, alignment: .trailing)
                }
                .padding(.horizontal, 18)
                .frame(height: 44)
                .background(vm.selectedItemName == item.name
                    ? ManagerTheme.activePillBg.opacity(0.6)
                    : hoveredItemID == item.id ? ManagerTheme.activePillBg.opacity(0.35) : Color.white)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering { hoveredItemID = item.id }
                    else if hoveredItemID == item.id { hoveredItemID = nil }
                }
                .animation(.easeInOut(duration: 0.16), value: hoveredItemID)
                .onTapGesture {
                    vm.selectItem(item)
                }
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
                            deletingItem = item
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

                Rectangle()
                    .fill(ManagerTheme.borderLine.opacity(0.6))
                    .frame(height: 1)
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ManagerTheme.borderLine, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
        .confirmationDialog("将“\(deletingItem?.name ?? "")”移至废纸篓？", isPresented: Binding(
            get: { deletingItem != nil },
            set: { if !$0 { deletingItem = nil } }
        ), titleVisibility: .visible) {
            if let item = deletingItem,
               vm.managedDeploymentCount(name: item.name, isSkill: item.isSkill) == 0 {
                Button("移至废纸篓", role: .destructive) {
                    vm.deleteFromLibrary(name: item.name, isSkill: item.isSkill)
                    deletingItem = nil
                }
            }
            Button("取消", role: .cancel) { deletingItem = nil }
        } message: {
            if let item = deletingItem {
                let count = vm.managedDeploymentCount(name: item.name, isSkill: item.isSkill)
                Text(count == 0 ? "只移除中央库文件；可从 macOS 废纸篓恢复。" : "该条目仍在 \(count) 处启用。请先停用这些位置，再删除中央库文件。")
            }
        }
    }
}
