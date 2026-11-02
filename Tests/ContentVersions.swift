import Foundation

extension Smoke {
    static func contentVersionChecks() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("looma-content-" + UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let home = root.appendingPathComponent("home")
        let project = root.appendingPathComponent("project")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        try fm.createDirectory(at: project, withIntermediateDirectories: true)
        let store = ManagerStore(baseURL: root.appendingPathComponent("library"), userHomeURL: home, agentAvailability: { _ in true })
        try store.addProject(project.path)
        let codex = Target(agent: .codex, project: project.path)
        let wb = Target(agent: .workbuddy, project: project.path)
        func write(_ value: [String: Any], to url: URL) throws {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]).write(to: url)
        }
        func version(_ target: Target?, skill: Bool = false) -> ContentVersion {
            store.contentVersions("A", skill: skill).first { $0.target == target }!
        }
        let a: [String: Any] = ["url": "https://example.test/mcp", "http_headers": ["Authorization": "secret-one"], "enabled": false]
        let b: [String: Any] = ["serverUrl": "https://example.test/mcp", "headers": ["Authorization": "secret-one"], "type": "streamable-http", "disabled": true]
        check(store.mcpContentManifest(a) == store.mcpContentManifest(b), "Lossless client aliases produce false difference")
        check(store.mcpContentManifest(["command": "echo"]) == store.mcpContentManifest(["command": "echo", "type": "stdio"]), "Default stdio differs")
        var changed = b
        changed["headers"] = ["Authorization": "secret-two"]
        check(store.mcpContentManifest(a) != store.mcpContentManifest(changed), "Credential changes ignored")
        let secretPreview = store.redactedMCPContent(["url": "https://user:password@example.test/mcp?token=hidden#secret", "headers": ["Authorization": "secret-one"], "env": ["VALUE": "secret-two"], "args": ["private"]])
        for secret in ["password", "hidden", "secret-one", "secret-two", "private"] { check(!secretPreview.contains(secret), "Preview leaked a credential") }
        check(secretPreview.contains("example.test/mcp"), "Preview lost endpoint context")

        try store.importMCP(name: "A", definition: a)
        try store.deployMCP("A", to: codex)
        try write(["unrelated": true, "mcpServers": ["A": changed, "neighbor": ["command": "keep"]]], to: wb.mcpConfig.0)
        let codexOriginal = try Data(contentsOf: codex.mcpConfig.0)
        let wbOriginal = try Data(contentsOf: wb.mcpConfig.0)
        let library = version(nil)
        check(library.differences(from: version(codex))?.isEmpty == true, "Parsed TOML metadata creates false difference")
        check(library.differences(from: version(wb)) == ["/headers/Authorization"], "Credential difference lost its field location")
        check(contentRelation(store.contentVersions("A", skill: false), target: wb) == "与中央库不同", "Different content mislabeled")
        try store.replaceContentVersion(from: library, to: version(wb))
        check(version(nil).digest == version(wb).digest, "MCP replacement failed")
        check(try store.mcpConfigurationState("A", target: wb) == .configured, "MCP replacement was not enabled")
        let rootJSON = try JSONSerialization.jsonObject(with: Data(contentsOf: wb.mcpConfig.0)) as! [String: Any]
        check(rootJSON["unrelated"] as? Bool == true && (rootJSON["mcpServers"] as? [String: Any])?["neighbor"] != nil, "Replacement changed neighboring config")
        check(try Data(contentsOf: codex.mcpConfig.0) == codexOriginal, "Replacement touched another client")
        try store.validateManagedMCPRemoval("A", from: wb)
        let replacement = store.operationHistory().first { $0.action == "替换 MCP 版本" }!
        try store.rollbackOperation(replacement)
        check(try Data(contentsOf: wb.mcpConfig.0) == wbOriginal, "MCP rollback lost original bytes")
        let stale = version(wb)
        try write(["mcpServers": ["A": ["url": "https://changed.test/mcp"]]], to: wb.mcpConfig.0)
        do { try store.replaceContentVersion(from: library, to: stale); preconditionFailure("Stale preview overwrote new configuration") } catch ManagerError.conflict { }
        check(version(wb).definition?["url"] as? String == "https://changed.test/mcp", "Rejected stale action modified target")
        try store.archiveContentVersion(version(wb), as: "A-workbuddy")
        check(store.libraryMCP().contains { $0.name == "A-workbuddy" }, "Alternate MCP archive missing")

        // Entire skill packages, linked resources, executable flags, and nested refresh.
        let skill = root.appendingPathComponent("A")
        try fm.createDirectory(at: skill.appendingPathComponent("scripts"), withIntermediateDirectories: true)
        try "---\nname: A\n---\nReview".write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try "one".write(to: skill.appendingPathComponent("scripts/tool.sh"), atomically: true, encoding: .utf8)
        try "hidden".write(to: skill.appendingPathComponent(".resource"), atomically: true, encoding: .utf8)
        try store.importSkill(skill)
        try store.deploySkill("A", to: wb, copy: true)
        let oldSkill = version(wb, skill: true)
        let before = store.synchronizationCheckpoint()
        try "two".write(to: oldSkill.path.appendingPathComponent("scripts/tool.sh"), atomically: true, encoding: .utf8)
        let after = store.synchronizationCheckpoint()
        check(before != after, "Nested same-size skill edit did not trigger refresh")
        check(version(nil, skill: true).differences(from: version(wb, skill: true)) == ["scripts/tool.sh"], "Resource-only skill difference ignored")
        try store.replaceContentVersion(from: version(nil, skill: true), to: version(wb, skill: true))
        check(version(nil, skill: true).digest == version(wb, skill: true).digest, "Skill replacement lost files")
        _ = try store.validateManagedSkillRemoval("A", from: wb)
        let skillReplacement = store.operationHistory().first { $0.action == "替换 Skill 版本" }!
        try store.rollbackOperation(skillReplacement)
        check(try String(contentsOf: oldSkill.path.appendingPathComponent("scripts/tool.sh"), encoding: .utf8) == "two", "Skill rollback lost external edit")
        try store.deploySkill("A", to: codex, copy: false)
        do { try store.replaceContentVersion(from: version(wb, skill: true), to: version(nil, skill: true)); preconditionFailure("Shared library modification was allowed") } catch ManagerError.conflict { }
        let outside = root.appendingPathComponent("outside")
        try fm.createDirectory(at: outside, withIntermediateDirectories: true)
        try "linked".write(to: outside.appendingPathComponent("data"), atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: skill.appendingPathComponent("linked"), withDestinationURL: outside)
        check(try store.skillContentManifest(skill)["linked/data"] != nil, "Linked resource directory was skipped")
        try fm.createSymbolicLink(at: outside.appendingPathComponent("cycle"), withDestinationURL: skill)
        do { _ = try store.skillContentManifest(skill); preconditionFailure("Cycle was silently treated as equivalent") } catch ManagerError.invalid { }

        let atomicFile = root.appendingPathComponent("atomic")
        try Data("before".utf8).write(to: atomicFile)
        do {
            try store.withAtomicContentOperation(action: "failure test", kind: "mcp", target: "test", paths: [atomicFile]) {
                try Data("partial".utf8).write(to: atomicFile)
                throw ManagerError.invalid("simulated failure")
            }
            preconditionFailure("Failure was swallowed")
        } catch ManagerError.invalid { }
        check(try Data(contentsOf: atomicFile) == Data("before".utf8), "Partial replacement was not restored")
        print("Content version checks passed")
    }
}
