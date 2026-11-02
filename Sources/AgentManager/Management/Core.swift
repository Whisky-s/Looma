import AppKit
import CryptoKit
import Foundation

enum Agent: String, CaseIterable, Identifiable, Codable {
    case claude = "Claude Code"
    case codex = "Codex"
    case cursor = "Cursor"
    case antigravity = "Antigravity"
    case qoder = "Qoder"
    case workbuddy = "WorkBuddy"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .claude: "sparkle"
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .cursor: "cursorarrow"
        case .antigravity: "globe"
        case .qoder: "curlybraces"
        case .workbuddy: "person.crop.circle"
        }
    }

    var globalSkillRoots: [String] {
        switch self {
        case .claude: ["~/.claude/skills"]
        case .codex: ["~/.codex/skills", "~/.agents/skills"]
        case .cursor: ["~/.cursor/skills"]
        case .antigravity: ["~/.gemini/config/skills", "~/.gemini/antigravity-cli/skills"]
        case .qoder: ["~/.qoder/skills"]
        case .workbuddy: ["~/.workbuddy/skills"]
        }
    }

    var projectSkillRoots: [String] {
        switch self {
        case .claude: [".claude/skills"]
        case .codex: [".agents/skills"]
        case .cursor: [".cursor/skills", ".agents/skills"]
        case .antigravity: [".agents/skills"]
        case .qoder: [".qoder/skills"]
        case .workbuddy: [".workbuddy/skills"]
        }
    }

    var globalMCP: (String, ConfigFormat) {
        switch self {
        case .claude: ("~/.claude.json", .json)
        case .codex: ("~/.codex/config.toml", .toml)
        case .cursor: ("~/.cursor/mcp.json", .json)
        case .antigravity: ("~/.gemini/config/mcp_config.json", .json)
        case .qoder: ("~/.qoder/settings.json", .json)
        case .workbuddy: ("~/.workbuddy/mcp.json", .json)
        }
    }

    var projectMCP: (String, ConfigFormat) {
        switch self {
        case .claude: (".mcp.json", .json)
        case .codex: (".codex/config.toml", .toml)
        case .cursor: (".cursor/mcp.json", .json)
        case .antigravity: (".agents/mcp_config.json", .json)
        case .qoder: (".qoder/settings.json", .json)
        case .workbuddy: (".workbuddy/mcp.json", .json)
        }
    }
}

enum ConfigFormat { case json, toml }

enum AgentPresence {
    private static let lock = NSLock()
    private static var cache: [Agent: (installed: Bool, checkedAt: Date)] = [:]

    /// 界面每次渲染都会查询安装状态；短时缓存避免反复访问 LaunchServices 和文件系统。
    static func isInstalled(_ agent: Agent) -> Bool {
        lock.lock()
        if let entry = cache[agent], Date().timeIntervalSince(entry.checkedAt) < 10 {
            lock.unlock()
            return entry.installed
        }
        lock.unlock()
        let installed = detect(agent)
        lock.lock()
        cache[agent] = (installed, Date())
        lock.unlock()
        return installed
    }

    private static func detect(_ agent: Agent) -> Bool {
        let identifiers: [String]
        let appNames: [String]
        let commands: [String]
        switch agent {
        case .claude:
            identifiers = []
            appNames = []
            commands = ["claude"]
        case .codex:
            identifiers = ["com.openai.codex"]
            appNames = ["Codex"]
            commands = ["codex"]
        case .cursor:
            identifiers = ["com.todesktop.230313mzl4w4u92"]
            appNames = ["Cursor"]
            commands = ["cursor"]
        case .antigravity:
            identifiers = ["com.google.antigravity"]
            appNames = ["Antigravity"]
            commands = ["antigravity"]
        case .qoder:
            identifiers = ["com.qoder.app"]
            appNames = ["Qoder"]
            commands = ["qoder"]
        case .workbuddy:
            identifiers = ["com.workbuddy.workbuddy"]
            appNames = ["WorkBuddy"]
            commands = ["workbuddy"]
        }
        let fm = FileManager.default
        if identifiers.contains(where: { id in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return false }
            return fm.fileExists(atPath: url.path)
        }) { return true }
        let applicationRoots = ["/Applications", "/Applications/Utilities", fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications").path]
        if applicationRoots.contains(where: { root in
            appNames.contains { fm.fileExists(atPath: URL(fileURLWithPath: root).appendingPathComponent($0 + ".app").path) }
        }) { return true }
        let pathDirectories = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map(String.init)
        let commandRoots = pathDirectories + ["/opt/homebrew/bin", "/usr/local/bin", fm.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin").path]
        return commandRoots.contains { root in
            commands.contains { fm.isExecutableFile(atPath: URL(fileURLWithPath: root).appendingPathComponent($0).path) }
        }
    }
}

struct Target: Hashable, Identifiable {
    let agent: Agent
    let project: String?
    var id: String { agent.rawValue + "|" + (project ?? "global") }
    var scopeName: String { project.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "全局" }
    var label: String { "\(agent.rawValue) · \(scopeName)" }

