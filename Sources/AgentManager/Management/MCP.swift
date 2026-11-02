import CryptoKit
import CoreFoundation
import Foundation

extension ManagerStore {
    func libraryMCP() -> [MCPItem] {
        ((try? fm.contentsOfDirectory(at: mcpRoot, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "json" }
            .compactMap { file in
                guard let data = try? Data(contentsOf: file), let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
                return MCPItem(name: file.deletingPathExtension().lastPathComponent, definition: value, agent: nil, project: nil, source: file, isLibrary: true)
            }.sorted { $0.name < $1.name }
    }

    func installedMCP() -> [MCPItem] {
        var result: [MCPItem] = []
        for agent in Agent.allCases {
            let targets = [Target(agent: agent, project: nil)] + projects().map { Target(agent: agent, project: $0) }
            for target in targets {
                if agent == .claude, let project = target.project,
                   let root = try? jsonRoot(claudeUserConfig),
                   let projects = root["projects"] as? [String: Any],
                   let entry = projects[project] as? [String: Any], let servers = entry["mcpServers"] as? [String: Any] {
                    for (name, value) in servers {
                        if let definition = value as? [String: Any] {
                            result.append(MCPItem(name: name, definition: definition, agent: agent, project: project, source: claudeUserConfig, isLibrary: false))
                        }
                    }
                }
                let (file, format) = mcpConfig(for: target)
                guard fm.fileExists(atPath: file.path) else { continue }
                if format == .json {
                    guard let root = try? jsonRoot(file), let servers = root["mcpServers"] as? [String: Any] else { continue }
                    for (name, value) in servers {
                        guard let definition = value as? [String: Any] else { continue }
                        result.append(MCPItem(name: name, definition: definition, agent: agent, project: target.project, source: file, isLibrary: false))
                    }
                } else if let text = try? String(contentsOf: file, encoding: .utf8) {
                    for (name, block) in tomlBlocks(text) {
                        result.append(MCPItem(name: name, definition: parseTOMLBlock(block), agent: agent, project: target.project, source: file, isLibrary: false))
                    }
                }
            }
        }
        return result.sorted { $0.name < $1.name }
    }

    func importMCP(name: String, definition: [String: Any]) throws {
        guard safeName(name) else {
            throw ManagerError.invalid("MCP 名称无效：不可为空或包含路径分隔符 /、反斜杠 \\、冒号 : 等特殊字符")
        }
        try validatePortableMCP(definition)
        guard definition["command"] is String || definition["url"] is String || definition["serverUrl"] is String else {
            throw ManagerError.invalid("缺少必要配置：请提供 command（本地命令）或 url / serverUrl（远程服务地址）")
        }
        if let unsupported = definition["__unsupported"] as? [String], !unsupported.isEmpty,
           definition["__codexRawTOML"] == nil {
            throw ManagerError.invalid("原 MCP 含暂不支持转换的 TOML 字段：\(unsupported.joined(separator: ", "))")
        }
        let file = mcpRoot.appendingPathComponent(name + ".json")
        guard !fm.fileExists(atPath: file.path) else { throw ManagerError.conflict("中央库已有同名 MCP：\(name)") }
        try withRecordedOperation(action: "导入 MCP", kind: "mcp", target: name, paths: [file]) {
            let data = try JSONSerialization.data(withJSONObject: definition, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: file, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        }
    }

    private func validatePortableMCP(_ definition: [String: Any]) throws {
        let item = MCPItem(name: "", definition: definition, agent: nil, project: nil, source: base, isLibrary: true)
        guard !item.isSystemService else {
            throw ManagerError.invalid("启动程序位于应用包内，跨客户端兼容性未确认，不能归档或分发；请使用独立安装的 MCP 服务")
        }
    }

    func deleteLibraryMCP(_ name: String) throws {
        let file = mcpRoot.appendingPathComponent(name + ".json")
        guard fm.fileExists(atPath: file.path) else { throw ManagerError.invalid("中央库中不存在该 MCP：\(name)") }
        guard !deployments().contains(where: { $0.kind == "mcp" && $0.item == name }) else {
            throw ManagerError.conflict("该 MCP 仍有启用位置，请先停用后再从中央库删除")
        }
        try withRecordedOperation(action: "删除中央库 MCP", kind: "mcp", target: name, paths: [file]) {
            try fm.trashItem(at: file, resultingItemURL: nil)
        }
    }

    func deployMCP(_ name: String, to target: Target) throws {
        guard agentAvailability(target.agent) else { throw ManagerError.invalid("未检测到 \(target.agent.rawValue) 安装，无法启用 MCP") }
        try validateMCPDeployment(name, to: target)
        let template = mcpRoot.appendingPathComponent(name + ".json")
        guard let data = try? Data(contentsOf: template), let sourceDefinition = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ManagerError.invalid("中央库没有这个 MCP") }
        let definition = enabledMCPDefinition(sourceDefinition, for: target.agent)
        let (file, format) = mcpConfig(for: target)
        if target.agent == .claude, target.project != nil, try mcpLocation(name, target: target).0 != file {
            throw ManagerError.conflict("Claude 项目本地范围已有同名 MCP，请先处理原配置")
        }
        if let other = claudeToolNameClash(name, target: target, among: installedMCP()) {
            throw ManagerError.conflict(claudeToolNameClashMessage(name, other))
        }
        try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try withRecordedOperation(action: "启用 MCP", kind: "mcp", target: "\(name) · \(target.label)", paths: [file, deploymentsURL]) {
        if format == .json {
            if let unsupported = definition["__unsupported"] as? [String], !unsupported.isEmpty {
                throw ManagerError.invalid("原 Codex MCP 含无法安全转换为 JSON 的 TOML 字段：\(unsupported.joined(separator: ", "))")
            }
            var root = fm.fileExists(atPath: file.path) ? try jsonRoot(file) : [:]
            var servers = try managedMCPServers(root, file: file, target: target)
            guard servers[name] == nil else { throw ManagerError.conflict("目标已有同名 MCP：\(name)") }
            try backup(file)
            servers[name] = adapt(definition, for: target.agent)
            try setManagedMCPServers(servers, in: &root, file: file, target: target)
            try writeJSON(root, to: file)
            try record(Deployment(kind: "mcp", item: name, targetID: target.id, path: file.path, fingerprint: fingerprint(servers[name]!)))
        } else {
            let existing = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            guard tomlBlocks(existing)[name] == nil else { throw ManagerError.conflict("目标已有同名 MCP：\(name)") }
            let block = try makeTOMLBlock(name: name, definition: definition)
            try backup(file)
            let next = existing + (existing.isEmpty || existing.hasSuffix("\n") ? "" : "\n") + block
            try next.write(to: file, atomically: true, encoding: .utf8)
            try record(Deployment(kind: "mcp", item: name, targetID: target.id, path: file.path, fingerprint: fingerprint(block)))
        }
        }
    }

    func validateMCPDeployment(_ name: String, to target: Target) throws {
        let template = mcpRoot.appendingPathComponent(name + ".json")
        guard let data = try? Data(contentsOf: template), let sourceDefinition = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ManagerError.invalid("中央库没有这个 MCP")
        }
        try validateMCPDefinition(sourceDefinition, to: target)
    }

    func validateMCPDefinition(_ sourceDefinition: [String: Any], to target: Target) throws {
        try validatePortableMCP(sourceDefinition)
        guard sourceDefinition["command"] is String || sourceDefinition["url"] is String || sourceDefinition["serverUrl"] is String else {
            throw ManagerError.invalid("MCP 缺少命令或服务地址")
        }
        let definition = enabledMCPDefinition(sourceDefinition, for: target.agent)
        let configFile = mcpConfig(for: target).0
        if target.agent != .codex {
            let nonportable: Set<String> = ["env_http_headers", "bearer_token_env_var", "http_headers_helper", "enabled_tools", "disabled_tools", "default_tools_approval_mode", "oauth_resource", "env_vars"]
            let extra = nonportable.intersection(definition.keys)
            guard extra.isEmpty else { throw ManagerError.invalid("目标客户端不支持转换这些 MCP 字段：\(extra.sorted().joined(separator: ", "))") }
        }
        if mcpConfig(for: target).1 == .toml {
            _ = try makeTOMLBlock(name: "validation", definition: definition)
        } else {
            if fm.fileExists(atPath: configFile.path) {
                let root = try jsonRoot(configFile)
                guard root["mcpServers"] == nil || root["mcpServers"] is [String: Any] else {
                    throw ManagerError.invalid("目标配置的 mcpServers 不是对象")
                }
            }
            if let unsupported = definition["__unsupported"] as? [String], !unsupported.isEmpty {
                throw ManagerError.invalid("原 Codex MCP 含无法安全转换为 JSON 的 TOML 字段：\(unsupported.joined(separator: ", "))")
            }
            guard JSONSerialization.isValidJSONObject(adapt(definition, for: target.agent)) else {
                throw ManagerError.invalid("MCP 包含无法写入 JSON 的值")
            }
        }
    }

    func replaceMCPContent(from source: ContentVersion, to destination: ContentVersion) throws {
        guard let sourceDefinition = source.definition else { throw ManagerError.invalid("无法读取 MCP 来源") }
        try validatePortableMCP(sourceDefinition)
        if destination.isLibrary {
            try withAtomicContentOperation(action: "更新中央库 MCP 版本", kind: "mcp", target: destination.name, paths: [destination.path]) {
                _ = try verifyContentVersion(destination)
                try writeJSON(sourceDefinition, to: destination.path)
            }
            return
        }
        guard let target = destination.target, agentAvailability(target.agent) else { throw ManagerError.invalid("目标客户端不可用") }
        try validateMCPDefinition(sourceDefinition, to: target)
        let managed = deployments().contains { $0.kind == "mcp" && $0.item == destination.name && $0.targetID == target.id }
        try validateSystemServiceRemoval(destination.name, from: target, managed: managed)
        let (file, format) = try mcpLocation(destination.name, target: target)
        let original = try Data(contentsOf: file)
        let definition = enabledMCPDefinition(sourceDefinition, for: target.agent)
        try withAtomicContentOperation(action: "替换 MCP 版本", kind: "mcp", target: destination.name + " · " + destination.label, paths: [file, deploymentsURL]) {
            _ = try verifyContentVersion(destination)
            let digest: String
            if format == .json {
                var root = try jsonRoot(file)
                var servers = try managedMCPServers(root, file: file, target: target)
                guard servers[destination.name] != nil else { throw ManagerError.conflict("目标配置已移除") }
                servers[destination.name] = adapt(definition, for: target.agent)
                try setManagedMCPServers(servers, in: &root, file: file, target: target)
                try assertConfigurationUnchanged(file, expected: original)
                try writeJSON(root, to: file)
                digest = fingerprint(servers[destination.name]!)
            } else {
                guard let text = String(data: original, encoding: .utf8), let old = tomlBlocks(text)[destination.name], let range = text.range(of: old) else { throw ManagerError.invalid("无法定位目标 MCP") }
                let block = try makeTOMLBlock(name: destination.name, definition: definition)
                var next = text; next.replaceSubrange(range, with: block)
                try assertConfigurationUnchanged(file, expected: original)
                try next.write(to: file, atomically: true, encoding: .utf8)
                digest = fingerprint(block)
            }
            var records = deployments().filter { !($0.kind == "mcp" && $0.item == destination.name && $0.targetID == target.id) }
            if source.isLibrary {
                records.append(Deployment(kind: "mcp", item: destination.name, targetID: target.id, path: file.path, fingerprint: digest))
            }
            try saveDeployments(records)
        }
    }

    /// Claude Code 用 mcp__<服务名>__<工具名> 暴露工具，服务名中字母、数字、_、- 以外的字符都会被替换为 _。
    func claudeToolNameClash(_ name: String, target: Target, among items: [MCPItem], ignoring: Set<String> = []) -> String? {
        guard target.agent == .claude else { return nil }
        let key = claudeMCPToolKey(name)
        return items.first {
            $0.agent == .claude && ($0.project == target.project || $0.project == nil)
                && $0.name != name && !ignoring.contains($0.name) && claudeMCPToolKey($0.name) == key
        }?.name
    }

    func claudeToolNameClashMessage(_ name: String, _ other: String) -> String {
        "与「\(other)」在 Claude 中的工具名相同（均为 mcp__\(claudeMCPToolKey(name))__*），请重命名其中一个"
    }

    private func enabledMCPDefinition(_ source: [String: Any], for agent: Agent) -> [String: Any] {
        var definition = source
        let wasDisabled = definition.removeValue(forKey: "disabled") as? Bool == true
        if definition["enabled"] as? Bool == false || (wasDisabled && agent == .codex) {
            definition["enabled"] = true
        }
        return definition
    }

    func removeMCP(_ name: String, from target: Target) throws {
        try validateManagedMCPRemoval(name, from: target)
        let all = deployments()
        guard let deployment = all.first(where: { $0.kind == "mcp" && $0.item == name && $0.targetID == target.id }) else { throw ManagerError.conflict("这个 MCP 不是由本应用分发，不能直接移除") }
        let (file, format) = try mcpLocation(name, target: target)
        try withRecordedOperation(action: "停用 MCP", kind: "mcp", target: "\(name) · \(target.label)", paths: [file, deploymentsURL]) {
        if let data = try managedMCPConfigData(file) {
            if format == .json {
                let rootObject = try JSONSerialization.jsonObject(with: data)
                guard var root = rootObject as? [String: Any] else { throw ManagerError.invalid("配置不是 JSON 对象：\(file.path)") }
                var servers = try managedMCPServers(root, file: file, target: target)
                if let current = servers[name] {
                    guard fingerprint(current) == deployment.fingerprint else { throw ManagerError.conflict("目标 MCP 已被外部修改，操作已停止") }
                    try backup(file)
                    servers.removeValue(forKey: name)
                    try setManagedMCPServers(servers, in: &root, file: file, target: target)
                    try writeJSON(root, to: file)
                }
            } else {
                guard let text = String(data: data, encoding: .utf8) else { throw ManagerError.invalid("配置不是 UTF-8 文本") }
                if let current = tomlBlocks(text)[name] {
                    guard fingerprint(current) == deployment.fingerprint else { throw ManagerError.conflict("目标 MCP 已被外部修改，操作已停止") }
                    guard let range = text.range(of: current) else { throw ManagerError.invalid("找不到目标配置块") }
                    try backup(file)
                    var next = text
                    next.removeSubrange(range)
                    try next.write(to: file, atomically: true, encoding: .utf8)
                }
            }
        }
        try saveDeployments(all.filter { !($0.kind == "mcp" && $0.item == name && $0.targetID == target.id) })
        }
    }

    func validateManagedMCPRemoval(_ name: String, from target: Target) throws {
        guard let deployment = deployments().first(where: { $0.kind == "mcp" && $0.item == name && $0.targetID == target.id }) else {
            throw ManagerError.conflict("这个 MCP 不是由本应用分发，不能直接移除")
        }
        try validateSystemServiceRemoval(name, from: target, managed: true)
        let (file, format) = try mcpLocation(name, target: target)
        guard let data = try managedMCPConfigData(file) else { return }
        if format == .json {
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ManagerError.invalid("配置不是 JSON 对象：\(file.path)") }
            let servers = try managedMCPServers(root, file: file, target: target)
            guard let current = servers[name] else { return }
            guard fingerprint(current) == deployment.fingerprint else {
                throw ManagerError.conflict("目标 MCP 已被外部修改，操作已停止")
            }
        } else {
            guard let text = String(data: data, encoding: .utf8) else { throw ManagerError.invalid("配置不是 UTF-8 文本") }
            guard let current = tomlBlocks(text)[name] else { return }
            guard fingerprint(current) == deployment.fingerprint else {
                throw ManagerError.conflict("目标 MCP 已被外部修改，操作已停止")
            }
        }
    }

