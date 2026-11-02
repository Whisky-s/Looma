import AppKit
import SwiftUI

// MARK: - Community Preset Model
private struct GitCommunityPreset: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let url: String
    let branch: String?
    let subpath: String?
}

private let communityPresets: [GitCommunityPreset] = [
    GitCommunityPreset(
        title: "Anthropic Quickstarts",
        subtitle: "Anthropic 官方计算机使用与工具调用技能",
        url: "https://github.com/anthropics/anthropic-quickstarts",
        branch: "main",
        subpath: "skills"
    ),
    GitCommunityPreset(
        title: "Awesome Copilot",
        subtitle: "GitHub 官方 Agent 技能与指令模板合集",
        url: "https://github.com/github/awesome-copilot",
        branch: "main",
        subpath: ""
    ),
    GitCommunityPreset(
        title: "Skills Manager 社区库",
        subtitle: "精选多 Agent 通用生产力 Skill 集合",
        url: "https://github.com/xingkongliang/skills-manager",
        branch: "main",
        subpath: ""
    )
]

// MARK: - Git Skill Sheet View
struct GitSkillSheet: View {
    @ObservedObject var vm: AgentManagerViewModel
    @Environment(\.dismiss) private var dismiss

    // Configuration Inputs
    @State private var inputURL: String = ""
    @State private var branch: String = "master"
    @State private var subpath: String = ""
    @State private var customName: String = ""

    // State Tracking
    @State private var isLoading: Bool = false
    @State private var statusText: String = ""
    @State private var errorMessage: String? = nil
    @State private var recentRepositories: [GitRepositoryVisit] = []
    @State private var archiveStates: [String: GitArchiveState] = [:]
    @State private var importSummary: String?

    // Discovered Skills & Selection
    @State private var discoveredSkills: [DiscoveredGitSkill] = []
    @State private var selectedSkillRelativePaths: Set<String> = []
    @State private var filterQuery: String = ""
    @State private var tempClonedRoot: URL? = nil

    private var selectedRecentRepository: GitRepositoryVisit? {
        let repoURL = GitSkillService.reusableRepoURL(inputURL)
        return recentRepositories.first {
            $0.repoURL == repoURL && ($0.branch ?? "") == branch && ($0.subpath ?? "") == subpath
        }
    }

    // Filtered Skills
    private var filteredSkills: [DiscoveredGitSkill] {
        let q = filterQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return discoveredSkills }
        return discoveredSkills.filter {
            $0.name.lowercased().contains(q) ||
            $0.relativePath.lowercased().contains(q) ||
            $0.description.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            // Content Area
            if discoveredSkills.isEmpty {
                stage1ConfigurationView.disabled(isLoading)
            } else {
                stage2DiscoveryView.disabled(isLoading)
            }

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            // Bottom Actions Bar
            footerActionsBar
        }
        .frame(width: 880, height: 720)
        .background(Color.white)
        .toastNotification(vm: vm)
        .interactiveDismissDisabled(isLoading)
        .onAppear {
            branch = vm.defaultGitBranch
            recentRepositories = GitSkillService.shared.recentRepositories()
            if inputURL.isEmpty, let recent = recentRepositories.first { applyRecentRepository(recent) }
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ManagerTheme.electricBlue.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ManagerTheme.electricBlue)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("从 Git 仓库安装 Skill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ManagerTheme.primaryText)
                Text("支持 GitHub、GitLab、内网私有 Git 仓库，自动提取 SKILL.md 并归档至中央库")
                    .font(.system(size: 12))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }

            Spacer()