    var skillRoot: URL {
        let path = project == nil ? agent.globalSkillRoots[0] : agent.projectSkillRoots[0]
        return resolve(path, project: project)
    }
    var mcpConfig: (URL, ConfigFormat) {
        let info = project == nil ? agent.globalMCP : agent.projectMCP
        return (resolve(info.0, project: project), info.1)
    }
}

func resolve(_ path: String, project: String? = nil) -> URL {
    if path.hasPrefix("~/") {
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(String(path.dropFirst(2)))
    }
    return URL(fileURLWithPath: project ?? FileManager.default.currentDirectoryPath).appendingPathComponent(path)
}

struct GitSourceInfo: Codable, Hashable {
    let repo: String
    let branch: String?
    let subpath: String?
    let installedAt: Date
}

struct SkillItem: Identifiable, Hashable {
    let url: URL
    let agent: Agent?
    let project: String?
    let isLibrary: Bool
    var id: String { url.path + "|" + (agent?.rawValue ?? "library") }
    var name: String { url.lastPathComponent }
    var description: String {
        let file = url.appendingPathComponent("SKILL.md")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return "无法读取 SKILL.md" }
        let lines = text.components(separatedBy: .newlines)
        return lines.first(where: { $0.hasPrefix("description:") })?.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespacesAndNewlines) ?? "无描述"
    }
    var source: String {
        if isLibrary { return "中央库" }
        return "\(agent?.rawValue ?? "未知") · \(project.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "全局")"
    }
    var gitSource: GitSourceInfo? {
        let file = url.appendingPathComponent(".git-source.json")
        guard let data = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(GitSourceInfo.self, from: data)
    }
}

struct MCPItem: Identifiable {
    let name: String
    let definition: [String: Any]
    let agent: Agent?
    let project: String?
    let source: URL
    let isLibrary: Bool
    var id: String { source.path + "|" + name + "|" + (agent?.rawValue ?? "library") }
    var summary: String {
        if let command = definition["command"] as? String { return command }
        if let raw = (definition["url"] as? String) ?? (definition["serverUrl"] as? String) {
            guard var parts = URLComponents(string: raw), parts.scheme != nil else { return "远程 MCP" }
            parts.user = nil
            parts.password = nil
            parts.query = nil
            parts.fragment = nil
            return parts.string ?? "远程 MCP"
        }
        return "配置条目"
    }
    var sourceLabel: String {
        if isLibrary { return "中央库" }
        return "\(agent?.rawValue ?? "未知") · \(project.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "全局")"
    }

    /// Origin is inferred from the executable path, not verified portability.
    var applicationBundlePath: String? {
        guard let command = definition["command"] as? String, command.hasPrefix("/") else { return nil }
        let components = URL(fileURLWithPath: command).standardizedFileURL.path.split(separator: "/")
        guard let index = components.firstIndex(where: { $0.hasSuffix(".app") }), index < components.count - 1 else { return nil }
        return "/" + components[...index].joined(separator: "/")
    }

    /// Only services bundled inside AI clients depend on the host runtime. Third-party
    /// apps (e.g. TablePlus) shipping a standalone MCP binary stay portable.
    var isSystemService: Bool {
        guard let bundle = applicationBundlePath else { return false }
        return bundledOwner != nil || Self.otherAIClientBundles.contains(URL(fileURLWithPath: bundle).lastPathComponent.lowercased())
    }

    private static let otherAIClientBundles: Set<String> = [
        "claude.app", "windsurf.app", "trae.app", "trae cn.app", "kiro.app", "codebuddy.app",
        "visual studio code.app", "visual studio code - insiders.app", "zed.app", "lingma.app",
    ]

