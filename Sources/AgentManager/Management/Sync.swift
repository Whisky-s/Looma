import Foundation
import CryptoKit

/// Configuration state, not a claim about a running client's connection or loaded session.
enum CapabilityState: String { case configured, disabled, missing, unknown }

extension ManagerStore {
    func capabilityState(_ name: String, target: Target, skill: Bool) throws -> CapabilityState {
        if skill {
            let roots = target.project == nil ? target.agent.globalSkillRoots : target.agent.projectSkillRoots
            var found = false
            for root in roots {
                let folder = resolve(root, project: target.project).appendingPathComponent(name)
                let skillFile = folder.appendingPathComponent("SKILL.md")
                let present: Bool
                do { _ = try fm.attributesOfItem(atPath: skillFile.path); present = true }
                catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile { present = false }
                if present {
                    found = true
                    if try target.agent != .codex || !codexSkillDisabled(folder, target: target) { return .configured }
                }
            }
            return found ? .disabled : .missing
        }
        return try mcpConfigurationState(name, target: target)
    }

    func synchronizationStates() -> [String: CapabilityState] {
        let names = Set(librarySkills().map(\.name) + installedSkills().map(\.name) + deployments().filter { $0.kind == "skill" }.map(\.item))
        let mcps = Set(libraryMCP().map(\.name) + installedMCP().map(\.name) + deployments().filter { $0.kind == "mcp" }.map(\.item))
        var states: [String: CapabilityState] = [:]
        for agent in Agent.allCases {
            for target in [Target(agent: agent, project: nil)] + projects().map({ Target(agent: agent, project: $0) }) {
                for (skill, items) in [(true, names), (false, mcps)] {
                    for name in items {
                        states[syncKey(name, target: target, skill: skill)] = (try? capabilityState(name, target: target, skill: skill)) ?? .unknown
                    }
                }
            }
        }
        return states
    }

    /// A small configuration checkpoint; session logs and client caches are never scanned.
    func synchronizationCheckpoint() -> String {
        var lines: [String] = []
        func stamp(_ url: URL) {
            let attrs = try? fm.attributesOfItem(atPath: url.path)
            lines.append(url.path + ":" + String(describing: (attrs?[.modificationDate] as? Date)?.timeIntervalSince1970) + ":" + String(describing: attrs?[.size]) + ":" + String(describing: attrs?[.posixPermissions]))
            if let link = try? fm.destinationOfSymbolicLink(atPath: url.path) { lines.append(link) }
        }
        func stampSkillResources(_ folder: URL, ancestors: Set<String> = []) {
            let resolved = folder.resolvingSymlinksInPath().standardizedFileURL
            guard !ancestors.contains(resolved.path) else { return }
            stamp(resolved)
            for child in ((try? fm.contentsOfDirectory(at: resolved, includingPropertiesForKeys: nil)) ?? []).sorted(by: { $0.path < $1.path }) {
                guard ![".git", ".git-source.json", ".DS_Store"].contains(child.lastPathComponent) else { continue }
                stamp(child)
                var directory: ObjCBool = false
                if fm.fileExists(atPath: child.path, isDirectory: &directory), directory.boolValue {
                    stampSkillResources(child, ancestors: ancestors.union([resolved.path]))
                }
            }
        }
        for file in [deploymentsURL, disabledURL, base.appendingPathComponent("projects.json")] { stamp(file) }
        var configFiles = Set<URL>()
        for agent in Agent.allCases {
            for target in [Target(agent: agent, project: nil)] + projects().map({ Target(agent: agent, project: $0) }) {
                configFiles.formUnion(syncConfigurationFiles(target))
                let roots = target.project == nil ? agent.globalSkillRoots : agent.projectSkillRoots
                for root in roots {
                    let url = resolve(root, project: target.project)
                    stamp(url)
                    for child in ((try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []).sorted(by: { $0.path < $1.path }) {
                        stamp(child)
                        stamp(child.appendingPathComponent("SKILL.md"))
                        if fm.fileExists(atPath: child.appendingPathComponent("SKILL.md").path) { stampSkillResources(child) }
                    }
                }
            }
        }
        for file in configFiles.sorted(by: { $0.path < $1.path }) {
            if file.standardizedFileURL == claudeUserConfig.standardizedFileURL {
                // Claude Code 会频繁写入 ~/.claude.json 的统计字段，只比较与 MCP 相关的部分，避免无谓的整页刷新。
                lines.append(file.path + ":" + claudeMCPDigest())
                continue
            }
            stamp(file)
            if let data = try? Data(contentsOf: file) { lines.append(SHA256.hash(data: data).description) }
        }
        for root in [skillsRoot, mcpRoot] {
            stamp(root)
            for child in ((try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []).sorted(by: { $0.path < $1.path }) {
                stamp(child); stamp(child.appendingPathComponent("SKILL.md"))
                if root == skillsRoot { stampSkillResources(child) }
            }
        }
        return SHA256.hash(data: Data(lines.joined(separator: "\n").utf8)).description
    }

    private func claudeMCPDigest() -> String {
        do {
            return try cachedParse(claudeUserConfig, as: "claude-mcp-digest", { data -> String in
            guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "invalid" }
            let keys = ["mcpServers", "disabledMcpServers", "disabledMcpjsonServers", "enabledMcpjsonServers"]
            var relevant: [String: Any] = [:]
            for key in keys { relevant[key] = root[key] }
            if let projects = root["projects"] as? [String: Any] {
                var subset: [String: Any] = [:]
                for (path, value) in projects {
                    guard let entry = value as? [String: Any] else { subset[path] = "invalid"; continue }
                    var picked: [String: Any] = [:]
                    for key in keys { picked[key] = entry[key] }
                    if !picked.isEmpty { subset[path] = picked }
                }
                relevant["projects"] = subset
            } else if root["projects"] != nil {
                relevant["projects"] = "invalid"
            }
            let normalized = (try? JSONSerialization.data(withJSONObject: relevant, options: [.sortedKeys, .fragmentsAllowed])) ?? Data()
            return SHA256.hash(data: normalized).description
            }) ?? "missing"
        } catch { return "invalid" }
    }

    func syncConfigurationFiles(_ target: Target) -> [URL] {
        var files = [mcpConfig(for: target).0]
        if target.agent == .codex { files.append(resolve("~/.codex/config.toml")) }
        if target.agent == .claude {
            files.append(claudeUserConfig)
            files.append(userHomeURL.appendingPathComponent(".claude/settings.json"))
            if let project = target.project {
                files.append(resolve(".claude/settings.json", project: project))
                files.append(resolve(".claude/settings.local.json", project: project))
            }
        }
        return Array(Set(files)).sorted { $0.path < $1.path }
    }
}

func syncKey(_ name: String, target: Target, skill: Bool) -> String {
    (skill ? "skill:" : "mcp:") + target.id + ":" + name
}
