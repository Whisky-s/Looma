import Foundation
import CryptoKit
import CoreFoundation

/// One actual source, identified by location rather than its display name.
struct ContentVersion: Identifiable {
    let id: String
    let name: String
    let isSkill: Bool
    let label: String
    let path: URL
    let target: Target?
    let definition: [String: Any]?
    let manifest: [String: String]?
    let error: String?
    var isLibrary: Bool { target == nil }
    var digest: String? { manifest.map { contentHash($0) } }
    var revision: String? { definition.map { contentHash($0) } ?? digest }

    func differences(from other: ContentVersion) -> [String]? {
        guard let lhs = manifest, let rhs = other.manifest else { return nil }
        return Set(lhs.keys).union(rhs.keys).filter { lhs[$0] != rhs[$0] }.sorted()
    }
}

private func contentHash(_ object: Any) -> String {
    let data = (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .fragmentsAllowed])) ?? Data()
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

/// Enablement and content equivalence are independent facts.
func contentRelation(_ versions: [ContentVersion], target: Target) -> String? {
    let local = versions.filter { $0.target == target }
    guard !local.isEmpty else { return nil }
    guard local.allSatisfy({ $0.digest != nil }) else { return "内容无法读取" }
    if let library = versions.first(where: \.isLibrary) {
        guard let digest = library.digest else { return "中央库内容无法读取" }
        return local.allSatisfy { $0.digest == digest } ? "与中央库一致" : "与中央库不同"
    }
    guard versions.allSatisfy({ $0.digest != nil }) else { return "存在无法读取的来源" }
    if versions.count == 1 { return "单一来源 · 未归档" }
    return Set(versions.compactMap(\.digest)).count == 1 ? "各来源内容一致" : "同名内容不同"
}

extension ManagerStore {
    /// Ignore only client switches and lossless format aliases. All other fields matter.
    func normalizedMCPContent(_ input: [String: Any]) -> [String: Any] {
        var result = input
        for key in ["enabled", "disabled", "__codexRawTOML", "__codexRawFingerprint", "__codexRawName", "__unsupported"] { result.removeValue(forKey: key) }
        if result["url"] == nil { result["url"] = result.removeValue(forKey: "serverUrl") }
        if result["headers"] == nil { result["headers"] = result.removeValue(forKey: "http_headers") }
        if result["url"] != nil, result["type"] == nil || result["type"] as? String == "streamable-http" { result["type"] = "http" }
        if result["command"] != nil, result["type"] == nil { result["type"] = "stdio" }
        return result
    }

    func mcpContentManifest(_ input: [String: Any]) -> [String: String] {
        var manifest: [String: String] = [:]
        func visit(_ value: Any, path: String) {
            if let object = value as? [String: Any], !object.isEmpty {
                for (key, child) in object { visit(child, path: path + "/" + key.replacingOccurrences(of: "~", with: "~0").replacingOccurrences(of: "/", with: "~1")) }
            } else { manifest[path] = contentHash(value) }
        }
        visit(normalizedMCPContent(input), path: "")
        // Unknown TOML fields must never be silently declared equivalent.
        if let unsupported = input["__unsupported"] as? [String], !unsupported.isEmpty { manifest["/未解析的TOML配置"] = contentHash(input["__codexRawTOML"] ?? unsupported) }
        return manifest
    }

    /// Read every usable file, including hidden resources and linked directories.
    /// Provenance and OS metadata are not part of a skill's behavior.
    func skillContentManifest(_ folder: URL) throws -> [String: String] {
        var result: [String: String] = [:]
        func visit(_ input: URL, relative: String, ancestors: Set<String>) throws {
            let resolved = input.resolvingSymlinksInPath().standardizedFileURL
            let attrs = try fm.attributesOfItem(atPath: resolved.path)
            if attrs[.type] as? FileAttributeType == .typeDirectory {
                guard !ancestors.contains(resolved.path) else { throw ManagerError.invalid("Skill 存在循环目录链接") }
                result[relative + "/"] = "directory"
                for child in try fm.contentsOfDirectory(at: resolved, includingPropertiesForKeys: nil) {
                    guard ![".git", ".git-source.json", ".DS_Store"].contains(child.lastPathComponent) else { continue }
                    try visit(child, relative: relative.isEmpty ? child.lastPathComponent : relative + "/" + child.lastPathComponent, ancestors: ancestors.union([resolved.path]))
                }
            } else if attrs[.type] as? FileAttributeType == .typeRegular {
                let bytes = try Data(contentsOf: resolved)
                let executable = (attrs[.posixPermissions] as? Int ?? 0) & 0o111
                result[relative] = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined() + ":\(executable)"
            } else { throw ManagerError.invalid("Skill 包含无法读取的文件：\(relative)") }
        }
        try visit(folder, relative: "", ancestors: [])
        return result
    }

    func contentVersions(_ name: String, skill: Bool, skillItems: [SkillItem]? = nil, mcpItems: [MCPItem]? = nil) -> [ContentVersion] {
        if skill {
            return (skillItems ?? (librarySkills() + installedSkills())).filter { $0.name == name }.map { item in
                let target = item.agent.map { Target(agent: $0, project: item.project) }
                let manifest = Result { try skillContentManifest(item.url) }
                return ContentVersion(id: (target?.id ?? "library") + "|" + item.url.path, name: name, isSkill: true,
                    label: target?.label ?? "中央库", path: item.url, target: target, definition: nil,
                    manifest: try? manifest.get(), error: { if case .failure(let error) = manifest { return error.localizedDescription }; return nil }())
            }
        }
        return (mcpItems ?? (libraryMCP() + installedMCP())).filter { $0.name == name }.map { item in
            let target = item.agent.map { Target(agent: $0, project: item.project) }
            return ContentVersion(id: (target?.id ?? "library") + "|" + item.source.path, name: name, isSkill: false,
                label: target?.label ?? "中央库", path: item.source, target: target, definition: item.definition,
                manifest: mcpContentManifest(item.definition), error: nil)
        }
    }

