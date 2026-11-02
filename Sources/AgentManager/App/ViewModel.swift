import AppKit
import Combine
import Foundation
import SwiftUI

enum ViewMode: String, CaseIterable {
    case grid = "网格"
    case table = "列表"
}

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String?
    let isError: Bool
    let undoAction: (() -> Void)?

    init(title: String, detail: String? = nil, isError: Bool = false, undoAction: (() -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.isError = isError
        self.undoAction = undoAction
    }

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct DisplayTarget: Identifiable, Hashable {
    let target: Target
    let status: String
    let action: String?
    var managed: Bool = false
    var contentStatus: String? = nil
    var isEnabled: Bool { status == "配置已启用" || status == "已有配置" || status == "系统服务" }
    var id: String { target.id }

    static func == (lhs: DisplayTarget, rhs: DisplayTarget) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status && lhs.action == rhs.action && lhs.managed == rhs.managed && lhs.contentStatus == rhs.contentStatus
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(status)
    }
}

struct DisplayItem: Identifiable, Hashable {
    let name: String
    let detail: String
    let isSkill: Bool
    let library: Bool
    let installedCount: Int
    let targets: [DisplayTarget]
    let rawSkill: SkillItem?
    let rawMCP: MCPItem?

    var id: String { (isSkill ? "skill:" : "mcp:") + name }

    var gitSource: GitSourceInfo? {
        if let g = rawSkill?.gitSource { return g }
        if isSkill {
            let file = ManagerStore.shared.skillsRoot.appendingPathComponent(name).appendingPathComponent(".git-source.json")
            if let data = try? Data(contentsOf: file),
               let info = try? JSONDecoder().decode(GitSourceInfo.self, from: data) {
                return info
            }
        }
        return nil
    }

    var hasGitSource: Bool {
        gitSource != nil
    }

    var typeLabel: String {
        if isSkill { return library ? "中央库 Skill" : "用户 Skill" }
        if rawMCP?.isSystemService == true {
            return rawMCP?.bundledOwner.map { "\($0.rawValue) 内置 MCP" } ?? "应用包内 MCP"
        }
        return library ? "中央库 MCP" : "用户 MCP"
    }

    var isSystemService: Bool { !isSkill && rawMCP?.isSystemService == true }

    /// Runtime origin counts are separate from `library`: a central-library item
    /// can still have an older, client-owned configuration with the same name.
    var managedTargetCount: Int {
        targets.filter { $0.managed }.count
    }

    var externalTargetCount: Int {
        targets.filter { $0.status == "已有配置" }.count
    }

    var systemTargetCount: Int {
        targets.filter { $0.status == "系统服务" }.count
    }

    var hasRuntimeOriginSummary: Bool {
        managedTargetCount > 0 || externalTargetCount > 0 || systemTargetCount > 0
    }

    var hasContentDifferences: Bool {
        targets.contains { $0.contentStatus == "与中央库不同" || $0.contentStatus == "同名内容不同" }
    }

    static func == (lhs: DisplayItem, rhs: DisplayItem) -> Bool {
        lhs.id == rhs.id &&
            lhs.installedCount == rhs.installedCount &&
            lhs.library == rhs.library &&
            lhs.hasGitSource == rhs.hasGitSource &&
            lhs.managedTargetCount == rhs.managedTargetCount &&
            lhs.externalTargetCount == rhs.externalTargetCount &&
            lhs.systemTargetCount == rhs.systemTargetCount && lhs.targets == rhs.targets && lhs.detail == rhs.detail
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct AdoptionCandidate: Identifiable {
    let id: String
    let name: String
    let isSkill: Bool
    let source: String
    let path: String
    let summary: String
    let contentFingerprint: String
    let skillURL: URL?
    let mcpDefinition: [String: Any]?
}

struct AdoptionResult {
    var imported: [String] = []
    var failed: [String] = []
}

// MARK: - Detail Presentation Mode (Modal vs Sidebar)
enum DetailPresentationMode: String, CaseIterable, Identifiable {
    case modal = "modal"
    case sidebar = "sidebar"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .modal: return "弹窗卡片 (默认)"
        case .sidebar: return "右侧抽屉"
        }
    }
}