    private func managedMCPConfigData(_ file: URL) throws -> Data? {
        do { return try Data(contentsOf: file) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { return nil }
    }

    private func validateSystemServiceRemoval(_ name: String, from target: Target, managed: Bool) throws {
        if let item = installedMCP().first(where: { $0.name == name && $0.agent == target.agent && $0.project == target.project }),
           item.isProtectedSystemService(in: target.agent, managed: managed) {
            throw ManagerError.conflict("这是 \(item.bundledOwner?.rawValue ?? target.agent.rawValue) 的内置服务，原客户端配置受保护")
        }
    }

    private func mcpLocation(_ name: String, target: Target) throws -> (URL, ConfigFormat) {
        if target.agent == .claude, target.project != nil, let data = try managedMCPConfigData(claudeUserConfig) {
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ManagerError.invalid("Claude 配置不是对象") }
            if try managedMCPServers(root, file: claudeUserConfig, target: target)[name] != nil { return (claudeUserConfig, .json) }
        }
        return mcpConfig(for: target)
    }

    private func managedMCPServers(_ root: [String: Any], file: URL, target: Target) throws -> [String: Any] {
        var entry = root
        if target.agent == .claude, let project = target.project, file.standardizedFileURL == claudeUserConfig.standardizedFileURL {
            if let value = root["projects"], !(value is [String: Any]) { throw ManagerError.invalid("Claude projects 不是对象") }
            let projects = root["projects"] as? [String: Any] ?? [:]
            if let value = projects[project], !(value is [String: Any]) { throw ManagerError.invalid("Claude 项目配置不是对象") }
            entry = projects[project] as? [String: Any] ?? [:]
        }
        guard let value = entry["mcpServers"] else { return [:] }
        guard let servers = value as? [String: Any] else { throw ManagerError.invalid("目标配置的 mcpServers 不是对象") }
        return servers
    }