    var bundledOwner: Agent? {
        guard let bundle = applicationBundlePath else { return nil }
        let components = URL(fileURLWithPath: bundle).pathComponents
        if components.contains(".codex") { return .codex }
        switch URL(fileURLWithPath: bundle).lastPathComponent.lowercased() {
        case "codex.app", "codex computer use.app", "chatgpt.app": return .codex
        case "cursor.app": return .cursor
        case "antigravity.app": return .antigravity
        case "qoder.app": return .qoder
        case "workbuddy.app": return .workbuddy
        default: return nil
        }
    }

    func isProtectedSystemService(in client: Agent, managed: Bool) -> Bool {
        guard isSystemService else { return false }
        // An owner's built-in service stays protected even if legacy distribution
        // records incorrectly claim that Looma created it.
        if let owner = bundledOwner { return owner == client }
        return !managed
    }

}

private func fmExists(_ path: String) -> Bool {
    FileManager.default.fileExists(atPath: path)
}

struct Deployment: Codable {
    let kind: String
    let item: String
    let targetID: String
    let path: String
    let fingerprint: String
}

struct DisabledItem: Codable {
    let kind: String
    let item: String
    let targetID: String
    let originalPath: String
    let stashPath: String
}

struct ConfigBackup: Identifiable, Codable {
    let id: String
    let originalPath: String?
    let createdAt: Date
}

enum ManagerError: LocalizedError {
    case conflict(String)
    case invalid(String)
    var errorDescription: String? {
        switch self { case .conflict(let s), .invalid(let s): s }
    }
}

final class ManagerStore {
    static let shared = ManagerStore()
    let fm = FileManager.default
    let agentAvailability: (Agent) -> Bool
    let historyLock = NSRecursiveLock()
    private let parseLock = NSLock()
    private var parseCache: [String: (stamp: String, value: Any)] = [:]
    var historyPruningSuspensions = 0
    let base: URL
    let userHomeURL: URL
    var claudeUserConfig: URL { userHomeURL.appendingPathComponent(".claude.json") }
    var skillsRoot: URL { base.appendingPathComponent("skills", isDirectory: true) }
    var mcpRoot: URL { base.appendingPathComponent("mcp", isDirectory: true) }
    var deploymentsURL: URL { base.appendingPathComponent("deployments.json") }
    var disabledURL: URL { base.appendingPathComponent("disabled.json") }
    var disabledRoot: URL { base.appendingPathComponent("disabled", isDirectory: true) }
    var projectsURL: URL { base.appendingPathComponent("projects.json") }
    init(baseURL: URL? = nil, userHomeURL: URL = FileManager.default.homeDirectoryForCurrentUser, agentAvailability: @escaping (Agent) -> Bool = AgentPresence.isInstalled) {
        self.agentAvailability = agentAvailability
        self.userHomeURL = userHomeURL
        base = baseURL ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/AgentManager", isDirectory: true)
        try? fm.createDirectory(at: skillsRoot, withIntermediateDirectories: true)
        try? fm.createDirectory(at: mcpRoot, withIntermediateDirectories: true)
        autoHealGitSourceFiles()
    }

    func autoHealGitSourceFiles() {
        guard let items = try? fm.contentsOfDirectory(at: skillsRoot, includingPropertiesForKeys: nil) else { return }
        for dir in items {
            let jsonFile = dir.appendingPathComponent(".git-source.json")
            guard let data = try? Data(contentsOf: jsonFile),
                  let info = try? JSONDecoder().decode(GitSourceInfo.self, from: data) else { continue }
            if let sub = info.subpath, sub.contains("/private") {
                let fixedSub = sub.replacingOccurrences(of: "/privateskills", with: "skills")
                                  .replacingOccurrences(of: "/private/", with: "")
                                  .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                let newInfo = GitSourceInfo(
                    repo: info.repo,
                    branch: info.branch,
                    subpath: fixedSub.isEmpty ? nil : fixedSub,
                    installedAt: info.installedAt
                )
                if let newData = try? JSONEncoder().encode(newInfo) {
                    try? newData.write(to: jsonFile, options: .atomic)
                }
            }
        }
    }