enum SkillDeploymentMode: String, CaseIterable, Identifiable {
    case link
    case copy

    var id: String { rawValue }
}

@MainActor
final class AgentManagerViewModel: ObservableObject {
    static let shared = AgentManagerViewModel()

    private let store: ManagerStore

    // MARK: - Navigation & Filter States
    @Published var page: Int = 0 // 0: Skills, 1: MCP, 2: Projects
    @Published var selectedAgent: Agent? = nil
    @Published var selectedProject: String? = nil
    @Published var selectedItemName: String? = nil
    @Published var selectedModalItem: DisplayItem? = nil

    @Published var detailPresentationMode: DetailPresentationMode = {
        let saved = UserDefaults.standard.string(forKey: "detailPresentationMode") ?? DetailPresentationMode.modal.rawValue
        return DetailPresentationMode(rawValue: saved) ?? .modal
    }() {
        didSet {
            UserDefaults.standard.set(detailPresentationMode.rawValue, forKey: "detailPresentationMode")
        }
    }

    @Published var query: String = ""
    @Published var statusFilter: Int = 0 // 0: 全部, 1: 已启用, 2: 可启用, 3: 已关联 Git
    @Published var sourceFilter: Int = 0 // 0: 全部, 1: 仅中央库, 2: 仅待入库
    @Published var viewMode: ViewMode = .grid

    func navigateToClient(_ agent: Agent) {
        selectedAgent = agent
        selectedProject = nil
        selectedItemName = nil
        sourceFilter = 0
        if page >= 2 { page = 0 }
    }

    func selectItem(_ item: DisplayItem) {
        selectedItemName = item.name
        if detailPresentationMode == .modal {
            selectedModalItem = item
        } else {
            selectedModalItem = nil
        }
    }

    // MARK: - App Preferences & System Settings
    @Published var defaultGitBranch: String = {
        UserDefaults.standard.string(forKey: "defaultGitBranch") ?? "master"
    }() {
        didSet {
            UserDefaults.standard.set(defaultGitBranch, forKey: "defaultGitBranch")
        }
    }

    @Published var defaultMarkdownMode: Int = {
        UserDefaults.standard.integer(forKey: "defaultMarkdownMode")
    }() {
        didSet {
            UserDefaults.standard.set(defaultMarkdownMode, forKey: "defaultMarkdownMode")
        }
    }

    @Published var enableShallowClone: Bool = {
        if UserDefaults.standard.object(forKey: "enableShallowClone") == nil { return true }
        return UserDefaults.standard.bool(forKey: "enableShallowClone")
    }() {
        didSet {
            UserDefaults.standard.set(enableShallowClone, forKey: "enableShallowClone")
        }
    }

    @Published var skillDeploymentMode: SkillDeploymentMode = {
        let saved = UserDefaults.standard.string(forKey: "skillDeploymentMode") ?? SkillDeploymentMode.link.rawValue
        return SkillDeploymentMode(rawValue: saved) ?? .link
    }() {
        didSet {
            UserDefaults.standard.set(skillDeploymentMode.rawValue, forKey: "skillDeploymentMode")
        }
    }