    private func setManagedMCPServers(_ servers: [String: Any], in root: inout [String: Any], file: URL, target: Target) throws {
        _ = try managedMCPServers(root, file: file, target: target)
        if target.agent == .claude, let project = target.project, file.standardizedFileURL == claudeUserConfig.standardizedFileURL {
            var projects = root["projects"] as? [String: Any] ?? [:]
            var entry = projects[project] as? [String: Any] ?? [:]
            entry["mcpServers"] = servers
            projects[project] = entry
            root["projects"] = projects
        } else { root["mcpServers"] = servers }
    }

    func disableExistingMCP(_ name: String, from target: Target, preserveManagedConfiguration: Bool = false) throws {
        guard preserveManagedConfiguration || !deployments().contains(where: { $0.kind == "mcp" && $0.item == name && $0.targetID == target.id }) else { throw ManagerError.conflict("这个 MCP 由本应用分发，请使用停用操作") }
        let managed = deployments().contains { $0.kind == "mcp" && $0.item == name && $0.targetID == target.id }
        try validateSystemServiceRemoval(name, from: target, managed: managed)
        let (file, format) = try mcpLocation(name, target: target)
        try fm.createDirectory(at: disabledRoot, withIntermediateDirectories: true)
        let stash = disabledRoot.appendingPathComponent(UUID().uuidString + "-" + name + (format == .json ? ".json" : ".toml"))
        try withRecordedOperation(action: "停用现有 MCP", kind: "mcp", target: "\(name) · \(target.label)", paths: [file, stash, disabledURL] + (preserveManagedConfiguration ? [deploymentsURL] : [])) {
        let originalData = try Data(contentsOf: file)
        if format == .json {
            var root = try jsonRoot(file)
            var servers = try managedMCPServers(root, file: file, target: target)
            guard let value = servers.removeValue(forKey: name) else { throw ManagerError.invalid("目标 MCP 不存在") }
            let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: stash, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stash.path)
            try backup(file)
            try setManagedMCPServers(servers, in: &root, file: file, target: target)
            try assertConfigurationUnchanged(file, expected: originalData)
            try writeJSON(root, to: file)
        } else {
            let text = try String(contentsOf: file, encoding: .utf8)
            guard let block = tomlBlocks(text)[name], let range = text.range(of: block) else { throw ManagerError.invalid("目标 MCP 不存在") }
            try block.write(to: stash, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: stash.path)
            try backup(file)
            var next = text; next.removeSubrange(range)
            try assertConfigurationUnchanged(file, expected: originalData)
            try next.write(to: file, atomically: true, encoding: .utf8)
        }
        var all = disabledItems()
        all.append(DisabledItem(kind: "mcp", item: name, targetID: target.id, originalPath: file.path, stashPath: stash.path))
        try saveDisabled(all)
        if preserveManagedConfiguration {
            try saveDeployments(deployments().filter { !($0.kind == "mcp" && $0.item == name && $0.targetID == target.id) })
        }
        }
    }

    func deleteExistingMCP(_ name: String, from target: Target) throws {
        guard !deployments().contains(where: { $0.kind == "mcp" && $0.item == name && $0.targetID == target.id }) else {
            throw ManagerError.conflict("这个 MCP 由本应用分发，请使用停用操作")
        }
        try validateSystemServiceRemoval(name, from: target, managed: false)
        let (file, format) = try mcpLocation(name, target: target)
        try withRecordedOperation(action: "删除用户 MCP", kind: "mcp", target: "\(name) · \(target.label)", paths: [file]) {
            if format == .json {
                var root = try jsonRoot(file)
                var servers = try managedMCPServers(root, file: file, target: target)
                guard servers.removeValue(forKey: name) != nil else { throw ManagerError.invalid("目标 MCP 不存在") }
                try setManagedMCPServers(servers, in: &root, file: file, target: target)
                try backup(file)
                try writeJSON(root, to: file)
            } else {
                let text = try String(contentsOf: file, encoding: .utf8)
                let blocks = tomlBlocks(text)
                guard let block = blocks[name], let range = text.range(of: block) else { throw ManagerError.invalid("目标 MCP 不存在") }
                var next = text
                next.removeSubrange(range)
                try backup(file)
                try next.write(to: file, atomically: true, encoding: .utf8)
            }
        }
    }

    func restoreExistingMCP(_ name: String, to target: Target) throws {
        let all = disabledItems()
        guard let record = all.first(where: { $0.kind == "mcp" && $0.item == name && $0.targetID == target.id }) else { throw ManagerError.invalid("没有停用记录") }
        let file = URL(fileURLWithPath: record.originalPath)
        let format = mcpConfig(for: target).1
        let stashData = try Data(contentsOf: URL(fileURLWithPath: record.stashPath))
        if format == .json {
            guard let definition = try JSONSerialization.jsonObject(with: stashData) as? [String: Any] else { throw ManagerError.invalid("暂存配置不是对象") }
            try validatePortableMCP(definition)
        } else {
            guard let text = String(data: stashData, encoding: .utf8) else { throw ManagerError.invalid("暂存配置不是 UTF-8") }
            try validatePortableMCP(parseTOMLBlock(text))
        }
        try withRecordedOperation(action: "恢复现有 MCP", kind: "mcp", target: "\(name) · \(target.label)", paths: [file, URL(fileURLWithPath: record.stashPath), disabledURL]) {
        if format == .json {
            var root = fm.fileExists(atPath: file.path) ? try jsonRoot(file) : [:]
            var servers = try managedMCPServers(root, file: file, target: target)
            guard servers[name] == nil else { throw ManagerError.conflict("原位置已有同名 MCP") }
            let data = try Data(contentsOf: URL(fileURLWithPath: record.stashPath))
            let value = try JSONSerialization.jsonObject(with: data)
            try backup(file)
            servers[name] = value
            try setManagedMCPServers(servers, in: &root, file: file, target: target)
            try writeJSON(root, to: file)
        } else {
            let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
            guard tomlBlocks(text)[name] == nil else { throw ManagerError.conflict("原位置已有同名 MCP") }
            let block = try String(contentsOfFile: record.stashPath, encoding: .utf8)
            try backup(file)
            try (text + (text.isEmpty || text.hasSuffix("\n") ? "" : "\n") + block).write(to: file, atomically: true, encoding: .utf8)
        }
        try fm.removeItem(atPath: record.stashPath)
        try saveDisabled(all.filter { !($0.kind == "mcp" && $0.item == name && $0.targetID == target.id) })
        }
    }

    private func record(_ entry: Deployment) throws {
        var all = deployments(); all.append(entry); try saveDeployments(all)
    }
    func safeName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix(".") else { return false }
        let forbidden = CharacterSet(charactersIn: "/\\:\0\n\r\t")
        return trimmed.rangeOfCharacter(from: forbidden) == nil
    }
    var backupRoot: URL { base.appendingPathComponent("backups", isDirectory: true) }

    func configBackups() -> [ConfigBackup] {
        let files = (try? fm.contentsOfDirectory(at: backupRoot, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files.filter { $0.pathExtension == "bak" }.map { file in
            let meta = file.appendingPathExtension("json")
            if let data = try? Data(contentsOf: meta), let record = try? JSONDecoder().decode(ConfigBackup.self, from: data) {
                return record
            }
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return ConfigBackup(id: file.lastPathComponent, originalPath: nil, createdAt: date)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    func restoreConfigBackup(_ record: ConfigBackup, to selectedTarget: URL? = nil) throws {
        let snapshot = backupRoot.appendingPathComponent(record.id)
        guard snapshot.deletingLastPathComponent().standardizedFileURL == backupRoot.standardizedFileURL,
              snapshot.pathExtension == "bak", fm.fileExists(atPath: snapshot.path) else {
            throw ManagerError.invalid("备份文件不存在")
        }
        let target = selectedTarget ?? record.originalPath.map { URL(fileURLWithPath: $0) }
        guard let target, target.isFileURL, target.path != snapshot.path,
              !target.standardizedFileURL.path.hasPrefix(backupRoot.standardizedFileURL.path + "/") else {
            throw ManagerError.invalid("请选择正确的配置文件作为恢复目标")
        }
        try withRecordedOperation(action: "恢复配置备份", kind: "config", target: target.path, paths: [target]) {
            let data = try Data(contentsOf: snapshot)
            let existingPermissions = (try? fm.attributesOfItem(atPath: target.path)[.posixPermissions] as? NSNumber)?.intValue
            if fm.fileExists(atPath: target.path) { try backup(target) }
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
            try fm.setAttributes([.posixPermissions: existingPermissions ?? 0o600], ofItemAtPath: target.path)
        }
    }

    private func backup(_ file: URL) throws {
        guard fm.fileExists(atPath: file.path) else { return }
        try fm.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let name = file.lastPathComponent + "-" + stamp + "-" + UUID().uuidString.prefix(6) + ".bak"
        let snapshot = backupRoot.appendingPathComponent(name)
        try fm.copyItem(at: file, to: snapshot)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: snapshot.path)
        let record = ConfigBackup(id: name, originalPath: file.path, createdAt: Date())
        try JSONEncoder().encode(record).write(to: snapshot.appendingPathExtension("json"), options: .atomic)
    }
    private func jsonRoot(_ file: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: file)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ManagerError.invalid("配置不是 JSON 对象：\(file.path)") }
        return root
    }
    private func writeJSON(_ root: [String: Any], to file: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: file, options: .atomic)
    }
    private func adapt(_ definition: [String: Any], for agent: Agent) -> [String: Any] {
        var d = definition
        for key in ["__codexRawTOML", "__codexRawFingerprint", "__codexRawName", "__unsupported"] {
            d.removeValue(forKey: key)
        }
        if agent != .codex, let headers = d.removeValue(forKey: "http_headers"), d["headers"] == nil { d["headers"] = headers }
        if agent == .claude, d["url"] != nil || d["serverUrl"] != nil, d["type"] == nil { d["type"] = "http" }
        if agent != .codex, d["type"] as? String == "streamable-http" { d["type"] = "http" }
        if agent == .antigravity, let url = d.removeValue(forKey: "url") { d["serverUrl"] = url }
        if agent != .antigravity, let url = d.removeValue(forKey: "serverUrl") { d["url"] = url }
        return d
    }
    private func fingerprint(_ value: Any) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    func mcpContentFingerprint(_ definition: [String: Any]) -> String {
        fingerprint(mcpContentManifest(definition))
    }
    func mcpDeploymentFingerprint(_ definition: [String: Any]) -> String {
        fingerprint(definition)
    }
    private func fingerprint(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func tomlSection(_ raw: String) -> [String]? {
        let line = stripTOMLComment(raw).trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("["), line.hasSuffix("]"), !line.hasPrefix("[[") else { return nil }
        let body = String(line.dropFirst().dropLast())
        var keys: [String] = [], key = ""
        var quote: Character?, escaped = false
        for char in body {
            if let q = quote {
                key.append(char)
                if escaped { escaped = false }
                else if q == "\"" && char == "\\" { escaped = true }
                else if char == q { quote = nil }
            } else if char == "\"" || char == "'" { quote = char; key.append(char) }
            else if char == "." { keys.append(key); key = "" }
            else { key.append(char) }
        }
        guard quote == nil else { return nil }
        keys.append(key)
        return keys.map { value in
            let clean = value.trimmingCharacters(in: .whitespaces)
            return (decodeTOMLValue(clean) as? String) ?? clean
        }
    }

    private func tomlBlocks(_ text: String) -> [String: String] {
        let lines = text.components(separatedBy: .newlines)
        var blocks: [String: String] = [:]
        var start: Int?, name: String?
        var multilineQuote: String?
        for index in lines.indices {
            let raw = lines[index]
            if let delimiter = multilineQuote {
                if raw.contains(delimiter) { multilineQuote = nil }
                continue
            }
            let clean = stripTOMLComment(lines[index]).trimmingCharacters(in: .whitespaces)
            for delimiter in [String(repeating: "\"", count: 3), String(repeating: "'", count: 3)] {
                if clean.components(separatedBy: delimiter).count % 2 == 0 { multilineQuote = delimiter }
            }
            guard clean.hasPrefix("["), clean.hasSuffix("]") else { continue }
            let section = tomlSection(lines[index])
            let next = section.flatMap { $0.count >= 2 && $0[0] == "mcp_servers" ? $0[1] : nil }
            if let name, next == name { continue }
            if let start, let name { blocks[name] = lines[start..<index].joined(separator: "\n") + "\n" }
            name = next
            start = next == nil ? nil : index
        }
        if let start, let name { blocks[name] = lines[start...].joined(separator: "\n") }
        return blocks
    }
    private func parseTOMLBlock(_ block: String) -> [String: Any] {
        var result: [String: Any] = [:]
        var unsupported: [String] = []
        var section: [String] = []
        var serverName: String?
        for line in block.components(separatedBy: .newlines) {
            let trimmed = stripTOMLComment(line).trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                let parts = tomlSection(line) ?? []
                guard parts.count >= 2, parts[0] == "mcp_servers" else { unsupported.append(trimmed); continue }
                let currentName = parts[1]
                if serverName == nil { serverName = currentName }
                section = Array(parts.dropFirst(2))
                continue
            }
            let pieces = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard pieces.count == 2 else { continue }
            let key = decodeTOMLString(pieces[0]) ?? pieces[0]
            if let value = decodeTOMLValue(pieces[1]) {
                putTOMLValue(value, at: section + [key], into: &result)
            } else {
                unsupported.append((section + [key]).joined(separator: "."))
            }
        }
        let rawFingerprint = fingerprint(adapt(result, for: .codex))
        if !unsupported.isEmpty { result["__unsupported"] = unsupported }
        result["__codexRawTOML"] = block
        result["__codexRawName"] = serverName ?? ""
        result["__codexRawFingerprint"] = rawFingerprint
        return result
    }
    private func putTOMLValue(_ value: Any, at path: [String], into result: inout [String: Any]) {
        guard let first = path.first else { return }
        if path.count == 1 { result[first] = value; return }
        var nested = result[first] as? [String: Any] ?? [:]
        putTOMLValue(value, at: Array(path.dropFirst()), into: &nested)
        result[first] = nested
    }
    private func decodeTOMLValue(_ raw: String) -> Any? {
        let value = stripTOMLComment(raw).trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("'"), value.hasSuffix("'"), value.count >= 2 {
            return String(value.dropFirst().dropLast())
        }
        if value.hasPrefix("{"), value.hasSuffix("}") {
            var map: [String: Any] = [:]
            let body = String(value.dropFirst().dropLast())
            for entry in splitTOMLItems(body) where !entry.trimmingCharacters(in: .whitespaces).isEmpty {
                let pair = entry.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                guard pair.count == 2, let child = decodeTOMLValue(pair[1]) else { return nil }
                map[decodeTOMLString(pair[0]) ?? pair[0]] = child
            }
            return map
        }
        if value.hasPrefix("["), value.hasSuffix("]") {
            let body = String(value.dropFirst().dropLast())
            var items: [Any] = []
            for entry in splitTOMLItems(body) where !entry.trimmingCharacters(in: .whitespaces).isEmpty {
                guard let item = decodeTOMLValue(entry) else { return nil }
                items.append(item)
            }
            return items
        }
        guard let data = ("[" + value + "]").data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Any] else { return nil }
        return array.first
    }
    private func stripTOMLComment(_ raw: String) -> String {
        var result = ""
        var quote: Character?
        var escaped = false
        for char in raw {
            if let current = quote {
                result.append(char)
                if escaped { escaped = false }
                else if current == "\"" && char == "\\" { escaped = true }
                else if char == current { quote = nil }
            } else {
                if char == "#" { break }
                if char == "\"" || char == "'" { quote = char }
                result.append(char)
            }
        }
        return result
    }
    private func splitTOMLItems(_ body: String) -> [String] {
        var parts: [String] = []
        var current = ""
        var square = 0, curly = 0
        var quote: Character?
        var escaped = false
        for char in body {
            if let currentQuote = quote {
                current.append(char)
                if escaped { escaped = false }
                else if currentQuote == "\"" && char == "\\" { escaped = true }
                else if char == currentQuote { quote = nil }
                continue
            }
            if char == "\"" || char == "'" { quote = char }
            else if char == "[" { square += 1 }
            else if char == "]" { square -= 1 }
            else if char == "{" { curly += 1 }
            else if char == "}" { curly -= 1 }
            if char == ",", square == 0, curly == 0 {
                parts.append(current)
                current = ""
            } else { current.append(char) }
        }
        parts.append(current)
        return parts
    }
    private func decodeTOMLString(_ value: String) -> String? {
        guard let data = ("[" + value + "]").data(using: .utf8), let array = try? JSONSerialization.jsonObject(with: data) as? [String] else { return nil }
        return array.first
    }
    private func makeTOMLBlock(name: String, definition: [String: Any]) throws -> String {
        guard safeName(name) else { throw ManagerError.invalid("MCP 名称无效：不可为空或包含路径分隔符 /、反斜杠 \\、冒号 : 等特殊字符") }
        var d = adapt(definition, for: .codex)
        if let transport = d["type"] as? String, ["sse", "ws"].contains(transport) {
            throw ManagerError.invalid("Codex 不支持 \(transport) 传输，请使用 HTTP MCP 或本地代理")
        }
        if let raw = definition["__codexRawTOML"] as? String,
           definition["__codexRawName"] as? String == name,
           definition["__codexRawFingerprint"] as? String == fingerprint(d) {
            let clean = removingCodexTransportType(raw)
            return clean.hasSuffix("\n") ? clean : clean + "\n"
        }
        if let unsupported = definition["__unsupported"] as? [String], !unsupported.isEmpty {
            throw ManagerError.invalid("原 TOML 含无法安全转换的字段：\(unsupported.joined(separator: ", "))")
        }
        if let transport = d.removeValue(forKey: "type") as? String {
            guard (d["command"] != nil && transport == "stdio") ||
                  (d["url"] != nil && ["http", "streamable-http"].contains(transport)) else {
                throw ManagerError.invalid("Codex 不支持此 MCP 传输类型：\(transport)")
            }
        }
        if let headers = d.removeValue(forKey: "headers") {
            guard d["url"] != nil, d["http_headers"] == nil else { throw ManagerError.invalid("headers 只能转换为 HTTP MCP 的 http_headers") }
            d["http_headers"] = headers
        }
        let allowed: Set<String> = ["command", "url", "args", "env", "env_vars", "cwd", "experimental_environment", "auth", "bearer_token_env_var", "http_headers", "env_http_headers", "http_headers_helper", "oauth_resource", "oauth", "enabled", "required", "enabled_tools", "disabled_tools", "startup_timeout_sec", "startup_timeout_ms", "tool_timeout_sec", "default_tools_approval_mode", "tools", "scopes"]
        let extra = Set(d.keys).subtracting(allowed)
        guard extra.isEmpty else { throw ManagerError.invalid("Codex 不识别 MCP 字段：\(extra.sorted().joined(separator: ", "))") }
        let tomlKey = name.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil ? name : tomlString(name)
        var lines = ["[mcp_servers.\(tomlKey)]"]
        guard (d["command"] as? String) != nil || (d["url"] as? String) != nil else {
            throw ManagerError.invalid("MCP 缺少 command 或 url")
        }
        for key in d.keys.sorted() {
            lines.append("\(key) = \(try tomlValue(d[key]!))")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func removingCodexTransportType(_ block: String) -> String {
        var headers = 0
        return block.components(separatedBy: "\n").filter { line in
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("[") { headers += 1 }
            return headers != 1 || line.range(of: "^\\s*(?:type|\"type\"|'type')\\s*=", options: .regularExpression) == nil
        }.joined(separator: "\n")
    }

    @discardableResult
    func repairCodexMCPTransportTypes(_ target: Target) throws -> Int {
        guard target.agent == .codex else { throw ManagerError.invalid("仅适用于 Codex 配置") }
        let file = mcpConfig(for: target).0
        let originalData = try Data(contentsOf: file)
        guard let original = String(data: originalData, encoding: .utf8) else { throw ManagerError.invalid("配置不是 UTF-8 文本") }
        var next = original
        var changed: [String: (String, String)] = [:]
        for (name, block) in tomlBlocks(original) {
            let clean = removingCodexTransportType(block)
            if block != clean, let range = next.range(of: block) {
                next.replaceSubrange(range, with: clean)
                changed[name] = (fingerprint(block), fingerprint(clean))
            }
        }
        guard !changed.isEmpty else { return 0 }
        try withRecordedOperation(action: "修复 Codex MCP type 字段", kind: "mcp", target: target.label, paths: [file, deploymentsURL]) {
            try backup(file)
            try assertConfigurationUnchanged(file, expected: originalData)
            try next.write(to: file, atomically: true, encoding: .utf8)
            let updated = deployments().map { record in
                if record.kind == "mcp", record.targetID == target.id,
                   let pair = changed[record.item], record.fingerprint == pair.0 {
                    return Deployment(kind: record.kind, item: record.item, targetID: record.targetID, path: record.path, fingerprint: pair.1)
                }
                return record
            }
            try saveDeployments(updated)
        }
        return changed.count
    }
    private func tomlValue(_ value: Any) throws -> String {
        if let string = value as? String { return tomlString(string) }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "true" : "false" }
            guard number.doubleValue.isFinite else { throw ManagerError.invalid("TOML 数值必须有限") }
            return number.stringValue
        }
        if let array = value as? [Any] {
            return "[" + (try array.map(tomlValue).joined(separator: ", ")) + "]"
        }
        if let map = value as? [String: Any] {
            let entries = try map.keys.sorted().map { key in "\(tomlString(key)) = \(try tomlValue(map[key]!))" }
            return "{" + entries.joined(separator: ", ") + "}"
        }
        throw ManagerError.invalid("MCP 包含不能写入 TOML 的值")
    }
    private func tomlString(_ s: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [s], options: [.fragmentsAllowed, .withoutEscapingSlashes])
        let json = String(data: data, encoding: .utf8)!
        return String(json.dropFirst().dropLast())
    }
}