    func contentSnapshot(skills: [SkillItem], mcps: [MCPItem]) -> [String: [ContentVersion]] {
        var result: [String: [ContentVersion]] = [:]
        for (name, items) in Dictionary(grouping: skills, by: \.name) {
            result["skill:" + name] = contentVersions(name, skill: true, skillItems: items)
        }
        for (name, items) in Dictionary(grouping: mcps, by: \.name) {
            result["mcp:" + name] = contentVersions(name, skill: false, mcpItems: items)
        }
        return result
    }

    func archiveContentVersion(_ expected: ContentVersion, as name: String) throws {
        guard safeName(name) else { throw ManagerError.invalid("中央库名称无效") }
        let source = try verifyContentVersion(expected)
        if source.isSkill {
            let destination = skillsRoot.appendingPathComponent(name)
            guard !fm.fileExists(atPath: destination.path), (try? fm.destinationOfSymbolicLink(atPath: destination.path)) == nil else { throw ManagerError.conflict("中央库已有同名 Skill，请另选名称") }
            let staging = base.appendingPathComponent("version-stage-" + UUID().uuidString)
            defer { try? fm.removeItem(at: staging) }
            try copyIndependentSkill(source.path, to: staging)
            guard try skillContentManifest(staging) == source.manifest else { throw ManagerError.conflict("复制期间来源内容已变化") }
            try withRecordedOperation(action: "另存 Skill 版本", kind: "skill", target: name, paths: [destination]) {
                try fm.moveItem(at: staging, to: destination)
            }
        } else {
            guard let definition = source.definition else { throw ManagerError.invalid("无法读取来源") }
            try importMCP(name: name, definition: definition)
        }
    }

    func verifyContentVersion(_ expected: ContentVersion) throws -> ContentVersion {
        guard let current = contentVersions(expected.name, skill: expected.isSkill).first(where: { $0.id == expected.id }),
              let revision = expected.revision, current.revision == revision else {
            throw ManagerError.conflict("来源或目标内容已变化，请刷新差异后重试")
        }
        return current
    }

    func replaceContentVersion(from source: ContentVersion, to destination: ContentVersion) throws {
        guard source.name == destination.name, source.isSkill == destination.isSkill,
              source.id != destination.id else { throw ManagerError.invalid("请选择不同来源和目标") }
        let currentSource = try verifyContentVersion(source)
        let currentTarget = try verifyContentVersion(destination)
        if !source.isSkill {
            try replaceMCPContent(from: currentSource, to: currentTarget)
            return
        }
        guard currentSource.path.standardizedFileURL != currentTarget.path.standardizedFileURL else {
            throw ManagerError.conflict("来源和目标共用同一目录，无需替换")
        }
        let all = contentVersions(source.name, skill: true)
        let shared = all.filter { $0.id != destination.id && $0.path.resolvingSymlinksInPath() == currentTarget.path.resolvingSymlinksInPath() }
        // A symlink can be detached safely, but writing its shared directory cannot.
        let targetIsLink = (try? fm.destinationOfSymbolicLink(atPath: currentTarget.path.path)) != nil
        guard shared.isEmpty || targetIsLink else {
            throw ManagerError.conflict("目标目录被其他来源或客户端共享，请另存版本后分别部署，避免连带修改")
        }
        let staging = base.appendingPathComponent("version-stage-" + UUID().uuidString)
        defer { try? fm.removeItem(at: staging) }
        try copyIndependentSkill(currentSource.path, to: staging)
        guard try skillContentManifest(staging) == currentSource.manifest else { throw ManagerError.conflict("复制期间来源内容已变化") }
        _ = try verifyContentVersion(destination)
        try withAtomicContentOperation(action: "替换 Skill 版本", kind: "skill", target: source.name + " · " + destination.label,
                                       paths: [currentTarget.path, deploymentsURL]) {
            try fm.removeItem(at: currentTarget.path)
            try fm.moveItem(at: staging, to: currentTarget.path)
            if let target = destination.target {
                var records = deployments().filter { !($0.kind == "skill" && $0.item == source.name && $0.targetID == target.id) }
                if source.isLibrary {
                    records.append(Deployment(kind: "skill", item: source.name, targetID: target.id, path: currentTarget.path.path, fingerprint: skillDeploymentFingerprint(currentTarget.path)))
                }
                try saveDeployments(records)
            }
        }
    }

    /// Preserve safe connection context; arbitrary values remain masked.
    func redactedMCPContent(_ input: [String: Any]) -> String {
        func redact(_ value: Any) -> Any {
            if let object = value as? [String: Any] {
                return object.filter { !$0.key.hasPrefix("__") }.mapValues { redact($0) }
            }
            if let array = value as? [Any] { return array.map { redact($0) } }
            return "••••••"
        }
        var result = redact(input) as? [String: Any] ?? [:]
        for key in ["url", "serverUrl"] {
            if let raw = input[key] as? String, var url = URLComponents(string: raw), url.host != nil {
                url.user = nil; url.password = nil; url.query = nil; url.fragment = nil
                result[key] = url.string
            }
        }
        if let type = input["type"] as? String, ["http", "streamable-http", "sse", "stdio"].contains(type) { result["type"] = type }
        if let command = input["command"] as? String { result["command"] = URL(fileURLWithPath: command).lastPathComponent }
        let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "无法读取"
    }
}