    func cleanTempGitClones() {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory
        var cleanedCount = 0
        if let contents = try? fm.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for item in contents {
                if item.lastPathComponent.hasPrefix("AgentManagerGit-") {
                    try? fm.removeItem(at: item)
                    cleanedCount += 1
                }
            }
        }
        showToast(title: "临时克隆缓存清理完成", detail: "已安全释放 \(cleanedCount) 个历史临时目录")
    }

    func resetPreferencesToDefault() {
        detailPresentationMode = .modal
        defaultGitBranch = "master"
        defaultMarkdownMode = 0
        enableShallowClone = true
        skillDeploymentMode = .link
        showToast(title: "偏好设置已重置为默认", detail: "Skill 启用方式已恢复为软链接")
    }

    // MARK: - Data States
    @Published var isScanning: Bool = false
    @Published var librarySkills: [SkillItem] = []
    @Published var installedSkills: [SkillItem] = []
    @Published var libraryMCP: [MCPItem] = []
    @Published var installedMCP: [MCPItem] = []
    @Published var deployments: [Deployment] = []
    @Published var disabledItems: [DisabledItem] = []
    @Published var projects: [String] = []

    // MARK: - Toast & Modal States
    @Published var activeToast: ToastMessage? = nil
    @Published var showNewMCPSheet: Bool = false
    @Published var editingMCPItem: MCPItem? = nil
    @Published var showGitImportSheet: Bool = false
    @Published var adoptionRequest: String? = nil
    @Published var showAdoptionSheet: Bool = false

    var hasPresentedSheet: Bool {
        selectedModalItem != nil || showNewMCPSheet || showGitImportSheet || showAdoptionSheet
    }

    @Published var configurationStates: [String: CapabilityState] = [:]
    @Published var contentVersionSnapshot: [String: [ContentVersion]] = [:]
    private var syncSubscriptions = Set<AnyCancellable>()
    private var syncCheckpoint: String?
    private var checkingSync = false
    private var rescanRequested = false

    private func checkSynchronization() async {
        guard !checkingSync else { return }
        checkingSync = true
        defer { checkingSync = false }
        let store = self.store
        let checkpoint = await Task.detached { store.synchronizationCheckpoint() }.value
        if checkpoint != syncCheckpoint { await reloadAll() }
    }

    private var toastDismissTask: Task<Void, Never>? = nil

    init(store: ManagerStore = .shared) {
        self.store = store
        Timer.publish(every: 2, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in Task { await self?.checkSynchronization() } }
            .store(in: &syncSubscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in Task { await self?.reloadAll() } }
            .store(in: &syncSubscriptions)
        Task { [weak self] in
            await self?.reloadAll()
        }
    }

    // MARK: - Async Scanning & Loading
    func reloadAll() async {
        guard !isScanning else { rescanRequested = true; return }
        isScanning = true
        defer {
            isScanning = false
            if rescanRequested { rescanRequested = false; Task { await reloadAll() } }
        }

        let baseStore = self.store
        let (libSkills, instSkills, libM, instM, deps, disList, projs, states, checkpoint, versions) = await Task.detached(priority: .userInitiated) {
            let checkpoint = baseStore.synchronizationCheckpoint()
            let ls = baseStore.librarySkills()
            let iskills = baseStore.installedSkills()
            let lm = baseStore.libraryMCP()
            let im = baseStore.installedMCP()
            let d = baseStore.deployments()
            let dis = baseStore.disabledItems()
            let p = baseStore.projects()
            return (ls, iskills, lm, im, d, dis, p, baseStore.synchronizationStates(), checkpoint,
                    baseStore.contentSnapshot(skills: ls + iskills, mcps: lm + im))
        }.value

        self.dataGeneration += 1
        self.configurationStates = states
        self.contentVersionSnapshot = versions
        self.syncCheckpoint = checkpoint
        self.librarySkills = libSkills
        self.installedSkills = instSkills
        self.libraryMCP = libM
        self.installedMCP = instM
        self.deployments = deps
        self.disabledItems = disList
        self.projects = projs
        if let selectedAgent, !store.agentAvailability(selectedAgent) { self.selectedAgent = nil }
    }

    // MARK: - Computed Counts & Central Library Separation
    var availableAgents: [Agent] { Agent.allCases.filter { store.agentAvailability($0) } }
    var librarySkillCount: Int { librarySkills.count }
    var libraryMCPCount: Int { libraryMCP.count }
    var gitLinkedSkillCount: Int {
        Set((librarySkills + installedSkills).filter { $0.gitSource != nil }.map(\.name)).count
    }
    var totalSkillCount: Int { Set(librarySkills.map(\.name) + installedSkills.map(\.name)).count }
    var totalMCPCount: Int { Set(libraryMCP.map(\.name) + installedMCP.map(\.name)).count }

    var unadoptedSkillCount: Int {
        let libNames = Set(librarySkills.map(\.name))
        return Set(installedSkills.map(\.name).filter { !libNames.contains($0) }).count
    }

    var unadoptedMCPCount: Int {
        let libNames = Set(libraryMCP.map(\.name))
        return Set(installedMCP.filter { !$0.isSystemService }.map(\.name).filter { !libNames.contains($0) }).count
    }

    var currentUnadoptedCount: Int {
        page == 0 ? unadoptedSkillCount : unadoptedMCPCount
    }

    var currentInstalledCount: Int {
        if page == 0 {
            return installedSkills.count
        } else if page == 1 {
            return installedMCP.count
        }
        return 0
    }

    func targetRow(for name: String, target: Target, isSkill: Bool) -> DisplayTarget {
        let kind = isSkill ? "skill" : "mcp"
        let deployed = deployments.contains { $0.kind == kind && $0.item == name && $0.targetID == target.id }
        let bundled = !isSkill && (installedMCP.first { $0.name == name && $0.agent == target.agent && $0.project == target.project }?.isSystemService ?? false)
        let restrictedLibrary = !isSkill && (libraryMCP.first { $0.name == name }?.isSystemService ?? false)
        if !isSkill,
           let systemItem = installedMCP.first(where: { $0.name == name && $0.agent == target.agent && $0.project == target.project }),
           systemItem.isProtectedSystemService(in: target.agent, managed: deployed) {
            let state = configurationStates[syncKey(name, target: target, skill: false)] ?? .unknown
            return DisplayTarget(target: target, status: state == .disabled ? "客户端已停用" : state == .configured ? "系统服务" : "状态未知", action: nil)
        }
        let disabled = disabledItems.contains { $0.kind == kind && $0.item == name && $0.targetID == target.id }
        let exists = isSkill
            ? installedSkills.contains { $0.name == name && $0.agent == target.agent && $0.project == target.project }
            : installedMCP.contains { $0.name == name && $0.agent == target.agent && $0.project == target.project }
        let inLibrary = isSkill
            ? librarySkills.contains { $0.name == name }
            : libraryMCP.contains { $0.name == name }

        let statusText: String
        let actionKey: String?

        let actual = configurationStates[syncKey(name, target: target, skill: isSkill)] ?? (exists ? .configured : .missing)
        if actual == .unknown {
            statusText = "状态未知"
            actionKey = nil
        } else if actual == .disabled {
            statusText = "客户端已停用"
            actionKey = bundled ? (deployed ? "remove" : "disable") : (isSkill ? "enableClientSkill" : "enableClientMCP")
        } else if deployed && actual == .missing {
            statusText = "目标已移除"
            actionKey = "reconcile"
        } else if deployed && exists {
            statusText = "配置已启用"
            actionKey = "remove"
        } else if exists {
            // A client can recreate a configuration after Looma stashed it.
            // The current configuration takes precedence over that historical backup.
            statusText = "已有配置"
            actionKey = "disable"
        } else if disabled {
            statusText = restrictedLibrary ? "副本已停用" : "已停用"
            actionKey = restrictedLibrary ? nil : "restore"
        } else if !store.agentAvailability(target.agent) {
            statusText = "未安装"
            actionKey = nil
        } else if restrictedLibrary {
            statusText = "禁止跨应用分发"
            actionKey = nil
        } else {
            statusText = "未启用"
            actionKey = inLibrary ? "add" : nil
        }

        return DisplayTarget(target: target, status: statusText, action: actionKey, managed: deployed,
                             contentStatus: contentRelation(contentVersionSnapshot[(isSkill ? "skill:" : "mcp:") + name] ?? [], target: target))
    }

    private struct DisplayItemsKey: Equatable {
        let generation: Int
        let page: Int
        let query: String
        let statusFilter: Int
        let sourceFilter: Int
        let selectedAgent: Agent?
        let selectedProject: String?
        let availableAgents: [Agent]
    }
    private var dataGeneration = 0
    private var displayItemsCache: (key: DisplayItemsKey, items: [DisplayItem])?

    /// 列表会在一次渲染中被多次读取，且条目描述需要读取 SKILL.md；数据或筛选不变时复用结果。
    var displayItems: [DisplayItem] {
        let key = DisplayItemsKey(generation: dataGeneration, page: page, query: query, statusFilter: statusFilter,
                                  sourceFilter: sourceFilter, selectedAgent: selectedAgent, selectedProject: selectedProject,
                                  availableAgents: availableAgents)
        if let cache = displayItemsCache, cache.key == key { return cache.items }
        let items = computeDisplayItems()
        displayItemsCache = (key, items)
        return items
    }

    private func computeDisplayItems() -> [DisplayItem] {
        guard page != 2 else { return [] }
        let isSkill = page == 0
        let availableAgents = self.availableAgents

        let names: Set<String>
        if isSkill {
            names = Set(librarySkills.map(\.name) + installedSkills.map(\.name) + deployments.filter { $0.kind == "skill" }.map(\.item) + disabledItems.filter { $0.kind == "skill" }.map(\.item))
        } else {
            names = Set(libraryMCP.map(\.name) + installedMCP.map(\.name) + deployments.filter { $0.kind == "mcp" }.map(\.item) + disabledItems.filter { $0.kind == "mcp" }.map(\.item))
        }

        let all: [DisplayItem] = names.sorted().map { name in
            if isSkill {
                let local = installedSkills.filter { $0.name == name }
                let lib = librarySkills.first { $0.name == name }
                let targets = availableAgents.map { targetRow(for: name, target: Target(agent: $0, project: selectedProject), isSkill: true) }
                return DisplayItem(
                    name: name,
                    detail: lib?.description ?? local.first?.description ?? "已停用的 Skill",
                    isSkill: true,
                    library: lib != nil,
                    installedCount: local.count,
                    targets: targets,
                    rawSkill: lib ?? local.first,
                    rawMCP: nil
                )
            } else {
                let local = installedMCP.filter { $0.name == name }
                let lib = libraryMCP.first { $0.name == name && !$0.isSystemService }
                let builtin = local.first { $0.isSystemService && $0.bundledOwner == $0.agent }
                let targets = builtin.map { origin in
                    local.filter { $0.agent == origin.agent }.compactMap { source -> DisplayTarget? in
                        guard let agent = source.agent else { return nil }
                        return targetRow(for: name, target: Target(agent: agent, project: source.project), isSkill: false)
                    }
                } ?? availableAgents.map { targetRow(for: name, target: Target(agent: $0, project: selectedProject), isSkill: false) }
                return DisplayItem(
                    name: name,
                    detail: lib?.summary ?? local.first?.summary ?? "已停用的 MCP Server",
                    isSkill: false,
                    library: lib != nil,
                    installedCount: local.count,
                    targets: targets,
                    rawSkill: nil,
                    rawMCP: lib ?? builtin ?? local.first(where: { !$0.isSystemService }) ?? local.first
                )
            }
        }

        return all.filter { item in
            let matchesSearch = query.isEmpty ||
                item.name.localizedCaseInsensitiveContains(query) ||
                item.detail.localizedCaseInsensitiveContains(query) ||
                (item.gitSource?.repo.localizedCaseInsensitiveContains(query) == true) ||
                (query.trimmingCharacters(in: .whitespaces).lowercased() == "git" && item.hasGitSource)

            let scoped = item.targets.filter { selectedAgent == nil || $0.target.agent == selectedAgent }
            let active = scoped.contains { $0.isEnabled }
            let matchesAgent = selectedAgent == nil || item.library || scoped.contains { $0.status != "未启用" && $0.status != "未安装" }
            let matchesProject = selectedProject == nil || item.library || scoped.contains { $0.status != "未启用" && $0.status != "未安装" }
            let matchesStatus: Bool
            switch statusFilter {
            case 1:
                matchesStatus = active
            case 2:
                matchesStatus = scoped.contains { $0.action == "add" }
            case 3:
                matchesStatus = item.hasGitSource
            default:
                matchesStatus = true
            }
            let matchesSource = sourceFilter == 0 || (sourceFilter == 1 ? item.library : !item.library && !item.isSystemService)

            return matchesSearch && matchesAgent && matchesProject && matchesStatus && matchesSource
        }
    }

    func openAdoption(name: String? = nil) {
        adoptionRequest = name
        showAdoptionSheet = true
    }

    func loadContentVersions(for item: DisplayItem) async -> [ContentVersion] {
        let store = self.store
        return await Task.detached { store.contentVersions(item.name, skill: item.isSkill) }.value
    }

    func saveContentVersion(_ version: ContentVersion, as name: String) async throws {
        let store = self.store
        try await Task.detached { try store.archiveContentVersion(version, as: name) }.value
        await reloadAll()
        showToast(title: "已另存到中央库", detail: name)
    }

    func replaceContentVersion(from source: ContentVersion, to target: ContentVersion) async throws {
        let store = self.store
        try await Task.detached { try store.replaceContentVersion(from: source, to: target) }.value
        await reloadAll()
        showToast(title: "已替换所选版本", detail: "\(target.label) · 可在操作记录中回滚；客户端可能需要重新加载")
    }

    func adoptionCandidates(name: String? = nil) -> [AdoptionCandidate] {
        if page == 0 {
            let existing = Set(librarySkills.map(\.name))
            return installedSkills.filter { !existing.contains($0.name) && (name == nil || $0.name == name) }
                .map { item in
                    AdoptionCandidate(id: "skill|\(item.name)|\(item.source)|\(item.url.path)", name: item.name,
                                      isSkill: true, source: item.source, path: item.url.path,
                                      summary: item.description, contentFingerprint: store.skillContentFingerprint(item.url),
                                      skillURL: item.url, mcpDefinition: nil)
                }
        }
        let existing = Set(libraryMCP.map(\.name))
        return installedMCP.filter { !$0.isSystemService && !existing.contains($0.name) && (name == nil || $0.name == name) }
            .map { item in
                AdoptionCandidate(id: "mcp|\(item.name)|\(item.sourceLabel)|\(item.source.path)", name: item.name,
                                  isSkill: false, source: item.sourceLabel, path: item.source.path,
                                  summary: item.summary, contentFingerprint: store.mcpContentFingerprint(item.definition),
                                  skillURL: nil, mcpDefinition: item.definition)
            }
    }

    func adoptCandidates(_ candidates: [AdoptionCandidate]) -> AdoptionResult {
        var result = AdoptionResult()
        for candidate in candidates {
            do {
                if let url = candidate.skillURL {
                    try store.importSkill(url)
                } else if let definition = candidate.mcpDefinition {
                    try store.importMCP(name: candidate.name, definition: definition)
                } else {
                    throw ManagerError.invalid("来源内容已不可用")
                }
                result.imported.append(candidate.name)
            } catch {
                result.failed.append("\(candidate.name) · \(candidate.source)：\(error.localizedDescription)")
            }
        }
        Task { await reloadAll() }
        return result
    }

    var selectedDisplayItem: DisplayItem? {
        guard let name = selectedItemName else { return nil }
        return displayItems.first { $0.name == name }
    }

    var inspectorTargetRows: [DisplayTarget] {
        guard let selected = selectedItemName, page != 2 else { return [] }
        let isSkill = page == 0

        let targets: [Target] = availableAgents.filter { selectedAgent == nil || $0 == selectedAgent }.flatMap { a in
            ([Target(agent: a, project: nil)] + projects.map { Target(agent: a, project: $0) })
                .filter { selectedProject == nil || $0.project == selectedProject }
        }
        if let item = selectedDisplayItem, item.isSystemService {
            return item.targets.filter { selectedAgent == nil || $0.target.agent == selectedAgent }
        }
        return targets.map { targetRow(for: selected, target: $0, isSkill: isSkill) }
    }

    // MARK: - Actions & Non-blocking Operations with Toast Undo
    func performAction(item: DisplayItem, row: DisplayTarget, mode: String) {
        let isSkill = item.isSkill
        let name = item.name
        let target = row.target

        do {
            // Recheck the current client configuration before interpreting a cached button.
            let actual = try store.capabilityState(name, target: target, skill: isSkill)
            if mode == "reconcile" {
                guard actual == .missing else { throw ManagerError.conflict("客户端配置已变化，请等待状态刷新后重试") }
                if isSkill { try store.removeSkill(name, from: target) } else { try store.removeMCP(name, from: target) }
                showToast(title: "已清理失效记录", detail: target.label)
                Task { await reloadAll() }
                return
            }
            if mode == "enableClientSkill" || mode == "enableClientMCP" {
                if isSkill { try store.enableClientSkill(name, target: target) }
                else { try store.enableClientMCP(name, target: target) }
                showToast(title: "启用配置已更新", detail: "客户端可能需要重新加载 · \(target.label)")
                Task { await reloadAll() }
                return
            }
            let removingManaged = mode == "remove" && store.deployments().contains { $0.kind == (isSkill ? "skill" : "mcp") && $0.item == name && $0.targetID == target.id }
            guard (actual != .disabled || removingManaged) && actual != .unknown else {
                throw ManagerError.conflict("客户端状态已变化，请等待状态刷新后重试")
            }
            if isSkill {
                switch mode {
                case "restore":
                    try store.restoreExistingSkill(name, to: target)
                    showToast(title: "已恢复 \(name)", detail: target.label) { [weak self] in
                        self?.runUndo { try $0.disableExistingSkill(name, from: target) }
                    }
                case "remove":
                    let wasCopy = store.deployments().first {
                        $0.kind == "skill" && $0.item == name && $0.targetID == target.id
                    }.map { $0.fingerprint != store.skillsRoot.appendingPathComponent(name).path } ?? false
                    try store.removeSkill(name, from: target)
                    showToast(title: "已停用 \(name)", detail: target.label) { [weak self] in
                        self?.runUndo { try $0.deploySkill(name, to: target, copy: wasCopy) }
                    }
                case "disable":
                    try store.disableExistingSkill(name, from: target)
                    showToast(title: "已停用原配置 \(name)", detail: target.label) { [weak self] in
                        self?.runUndo { try $0.restoreExistingSkill(name, to: target) }
                    }
                case "delete":
                    try store.deleteExistingSkill(name, from: target)
                    showToast(title: "已删除用户配置 \(name)", detail: target.label)
                case "add":
                    let copy = skillDeploymentMode == .copy
                    try store.deploySkill(name, to: target, copy: copy)
                    showToast(title: copy ? "已复制启用 \(name)" : "已软链接启用 \(name)", detail: target.label) { [weak self] in
                        self?.runUndo { try $0.removeSkill(name, from: target) }
                    }
                default:
                    throw ManagerError.invalid("未知的 Skill 操作")
                }
            } else {
                switch mode {
                case "restore":
                    try store.restoreExistingMCP(name, to: target)
                    showToast(title: "已恢复 \(name)", detail: target.label) { [weak self] in
                        self?.runUndo { try $0.disableExistingMCP(name, from: target) }
                    }
                case "remove":
                    if store.installedMCP().first(where: { $0.name == name && $0.agent == target.agent && $0.project == target.project })?.isSystemService == true {
                        let previous = Set(store.operationHistory().map(\.id))
                        try store.disableExistingMCP(name, from: target, preserveManagedConfiguration: true)
                        let operation = store.operationHistory().first { !previous.contains($0.id) && $0.canRollback }
                        showToast(title: "已停用本应用分发的 \(name)", detail: target.label) { [weak self] in
                            guard let self, let operation else { return }
                            do { try self.store.rollbackOperation(operation) }
                            catch { self.showToast(title: "撤销失败", detail: error.localizedDescription, isError: true) }
                            Task { await self.reloadAll() }
                        }
                        Task { await reloadAll() }
                        return
                    }
                    try store.disableExistingMCP(name, from: target, preserveManagedConfiguration: true)
                    showToast(title: "已停用 \(name)", detail: target.label) { [weak self] in
                        self?.runUndo { try $0.restoreExistingMCP(name, to: target) }
                    }
                case "disable":
                    try store.disableExistingMCP(name, from: target)
                    showToast(title: "已停用原配置 \(name)", detail: target.label) { [weak self] in
                        self?.runUndo { try $0.restoreExistingMCP(name, to: target) }
                    }
                case "delete":
                    try store.deleteExistingMCP(name, from: target)
                    showToast(title: "已删除用户配置 \(name)", detail: target.label)
                default: // deploy
                    try store.deployMCP(name, to: target)
                    showToast(title: "已启用 \(name)", detail: target.label) { [weak self] in
                        self?.runUndo { try $0.removeMCP(name, from: target) }
                    }
                }
            }
            Task { await reloadAll() }
        } catch {
            showToast(title: "操作失败", detail: error.localizedDescription, isError: true)
            Task { await reloadAll() }
        }
    }

    private func runUndo(_ work: (ManagerStore) throws -> Void) {
        do { try work(store) }
        catch { showToast(title: "撤销失败", detail: error.localizedDescription, isError: true) }
        Task { await reloadAll() }
    }

    func adoptToLibrary(name: String) {
        openAdoption(name: name)
    }

    func importSkill(url: URL) {
        do {
            try store.importSkill(url)
            showToast(title: "Skill 导入成功", detail: url.lastPathComponent)
            Task { await reloadAll() }
        } catch {
            showToast(title: "导入失败", detail: error.localizedDescription, isError: true)
        }
    }

    func managedDeploymentCount(name: String, isSkill: Bool) -> Int {
        deployments.filter { $0.kind == (isSkill ? "skill" : "mcp") && $0.item == name }.count
    }

    @discardableResult
    func deleteFromLibrary(name: String, isSkill: Bool) -> Bool {
        do {
            if isSkill {
                try store.deleteLibrarySkill(name)
            } else {
                try store.deleteLibraryMCP(name)
            }
            if selectedItemName == name {
                selectedItemName = nil
            }
            showToast(title: "已从中央库移至废纸篓", detail: name)
            Task { await reloadAll() }
            return true
        } catch {
            showToast(title: "删除失败", detail: error.localizedDescription, isError: true)
            return false
        }
    }

    func updateSkillFromGit(name: String) async {
        showToast(title: "正在从 Git 拉取最新更新...", detail: name)
        do {
            try await GitSkillService.shared.updateSkillFromGit(name: name) { _ in }
            showToast(title: "Skill 更新成功", detail: name)
            await reloadAll()
        } catch {
            showToast(title: "更新失败", detail: error.localizedDescription, isError: true)
        }
    }

    func addProject(url: URL) {
        do {
            try store.addProject(url.path)
            showToast(title: "已添加项目", detail: url.lastPathComponent)
            Task { await reloadAll() }
        } catch {
            showToast(title: "添加失败", detail: error.localizedDescription, isError: true)
        }
    }

    func removeProject(path: String) {
        do {
            try store.removeProject(path)
            showToast(title: "已移除项目", detail: URL(fileURLWithPath: path).lastPathComponent)
            if selectedProject == path { selectedProject = nil }
            Task { await reloadAll() }
        } catch {
            showToast(title: "移除失败", detail: error.localizedDescription, isError: true)
        }
    }

    func showToast(title: String, detail: String? = nil, isError: Bool = false, undo: (() -> Void)? = nil) {
        toastDismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.activeToast = ToastMessage(title: title, detail: detail, isError: isError, undoAction: undo)
        }
        let delayNanos: UInt64 = isError ? 8_000_000_000 : (undo != nil ? 4_200_000_000 : 3_500_000_000)
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                self?.activeToast = nil
            }
        }
    }

    func dismissToast() {
        toastDismissTask?.cancel()
        withAnimation(.easeInOut(duration: 0.2)) {
            self.activeToast = nil
        }
    }
}