extension ManagerStore {
    private func assertConfigurationUnchanged(_ file: URL, expected: Data) throws {
        guard (try? Data(contentsOf: file)) == expected else {
            throw ManagerError.conflict("客户端正在修改配置，请等待状态刷新后重试")
        }
    }

    func mcpConfigurationState(_ name: String, target: Target) throws -> CapabilityState {
        var (file, format) = mcpConfig(for: target)
        if target.agent == .claude, target.project != nil, let root = try cachedJSONObject(claudeUserConfig),
           try managedMCPServers(root, file: claudeUserConfig, target: target)[name] != nil {
            (file, format) = (claudeUserConfig, .json)
        }
        let definition: [String: Any]
        if format == .json {
            guard let root = try cachedJSONObject(file) else { return .missing }
            guard let value = try managedMCPServers(root, file: file, target: target)[name] else { return .missing }
            guard let object = value as? [String: Any] else { throw ManagerError.invalid("MCP 配置不是对象") }
            definition = object
        } else {
            let blocks = try cachedParse(file, as: "toml") { data -> [String: String] in
                guard let text = String(data: data, encoding: .utf8) else { throw ManagerError.invalid("配置不是 UTF-8 文本") }
                return tomlBlocks(text)
            }
            guard let block = blocks?[name] else { return .missing }
            definition = parseTOMLBlock(block)
        }
        for key in ["enabled", "disabled"] where definition[key] != nil {
            guard definition[key] is Bool else { throw ManagerError.invalid("MCP 开关不是布尔值") }
        }
        if definition["enabled"] as? Bool == false || definition["disabled"] as? Bool == true { return .disabled }
        if target.agent == .claude {
            for settings in syncConfigurationFiles(target) where settings.pathExtension == "json" {
                guard let root = try cachedJSONObject(settings) else { continue }
                if (root["disabledMcpServers"] as? [String] ?? []).contains(name) || (root["disabledMcpjsonServers"] as? [String] ?? []).contains(name) { return .disabled }
                if let project = target.project, let projects = root["projects"] as? [String: [String: Any]],
                   (projects[project]?["disabledMcpServers"] as? [String] ?? []).contains(name) { return .disabled }
            }
        }
        return .configured
    }

