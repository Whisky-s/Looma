import AppKit
import SwiftUI

private enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "常规"
    case data = "数据与备份"
    case history = "操作记录"
    case clients = "客户端与关于"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .data: "externaldrive"
        case .history: "clock.arrow.circlepath"
        case .clients: "square.grid.2x2"
        }
    }
}

private struct ClientConfigPaths: View {
    let title: String
    let skillPaths: [String]
    let mcpPath: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ManagerTheme.primaryText)
            HStack(alignment: .top, spacing: 8) {
                Text("Skill 目录")
                    .frame(width: 66, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(skillPaths, id: \.self) { path in
                        Text(path)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Text("MCP 文件")
                    .frame(width: 66, alignment: .leading)
                Text(mcpPath)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 10.5, design: .monospaced))
        .foregroundStyle(ManagerTheme.secondaryText)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsView: View {
    @ObservedObject var vm: AgentManagerViewModel
    @State private var selectedTab: SettingsTab = .general
    @State private var backups: [ConfigBackup] = []
    @State private var pendingRestore: (backup: ConfigBackup, target: URL)?
    @State private var showRestoreConfirmation = false
    @State private var history: [OperationHistoryEntry] = []
    @State private var historyLimit = 50
    @State private var pendingRollback: OperationHistoryEntry?
    @State private var showRollbackConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            tabBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedTab {
                    case .general:
                        appearanceSection
                        deploymentSection
                        gitDefaultsSection
                    case .data:
                        storageSection
                        backupSection
                    case .history:
                        historySection
                    case .clients:
                        clientsEnvironmentSection
                        aboutSection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
            .id(selectedTab)
        }
        .background(ManagerTheme.canvasBg)
        .onAppear { refreshRecords() }
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(SettingsTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                    if tab == .data || tab == .history { refreshRecords() }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                    }
                    .foregroundStyle(isSelected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                    .padding(.horizontal, 15)
                    .frame(height: 34)
                    .background(isSelected ? ManagerTheme.activePillBg : Color.clear, in: RoundedRectangle(cornerRadius: 9))
                    .contentShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .background(Color.white)
        .overlay(alignment: .bottom) {
            ManagerTheme.borderLine.frame(height: 1)
        }
    }

    // MARK: - Section 1: Appearance & Presentation Mode
    private var appearanceSection: some View {
        SettingsCard(title: "交互与展现偏好", icon: "macwindow", iconColor: ManagerTheme.indigo) {
            VStack(alignment: .leading, spacing: 16) {
                // Detail Presentation Mode
                VStack(alignment: .leading, spacing: 8) {
                    Text("能力详情交互方式")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    Text("设置点击 Skill 或 MCP 卡片时的呈现形式。默认为独立弹窗卡片模式。")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)

                    HStack(spacing: 14) {
                        // Modal Card Option
                        SettingsChoiceCard(
                            isSelected: vm.detailPresentationMode == .modal,
                            icon: "macwindow",
                            title: "弹窗卡片模式",
                            badge: "推荐 · 默认",
                            description: "在独立宽屏弹窗中沉浸展示，可全屏舒适阅读 SKILL.md 文档，主列表不受挤压。"
                        ) { vm.detailPresentationMode = .modal }

                        // Sidebar Drawer Option
                        SettingsChoiceCard(
                            isSelected: vm.detailPresentationMode == .sidebar,
                            icon: "sidebar.right",
                            title: "右侧抽屉栏模式",
                            badge: nil,
                            description: "在主窗口右侧滑出抽屉边栏，主列表随之缩小，适合紧凑随同浏览。"
                        ) { vm.detailPresentationMode = .sidebar }
                    }
                }

                Rectangle()
                    .fill(ManagerTheme.borderLine)
                    .frame(height: 1)

                // Default Markdown Mode
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("SKILL.md 初始阅读视图")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                        Text("打开能力详情时默认呈现的文档视图")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }

                    Spacer()

                    SettingsSegmentedControl(selection: $vm.defaultMarkdownMode, options: [
                        .init(0, title: "富文本渲染预览", icon: "text.book.closed.fill", badge: "推荐"),
                        .init(1, title: "原始 Markdown 源码", icon: "curlybraces")
                    ])
                }
            }
        }
    }

    private var deploymentSection: some View {
        SettingsCard(title: "Skill 启用方式", icon: "link", iconColor: ManagerTheme.electricBlue) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("默认部署方式")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                        Text("启用 Skill 时统一使用此方式，无需逐项选择。")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }

                    Spacer()

                    SettingsSegmentedControl(selection: $vm.skillDeploymentMode, options: [
                        .init(.link, title: "软链接", icon: "link", badge: "默认"),
                        .init(.copy, title: "复制", icon: "doc.on.doc")
                    ])
                }

                Text(vm.skillDeploymentMode == .link
                     ? "软链接直接引用中央库，中央库内容更新后，已启用位置会同步读取最新内容。"
                     : "复制会在目标位置创建独立副本，中央库更新不会自动覆盖该副本。")
                    .font(.system(size: 11.5))
                    .foregroundStyle(ManagerTheme.secondaryText)

                Text("修改设置只影响之后的启用；已有部署保持原方式。")
                    .font(.system(size: 11))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }
        }
    }

    // MARK: - Section 2: Git Defaults
    private var gitDefaultsSection: some View {
        SettingsCard(title: "Git 导入与克隆规则", icon: "arrow.triangle.branch", iconColor: ManagerTheme.electricBlue) {
            VStack(alignment: .leading, spacing: 14) {
                // Default Branch
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("默认克隆分支 (Default Branch)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                        Text("从 Git 导入新技能时预填的分支名称（如 master、main 或企业内部主分支）")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }

                    Spacer()

                    TextField("", text: $vm.defaultGitBranch, prompt: Text("master").foregroundStyle(ManagerTheme.secondaryText))
                        .textFieldStyle(.plain)
                        .foregroundStyle(ManagerTheme.primaryText)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(.horizontal, 12)
                        .frame(width: 140, height: 32)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.borderLine, lineWidth: 1))
                }

                Rectangle()
                    .fill(ManagerTheme.borderLine)
                    .frame(height: 1)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("启用浅克隆优化 (--depth 1)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                        Text("仅拉取最新一次提交代码，跳过历史 commit 记录，克隆速度提升 90% 并节省磁盘空间")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }

                    Spacer()

                    Toggle("启用浅克隆优化", isOn: $vm.enableShallowClone)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }

                Rectangle()
                    .fill(ManagerTheme.borderLine)
                    .frame(height: 1)

                // Cache Cleaner
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("临时克隆缓存")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                        Text("清理历史浅克隆过程中产生的临时安全缓存目录")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }

                    Spacer()

                    Button {
                        vm.cleanTempGitClones()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12))
                            Text("立即清理缓存")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .foregroundStyle(ManagerTheme.primaryText)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(ManagerTheme.insetBg, in: Capsule())
                        .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Section 3: Central Library Storage
    private var storageSection: some View {
        SettingsCard(title: "本地中央库资产管理", icon: "folder.fill", iconColor: ManagerTheme.mint) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("中央库物理存储路径")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                        Text(ManagerStore.shared.base.path)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([ManagerStore.shared.base])
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "folder.badge.gearshape")
                                .font(.system(size: 12))
                            Text("在访达中显示")
                                .font(.system(size: 12.5, weight: .semibold))
                        }
                        .foregroundStyle(ManagerTheme.electricBlue)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(ManagerTheme.electricBlue.opacity(0.1), in: Capsule())
                        .overlay(Capsule().stroke(ManagerTheme.electricBlue.opacity(0.25), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 20) {
                    storageStatBox(
                        title: "已归档 Skills",
                        value: "\(vm.librarySkillCount) 个",
                        icon: "square.stack.3d.up.fill",
                        color: ManagerTheme.indigo
                    )
                    storageStatBox(
                        title: "已归档 MCP 服务",
                        value: "\(vm.libraryMCPCount) 个",
                        icon: "point.3.connected.trianglepath.dotted",
                        color: ManagerTheme.amber
                    )
                    storageStatBox(
                        title: "接入本地项目",
                        value: "\(vm.projects.count) 个",
                        icon: "folder.fill",
                        color: ManagerTheme.electricBlue
                    )
                }
            }
        }
    }

    private func storageStatBox(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11))
                    .foregroundStyle(ManagerTheme.secondaryText)
                Text(value)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(ManagerTheme.primaryText)
            }
            Spacer()
        }
        .padding(12)
        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
    }

    private var backupSection: some View {
        SettingsCard(title: "配置备份", icon: "clock.arrow.circlepath", iconColor: ManagerTheme.indigo) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("恢复前会再次备份当前配置。旧版备份需要手动选择恢复目标。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ManagerTheme.secondaryText)
                    Spacer()
                    Button {
                        backups = ManagerStore.shared.configBackups()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                            Text("刷新")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(ManagerTheme.insetBg, in: Capsule())
                        .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if backups.isEmpty {
                    Text("暂无配置备份")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                } else {
                    ForEach(backups) { backup in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.badge.clock")
                                .foregroundStyle(ManagerTheme.indigo)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(backup.originalPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? backup.id)
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(ManagerTheme.primaryText)
                                Text(backup.originalPath ?? "旧版备份 · 需选择目标文件")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                                    .lineLimit(1)
                                Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                            }
                            Spacer(minLength: 8)
                            Button {
                                prepareRestore(backup)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("恢复")
                                        .font(.system(size: 11.5, weight: .bold))
                                }
                                .foregroundStyle(ManagerTheme.electricBlue)
                                .padding(.horizontal, 12)
                                .frame(height: 28)
                                .background(ManagerTheme.activePillBg, in: Capsule())
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .alert("恢复配置备份？", isPresented: $showRestoreConfirmation) {
            Button("取消", role: .cancel) { pendingRestore = nil }
            Button("恢复", role: .destructive) {
                guard let request = pendingRestore else { return }
                do {
                    try ManagerStore.shared.restoreConfigBackup(request.backup, to: request.target)
                    refreshRecords()
                    vm.showToast(title: "配置已恢复", detail: request.target.path)
                    Task { await vm.reloadAll() }
                } catch {
                    vm.showToast(title: "恢复失败", detail: error.localizedDescription, isError: true)
                }
                pendingRestore = nil
            }
        } message: {
            Text("将用备份覆盖 \(pendingRestore?.target.path ?? "")。当前文件会先保存为新备份。")
        }
    }

    private func prepareRestore(_ backup: ConfigBackup) {
        let target: URL
        if let original = backup.originalPath {
            target = URL(fileURLWithPath: original)
        } else {
            let panel = NSOpenPanel()
            panel.message = "选择这份旧备份原来的配置文件"
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            guard panel.runModal() == .OK, let selected = panel.url else { return }
            target = selected
        }
        pendingRestore = (backup, target)
        showRestoreConfirmation = true
    }

    private func refreshRecords() {
        backups = ManagerStore.shared.configBackups()
        history = ManagerStore.shared.operationHistory()
        historyLimit = ManagerStore.shared.historyLimit
    }

    private var historySection: some View {
        SettingsCard(title: "操作记录与回滚", icon: "arrow.uturn.backward.circle", iconColor: ManagerTheme.electricBlue) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("保留最近的操作记录")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                        Text("记录时间、动作和目标；回滚快照仅保存在本机，可能包含 MCP 凭据。")
                            .font(.system(size: 11.5))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }
                    Spacer()
                    SettingsSegmentedControl(selection: $historyLimit, options: [
                        .init(20, title: "20 条", icon: "clock"),
                        .init(50, title: "50 条", icon: "clock"),
                        .init(100, title: "100 条", icon: "clock")
                    ])
                    .onChange(of: historyLimit) { _, value in
                        do {
                            try ManagerStore.shared.setHistoryLimit(value)
                            history = ManagerStore.shared.operationHistory()
                        } catch {
                            vm.showToast(title: "设置失败", detail: error.localizedDescription, isError: true)
                            historyLimit = ManagerStore.shared.historyLimit
                        }
                    }

                    Button {
                        refreshRecords()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .semibold))
                            Text("刷新")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(ManagerTheme.insetBg, in: Capsule())
                        .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                if history.isEmpty {
                    Text("暂无操作记录")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .padding(.vertical, 8)
                } else {
                    ForEach(history) { entry in
                        HStack(spacing: 12) {
                            Image(systemName: entry.kind == "mcp" ? "point.3.connected.trianglepath.dotted" : "square.stack.3d.up")
                                .font(.system(size: 15))
                                .foregroundStyle(ManagerTheme.electricBlue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 7) {
                                    Text(entry.action)
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundStyle(ManagerTheme.primaryText)
                                    Text(entry.status)
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(entry.status == "成功" ? ManagerTheme.mint : ManagerTheme.secondaryText)
                                }
                                Text(entry.target)
                                    .font(.system(size: 11))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                                    .lineLimit(1)
                                Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                            }
                            Spacer(minLength: 8)
                            if entry.canRollback {
                                Button {
                                    pendingRollback = entry
                                    showRollbackConfirmation = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.uturn.backward")
                                            .font(.system(size: 10, weight: .bold))
                                        Text("回滚")
                                            .font(.system(size: 11.5, weight: .bold))
                                    }
                                    .foregroundStyle(ManagerTheme.stopOrange)
                                    .padding(.horizontal, 12)
                                    .frame(height: 28)
                                    .background(ManagerTheme.amber.opacity(0.14), in: Capsule())
                                    .overlay(Capsule().stroke(ManagerTheme.amber.opacity(0.55), lineWidth: 1))
                                    .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .alert("回滚这条操作？", isPresented: $showRollbackConfirmation) {
            Button("取消", role: .cancel) { pendingRollback = nil }
            Button("回滚", role: .destructive) {
                guard let entry = pendingRollback else { return }
                do {
                    try ManagerStore.shared.rollbackOperation(entry)
                    refreshRecords()
                    vm.showToast(title: "操作已回滚", detail: entry.action)
                    Task { await vm.reloadAll() }
                } catch {
                    vm.showToast(title: "回滚失败", detail: error.localizedDescription, isError: true)
                }
                pendingRollback = nil
            }
        } message: {
            Text("将恢复 \(pendingRollback?.paths.count ?? 0) 处文件或配置。若文件已被其他操作修改，回滚会自动停止。回滚本身也会写入记录。")
        }
    }

    // MARK: - Section 4: AI Clients Environment
    private var clientsEnvironmentSection: some View {
        SettingsCard(title: "客户端与配置位置", icon: "cpu", iconColor: ManagerTheme.amber) {
            VStack(alignment: .leading, spacing: 12) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 390), spacing: 10)], spacing: 10) {
                    ForEach(Agent.allCases) { agent in
                        let installed = ManagerStore.shared.agentAvailability(agent)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                AgentLogo(agent: agent, size: 24)
                                Text(agent.rawValue)
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundStyle(ManagerTheme.primaryText)
                                Spacer()
                                Text(installed ? "已安装" : "未检测到安装")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(installed ? ManagerTheme.mint : ManagerTheme.secondaryText)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(installed ? ManagerTheme.mint.opacity(0.12) : ManagerTheme.insetBg, in: Capsule())
                            }
                            Divider()
                            ClientConfigPaths(title: "全局", skillPaths: agent.globalSkillRoots, mcpPath: agent.globalMCP.0)
                            ClientConfigPaths(title: "项目", skillPaths: agent.projectSkillRoots.map { "<项目目录>/" + $0 }, mcpPath: "<项目目录>/" + agent.projectMCP.0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                    }
                }
            }
        }
    }

    // MARK: - Section 5: About
    private var aboutSection: some View {
        SettingsCard(title: "关于 Looma", icon: "info.circle.fill", iconColor: ManagerTheme.electricBlue) {
            HStack(spacing: 16) {
                Image(nsImage: AgentArtwork.appIcon())
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Looma")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                        Text(appVersionText)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(ManagerTheme.electricBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ManagerTheme.electricBlue.opacity(0.1), in: Capsule())
                    }

                    Text("全 Agent 生态生产力技能与 MCP 工具统一管理平台 · 高效分发与版本同步")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }

                Spacer()

                Button {
                    vm.resetPreferencesToDefault()
                } label: {
                    Text("重置为默认设置")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, 14)
                        .frame(height: 34)
                        .background(Color.red.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Color.red.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
