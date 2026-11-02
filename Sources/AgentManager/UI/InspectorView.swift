import AppKit
import Foundation
import SwiftUI

struct InspectorView: View {
    @ObservedObject var vm: AgentManagerViewModel
    let item: DisplayItem
    let rows: [DisplayTarget]

    @State private var skillMarkdown: String = ""
    @State private var cliCheckStatus: String? = nil
    @State private var isCheckingCLI: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var isUpdatingGit: Bool = false
    @State private var showContentVersions = false

    init(vm: AgentManagerViewModel, item: DisplayItem, rows: [DisplayTarget]) {
        self.vm = vm
        self.item = item
        self.rows = rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Inspector Header
            HStack(alignment: .top) {
                HStack(spacing: 14) {
                    Image(systemName: item.isSkill ? "square.stack.3d.up.fill" : "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 22))
                        .foregroundStyle(item.library ? ManagerTheme.indigo : ManagerTheme.amber)
                        .frame(width: 44, height: 44)
                        .background((item.library ? ManagerTheme.indigo : ManagerTheme.amber).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(item.isSkill ? "Skill" : "MCP")
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
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        vm.detailPresentationMode = .modal
                        vm.selectedModalItem = item
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .padding(8)
                            .background(Color.black.opacity(0.05), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .help("展开为独立弹窗卡片 (推荐)")

                    Button {
                        vm.selectedItemName = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .padding(8)
                            .background(Color.black.opacity(0.05), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 40) // Generous top padding
            .padding(.bottom, 16)

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("功能说明")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .tracking(1.0)
                            .textCase(.uppercase)

                        Text(item.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(ManagerTheme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        if item.isSystemService {
                            Text("服务由 \(item.rawMCP?.bundledOwner?.rawValue ?? "所属应用") 提供。内置能力只读展示，不进入中央库，不参与跨客户端分发。")
                                .font(.system(size: 12))
                                .foregroundStyle(ManagerTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !item.library && !item.isSystemService {
                            Button {
                                vm.adoptToLibrary(name: item.name)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .bold))
                                    Text("归档到中央库")
                                        .font(.system(size: 13, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .frame(height: 36) // Big grand button
                                .background(ManagerTheme.indigo, in: Capsule())
                                .shadow(color: ManagerTheme.indigo.opacity(0.35), radius: 6, y: 2)
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                        }
                    }

                    // Content Breakdown
                    if item.isSkill {
                        skillContentSection
                    } else {
                        mcpContentSection
                    }

                    // Git Source Origin & Sync
                    if let git = item.rawSkill?.gitSource {
                        Rectangle()
                            .fill(ManagerTheme.borderLine)
                            .frame(height: 1)
                        gitSourceSection(git)
                    }

                    Rectangle()
                        .fill(ManagerTheme.borderLine)
                        .frame(height: 1)

                    // Quick System Actions
                    if !item.isSystemService { quickActionsSection }

                    Rectangle()
                        .fill(ManagerTheme.borderLine)
                        .frame(height: 1)

                    // Targets Deployment Matrix
                    if item.isSystemService { BuiltinMCPInfoView(item: item, rows: rows) }
                    else {
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
                                    Text("查看各客户端实际内容并定向替换")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(ManagerTheme.secondaryText)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                            }
                            .padding(10)
                            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(item.hasContentDifferences ? ManagerTheme.amber.opacity(0.5) : ManagerTheme.borderLine, lineWidth: 1))
                            .contentShape(RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)

                        targetsSection
                    }
                }
                .padding(22)
            }
        }
        .frame(width: 330)
        .background(Color.white)
        .sheet(isPresented: $showContentVersions) { ContentVersionsSheet(vm: vm, item: item) }
        .onAppear {
            loadSkillContent()
        }
        .onChange(of: item.name) {
            loadSkillContent()
            cliCheckStatus = nil
        }
    }

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

    // MARK: - Skill Content
    private var skillContentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SKILL.md 规范文档")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .tracking(1.0)
                    .textCase(.uppercase)

                Spacer()

                Button {
                    vm.detailPresentationMode = .modal
                    vm.selectedModalItem = item
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9.5))
                        Text("全屏阅读")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .foregroundStyle(ManagerTheme.electricBlue)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(ManagerTheme.electricBlue.opacity(0.08), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            SkillMarkdownPreviewView(fileURL: skillFileURL, fallbackText: skillMarkdown)
                .frame(height: 280)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 1))
        }
    }

    private func loadSkillContent() {
        guard item.isSkill else { return }
        Task.detached(priority: .userInitiated) {
            let fileURL: URL?
            if let skill = item.rawSkill {
                fileURL = skill.url.appendingPathComponent("SKILL.md")
            } else {
                fileURL = ManagerStore.shared.skillsRoot.appendingPathComponent(item.name).appendingPathComponent("SKILL.md")
            }
            if let url = fileURL, let text = try? String(contentsOf: url, encoding: .utf8) {
                await MainActor.run {
                    self.skillMarkdown = text
                }
            } else {
                await MainActor.run {
                    self.skillMarkdown = "未找到 SKILL.md 文件"
                }
            }
        }
    }

    // MARK: - MCP Content
    private var isRemoteMCP: Bool {
        item.rawMCP?.definition["url"] != nil || item.rawMCP?.definition["serverUrl"] != nil
    }

    private var mcpContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isRemoteMCP ? "远程服务配置" : "启动指令与参数")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ManagerTheme.secondaryText)
                .tracking(1.0)
                .textCase(.uppercase)

            if let def = item.rawMCP?.definition {
                if let rawUrl = (def["url"] as? String) ?? (def["serverUrl"] as? String) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text("Service URL:").font(.system(size: 11, weight: .semibold)).foregroundStyle(ManagerTheme.secondaryText)
                            Spacer()
                            if let t = def["type"] as? String {
                                Text(t)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ManagerTheme.indigo)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(ManagerTheme.indigo.opacity(0.12), in: Capsule())
                            }
                        }
                        Text(rawUrl)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(ManagerTheme.primaryText)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                            .textSelection(.enabled)
                    }

                    if let headers = (def["headers"] as? [String: String]) ?? (def["http_headers"] as? [String: String]), !headers.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Headers:").font(.system(size: 11, weight: .semibold)).foregroundStyle(ManagerTheme.secondaryText)
                            ForEach(headers.keys.sorted(), id: \.self) { key in
                                HStack {
                                    Text(key).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(ManagerTheme.primaryText)
                                    Spacer()
                                    let isSecret = key.lowercased().contains("key") || key.lowercased().contains("token") || key.lowercased().contains("auth")
                                    Text(isSecret ? "••••••••" : headers[key]!)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(ManagerTheme.secondaryText)
                                }
                                .padding(8)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }

                if let cmd = def["command"] as? String {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Command:").font(.system(size: 11, weight: .semibold)).foregroundStyle(ManagerTheme.secondaryText)
                        HStack {
                            Text(cmd)
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(ManagerTheme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))

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
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Arguments:").font(.system(size: 11, weight: .semibold)).foregroundStyle(ManagerTheme.secondaryText)
                        WrappingHStack(models: args) { arg in
                            Text(arg)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(ManagerTheme.primaryText)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                        }
                    }
                }

                if let env = def["env"] as? [String: String], !env.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Environment:").font(.system(size: 11, weight: .semibold)).foregroundStyle(ManagerTheme.secondaryText)
                        ForEach(env.keys.sorted(), id: \.self) { key in
                            HStack {
                                Text(key).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(ManagerTheme.primaryText)
                                Spacer()
                                Text(key.contains("KEY") || key.contains("TOKEN") || key.contains("SECRET") ? "••••••••" : env[key]!)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                            }
                            .padding(8)
                            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
            }
        }
    }

    private func checkCLI(_ cmd: String) {
        isCheckingCLI = true
        cliCheckStatus = nil
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = [cmd]
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

    // MARK: - Git Source Section
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

                Text("已关联 Git")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ManagerTheme.mint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(ManagerTheme.mint.opacity(0.12), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(git.repo)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(ManagerTheme.primaryText)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    if let b = git.branch {
                        Text("分支: \(b)")
                            .font(.system(size: 11))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }
                    if let s = git.subpath {
                        Text("目录: \(s)")
                            .font(.system(size: 11))
                            .foregroundStyle(ManagerTheme.secondaryText)
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
                        Text(isUpdatingGit ? "正在从 Git 同步..." : "从 Git 检查并拉取最新版本")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(ManagerTheme.electricBlue)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(ManagerTheme.electricBlue.opacity(0.1), in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isUpdatingGit)
                .padding(.top, 4)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
        }
    }

    // MARK: - Quick Actions (Large Generous Buttons)
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
                    Label("访达", systemImage: "folder.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(ManagerTheme.insetBg, in: Capsule())
                        .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    copyPath()
                } label: {
                    Label("路径", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
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
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 12)
                            .frame(height: 34)
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
                                vm.deleteFromLibrary(name: item.name, isSkill: item.isSkill)
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

    private func revealItem() {
        if item.isSkill {
            let url = item.rawSkill?.url ?? ManagerStore.shared.skillsRoot.appendingPathComponent(item.name)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            let url = item.rawMCP?.source ?? ManagerStore.shared.mcpRoot.appendingPathComponent(item.name + ".json")
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
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

    // MARK: - Targets Matrix
    private var targetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("分发目标状态")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .tracking(1.0)
                    .textCase(.uppercase)
                Spacer()
                Text("\(rows.count) 个目标")
                    .font(.system(size: 11))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }

            VStack(spacing: 8) {
                ForEach(rows) { row in
                    targetRowView(row)
                }
            }
        }
    }

    private func targetRowView(_ row: DisplayTarget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                AgentLogo(agent: row.target.agent, size: 18)
                Text(row.target.agent.rawValue)
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text(row.target.project == nil ? "全局" : row.target.scopeName)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.05), in: Capsule())
                    .foregroundStyle(ManagerTheme.secondaryText)
            }

            HStack {
                Circle()
                    .fill(row.isEnabled ? ManagerTheme.mint : row.status.contains("停用") ? Color.orange : Color.gray.opacity(0.3))
                    .frame(width: 7, height: 7)
                Text(row.status)
                    .font(.system(size: 12))
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
            if let content = vm.targetRow(for: item.name, target: row.target, isSkill: item.isSkill).contentStatus {
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
        .padding(12)
        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
    }
}

// Simple tag wrap layout helper
private struct WrappingHStack<Model: Hashable, V: View>: View {
    let models: [Model]
    let content: (Model) -> V

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(models, id: \.self) { model in
                    content(model)
                }
            }
        }
    }
}