    func codexSkillDisabled(_ folder: URL, target: Target) throws -> Bool {
        var disabled = false
        for file in [resolve("~/.codex/config.toml")] + (target.project == nil ? [] : [mcpConfig(for: target).0]) {
            guard let data = try managedMCPConfigData(file), let text = String(data: data, encoding: .utf8) else { continue }
            for block in try codexSkillBlocks(text) {
                guard let path = block.path else { continue }
                if codexSkillIdentity(path) == codexSkillIdentity(folder.path) { disabled = block.enabled == false }
            }
        }
        return disabled
    }

    private func codexSkillIdentity(_ path: String) -> String {
        var url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL.resolvingSymlinksInPath()
        if url.lastPathComponent.lowercased() == "skill.md" { url.deleteLastPathComponent() }
        return url.path
    }

    private func codexSkillBlocks(_ text: String) throws -> [(range: Range<String.Index>, path: String?, enabled: Bool?)] {
        // Preserve the surrounding TOML verbatim, including unrelated settings.
        if text.contains("[skills]") && text.range(of: "(?m)^\\s*config\\s*=\\s*\\[", options: .regularExpression) != nil { throw ManagerError.invalid("暂不能判断内联 Skill 开关，请使用客户端查看") }
        let regex = try NSRegularExpression(pattern: "(?m)^\\s*\\[\\[skills\\.config\\]\\]\\s*(?:#.*)?$")
        return try regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let header = Range(match.range, in: text) else { return nil }
            let remainder = text[header.upperBound...]
            let nextHeader = remainder.range(of: "(?m)^\\s*\\[", options: .regularExpression)?.lowerBound ?? text.endIndex
            let range = header.lowerBound..<nextHeader
            var path: String?; var enabled: Bool?
            for line in text[range].components(separatedBy: .newlines) {
                let pair = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                if pair.count == 2 {
                    if pair[0] == "path" {
                        guard let value = decodeTOMLValue(pair[1]) as? String else { throw ManagerError.invalid("Skill 路径无法读取") }
                        path = value
                    }
                    if pair[0] == "enabled" {
                        guard let value = decodeTOMLValue(pair[1]) as? Bool else { throw ManagerError.invalid("Skill 开关不是布尔值") }
                        enabled = value
                    }
                }
            }
            return (range, path, enabled)
        }
    }

    func enableClientSkill(_ name: String, target: Target) throws {
        guard target.agent == .codex else { throw ManagerError.invalid("该客户端的 Skill 开关暂不支持直接修改") }
        let roots = target.project == nil ? target.agent.globalSkillRoots : target.agent.projectSkillRoots
        let folders = roots.map { resolve($0, project: target.project).appendingPathComponent(name) }
        let files = [resolve("~/.codex/config.toml")] + (target.project == nil ? [] : [mcpConfig(for: target).0])
        try withRecordedOperation(action: "启用客户端 Skill", kind: "skill", target: target.label, paths: files) {
            for file in files {
                guard let data = try managedMCPConfigData(file), var text = String(data: data, encoding: .utf8) else { continue }
                for block in try codexSkillBlocks(text).reversed() {
                    guard let path = block.path else { continue }
                    guard folders.contains(where: { codexSkillIdentity($0.path) == codexSkillIdentity(path) }) else { continue }
                    let original = String(text[block.range])
                    let next = original.replacingOccurrences(of: "(?m)^(\\s*enabled\\s*=\\s*)false", with: "$1true", options: .regularExpression)
                    text.replaceSubrange(block.range, with: next)
                }
                if text != String(data: data, encoding: .utf8) { try backup(file); try assertConfigurationUnchanged(file, expected: data); try text.write(to: file, atomically: true, encoding: .utf8) }
            }
            guard try capabilityState(name, target: target, skill: true) == .configured else { throw ManagerError.invalid("Skill 启用状态未确认") }
        }
    }

    func enableClientMCP(_ name: String, target: Target) throws {
        let (file, format) = try mcpLocation(name, target: target)
        let files = syncConfigurationFiles(target)
        try withRecordedOperation(action: "启用客户端 MCP", kind: "mcp", target: target.label, paths: files + [deploymentsURL]) {
            let originalData = try Data(contentsOf: file)
            if format == .json {
                var root = try jsonRoot(file)
                var servers = try managedMCPServers(root, file: file, target: target)
                guard var current = servers[name] as? [String: Any] else { throw ManagerError.invalid("目标 MCP 不存在") }
                if current["enabled"] as? Bool == false { current["enabled"] = true }
                if current["disabled"] as? Bool == true { current["disabled"] = false }
                servers[name] = current; try setManagedMCPServers(servers, in: &root, file: file, target: target)
                try backup(file); try assertConfigurationUnchanged(file, expected: originalData); try writeJSON(root, to: file)
                if target.agent == .claude {
                    for settings in files where settings.pathExtension == "json" && fm.fileExists(atPath: settings.path) {
                        let settingsData = try Data(contentsOf: settings)
                        var object = try jsonRoot(settings)
                        let originalFingerprint = fingerprint(object)
                        for key in ["disabledMcpServers", "disabledMcpjsonServers"] {
                            if let list = object[key] as? [String] { object[key] = list.filter { $0 != name } }
                        }
                        if let project = target.project, var projects = object["projects"] as? [String: [String: Any]], var entry = projects[project] {
                            if let list = entry["disabledMcpServers"] as? [String] { entry["disabledMcpServers"] = list.filter { $0 != name } }
                            projects[project] = entry; object["projects"] = projects
                        }
                        if fingerprint(object) != originalFingerprint {
                            try backup(settings); try assertConfigurationUnchanged(settings, expected: settingsData); try writeJSON(object, to: settings)
                        }
                    }
                }
            } else {
                var text = try String(contentsOf: file, encoding: .utf8)
                guard let block = tomlBlocks(text)[name], let range = text.range(of: block) else { throw ManagerError.invalid("目标 MCP 不存在") }
                var lines = block.components(separatedBy: .newlines)
                for index in lines.indices.dropFirst() {
                    if lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("[") { break }
                    lines[index] = lines[index].replacingOccurrences(of: "^(\\s*enabled\\s*=\\s*)false", with: "$1true", options: .regularExpression)
                }
                let next = lines.joined(separator: "\n")
                text.replaceSubrange(range, with: next)
                try backup(file); try assertConfigurationUnchanged(file, expected: originalData); try text.write(to: file, atomically: true, encoding: .utf8)
            }
            guard try mcpConfigurationState(name, target: target) == .configured else { throw ManagerError.invalid("MCP 启用状态未确认") }
            // Re-enabling explicitly adopts the current client definition as the managed baseline.
            let currentFingerprint: String
            if format == .json {
                let servers = try managedMCPServers(jsonRoot(file), file: file, target: target)
                guard let current = servers[name] else { throw ManagerError.invalid("目标 MCP 不存在") }
                currentFingerprint = fingerprint(current)
            } else {
                let text = try String(contentsOf: file, encoding: .utf8)
                guard let block = tomlBlocks(text)[name] else { throw ManagerError.invalid("目标 MCP 不存在") }
                currentFingerprint = fingerprint(block)
            }
            let updated = deployments().map { record in
                record.kind == "mcp" && record.item == name && record.targetID == target.id
                    ? Deployment(kind: record.kind, item: record.item, targetID: record.targetID, path: record.path, fingerprint: currentFingerprint)
                    : record
            }
            try saveDeployments(updated)
        }
    }
}