    /// MCP 配置文件位置；全局配置以 userHomeURL 为根，便于测试隔离真实主目录。
    func mcpConfig(for target: Target) -> (URL, ConfigFormat) {
        let (path, format) = target.project == nil ? target.agent.globalMCP : target.agent.projectMCP
        if target.project == nil, path.hasPrefix("~/") { return (userHomeURL.appendingPathComponent(String(path.dropFirst(2))), format) }
        return target.mcpConfig
    }

    func projects() -> [String] { (try? Data(contentsOf: projectsURL)).flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? [] }
    func addProject(_ path: String) throws {
        var all = projects()
        guard fm.fileExists(atPath: path) else { throw ManagerError.invalid("项目目录不存在") }
        if !all.contains(path) { all.append(path) }
        try withRecordedOperation(action: "添加项目", kind: "project", target: path, paths: [projectsURL]) {
            try JSONEncoder().encode(all).write(to: projectsURL, options: .atomic)
        }
    }
    func removeProject(_ path: String) throws {
        try withRecordedOperation(action: "移除项目", kind: "project", target: path, paths: [projectsURL]) {
            try JSONEncoder().encode(projects().filter { $0 != path }).write(to: projectsURL, options: .atomic)
        }
    }
    func deployments() -> [Deployment] { (try? Data(contentsOf: deploymentsURL)).flatMap { try? JSONDecoder().decode([Deployment].self, from: $0) } ?? [] }
    func disabledItems() -> [DisabledItem] { (try? Data(contentsOf: disabledURL)).flatMap { try? JSONDecoder().decode([DisabledItem].self, from: $0) } ?? [] }
    func saveDisabled(_ list: [DisabledItem]) throws { try JSONEncoder().encode(list).write(to: disabledURL, options: .atomic) }
    func saveDeployments(_ list: [Deployment]) throws { try JSONEncoder().encode(list).write(to: deploymentsURL, options: .atomic) }

