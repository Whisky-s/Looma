import AppKit
import Foundation
import SwiftUI

struct MainContentView: View {
    @ObservedObject var vm: AgentManagerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Text(titleText)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)

                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .help(helpText)
                    }

                    Text(subtitleText)
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .lineLimit(1)

                    if vm.page < 2 {
                        Text("操作目标：\(vm.selectedProject.map { "项目 · " + URL(fileURLWithPath: $0).lastPathComponent } ?? "全局") · \(vm.selectedAgent?.rawValue ?? "全部客户端")")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(ManagerTheme.electricBlue)
                            .help(vm.selectedProject ?? "全局配置")
                    }
                }

                Spacer()

                HStack(spacing: 7) {
                    Circle()
                        .fill(ManagerTheme.mint)
                        .frame(width: 7, height: 7)
                    Text("Looma")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    Text(appVersionText)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(ManagerTheme.electricBlue)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white, in: Capsule())
                .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.04), radius: 6, y: 2)
            }
            .padding(.horizontal, 28)
            .padding(.top, 40)
            .padding(.bottom, 16)

            if vm.page < 2 {
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        categoryTab("Skills 技能库", icon: "square.stack.3d.up", value: 0)
                        categoryTab("MCP 服务库", icon: "point.3.connected.trianglepath.dotted", value: 1)
                    }
                    .padding(3)
                    .background(Color.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 1))

                    Spacer()

                    HStack(spacing: 4) {
                        sourcePill("全部能力", count: vm.page == 0 ? vm.totalSkillCount : vm.totalMCPCount, value: 0)
                        sourcePill("仅中央库", count: vm.page == 0 ? vm.librarySkillCount : vm.libraryMCPCount, value: 1)
                        sourcePill("待入库发现", count: vm.currentUnadoptedCount, value: 2)
                    }
                    .padding(3)
                    .background(Color.white.opacity(0.7), in: Capsule())
                    .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 1))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)

                HStack(spacing: 12) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(ManagerTheme.secondaryText)

                        TextField("", text: $vm.query, prompt: Text("搜索能力名称、指令参数或详细说明...").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .foregroundStyle(ManagerTheme.primaryText)

                        if !vm.query.isEmpty {
                            Button {
                                vm.query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(ManagerTheme.secondaryText)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        Text("\(vm.displayItems.count) 项")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.05), in: Capsule())
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 38)
                    .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 10))

                    HStack(spacing: 3) {
                        viewModeButton(Image(systemName: "square.grid.2x2"), mode: .grid)
                        viewModeButton(Image(systemName: "list.bullet"), mode: .table)
                    }
                    .padding(3)
                    .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))

                    HStack(spacing: 6) {
                        filterPill("全部", value: 0)
                        filterPill("已启用", value: 1)
                        filterPill("可启用", value: 2)
                        if vm.page == 0 {
                            filterPill("已关联 Git", icon: "arrow.triangle.branch", count: vm.gitLinkedSkillCount, value: 3)
                        }
                    }

                    Rectangle()
                        .fill(ManagerTheme.borderLine)
                        .frame(width: 1, height: 26)

                    if vm.page == 0 {
                        Button {
                            vm.showGitImportSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Git 导入")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(ManagerTheme.primaryText)
                            .padding(.horizontal, 14)
                            .frame(height: 38)
                            .background(ManagerTheme.insetBg, in: Capsule())
                            .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 1))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        performAdd()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text(vm.page == 0 ? "本地导入" : vm.page == 1 ? "新建 MCP" : "添加项目")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(ManagerTheme.electricBlue, in: Capsule())
                        .shadow(color: ManagerTheme.electricBlue.opacity(0.35), radius: 8, y: 3)
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .help("自动同步配置状态：每 2 秒检查客户端配置变化；配置启用不代表运行中会话已加载，客户端内部私有开关可能无法读取。")

                    Button {
                        Task { await vm.reloadAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                            .frame(width: 38, height: 38)
                            .background(ManagerTheme.insetBg, in: Circle())
                            .overlay(Circle().stroke(ManagerTheme.borderLine, lineWidth: 1))
                            .rotationEffect(.degrees(vm.isScanning ? 360 : 0))
                            .animation(vm.isScanning ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: vm.isScanning)
                    }
                    .buttonStyle(.plain)
                    .help("重新扫描本地配置")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(ManagerTheme.borderLine, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }

            if vm.page == 3 {
                SettingsView(vm: vm)
            } else if vm.page == 2 {
                ProjectListView(vm: vm)
            } else if vm.page == 4 {
                PresetsView(vm: vm)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        if vm.currentUnadoptedCount > 0 && vm.sourceFilter != 1 {
                            grandBatchAdoptBanner
                        }

                        if vm.displayItems.isEmpty {
                            emptyView
                        } else if vm.viewMode == .grid {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 400), spacing: 18)], spacing: 18) {
                                ForEach(vm.displayItems) { item in
                                    ModernCardView(vm: vm, item: item)
                                }
                            }
                        } else {
                            TableView(vm: vm, items: vm.displayItems)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private var grandBatchAdoptBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(ManagerTheme.indigo.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "sparkles")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ManagerTheme.indigo)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("检测到 \(vm.currentUnadoptedCount) 个外部\(vm.page == 0 ? " Skill" : " MCP") 尚未归档至中央库")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)

                    Text("推荐归档")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ManagerTheme.indigo)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(ManagerTheme.indigo.opacity(0.12), in: Capsule())
                }

                Text("归档到中央库后，将脱离单一工具的本地限制，随时按需一键分发到任意客户端。")
                    .font(.system(size: 12))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }

            Spacer()

            Button {
                vm.openAdoption()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 13))
                    Text("预览并归档")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .frame(height: 38)
                .background(ManagerTheme.indigo, in: Capsule())
                .shadow(color: ManagerTheme.indigo.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(ManagerTheme.indigo.opacity(0.3), lineWidth: 1.2))
        .shadow(color: Color.black.opacity(0.04), radius: 10, y: 3)
    }

    private var helpText: String {
        switch vm.page {
        case 4: return "预设组合只保存条目名称；应用时会停用预设外的能力，并可在设置的操作记录中回滚。"
        case 3: return "偏好设置、操作记录、配置备份与客户端路径。"
        case 2: return "添加项目后会扫描其中的项目级 Skill 与 MCP 配置。"
        default: return "卡片上的客户端图标可直接启用、停用或恢复；修改后可能需要重启对应客户端才能生效。"
        }
    }

    private var titleText: String {
        if vm.page == 4 {
            return "预设组合"
        }
        if vm.page == 3 {
            return "偏好设置"
        }
        if vm.page == 2 {
            return "项目管理"
        }
        if let p = vm.selectedProject {
            return URL(fileURLWithPath: p).lastPathComponent
        }
        if let a = vm.selectedAgent {
            return a.rawValue
        }
        if vm.sourceFilter == 1 {
            return vm.page == 0 ? "中央库 Skills" : "中央库 MCP"
        }
        if vm.sourceFilter == 2 {
            return "待入库外部能力"
        }
        return vm.page == 0 ? "Skills 技能库" : "MCP 服务库"
    }

    private var subtitleText: String {
        if vm.page == 4 {
            return "组合中央库 Skill 与 MCP，一次应用到选定客户端"
        }
        if vm.page == 3 {
            return "自定义交互偏好、Git 默认规则、中央库与客户端配置"
        }
        if vm.page == 2 {
            return "配置与管理包含 Skills / MCP 的本地工程项目"
        }
        if let p = vm.selectedProject {
            return "本地项目代码目录: \(p)"
        }
        if let a = vm.selectedAgent {
            return "集中管理与调度 \(a.rawValue) 的全局能力配置"
        }
        if vm.sourceFilter == 1 {
            return "当前仅展示已保存至中央库的标准模版，随时可一键分发到任意客户端"
        }
        return "本地中央存储与多客户端分发中枢"
    }

    private func categoryTab(_ title: String, icon: String, value: Int) -> some View {
        Button {
            vm.page = value
            vm.selectedItemName = nil
            vm.query = ""
            vm.statusFilter = 0
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: vm.page == value ? .bold : .medium))
            }
            .foregroundStyle(vm.page == value ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(vm.page == value ? Color.white : Color.white.opacity(0.001))
                    .shadow(color: vm.page == value ? Color.black.opacity(0.05) : Color.clear, radius: 4, y: 2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func sourcePill(_ title: String, count: Int, value: Int) -> some View {
        let isSelected = vm.sourceFilter == value
        return Button {
            vm.sourceFilter = value
            if value == 2 && vm.statusFilter == 3 { vm.statusFilter = 0 }
            vm.selectedItemName = nil
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundStyle(isSelected ? ManagerTheme.primaryText : ManagerTheme.secondaryText)

                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(isSelected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? ManagerTheme.electricBlue.opacity(0.12) : Color.black.opacity(0.05), in: Capsule())
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.001))
                    .shadow(color: isSelected ? Color.black.opacity(0.08) : Color.clear, radius: 4, y: 2)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func viewModeButton(_ image: Image, mode: ViewMode) -> some View {
        Button {
            vm.viewMode = mode
        } label: {
            image
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(vm.viewMode == mode ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                .frame(width: 34, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(vm.viewMode == mode ? Color.white : Color.white.opacity(0.001))
                        .shadow(color: vm.viewMode == mode ? Color.black.opacity(0.05) : Color.clear, radius: 3, y: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func filterPill(_ title: String, icon: String? = nil, count: Int? = nil, value: Int) -> some View {
        let isSelected = vm.statusFilter == value
        return Button {
            vm.statusFilter = value
            if value == 3 { vm.sourceFilter = 0 }
            vm.selectedItemName = nil
        } label: {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isSelected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(isSelected ? ManagerTheme.electricBlue.opacity(0.12) : Color.black.opacity(0.05), in: Capsule())
                }
            }
            .foregroundStyle(isSelected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? ManagerTheme.electricBlue.opacity(0.12) : Color.white.opacity(0.001))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: vm.sourceFilter == 1 ? "folder.badge.plus" : "square.stack.3d.up")
                .font(.system(size: 40))
                .foregroundStyle(ManagerTheme.electricBlue)

            Text(vm.sourceFilter == 1 && vm.query.isEmpty ? "中央库目前暂无已归档能力" : "未找到相关能力条目")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(ManagerTheme.primaryText)

            Text(!vm.query.isEmpty ? "没有与「\(vm.query)」匹配的条目" : vm.sourceFilter == 1 ? "你可以预览本机来源并选择归档，或通过 Git / 本地目录导入" : "请尝试更换筛选条件或点击右上角刷新重新扫描")
                .font(.system(size: 13))
                .foregroundStyle(ManagerTheme.secondaryText)

            if !vm.query.isEmpty || vm.statusFilter != 0 {
                Button {
                    vm.query = ""
                    vm.statusFilter = 0
                } label: {
                    Text(vm.query.isEmpty ? "显示全部状态" : "清除搜索与筛选")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                        .padding(.horizontal, 18)
                        .frame(height: 38)
                        .background(ManagerTheme.insetBg, in: Capsule())
                        .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            } else if vm.sourceFilter == 1 && vm.currentUnadoptedCount > 0 {
                Button {
                    vm.openAdoption()
                } label: {
                    Text("预览入库来源 (\(vm.currentUnadoptedCount) 项)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 38)
                        .background(ManagerTheme.indigo, in: Capsule())
                        .shadow(color: ManagerTheme.indigo.opacity(0.35), radius: 8, y: 3)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            } else {
                HStack(spacing: 12) {
                    if vm.page == 0 {
                        Button {
                            vm.showGitImportSheet = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.branch")
                                    .font(.system(size: 12, weight: .bold))
                                Text("从 Git 仓库安装")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(ManagerTheme.primaryText)
                            .padding(.horizontal, 18)
                            .frame(height: 38)
                            .background(ManagerTheme.insetBg, in: Capsule())
                            .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 1))
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        performAdd()
                    } label: {
                        Text(vm.page == 0 ? "导入本地 Skill" : "新建 MCP 模板")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 38)
                            .background(ManagerTheme.electricBlue, in: Capsule())
                            .shadow(color: ManagerTheme.electricBlue.opacity(0.35), radius: 8, y: 3)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func performAdd() {
        if vm.page == 1 {
            vm.editingMCPItem = nil
            vm.showNewMCPSheet = true
            return
        }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK, let url = panel.url {
            if vm.page == 0 {
                vm.importSkill(url: url)
            } else {
                vm.addProject(url: url)
            }
        }
    }
}

var appVersionText: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    return "v" + (version ?? "开发版")
}
