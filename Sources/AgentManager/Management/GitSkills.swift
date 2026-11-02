import Foundation

// MARK: - Discovered Skill Model
struct DiscoveredGitSkill: Identifiable, Hashable {
    var id: String { relativePath }
    let name: String
    let description: String
    let relativePath: String
    let fullURL: URL
}

struct GitRepositoryVisit: Codable, Identifiable {
    var id: String { repoURL + "\n" + (branch ?? "") + "\n" + (subpath ?? "") }
    let repoURL: String
    let branch: String?
    let subpath: String?
    let visitedAt: Date
}

struct GitArchiveState {
    let name: String
    let label: String
}

struct GitSkillImportResult {
    let skill: DiscoveredGitSkill
    let archiveName: String
    let error: String?
}

// MARK: - Git Skill Service
final class GitSkillService {
    static let shared = GitSkillService()
    let store: ManagerStore
    init(store: ManagerStore = .shared) { self.store = store }

    private var visitsURL: URL { store.base.appendingPathComponent("git-repositories.json") }

    // Keep reusable addresses, never HTTP credentials or access-token query strings.
    static func reusableRepoURL(_ raw: String) -> String {
        let parsed = parseInputURL(raw).repoURL
        guard var url = URLComponents(string: parsed),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return parsed }
        url.user = nil
        url.password = nil
        url.query = nil
        url.fragment = nil
        return url.string ?? parsed
    }

    private static func repoKey(_ raw: String) -> String {
        var value = reusableRepoURL(raw)
        while value.hasSuffix("/") { value.removeLast() }
        if value.hasSuffix(".git") { value = String(value.dropLast(4)) }
        return value
    }

    func recentRepositories() -> [GitRepositoryVisit] {
        var visits = (try? Data(contentsOf: visitsURL)).flatMap {
            try? JSONDecoder().decode([GitRepositoryVisit].self, from: $0)
        } ?? []
        // Existing archives also seed history on upgrade.
        for entry in (try? store.fm.contentsOfDirectory(at: store.skillsRoot, includingPropertiesForKeys: nil)) ?? [] {
            guard let info = sourceInfo(at: entry) else { continue }
            visits.append(GitRepositoryVisit(repoURL: Self.reusableRepoURL(info.repo), branch: info.branch,
                                             subpath: nil, visitedAt: info.installedAt))
        }
        var seen = Set<String>()
        return Array(visits.sorted { $0.visitedAt > $1.visitedAt }.filter { seen.insert($0.id).inserted }.prefix(20))
    }

    func rememberRepository(repoURL: String, branch: String?, subpath: String? = nil) throws {
        let visit = GitRepositoryVisit(repoURL: Self.reusableRepoURL(repoURL),
                                       branch: branch?.isEmpty == false ? branch : nil,
                                       subpath: subpath?.isEmpty == false ? subpath : nil, visitedAt: Date())
        let visits = [visit] + recentRepositories().filter { $0.id != visit.id }
        try JSONEncoder().encode(Array(visits.prefix(20))).write(to: visitsURL, options: .atomic)
        try store.fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: visitsURL.path)
    }

    private func sourceInfo(at url: URL) -> GitSourceInfo? {
        guard let data = try? Data(contentsOf: url.appendingPathComponent(".git-source.json")) else { return nil }
        return try? JSONDecoder().decode(GitSourceInfo.self, from: data)
    }

    private func itemExists(at url: URL) -> Bool {
        store.fm.fileExists(atPath: url.path) || (try? store.fm.destinationOfSymbolicLink(atPath: url.path)) != nil
    }

    static func archiveName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "/", with: "-")
    }

    func archiveState(for skill: DiscoveredGitSkill, repoURL: String, branch: String?) -> GitArchiveState? {
        let entries = ((try? store.fm.contentsOfDirectory(at: store.skillsRoot, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        if let archived = entries.first(where: {
            guard let info = sourceInfo(at: $0) else { return false }
            return Self.repoKey(info.repo) == Self.repoKey(repoURL)
                && (info.branch ?? "") == (branch ?? "")
                && (info.subpath ?? ".") == skill.relativePath
        }) {
            return GitArchiveState(name: archived.lastPathComponent, label: "已归档 · 可更新")
        }
        let name = Self.archiveName(skill.name)
        let dest = store.skillsRoot.appendingPathComponent(name)
        guard itemExists(at: dest) else { return nil }
        let broken = !store.fm.fileExists(atPath: dest.path)
        return GitArchiveState(name: name, label: broken ? "失效链接 · 将修复" : "同名已存在 · 将替换")
    }

    /// Each item is independently recorded. A failed item does not abort the remaining batch.
    func installSkills(_ skills: [DiscoveredGitSkill], repoURL: String, branch: String?, customName: String? = nil,
                       progress: (Int, String) -> Void) -> [GitSkillImportResult] {
        var destinations = Set<String>()
        return skills.enumerated().map { index, skill in
            let existing = archiveState(for: skill, repoURL: repoURL, branch: branch)
            let name = Self.archiveName(customName ?? existing?.name ?? skill.name)
            progress(index, name)
            do {
                guard destinations.insert(name.lowercased()).inserted else {
                    throw ManagerError.conflict("所选 Skill 的归档名称重复：\(name)，请单项归档并指定不同名称")
                }
                try installSkill(from: skill.fullURL, skillName: name, repoURL: repoURL, branch: branch,
                                 subpath: skill.relativePath == "." ? nil : skill.relativePath)
                return GitSkillImportResult(skill: skill, archiveName: name, error: nil)
            } catch {
                return GitSkillImportResult(skill: skill, archiveName: name, error: error.localizedDescription)
            }
        }
    }

    struct ParseResult {
        let repoURL: String
        let branch: String?
        let subpath: String?
    }

    /// Smart parser for GitHub full URLs, tree/blob subpath links, and standard Git repos.
    static func parseInputURL(_ raw: String) -> ParseResult {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Pattern 1: https://github.com/owner/repo/(tree|blob)/branch/path/to/skill
        let treePattern = #"^https?:\/\/github\.com\/([^\/]+)\/([^\/]+)\/(?:tree|blob)\/([^\/]+)\/(.+)$"#
        if let regex = try? NSRegularExpression(pattern: treePattern, options: []) {
            let ns = trimmed as NSString
            if let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) {
                let owner = ns.substring(with: match.range(at: 1))
                let repo = ns.substring(with: match.range(at: 2))
                let branch = ns.substring(with: match.range(at: 3))
                var subpath = ns.substring(with: match.range(at: 4))
                if subpath.hasSuffix("/SKILL.md") {
                    subpath = String(subpath.dropLast("/SKILL.md".count))
                }
                return ParseResult(
                    repoURL: "https://github.com/\(owner)/\(repo).git",
                    branch: branch,
                    subpath: subpath
                )
            }
        }

        // Pattern 2: Standard GitHub repo https://github.com/owner/repo
        let repoPattern = #"^https?:\/\/github\.com\/([^\/]+)\/([^\/]+?)(?:\.git)?\/?$"#
        if let regex = try? NSRegularExpression(pattern: repoPattern, options: []) {
            let ns = trimmed as NSString
            if let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) {
                let owner = ns.substring(with: match.range(at: 1))
                let repo = ns.substring(with: match.range(at: 2))
                return ParseResult(
                    repoURL: "https://github.com/\(owner)/\(repo).git",
                    branch: nil,
                    subpath: nil
                )
            }
        }

        return ParseResult(repoURL: trimmed, branch: nil, subpath: nil)
    }

    /// Extracts clean repository name from a git URL.
    static func parseRepoName(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var clean = trimmed
        if clean.hasSuffix(".git") {
            clean = String(clean.dropLast(4))
        }
        while clean.hasSuffix("/") {
            clean = String(clean.dropLast())
        }
        if let last = clean.components(separatedBy: "/").last, !last.isEmpty {
            return last
        }
        return nil
    }

    /// Shallow clones a repository and discovers all directories containing a SKILL.md.
    func cloneAndDiscover(
        repoURL: String,
        branch: String?,
        shallowClone: Bool? = nil,
        progress: @escaping (String) -> Void
    ) async throws -> (tempRoot: URL, discovered: [DiscoveredGitSkill]) {
        progress("准备安全临时克隆目录...")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("AgentManagerGit-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let requestedBranch = branch?.trimmingCharacters(in: .whitespacesAndNewlines)
        let shallow = shallowClone ?? (UserDefaults.standard.object(forKey: "enableShallowClone") == nil || UserDefaults.standard.bool(forKey: "enableShallowClone"))
        progress("正在克隆 Git 仓库...")
        var args = ["clone"]
        if shallow { args += ["--depth", "1"] }
        if let requestedBranch, !requestedBranch.isEmpty { args += ["-b", requestedBranch] }
        args += ["--", repoURL, tempDir.path]
        let output = try await runGit(args: args)

        if output.exitCode != 0 {
            try? FileManager.default.removeItem(at: tempDir)
            let err = output.error.trimmingCharacters(in: .whitespacesAndNewlines)
            throw ManagerError.invalid("Git 克隆失败: \(err.isEmpty ? output.output : err)")
        }

        progress("正在全库检索 Skill 规范定义 (SKILL.md)...")
        let discovered = scanForSkills(in: tempDir, repoURL: repoURL)
        return (tempDir, discovered)
    }

    /// Finds an actual Skill definition; repository README files are not skills.
    static func findSkillMarkdownFile(in dir: URL) -> URL? {
        let children = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        for name in ["SKILL.md", "skill.md", "Skill.md", "SKILL.MD"] {
            if let file = children.first(where: { $0.lastPathComponent == name }) { return file }
        }
        return nil
    }

    /// Safely resolves a multi-segment subpath relative to a root URL without percent-encoding slashes.
    static func resolveSubpath(_ sub: String, relativeTo root: URL) -> URL {
        var current = root.standardizedFileURL.resolvingSymlinksInPath()
        let components = sub.components(separatedBy: "/").filter { !$0.isEmpty && $0 != "." }
        for part in components {
            current = current.appendingPathComponent(part)
        }
        return current
    }

    /// Scans a directory recursively for SKILL.md files.
    func scanForSkills(in root: URL, repoURL: String) -> [DiscoveredGitSkill] {
        var results: [DiscoveredGitSkill] = []
        let fm = FileManager.default
        let fallbackName = GitSkillService.parseRepoName(from: repoURL) ?? "skill"

        let standardRoot = root.standardizedFileURL.resolvingSymlinksInPath()

        // Check if root is itself a skill
        if let rootSkillFile = GitSkillService.findSkillMarkdownFile(in: standardRoot) {
            let desc = parseDescription(from: rootSkillFile)
            let name = parseSkillName(from: rootSkillFile) ?? fallbackName
            results.append(DiscoveredGitSkill(name: name, description: desc, relativePath: ".", fullURL: standardRoot))
        }

        // Enumerate subdirectories
        guard let enumerator = fm.enumerator(
            at: standardRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return results }

        let rootPath = standardRoot.path.hasSuffix("/") ? standardRoot.path : standardRoot.path + "/"

        for case let url as URL in enumerator {
            if url.pathComponents.contains(".git") {
                enumerator.skipDescendants()
                continue
            }
            let standardURL = url.standardizedFileURL.resolvingSymlinksInPath()
            if standardURL.path == standardRoot.path { continue }

            if let skillFile = GitSkillService.findSkillMarkdownFile(in: standardURL) {
                var rel = standardURL.path
                if rel.hasPrefix(rootPath) {
                    rel = String(rel.dropFirst(rootPath.count))
                }
                while rel.hasPrefix("/") {
                    rel = String(rel.dropFirst())
                }

                let desc = parseDescription(from: skillFile)
                let name = parseSkillName(from: skillFile) ?? standardURL.lastPathComponent
                if !results.contains(where: { $0.fullURL.path == standardURL.path }) {
                    results.append(DiscoveredGitSkill(name: name, description: desc, relativePath: rel, fullURL: standardURL))
                }
                enumerator.skipDescendants()
            }
        }
        return results.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Installs a specific skill folder into the Central Library and marks its git origin.
    func installSkill(
        from sourceDir: URL,
        skillName: String,
        repoURL: String,
        branch: String?,
        subpath: String?
    ) throws {
        let fm = FileManager.default
        let safeName = Self.archiveName(skillName)
        guard !safeName.isEmpty, !safeName.hasPrefix("."), !safeName.contains("\\"), !safeName.contains(":"), !safeName.contains("\n") else {
            throw ManagerError.invalid("Skill 名称无效")
        }
        guard Self.findSkillMarkdownFile(in: sourceDir) != nil else { throw ManagerError.invalid("Skill 缺少 SKILL.md") }
        let staging = store.base.appendingPathComponent("git-stage-" + UUID().uuidString)
        let previous = store.base.appendingPathComponent("git-previous-" + UUID().uuidString)
        defer { try? fm.removeItem(at: staging) }
        // Retain the backup if restoring it fails, rather than discarding the old archive.

        try store.copyIndependentSkill(sourceDir, to: staging)
        if let markdown = Self.findSkillMarkdownFile(in: staging), markdown.lastPathComponent != "SKILL.md" {
            let content = try Data(contentsOf: markdown)
            try fm.removeItem(at: markdown)
            try content.write(to: staging.appendingPathComponent("SKILL.md"), options: .atomic)
        }
        let info = GitSourceInfo(repo: repoURL, branch: branch?.isEmpty == false ? branch : nil,
                                 subpath: subpath?.isEmpty == false ? subpath : nil, installedAt: Date())
        try JSONEncoder().encode(info).write(to: staging.appendingPathComponent(".git-source.json"), options: .atomic)
        let dest = store.skillsRoot.appendingPathComponent(safeName)
        try store.withRecordedOperation(action: itemExists(at: dest) ? "更新 Git Skill" : "安装 Git Skill", kind: "skill", target: safeName, paths: [dest]) {
            let existed = itemExists(at: dest)
            if existed { try fm.moveItem(at: dest, to: previous) }
            do { try fm.moveItem(at: staging, to: dest) }
            catch {
                if existed {
                    do { try fm.moveItem(at: previous, to: dest) }
                    catch { throw ManagerError.invalid("归档失败且恢复失败，旧归档保留于：\(previous.path)。\(error.localizedDescription)") }
                }
                throw error
            }
        }
        try? fm.removeItem(at: previous)
    }

    /// Pulls the latest version from git for an already installed skill.
    func updateSkillFromGit(
        name: String,
        progress: @escaping (String) -> Void
    ) async throws {
        let target = store.skillsRoot.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: target.path) else {
            throw ManagerError.invalid("目标 Skill 在中央库中不存在")
        }
        let sourceFile = target.appendingPathComponent(".git-source.json")
        guard let data = try? Data(contentsOf: sourceFile),
              let info = try? JSONDecoder().decode(GitSourceInfo.self, from: data) else {
            throw ManagerError.invalid("该 Skill 不是通过 Git 导入，缺少来源信息")
        }

        let (tempRoot, discovered) = try await cloneAndDiscover(repoURL: info.repo, branch: info.branch, progress: progress)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        progress("正在更新本地 Skill 文件...")

        // Clean stored subpath from any legacy /private or leading slash artifacts
        let sanitizedStoredSubpath = info.subpath?
            .replacingOccurrences(of: "/privateskills", with: "skills")
            .replacingOccurrences(of: "/private/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // The saved directory identifies the installed skill even when names change.
        let expectedPath = sanitizedStoredSubpath?.isEmpty == false ? sanitizedStoredSubpath! : "."
        let matchedSkill = discovered.first { $0.relativePath == expectedPath }
        guard matchedSkill != nil else {
            throw ManagerError.invalid("原 Skill 目录已不存在：\(expectedPath)，请重新选择来源，避免更新为其他 Skill")
        }

        let sourceDir: URL
        let finalSubpath: String?
        if let matched = matchedSkill {
            sourceDir = matched.fullURL
            finalSubpath = matched.relativePath == "." ? nil : matched.relativePath
        } else if let sub = sanitizedStoredSubpath, !sub.isEmpty {
            sourceDir = GitSkillService.resolveSubpath(sub, relativeTo: tempRoot)
            finalSubpath = sub
        } else {
            sourceDir = tempRoot
            finalSubpath = nil
        }

        guard GitSkillService.findSkillMarkdownFile(in: sourceDir) != nil else {
            throw ManagerError.invalid("最新代码中未找到包含 SKILL.md 的有效目录")
        }

        try installSkill(
            from: sourceDir,
            skillName: name,
            repoURL: info.repo,
            branch: info.branch,
            subpath: finalSubpath
        )
    }

    private func parseSkillName(from file: URL) -> String? {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        let lines = text.components(separatedBy: .newlines)
        var inFrontmatter = false
        var frontmatterChecked = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if !inFrontmatter && !frontmatterChecked {
                    inFrontmatter = true
                    continue
                } else if inFrontmatter {
                    inFrontmatter = false
                    frontmatterChecked = true
                    break
                }
            }
            if inFrontmatter && (trimmed.hasPrefix("name:") || trimmed.hasPrefix("name :")) {
                let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count == 2 {
                    let val = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                    if !val.isEmpty { return val }
                }
            }
        }

        // Fallback: check lines outside frontmatter for "name: ..."
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name:") || trimmed.hasPrefix("name :") {
                let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count == 2 {
                    let val = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                    if !val.isEmpty { return val }
                }
            }
        }

        // Fallback: first H1 markdown heading "# SkillName"
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") {
                let title = trimmed.dropFirst(2).trimmingCharacters(in: .whitespaces)
                if !title.isEmpty && title.count < 60 {
                    return title
                }
            }
        }
        return nil
    }

    private func parseDescription(from file: URL) -> String {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return "无描述" }
        let lines = text.components(separatedBy: .newlines)
        var inFrontmatter = false
        var frontmatterChecked = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if !inFrontmatter && !frontmatterChecked {
                    inFrontmatter = true
                    continue
                } else if inFrontmatter {
                    inFrontmatter = false
                    frontmatterChecked = true
                    break
                }
            }
            if inFrontmatter && (trimmed.hasPrefix("description:") || trimmed.hasPrefix("description :")) {
                let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count == 2 {
                    let val = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                    if !val.isEmpty { return val }
                }
            }
        }

        // Fallback 1: search for description: outside frontmatter
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("description:") || trimmed.hasPrefix("description :") {
                let parts = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
                if parts.count == 2 {
                    let val = parts[1].trimmingCharacters(in: CharacterSet(charactersIn: " \"'"))
                    if !val.isEmpty { return val }
                }
            }
        }

        // Fallback 2: first non-empty descriptive text line
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") && !trimmed.hasPrefix("---") && trimmed.count > 5 {
                return String(trimmed.prefix(120))
            }
        }
        return "无描述"
    }

    private func runGit(args: [String]) async throws -> (exitCode: Int32, output: String, error: String) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args

                var env = ProcessInfo.processInfo.environment
                env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin"
                env["GIT_TERMINAL_PROMPT"] = "0"
                process.environment = env

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                    let stderrRead = DispatchGroup()
                    let stderrBox = GitOutputBuffer()
                    stderrRead.enter()
                    DispatchQueue.global(qos: .utility).async {
                        stderrBox.data = errPipe.fileHandleForReading.readDataToEndOfFile()
                        stderrRead.leave()
                    }
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    stderrRead.wait()
                    let errData = stderrBox.data
                    let output = String(data: outData, encoding: .utf8) ?? ""
                    let error = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(returning: (process.terminationStatus, output, error))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}


private final class GitOutputBuffer: @unchecked Sendable { var data = Data() }