    func librarySkills() -> [SkillItem] {
        ((try? fm.contentsOfDirectory(at: skillsRoot, includingPropertiesForKeys: nil)) ?? [])
            .filter { dir in
                let names = ["SKILL.md", "skill.md", "Skill.md", "SKILL.MD", "README.md"]
                return names.contains { fm.fileExists(atPath: dir.appendingPathComponent($0).path) }
            }
            .map { SkillItem(url: $0, agent: nil, project: nil, isLibrary: true) }.sorted { $0.name < $1.name }
    }
    func installedSkills() -> [SkillItem] {
        var result: [SkillItem] = []
        for agent in Agent.allCases {
            for (path, project) in agent.globalSkillRoots.map({ ($0, Optional<String>.none) }) + projects().flatMap({ p in agent.projectSkillRoots.map { ($0, Optional(p)) } }) {
                let root = resolve(path, project: project)
                let children = (try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
                for child in children where fm.fileExists(atPath: child.appendingPathComponent("SKILL.md").path) {
                    result.append(SkillItem(url: child, agent: agent, project: project, isLibrary: false))
                }
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    func importSkill(_ source: URL) throws {
        let folder = source.lastPathComponent
        guard fm.fileExists(atPath: source.appendingPathComponent("SKILL.md").path) else { throw ManagerError.invalid("请选择包含 SKILL.md 的文件夹") }
        let dest = skillsRoot.appendingPathComponent(folder)
        guard !fm.fileExists(atPath: dest.path), (try? fm.destinationOfSymbolicLink(atPath: dest.path)) == nil else { throw ManagerError.conflict("中央库已存在同名 Skill：\(folder)") }
        let staging = base.appendingPathComponent("skill-stage-" + UUID().uuidString)
        defer { try? fm.removeItem(at: staging) }
        try copyIndependentSkill(source, to: staging)
        try withRecordedOperation(action: "导入 Skill", kind: "skill", target: folder, paths: [dest]) {
            try fm.moveItem(at: staging, to: dest)
        }
    }

    /// Materialize links at every level so the archived folder survives source removal.
    func copyIndependentSkill(_ source: URL, to destination: URL) throws {
        func copy(_ input: URL, _ output: URL, ancestors: Set<String>) throws {
            let resolved = input.resolvingSymlinksInPath().standardizedFileURL
            let attributes = try fm.attributesOfItem(atPath: resolved.path)
            guard let type = attributes[.type] as? FileAttributeType else { throw ManagerError.invalid("无法读取 Skill 文件类型：\(input.path)") }
            if type == .typeDirectory {
                guard !ancestors.contains(resolved.path) else { throw ManagerError.invalid("Skill 存在循环目录链接：\(input.path)") }
                try fm.createDirectory(at: output, withIntermediateDirectories: false)
                for child in try fm.contentsOfDirectory(at: resolved, includingPropertiesForKeys: nil) {
                    try copy(child, output.appendingPathComponent(child.lastPathComponent), ancestors: ancestors.union([resolved.path]))
                }
                if let permissions = attributes[.posixPermissions] {
                    try fm.setAttributes([.posixPermissions: permissions], ofItemAtPath: output.path)
                }
            } else if type == .typeRegular {
                try fm.copyItem(at: resolved, to: output)
            } else {
                throw ManagerError.invalid("Skill 包含失效链接或不支持的文件：\(input.path)")
            }
        }
        do { try copy(source, destination, ancestors: []) }
        catch { try? fm.removeItem(at: destination); throw error }
    }

    /// Explicit repair for archives imported by older versions; never alters source folders.
    func materializeLibrarySkillLinks() -> [String] {
        let entries = (try? fm.contentsOfDirectory(at: skillsRoot, includingPropertiesForKeys: nil)) ?? []
        var report: [String] = []
        for entry in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let rootLink = (try? fm.destinationOfSymbolicLink(atPath: entry.path)) != nil
            let children = fm.enumerator(at: entry, includingPropertiesForKeys: nil)
            var hasLink = rootLink
            if !hasLink {
                while let child = children?.nextObject() as? URL {
                    if (try? fm.destinationOfSymbolicLink(atPath: child.path)) != nil { hasLink = true; break }
                }
            }
            guard hasLink else { continue }
            let staging = base.appendingPathComponent("skill-stage-" + UUID().uuidString)
            let previous = base.appendingPathComponent("skill-previous-" + UUID().uuidString)
            defer { try? fm.removeItem(at: staging); try? fm.removeItem(at: previous) }
            do {
                try copyIndependentSkill(entry, to: staging)
                try withRecordedOperation(action: "中央库链接转独立副本", kind: "skill", target: entry.lastPathComponent, paths: [entry]) {
                    try fm.moveItem(at: entry, to: previous)
                    do { try fm.moveItem(at: staging, to: entry) }
                    catch { try fm.moveItem(at: previous, to: entry); throw error }
                }
                report.append("已转独立副本：\(entry.lastPathComponent)")
            } catch {
                report.append("未转换（保留原条目）：\(entry.lastPathComponent) · \(error.localizedDescription)")
            }
        }
        return report
    }

    func deleteLibrarySkill(_ name: String) throws {
        let dest = skillsRoot.appendingPathComponent(name)
        guard fm.fileExists(atPath: dest.path) else { throw ManagerError.invalid("中央库中不存在该 Skill：\(name)") }
        guard !deployments().contains(where: { $0.kind == "skill" && $0.item == name }) else {
            throw ManagerError.conflict("该 Skill 仍有启用位置，请先停用后再从中央库删除")
        }
        try withRecordedOperation(action: "删除中央库 Skill", kind: "skill", target: name, paths: [dest]) {
            try fm.trashItem(at: dest, resultingItemURL: nil)
        }
    }

    func deploySkill(_ name: String, to target: Target, copy: Bool) throws {
        guard agentAvailability(target.agent) else { throw ManagerError.invalid("未检测到 \(target.agent.rawValue) 安装，无法启用 Skill") }
        let source = skillsRoot.appendingPathComponent(name)
        guard fm.fileExists(atPath: source.appendingPathComponent("SKILL.md").path) else { throw ManagerError.invalid("中央库没有这个 Skill") }
        let root = target.skillRoot
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let dest = root.appendingPathComponent(name)
        guard !fm.fileExists(atPath: dest.path) && (try? fm.destinationOfSymbolicLink(atPath: dest.path)) == nil else { throw ManagerError.conflict("目标已存在同名 Skill：\(dest.path)") }
        try withRecordedOperation(action: copy ? "复制启用 Skill" : "链接启用 Skill", kind: "skill", target: "\(name) · \(target.label)", paths: [dest, deploymentsURL]) {
            if copy { try copyIndependentSkill(source, to: dest) }
            else { try fm.createSymbolicLink(at: dest, withDestinationURL: source) }
            var list = deployments()
            list.append(Deployment(kind: "skill", item: name, targetID: target.id, path: dest.path, fingerprint: copy ? folderFingerprint(dest) : source.path))
            try saveDeployments(list)
        }
    }

    func removeSkill(_ name: String, from target: Target) throws {
        let d = try validateManagedSkillRemoval(name, from: target)
        let list = deployments()
        let dest = URL(fileURLWithPath: d.path)
        try withRecordedOperation(action: "停用 Skill", kind: "skill", target: "\(name) · \(target.label)", paths: [dest, deploymentsURL]) {
            // A missing target only needs its stale deployment record removed.
            if try managedSkillTargetExists(dest) {
                _ = try validateManagedSkillRemoval(name, from: target)
                try fm.removeItem(at: dest)
            }
            try saveDeployments(list.filter { !($0.kind == "skill" && $0.item == name && $0.targetID == target.id) })
        }
    }

    func validateManagedSkillRemoval(_ name: String, from target: Target) throws -> Deployment {
        guard let d = deployments().first(where: { $0.kind == "skill" && $0.item == name && $0.targetID == target.id }) else { throw ManagerError.conflict("这个 Skill 不是由本应用分发，不能直接移除") }
        let dest = URL(fileURLWithPath: d.path)
        guard try managedSkillTargetExists(dest) else { return d }
        if d.fingerprint == skillsRoot.appendingPathComponent(name).path {
            guard (try? fm.destinationOfSymbolicLink(atPath: dest.path)) == d.fingerprint else { throw ManagerError.conflict("链接已被外部修改，操作已停止") }
        } else {
            let current = folderFingerprint(dest)
            // Old releases excluded hidden files. Only accept that baseline when the
            // complete copy still matches the central library, which retains its data.
            let unchangedLegacyCopy = folderFingerprint(dest, includeHidden: false) == d.fingerprint &&
                current == folderFingerprint(skillsRoot.appendingPathComponent(name))
            guard current == d.fingerprint || unchangedLegacyCopy else { throw ManagerError.conflict("目标副本已修改（包括隐藏文件），操作已停止") }
        }
        return d
    }

    private func managedSkillTargetExists(_ url: URL) throws -> Bool {
        do {
            // Inspect the link itself, including dangling links.
            _ = try fm.attributesOfItem(atPath: url.path)
            return true
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
            return false
        }
    }

    func disableExistingSkill(_ name: String, from target: Target, at selectedPath: URL? = nil) throws {
        let source = selectedPath ?? installedSkills().first(where: { $0.name == name && $0.agent == target.agent && $0.project == target.project })?.url ?? target.skillRoot.appendingPathComponent(name)
        let roots = target.project == nil ? target.agent.globalSkillRoots : target.agent.projectSkillRoots
        guard source.lastPathComponent == name,
              roots.contains(where: { resolve($0, project: target.project).standardizedFileURL.path == source.deletingLastPathComponent().standardizedFileURL.path }) else {
            throw ManagerError.invalid("Skill 不在所选客户端的目录中")
        }
        guard fm.fileExists(atPath: source.appendingPathComponent("SKILL.md").path) else { throw ManagerError.invalid("目标 Skill 不存在") }
        guard !deployments().contains(where: { $0.kind == "skill" && URL(fileURLWithPath: $0.path).standardizedFileURL.path == source.standardizedFileURL.path }) else { throw ManagerError.conflict("这个 Skill 由本应用分发，请使用停用操作") }
        try fm.createDirectory(at: disabledRoot, withIntermediateDirectories: true)
        let stash = disabledRoot.appendingPathComponent(UUID().uuidString + "-" + name)
        try withRecordedOperation(action: "停用现有 Skill", kind: "skill", target: "\(name) · \(target.label)", paths: [source, stash, disabledURL]) {
            try fm.moveItem(at: source, to: stash)
            var all = disabledItems()
            all.append(DisabledItem(kind: "skill", item: name, targetID: target.id, originalPath: source.path, stashPath: stash.path))
            try saveDisabled(all)
        }
    }

    func deleteExistingSkill(_ name: String, from target: Target, at selectedPath: URL? = nil) throws {
        let source = selectedPath ?? installedSkills().first(where: { $0.name == name && $0.agent == target.agent && $0.project == target.project })?.url ?? target.skillRoot.appendingPathComponent(name)
        let roots = target.project == nil ? target.agent.globalSkillRoots : target.agent.projectSkillRoots
        guard source.lastPathComponent == name,
              roots.contains(where: { resolve($0, project: target.project).standardizedFileURL.path == source.deletingLastPathComponent().standardizedFileURL.path }) else {
            throw ManagerError.invalid("Skill 不在所选客户端的目录中")
        }
        guard fm.fileExists(atPath: source.appendingPathComponent("SKILL.md").path) else { throw ManagerError.invalid("目标 Skill 不存在") }
        guard !deployments().contains(where: { $0.kind == "skill" && URL(fileURLWithPath: $0.path).standardizedFileURL.path == source.standardizedFileURL.path }) else {
            throw ManagerError.conflict("这个 Skill 由本应用分发，请使用停用操作")
        }
        try withRecordedOperation(action: "删除用户 Skill", kind: "skill", target: "\(name) · \(target.label)", paths: [source]) {
            try fm.trashItem(at: source, resultingItemURL: nil)
        }
    }

    func restoreExistingSkill(_ name: String, to target: Target) throws {
        let all = disabledItems()
        guard let record = all.first(where: { $0.kind == "skill" && $0.item == name && $0.targetID == target.id }) else { throw ManagerError.invalid("没有停用记录") }
        guard !fm.fileExists(atPath: record.originalPath) else { throw ManagerError.conflict("原位置已被占用：\(record.originalPath)") }
        try fm.createDirectory(at: URL(fileURLWithPath: record.originalPath).deletingLastPathComponent(), withIntermediateDirectories: true)
        try withRecordedOperation(action: "恢复现有 Skill", kind: "skill", target: "\(name) · \(target.label)", paths: [URL(fileURLWithPath: record.originalPath), URL(fileURLWithPath: record.stashPath), disabledURL]) {
            try fm.moveItem(atPath: record.stashPath, toPath: record.originalPath)
            try saveDisabled(all.filter { !($0.kind == "skill" && $0.item == name && $0.targetID == target.id) })
        }
    }

    private func folderFingerprint(_ folder: URL, includeHidden: Bool = true) -> String {
        let items = (fm.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey], options: includeHidden ? [] : [.skipsHiddenFiles])?.allObjects as? [URL] ?? [])
            .filter { !$0.hasDirectoryPath }.sorted { $0.path < $1.path }
        let parts = items.map { "\($0.path.replacingOccurrences(of: folder.path, with: "")):\((try? Data(contentsOf: $0)).map { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() } ?? "missing")" }
        return parts.joined(separator: "|")
    }

    func skillContentFingerprint(_ folder: URL) -> String {
        SHA256.hash(data: Data(folderFingerprint(folder).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func skillDeploymentFingerprint(_ folder: URL) -> String { folderFingerprint(folder) }
}

extension ManagerStore {
    private func fileStamp(_ file: URL) -> String? {
        guard let attrs = try? fm.attributesOfItem(atPath: file.path) else { return nil }
        let date = (attrs[.modificationDate] as? Date)?.timeIntervalSinceReferenceDate ?? 0
        return "\(date):\(attrs[.size] ?? 0):\(attrs[.systemFileNumber] ?? 0)"
    }

    /// 只读状态查询用：同一文件未变化时复用解析结果。写入路径必须直接读取文件。
    func cachedParse<T>(_ file: URL, as key: String, _ parse: (Data) throws -> T) throws -> T? {
        guard let stamp = fileStamp(file) else { return nil }
        let cacheKey = key + "|" + file.standardizedFileURL.path
        parseLock.lock()
        if let entry = parseCache[cacheKey], entry.stamp == stamp, let value = entry.value as? T {
            parseLock.unlock()
            return value
        }
        parseLock.unlock()
        let data: Data
        do { data = try Data(contentsOf: file) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return nil }
        let value = try parse(data)
        parseLock.lock()
        parseCache[cacheKey] = (stamp, value)
        parseLock.unlock()
        return value
    }

    func cachedJSONObject(_ file: URL) throws -> [String: Any]? {
        try cachedParse(file, as: "json") { data in
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ManagerError.invalid("配置不是 JSON 对象：\(file.path)") }
            return root
        }
    }
}
