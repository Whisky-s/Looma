import AppKit
import SwiftUI

// MARK: - Item Detail Sheet View
struct ItemDetailSheet: View {
    @ObservedObject var vm: AgentManagerViewModel
    let item: DisplayItem
    let rows: [DisplayTarget]
    @Environment(\.dismiss) private var dismiss

    @State private var isUpdatingGit: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var cliCheckStatus: String? = nil
    @State private var isCheckingCLI: Bool = false
    @State private var showAdoptionSources = false
    @State private var showContentVersions = false

    private var skillFileURL: URL? {
        if let raw = item.rawSkill {
            let possible = ["SKILL.md", "skill.md", "Skill.md", "SKILL.MD", "README.md"]
            for name in possible {
                let target = raw.url.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: target.path) {
                    return target
                }
            }
            return raw.url.appendingPathComponent("SKILL.md")
        }
        let libFolder = ManagerStore.shared.skillsRoot.appendingPathComponent(item.name)
        let possible = ["SKILL.md", "skill.md", "Skill.md", "SKILL.MD", "README.md"]
        for name in possible {
            let target = libFolder.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: target.path) {
                return target
            }
        }
        return libFolder.appendingPathComponent("SKILL.md")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            // Two-Column Stage
            HStack(spacing: 0) {
                // Left Column: Document Reader / Code Config (530pt)
                VStack(spacing: 0) {
                    if !item.isSystemService {
                        Text("当前预览：" + (item.library ? "中央库" : (item.rawSkill?.source ?? item.rawMCP?.sourceLabel ?? "扫描来源")))
                            .font(.caption).foregroundStyle(.secondary).padding(10)
                    }
                    if item.isSkill {
                        SkillMarkdownPreviewView(fileURL: skillFileURL, fallbackText: item.detail)
                    } else if !item.isSystemService {
                        mcpDefinitionDetailView
                    } else {
                        Text("服务由 \(item.rawMCP?.bundledOwner?.rawValue ?? "所属应用") 提供。内置能力只读展示，不进入中央库，不参与跨客户端分发。")
                            .font(.system(size: 13))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .padding(24)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .frame(width: 530)
                .background(Color.white)

                Rectangle()
                    .fill(ManagerTheme.borderLine)
                    .frame(width: 1)

                // Right Column: Controls, Git Sync, Deployments (350pt)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Function Description
                        descriptionSection
                        if !item.isSystemService {
                            Button {
                                showContentVersions = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(ManagerTheme.electricBlue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("版本比较与替换")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(ManagerTheme.primaryText)
                                            if item.hasContentDifferences {
                                                HStack(spacing: 3) {
                                                    Circle().fill(ManagerTheme.amber).frame(width: 5, height: 5)
                                                    Text("有差异")
                                                        .font(.system(size: 9.5, weight: .bold))
                                                        .foregroundStyle(ManagerTheme.stopOrange)
                                                }
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 1.5)
                                                .background(ManagerTheme.amber.opacity(0.15), in: Capsule())
                                            }
                                        }
                                        Text("逐项查看各客户端实际内容，比对差异并定向替换")
                                            .font(.system(size: 10.5))
                                            .foregroundStyle(ManagerTheme.secondaryText)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(ManagerTheme.secondaryText)
                                }
                                .padding(10)
                                .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
                                .overlay(RoundedRectangle(cornerRadius: 9).stroke(item.hasContentDifferences ? ManagerTheme.amber.opacity(0.5) : ManagerTheme.borderLine, lineWidth: 1))
                                .contentShape(RoundedRectangle(cornerRadius: 9))
                            }
                            .buttonStyle(.plain)
                        }

                        // If unadopted: Adopt to central library button
                        if !item.library && !item.isSystemService {
                            adoptSection
                        }

                        // Git Sync Section (if git-sourced)
                        if let git = item.rawSkill?.gitSource {
                            Rectangle()
                                .fill(ManagerTheme.borderLine)
                                .frame(height: 1)
                            gitSourceSection(git)
                        }

                        Rectangle()
                            .fill(ManagerTheme.borderLine)
                            .frame(height: 1)

                        // Built-in capabilities have an owner, not deployment targets.
                        if item.isSystemService { BuiltinMCPInfoView(item: item, rows: rows) }
                        else { targetsSection }

                        Rectangle()
                            .fill(ManagerTheme.borderLine)
                            .frame(height: 1)

                        // Quick System Actions
                        if !item.isSystemService { quickActionsSection }
                    }
                    .padding(22)
                }
                .frame(maxWidth: .infinity)
                .background(ManagerTheme.canvasBg.opacity(0.3))
            }

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            // Footer
            footerView
        }
        .frame(width: 880, height: 700)
        .background(Color.white)
        .toastNotification(vm: vm)
        .sheet(isPresented: $showAdoptionSources) {
            AdoptionSheet(vm: vm, requestedName: item.name,
                          candidates: vm.adoptionCandidates(name: item.name))
        }
        .sheet(isPresented: $showContentVersions) { ContentVersionsSheet(vm: vm, item: item) }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((item.library ? ManagerTheme.indigo : ManagerTheme.amber).opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: item.isSkill ? "square.stack.3d.up.fill" : "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 22))
                    .foregroundStyle(item.library ? ManagerTheme.indigo : ManagerTheme.amber)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)

                    Text(item.isSkill ? "Skill 技能" : "MCP 服务")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.06), in: Capsule())
                        .foregroundStyle(ManagerTheme.secondaryText)

                    CapabilityTypeBadge(label: item.typeLabel)

                    if item.library {
                        Text("中央库已归档")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(ManagerTheme.indigo.opacity(0.12), in: Capsule())
                            .foregroundStyle(ManagerTheme.indigo)
                    } else if !item.isSystemService {
                        Text("外部扫描 · 待入库")
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(ManagerTheme.amber.opacity(0.15), in: Capsule())
                            .foregroundStyle(ManagerTheme.amber)
                    }

                    if item.hasGitSource {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.branch")
                                .font(.system(size: 9, weight: .bold))
                            Text("已关联 Git")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(ManagerTheme.electricBlue.opacity(0.12), in: Capsule())
                            .foregroundStyle(ManagerTheme.electricBlue)
                    }

                }

                if item.hasRuntimeOriginSummary {
                    CapabilityOriginSummary(item: item)
                }

                Text(item.isSkill ? "规范化 Agent 技能包，支持一键多目标部署与 Git 版本同步" : "Model Context Protocol 标准服务定义")
                    .font(.system(size: 11.5))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }

            Spacer()

            // Close Button
            Button {
                vm.selectedModalItem = nil
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .padding(8)
                    .background(Color.black.opacity(0.04), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    // MARK: - Right Column: Description
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("功能定位")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ManagerTheme.secondaryText)
                .tracking(1.0)
                .textCase(.uppercase)

            Text(item.detail)
                .font(.system(size: 12.5))
                .foregroundStyle(ManagerTheme.primaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Right Column: Adopt
    private var adoptSection: some View {
        Button {
            showAdoptionSources = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                Text("归档到中央库")
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .background(ManagerTheme.indigo, in: Capsule())
            .shadow(color: ManagerTheme.indigo.opacity(0.35), radius: 6, y: 2)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Right Column: Git Sync
    private func gitSourceSection(_ git: GitSourceInfo) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(ManagerTheme.electricBlue)
                    .font(.system(size: 12, weight: .bold))
                Text("Git 来源与同步")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .tracking(1.0)
                    .textCase(.uppercase)

                Spacer()

                Text("已连接 Git")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ManagerTheme.mint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(ManagerTheme.mint.opacity(0.12), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(git.repo)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(ManagerTheme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let b = git.branch {
                        Text("分支: \(b)")
                            .font(.system(size: 11))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }
                    if let s = git.subpath {
                        let cleanSub = s.replacingOccurrences(of: "/privateskills", with: "skills")
                                        .replacingOccurrences(of: "/private/", with: "")
                        Text("目录: \(cleanSub)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Button {
                    Task {
                        isUpdatingGit = true
                        await vm.updateSkillFromGit(name: item.name)
                        isUpdatingGit = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isUpdatingGit {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                        }
                        Text(isUpdatingGit ? "正在从 Git 同步更新..." : "从 Git 检查并拉取最新版本")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(ManagerTheme.electricBlue)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(ManagerTheme.electricBlue.opacity(0.1), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isUpdatingGit)
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
        }
    }

    // MARK: - Right Column: Target Deployments Matrix
    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("部署目标矩阵")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .tracking(1.0)
                    .textCase(.uppercase)

                let activeCount = rows.filter { $0.status == "已有配置" || $0.status == "配置已启用" }.count
                Text("\(activeCount) / \(rows.count) 已部署")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }

            VStack(spacing: 8) {
                ForEach(rows.map { vm.targetRow(for: item.name, target: $0.target, isSkill: item.isSkill) }) { row in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            AgentLogo(agent: row.target.agent, size: 18)
                            Text(row.target.agent.rawValue)
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundStyle(ManagerTheme.primaryText)
                            Spacer()
                            Text(row.target.project == nil ? "全局" : row.target.scopeName)
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.04), in: Capsule())
                                .foregroundStyle(ManagerTheme.secondaryText)
                        }

                        HStack {
                            Circle()
                                .fill(row.isEnabled ? ManagerTheme.mint : row.status.contains("停用") ? Color.orange : Color.gray.opacity(0.3))
                                .frame(width: 7, height: 7)
                            Text(row.status)
                                .font(.system(size: 11.5))
                                .foregroundStyle(ManagerTheme.secondaryText)

                            Spacer()

                            if let action = row.action {
                                HStack(spacing: 6) {
                                    TargetActionButton(action: action) {
                                        vm.performAction(item: item, row: row, mode: action)
                                    }
                                    if row.status == "已有配置" {
                                        TargetDeleteButton {
                                            vm.performAction(item: item, row: row, mode: "delete")
                                        }
                                    }
                                }
                            }
                        }
                        if let content = row.contentStatus {
                            HStack(spacing: 4) {
                                Image(systemName: content.contains("不同") ? "exclamationmark.circle.fill" : (content.contains("一致") ? "checkmark.circle.fill" : "info.circle.fill"))
                                    .font(.system(size: 9.5))
                                Text(content)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(content.contains("不同") ? ManagerTheme.stopOrange : (content.contains("一致") ? ManagerTheme.enableGreen : ManagerTheme.secondaryText))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((content.contains("不同") ? ManagerTheme.amber : (content.contains("一致") ? ManagerTheme.mint : Color.gray)).opacity(0.12), in: Capsule())
                        }
                    }
                    .padding(10)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                }
            }
        }
    }

    // MARK: - Right Column: Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快捷操作")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ManagerTheme.secondaryText)
                .tracking(1.0)
                .textCase(.uppercase)

            HStack(spacing: 8) {
                Button {
                    revealItem()
                } label: {
                    Label("访达定位", systemImage: "folder.fill")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(ManagerTheme.insetBg, in: Capsule())
                        .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    copyPath()
                } label: {
                    Label("复制路径", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(ManagerTheme.insetBg, in: Capsule())
                        .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                if item.library {
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        Label("移至废纸篓", systemImage: "trash.fill")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .background(Color.red.opacity(0.08), in: Capsule())
                            .overlay(Capsule().stroke(Color.red.opacity(0.3), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog(
                        "确定要将 '\(item.name)' 从中央库移至废纸篓吗？",
                        isPresented: $showDeleteConfirm,
                        titleVisibility: .visible
                    ) {
                        if vm.managedDeploymentCount(name: item.name, isSkill: item.isSkill) == 0 {
                            Button("移至废纸篓", role: .destructive) {
                                if vm.deleteFromLibrary(name: item.name, isSkill: item.isSkill) {
                                    vm.selectedModalItem = nil
                                    dismiss()
                                }
                            }
                        }
                        Button("取消", role: .cancel) {}
                    } message: {
                        let count = vm.managedDeploymentCount(name: item.name, isSkill: item.isSkill)
                        Text(count == 0 ? "只移除中央库文件；可从 macOS 废纸篓恢复。" : "该条目仍在 \(count) 处启用。请先停用这些位置，再删除中央库文件。")
                    }
                }
            }
        }
    }

    // MARK: - Left Column: MCP Definition Detail View
    private var mcpDefinitionDetailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                let isRemote = item.rawMCP?.definition["url"] != nil || item.rawMCP?.definition["serverUrl"] != nil
                HStack(spacing: 8) {
                    Image(systemName: isRemote ? "network" : "terminal.fill")
                        .foregroundStyle(isRemote ? ManagerTheme.indigo : ManagerTheme.electricBlue)
                    Text(isRemote ? "MCP 远程服务与网络配置" : "MCP 启动命令与本地环境")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    Spacer()
                }

                if let def = item.rawMCP?.definition {
                    // Remote Service Section (URL & Headers)
                    if let rawUrl = (def["url"] as? String) ?? (def["serverUrl"] as? String) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("远程服务地址 (Service URL):")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                                Spacer()
                                if let t = def["type"] as? String {
                                    Text(t)
                                        .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                        .foregroundStyle(ManagerTheme.indigo)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2.5)
                                        .background(ManagerTheme.indigo.opacity(0.12), in: Capsule())
                                }
                            }
                            HStack {
                                Text(rawUrl)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(ManagerTheme.primaryText)
                                    .lineLimit(2)
                                    .textSelection(.enabled)
                                Spacer()
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(rawUrl, forType: .string)
                                    vm.showToast(title: "已复制服务 URL", detail: rawUrl)
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 10))
                                        Text("复制")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundStyle(ManagerTheme.electricBlue)
                                    .padding(.horizontal, 8)
                                    .frame(height: 24)
                                    .background(ManagerTheme.electricBlue.opacity(0.08), in: Capsule())
                                    .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                                if let url = URL(string: rawUrl), url.scheme == "http" || url.scheme == "https" {
                                    Button {
                                        NSWorkspace.shared.open(url)
                                    } label: {
                                        Image(systemName: "safari")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(ManagerTheme.secondaryText)
                                            .frame(width: 24, height: 24)
                                            .background(Color.black.opacity(0.04), in: Circle())
                                            .contentShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                    .help("在浏览器中打开")
                                }
                            }
                            .padding(10)
                            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                        }

                        if let headers = (def["headers"] as? [String: String]) ?? (def["http_headers"] as? [String: String]), !headers.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("请求头 (Headers):")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(headers.keys.sorted(), id: \.self) { k in
                                        HStack {
                                            Text(k)
                                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                                .foregroundStyle(ManagerTheme.primaryText)
                                            Text(":")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(ManagerTheme.secondaryText)
                                            let val = headers[k] ?? ""
                                            let isSecret = k.lowercased().contains("auth") || k.lowercased().contains("token") || k.lowercased().contains("key")
                                            Text(isSecret ? "••••••••" : val)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundStyle(ManagerTheme.secondaryText)
                                            Spacer()
                                            Button {
                                                NSPasteboard.general.clearContents()
                                                NSPasteboard.general.setString(val, forType: .string)
                                                vm.showToast(title: "已复制 Header", detail: k)
                                            } label: {
                                                Image(systemName: "doc.on.doc")
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(ManagerTheme.secondaryText)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .padding(10)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.borderLine, lineWidth: 1))
                            }
                        }
                    }

                    if let cmd = def["command"] as? String {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("命令 (Command):").font(.system(size: 11.5, weight: .bold)).foregroundStyle(ManagerTheme.secondaryText)
                            HStack {
                                Text(cmd)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ManagerTheme.primaryText)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))

                                Spacer()

                                Button {
                                    checkCLI(cmd)
                                } label: {
                                    if isCheckingCLI {
                                        ProgressView().controlSize(.mini)
                                            .padding(.horizontal, 10)
                                            .frame(height: 28)
                                            .background(ManagerTheme.activePillBg, in: Capsule())
                                    } else {
                                        HStack(spacing: 4) {
                                            Image(systemName: "bolt.shield.fill")
                                                .font(.system(size: 10, weight: .bold))
                                            Text("检查环境")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        .foregroundStyle(ManagerTheme.electricBlue)
                                        .padding(.horizontal, 10)
                                        .frame(height: 28)
                                        .background(ManagerTheme.activePillBg, in: Capsule())
                                        .contentShape(Capsule())
                                    }
                                }
                                .buttonStyle(.plain)
                            }

                            if let status = cliCheckStatus {
                                Text(status)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(status.contains("✓") ? ManagerTheme.mint : Color.red)
                            }
                        }
                    }

                    if let args = def["args"] as? [String], !args.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("参数 (Arguments):").font(.system(size: 11.5, weight: .bold)).foregroundStyle(ManagerTheme.secondaryText)
                            Text(args.joined(separator: " "))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(ManagerTheme.primaryText)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    if let env = def["env"] as? [String: String], !env.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("环境变量 (Environment):").font(.system(size: 11.5, weight: .bold)).foregroundStyle(ManagerTheme.secondaryText)
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(env.keys.sorted(), id: \.self) { k in
                                    Text("\(k)=••••••")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(ManagerTheme.primaryText)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    // Full Raw JSON
                    VStack(alignment: .leading, spacing: 6) {
                        Text("原始配置 (JSON):").font(.system(size: 11.5, weight: .bold)).foregroundStyle(ManagerTheme.secondaryText)
                        JSONCodeBlockView(jsonString: ManagerStore.shared.redactedMCPContent(def))
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(item.isSystemService ? ManagerTheme.secondaryText : item.library ? ManagerTheme.indigo : ManagerTheme.amber)
                    .frame(width: 7, height: 7)
                Text(item.isSystemService ? "系统服务" : item.library ? "本地中央库资产" : "外部扫描待入库")
                    .font(.system(size: 11.5))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }

            Spacer()

            Button("完成") {
                vm.selectedModalItem = nil
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .frame(height: 36)
            .background(ManagerTheme.electricBlue, in: Capsule())
            .shadow(color: ManagerTheme.electricBlue.opacity(0.35), radius: 6, y: 2)
            .contentShape(Capsule())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(Color.white)
    }

    // MARK: - Actions
    private func revealItem() {
        let path: URL
        if item.isSkill {
            path = item.rawSkill?.url ?? ManagerStore.shared.skillsRoot.appendingPathComponent(item.name)
        } else {
            path = item.rawMCP?.source ?? ManagerStore.shared.mcpRoot.appendingPathComponent(item.name + ".json")
        }
        NSWorkspace.shared.activateFileViewerSelecting([path])
    }

    private func copyPath() {
        let path: String
        if item.isSkill {
            path = (item.rawSkill?.url ?? ManagerStore.shared.skillsRoot.appendingPathComponent(item.name)).path
        } else {
            path = (item.rawMCP?.source ?? ManagerStore.shared.mcpRoot.appendingPathComponent(item.name + ".json")).path
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        vm.showToast(title: "路径已复制到剪贴板", detail: path)
    }

    private func checkCLI(_ cmd: String) {
        isCheckingCLI = true
        cliCheckStatus = nil
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [cmd]
            var env = ProcessInfo.processInfo.environment
            env["PATH"] = "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin"
            process.environment = env
            let pipe = Pipe()
            process.standardOutput = pipe
            try? process.run()
            process.waitUntilExit()

            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            await MainActor.run {
                self.isCheckingCLI = false
                if process.terminationStatus == 0 && !output.isEmpty {
                    self.cliCheckStatus = "✓ 命令就绪: \(output)"
                } else {
                    self.cliCheckStatus = "✗ 未在 PATH 中找到 \(cmd)"
                }
            }
        }
    }
}