            Button {
                cleanupAndDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .padding(8)
                    .background(Color.black.opacity(0.04), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
        }
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 16)
    }

    // MARK: - Stage 1: Initial URL & Branch Input
    private var stage1ConfigurationView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                // Community Presets
                VStack(alignment: .leading, spacing: 10) {
                    Text("社区精选预设")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .tracking(1.0)
                        .textCase(.uppercase)

                    HStack(spacing: 10) {
                        ForEach(communityPresets) { preset in
                            Button {
                                applyPreset(preset)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11))
                                        .foregroundStyle(ManagerTheme.electricBlue)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(preset.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(ManagerTheme.primaryText)
                                    }
                                }
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !recentRepositories.isEmpty {
                    HStack {
                        Text("最近拉取的仓库")
                            .font(.system(size: 12, weight: .bold))
                        ManagerDropdown(
                            title: selectedRecentRepository.map { $0.repoURL + " · " + ($0.branch ?? "默认分支") } ?? "选择历史仓库（含分支）",
                            icon: "arrow.triangle.branch",
                            accessibilityLabel: "最近拉取的仓库",
                            options: recentRepositories.map {
                                ManagerDropdownOption(id: $0.id, title: $0.repoURL,
                                                      detail: ($0.branch ?? "默认分支") + ($0.subpath.map { " · " + $0 } ?? ""))
                            },
                            selectedID: selectedRecentRepository?.id
                        ) { id in
                            if let visit = recentRepositories.first(where: { $0.id == id }) {
                                applyRecentRepository(visit)
                            }
                        }
                        .frame(maxWidth: 360)
                    }
                }

                // Form Inputs
                VStack(alignment: .leading, spacing: 16) {
                    // Git URL
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Git 仓库地址 / GitHub 目录链接")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ManagerTheme.primaryText)
                            Spacer()
                            Button {
                                if let str = NSPasteboard.general.string(forType: .string) {
                                    inputURL = str
                                    handleURLChanged(str)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.clipboard")
                                        .font(.system(size: 10))
                                    Text("粘贴剪贴板")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundStyle(ManagerTheme.electricBlue)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(ManagerTheme.electricBlue.opacity(0.1), in: Capsule())
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        TextField("", text: $inputURL, prompt: Text("例如: http://172.16.162.150/group/repo.git 或 https://github.com/owner/repo"))
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, design: .monospaced))
                            .padding(.horizontal, 12)
                            .frame(height: 40)
                            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                            .onChange(of: inputURL) { _, val in
                                handleURLChanged(val)
                            }
                    }

                    // Branch & Subpath
                    HStack(spacing: 16) {
                        // Branch
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("分支 (Branch)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(ManagerTheme.primaryText)
                                Text("默认 master")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                            }

                            TextField("", text: $branch, prompt: Text("留空使用仓库默认分支"))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(.horizontal, 12)
                                .frame(height: 40)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                        }

                        // Subpath
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("子目录 (Subdirectory)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(ManagerTheme.primaryText)
                                Text("默认为空，全库扫描")
                                    .font(.system(size: 11))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                            }

                            TextField("", text: $subpath, prompt: Text("默认为空，检索全库 (推荐)"))
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(.horizontal, 12)
                                .frame(height: 40)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                        }
                    }
                }

                // Friendly Tip Box
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(ManagerTheme.electricBlue)
                            .font(.system(size: 13))
                        Text("归档特性说明")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("• **归档名称自动提取**：无需手动填写，克隆后将自动从各 Skill 的 `SKILL.md` 规范提取名称。")
                        Text("• **单项目与 Monorepo 多技能**：支持单个 Skill 仓库，亦支持包含几十个 Skill 的多模块大仓库。")
                        Text("• **安全快速浅克隆**：使用 `--depth 1` 浅克隆，避免下载冗余 Git 历史，速度更快。")
                    }
                    .font(.system(size: 11.5))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .lineSpacing(2)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))

                // Error Message
                if let err = errorMessage {
                    errorMessageBanner(err)
                }
            }
            .padding(28)
        }
    }

    // MARK: - Stage 2: Discovered Skills & Selection
    private var stage2DiscoveryView: some View {
        VStack(spacing: 14) {
            // Repo Summary Bar
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(ManagerTheme.mint)
                            .font(.system(size: 14))
                        Text("检索完成：共发现 \(discoveredSkills.count) 个 Skill 规范模块")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                    }
                    Text("仓库: \(inputURL)  ·  分支: \(branch.isEmpty ? "仓库默认分支" : branch)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    resetDiscovery()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 11))
                        Text("更换仓库 / 重新克隆")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Search Bar & Batch Selection Bar
            HStack(spacing: 12) {
                // Search Field
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)

                    TextField("在 \(discoveredSkills.count) 个 Skill 中搜索名称或路径...", text: $filterQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !filterQuery.isEmpty {
                        Button {
                            filterQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(ManagerTheme.secondaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.borderLine, lineWidth: 0.8))

                // Selection Actions
                Button("全选 (\(filteredSkills.count))") {
                    for s in filteredSkills {
                        selectedSkillRelativePaths.insert(s.relativePath)
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ManagerTheme.electricBlue)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(ManagerTheme.electricBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                Button("取消全选") {
                    selectedSkillRelativePaths.removeAll()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ManagerTheme.secondaryText)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.borderLine, lineWidth: 0.8))

                Text("已选 \(selectedSkillRelativePaths.count) 项")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(selectedSkillRelativePaths.isEmpty ? ManagerTheme.secondaryText : ManagerTheme.electricBlue)
                    .padding(.leading, 4)
            }
            .padding(.horizontal, 24)

            // If 1 skill selected: Show custom archive name field (default auto-extracted from git)
            if selectedSkillRelativePaths.count == 1,
               let selectedRel = selectedSkillRelativePaths.first,
               let skill = discoveredSkills.first(where: { $0.relativePath == selectedRel }) {
                HStack(spacing: 12) {
                    Text("中央库归档名称：")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)

                    TextField("", text: $customName, prompt: Text(skill.name))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(ManagerTheme.electricBlue.opacity(0.6), lineWidth: 1))

                    Text("(默认已从 git 提取，可直接修改)")
                        .font(.system(size: 11))
                        .foregroundStyle(ManagerTheme.secondaryText)

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ManagerTheme.electricBlue.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.electricBlue.opacity(0.2), lineWidth: 0.8))
                .padding(.horizontal, 24)
            } else if selectedSkillRelativePaths.count > 1 {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.badge.questionmark")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.electricBlue)
                    Text("批量归档 \(selectedSkillRelativePaths.count) 项：已归档项更新原归档，同名项替换，失效链接自动修复")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                .padding(.horizontal, 24)
            }

            if let importSummary {
                Text(importSummary)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ManagerTheme.electricBlue)
                    .padding(.horizontal, 24)
            }

            // Error Message (if any during install)
            if let err = errorMessage {
                errorMessageBanner(err)
                    .padding(.horizontal, 24)
            }

            // Scrollable Discovered Skills List
            ScrollView {
                LazyVStack(spacing: 8) {
                    if filteredSkills.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundStyle(ManagerTheme.secondaryText)
                            Text("未找到与 \"\(filterQuery)\" 匹配的 Skill")
                                .font(.system(size: 13))
                                .foregroundStyle(ManagerTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(filteredSkills) { skill in
                            let isSelected = selectedSkillRelativePaths.contains(skill.relativePath)
                            discoveredSkillRow(skill: skill, isSelected: isSelected)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Discovered Skill Row Card
    private func discoveredSkillRow(skill: DiscoveredGitSkill, isSelected: Bool) -> some View {
        Button {
            // Click row: toggle in selection or select single
            if selectedSkillRelativePaths.contains(skill.relativePath) {
                selectedSkillRelativePaths.remove(skill.relativePath)
                if let next = selectedSkillRelativePaths.first,
                   let nextSkill = discoveredSkills.first(where: { $0.relativePath == next }) {
                    customName = archiveStates[nextSkill.relativePath]?.name ?? nextSkill.name
                } else {
                    customName = ""
                }
            } else {
                selectedSkillRelativePaths.insert(skill.relativePath)
                customName = archiveStates[skill.relativePath]?.name ?? skill.name
            }
        } label: {
            HStack(spacing: 14) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(skill.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)

                        Text(skill.relativePath == "." ? "根目录" : skill.relativePath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(ManagerTheme.borderLine, lineWidth: 0.6))
                    }

                    if let state = archiveStates[skill.relativePath] {
                        Text(state.label + (state.name == skill.name ? "" : " · " + state.name))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(state.label.hasPrefix("已归档") ? Color.green : Color.orange)
                    }

                    Text(skill.description)
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .lineLimit(2)
                }

                Spacer()

                // Quick single-archive button
                Button {
                    selectedSkillRelativePaths = [skill.relativePath]
                    customName = archiveStates[skill.relativePath]?.name ?? skill.name
                    handleStartImport()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 11))
                        Text(archiveStates[skill.relativePath] == nil ? "单项归档" : "更新归档")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(ManagerTheme.electricBlue)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(ManagerTheme.electricBlue.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .opacity(isSelected ? 1.0 : 0.7)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? ManagerTheme.electricBlue.opacity(0.06) : Color.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? ManagerTheme.electricBlue : ManagerTheme.borderLine, lineWidth: isSelected ? 1.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer Actions Bar
    private var footerActionsBar: some View {
        HStack {
            if isLoading {
                HStack(spacing: 10) {
                    ProgressView().controlSize(.small)
                    Text(statusText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ManagerTheme.primaryText)
                }
            } else if !discoveredSkills.isEmpty {
                Text("已选 \(selectedSkillRelativePaths.count) / \(discoveredSkills.count) 个 Skill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }

            Spacer()

            Button("取消") {
                cleanupAndDismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(ManagerTheme.secondaryText)
            .padding(.horizontal, 18)
            .frame(height: 38)
            .background(ManagerTheme.insetBg, in: Capsule())
            .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 0.8))
            .keyboardShortcut(.cancelAction)
            .disabled(isLoading)

            Button {
                handleStartImport()
            } label: {
                HStack(spacing: 6) {
                    if discoveredSkills.isEmpty {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                        Text("检索并克隆")
                            .font(.system(size: 13, weight: .bold))
                    } else if selectedSkillRelativePaths.count > 1 {
                        Image(systemName: "square.and.arrow.down.on.square.fill")
                            .font(.system(size: 13))
                        Text("批量归档所选 (\(selectedSkillRelativePaths.count) 个 Skill)")
                            .font(.system(size: 13, weight: .bold))
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 13))
                        let nameToDisplay = customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? (discoveredSkills.first(where: { selectedSkillRelativePaths.contains($0.relativePath) })?.name ?? "所选项")
                            : customName
                        Text("确认归档入库 (\(nameToDisplay))")
                            .font(.system(size: 13, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 38)
                .background(isActionButtonDisabled ? Color.gray.opacity(0.35) : ManagerTheme.electricBlue, in: Capsule())
                .shadow(color: isActionButtonDisabled ? Color.clear : ManagerTheme.electricBlue.opacity(0.35), radius: 8, y: 3)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isActionButtonDisabled)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 16)
        .background(Color.white)
    }

    private var isActionButtonDisabled: Bool {
        if isLoading { return true }
        if discoveredSkills.isEmpty {
            return inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } else {
            return selectedSkillRelativePaths.isEmpty
        }
    }

    private func errorMessageBanner(_ err: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(err)
                .lineLimit(4)
                .help(err)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.red)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Logic & Actions
    private func applyRecentRepository(_ visit: GitRepositoryVisit) {
        inputURL = visit.repoURL
        branch = visit.branch ?? ""
        subpath = visit.subpath ?? ""
        customName = ""
        errorMessage = nil
    }

    private func refreshArchiveStates(repoURL: String, branch: String) {
        archiveStates = Dictionary(uniqueKeysWithValues: discoveredSkills.compactMap { skill in
            GitSkillService.shared.archiveState(for: skill, repoURL: repoURL, branch: branch).map { (skill.relativePath, $0) }
        })
    }

    private func applyPreset(_ preset: GitCommunityPreset) {
        inputURL = preset.url
        branch = preset.branch ?? ""
        subpath = preset.subpath ?? ""
        customName = ""
        errorMessage = nil
        discoveredSkills = []
        selectedSkillRelativePaths = []
    }

    private func handleURLChanged(_ url: String) {
        let res = GitSkillService.parseInputURL(url)
        if let b = res.branch, !b.isEmpty {
            branch = b
        }
        if let s = res.subpath, !s.isEmpty {
            subpath = s
        }
        // Do NOT set customName from repo name!
        // Skill archive name is strictly extracted from SKILL.md after git clone.
    }

    private func resetDiscovery() {
        if let root = tempClonedRoot {
            try? FileManager.default.removeItem(at: root)
            tempClonedRoot = nil
        }
        discoveredSkills = []
        selectedSkillRelativePaths = []
        filterQuery = ""
        customName = ""
        errorMessage = nil
        importSummary = nil
        archiveStates = [:]
    }

    private func handleStartImport() {
        let parsed = GitSkillService.parseInputURL(inputURL)
        let repoToUse = parsed.repoURL
        let branchToUse = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        let subpathToUse = subpath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : subpath.trimmingCharacters(in: .whitespacesAndNewlines)

        errorMessage = nil
        isLoading = true

        Task {
            do {
                if self.tempClonedRoot != nil, !discoveredSkills.isEmpty {
                    // Stage 2: Install selected skill(s)
                    let toInstall = discoveredSkills.filter { selectedSkillRelativePaths.contains($0.relativePath) }
                    guard !toInstall.isEmpty else {
                        throw ManagerError.invalid("请至少选择一个要归档的 Skill")
                    }

                    let requestedName = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let results = GitSkillService.shared.installSkills(
                        toInstall, repoURL: repoToUse, branch: branchToUse,
                        customName: toInstall.count == 1 && !requestedName.isEmpty ? requestedName : nil
                    ) { index, name in
                        statusText = "正在归档 [\(index + 1)/\(toInstall.count)] \(name)..."
                    }
                    let failures = results.filter { $0.error != nil }
                    let succeeded = results.count - failures.count
                    await MainActor.run {
                        isLoading = false
                        refreshArchiveStates(repoURL: repoToUse, branch: branchToUse)
                        importSummary = "归档完成：成功 \(succeeded) 项，失败 \(failures.count) 项"
                        if failures.isEmpty {
                            vm.showToast(title: "成功归档 \(succeeded) 个 Skill 到中央库", detail: "已有归档已更新")
                            cleanupAndDismiss()
                        } else {
                            errorMessage = failures.map { "\($0.skill.name)：\($0.error!)" }.joined(separator: "\n")
                            selectedSkillRelativePaths = Set(failures.map { $0.skill.relativePath })
                            if failures.count == 1 { customName = failures[0].archiveName }
                        }
                        Task { await vm.reloadAll() }
                    }
                    return
                }

                // Stage 1: Clone & Discover
                if let previousRoot = tempClonedRoot {
                    try? FileManager.default.removeItem(at: previousRoot)
                    tempClonedRoot = nil
                }
                let (tempRoot, discovered) = try await GitSkillService.shared.cloneAndDiscover(
                    repoURL: repoToUse,
                    branch: branchToUse
                ) { msg in
                    Task { @MainActor in
                        self.statusText = msg
                    }
                }

                self.tempClonedRoot = tempRoot
                try GitSkillService.shared.rememberRepository(repoURL: repoToUse, branch: branchToUse, subpath: subpathToUse)
                recentRepositories = GitSkillService.shared.recentRepositories()

                if discovered.isEmpty {
                    throw ManagerError.invalid("在克隆的仓库中未检索到包含 SKILL.md 的有效 Skill 规范目录")
                }

                await MainActor.run {
                    self.discoveredSkills = discovered
                    self.importSummary = nil
                    refreshArchiveStates(repoURL: repoToUse, branch: branchToUse)
                    if let sub = subpathToUse, !sub.isEmpty {
                        let matched = discovered.filter { $0.relativePath == sub || $0.relativePath.hasPrefix(sub) }
                        if !matched.isEmpty {
                            self.selectedSkillRelativePaths = Set(matched.map(\.relativePath))
                            if matched.count == 1 {
                                self.customName = archiveStates[matched[0].relativePath]?.name ?? matched[0].name
                            }
                        } else {
                            self.selectedSkillRelativePaths = [discovered[0].relativePath]
                            self.customName = archiveStates[discovered[0].relativePath]?.name ?? discovered[0].name
                        }
                    } else {
                        if let first = discovered.first {
                            self.selectedSkillRelativePaths = [first.relativePath]
                            self.customName = archiveStates[first.relativePath]?.name ?? first.name
                        }
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func cleanupAndDismiss() {
        if let root = tempClonedRoot {
            try? FileManager.default.removeItem(at: root)
            tempClonedRoot = nil
        }
        dismiss()
    }
}