func mcpFormDefinition(existing: [String: Any], command: String, args: [String], env: [String: String], url: String?, transport: String, headers: [String: String]) -> [String: Any] {
    var definition = existing
    for key in ["command", "args", "env", "url", "serverUrl", "headers", "http_headers", "type"] { definition.removeValue(forKey: key) }
    if let url {
        definition["type"] = transport
        definition["url"] = url
        if !headers.isEmpty { definition["headers"] = headers }
    } else {
        definition["command"] = command
        definition["args"] = args
        if !env.isEmpty { definition["env"] = env }
    }
    return definition
}

extension ManagerStore {
    /// Explicit cleanup, never run automatically during scanning or startup.
    /// Snapshots preserve the deleted artifacts for operation-history recovery.
    func cleanupBundledMCPArtifacts() throws -> [String] {
        let libraries = libraryMCP().filter(\.isSystemService)
        let installed = installedMCP().filter(\.isSystemService)
        let records = deployments()
        let copies = installed.filter { item in
            if let owner = item.bundledOwner { return owner != item.agent }
            return records.contains { $0.kind == "mcp" && $0.item == item.name && $0.path == item.source.path }
        }
        let disabled = disabledItems()
        let stashes = disabled.filter { record in
            guard record.kind == "mcp" else { return false }
            let file = URL(fileURLWithPath: record.stashPath)
            guard let data = try? Data(contentsOf: file) else { return false }
            let definition: [String: Any]
            if file.pathExtension == "json" {
                guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
                definition = object
            } else {
                guard let text = String(data: data, encoding: .utf8) else { return false }
                definition = parseTOMLBlock(text)
            }
            let item = MCPItem(name: record.item, definition: definition, agent: nil, project: nil, source: file, isLibrary: false)
            guard item.isSystemService else { return false }
            return item.bundledOwner.map { !record.targetID.hasPrefix($0.rawValue + "|") } ?? true
        }
        let names = Set((libraries + installed).map(\.name) + stashes.map(\.item))
        let obsolete = records.filter { record in
            guard record.kind == "mcp" else { return false }
            let live = installedMCP().first { item in
                item.name == record.item && item.agent.map { Target(agent: $0, project: item.project).id } == record.targetID
            }
            if let live { return live.isSystemService }
            return libraries.contains { $0.name == record.item } || stashes.contains { $0.item == record.item && $0.targetID == record.targetID }
        }
        guard !libraries.isEmpty || !copies.isEmpty || !stashes.isEmpty || !obsolete.isEmpty else { return [] }
        let paths = libraries.map(\.source) + copies.map(\.source) + stashes.map { URL(fileURLWithPath: $0.stashPath) } + [deploymentsURL, disabledURL, presetsURL]
        var result: [String] = []
        try withRecordedOperation(action: "清理内置 MCP 副本与中央库", kind: "mcp", target: names.sorted().joined(separator: ", "), paths: paths) {
            for item in copies {
                guard let agent = item.agent else { continue }
                let target = Target(agent: agent, project: item.project)
                let file = item.source
                let original = try Data(contentsOf: file)
                if file.pathExtension == "toml" {
                    guard var text = String(data: original, encoding: .utf8), let block = tomlBlocks(text)[item.name], let range = text.range(of: block) else { throw ManagerError.invalid("找不到内置副本配置块") }
                    text.removeSubrange(range)
                    try backup(file)
                    try assertConfigurationUnchanged(file, expected: original)
                    try text.write(to: file, atomically: true, encoding: .utf8)
                } else {
                    var root = try jsonRoot(file)
                    var servers = try managedMCPServers(root, file: file, target: target)
                    servers.removeValue(forKey: item.name)
                    try setManagedMCPServers(servers, in: &root, file: file, target: target)
                    try backup(file)
                    try assertConfigurationUnchanged(file, expected: original)
                    try writeJSON(root, to: file)
                }
                result.append("删除副本：\(item.name) · \(target.label)")
            }
            for item in libraries {
                try fm.removeItem(at: item.source)
                result.append("移出中央库：\(item.name)")
            }
            for record in stashes {
                try fm.removeItem(atPath: record.stashPath)
                result.append("删除暂存副本：\(record.item) · \(record.targetID)")
            }
            let obsoleteIDs = Set(obsolete.map { $0.targetID + "|" + $0.item })
            try saveDeployments(records.filter { !($0.kind == "mcp" && obsoleteIDs.contains($0.targetID + "|" + $0.item)) })
            let stashPaths = Set(stashes.map(\.stashPath))
            try saveDisabled(disabled.filter { !stashPaths.contains($0.stashPath) })
            let updated = presets().compactMap { preset -> CapabilityPreset? in
                var next = preset
                next.mcps.removeAll { names.contains($0) }
                return next.itemCount == 0 ? nil : next
            }
            if fm.fileExists(atPath: presetsURL.path) { try JSONEncoder().encode(updated).write(to: presetsURL, options: .atomic) }
        }
        return result
    }
}

func claudeMCPToolKey(_ name: String) -> String {
    name.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_", options: .regularExpression)
}
