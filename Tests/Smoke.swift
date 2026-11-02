import Foundation

@main struct Smoke {
    static func check(_ value: Bool, _ message: String) { precondition(value, message) }
    static func main() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("agent-manager-test-" + UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let project = root.appendingPathComponent("project")
        try fm.createDirectory(at: project, withIntermediateDirectories: true)
        let store = ManagerStore(baseURL: root.appendingPathComponent("app"), agentAvailability: { _ in true })
        try store.addProject(project.path)

        let privateURL = MCPItem(name: "remote", definition: ["url": "https://user:password@example.com/mcp?token=hidden#section"], agent: nil, project: nil, source: root, isLibrary: true)
        check(privateURL.summary == "https://example.com/mcp", "MCP URL summary exposed credentials")

        let source = root.appendingPathComponent("review")
        try fm.createDirectory(at: source, withIntermediateDirectories: true)
        try "---\nname: review\ndescription: review code\n---\n".write(to: source.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try store.importSkill(source)
        let claude = Target(agent: .claude, project: project.path)
        try store.deploySkill("review", to: claude, copy: false)
        check(fm.fileExists(atPath: claude.skillRoot.appendingPathComponent("review/SKILL.md").path), "Skill link not created")
        do {
            try store.deleteLibrarySkill("review")
            preconditionFailure("Active Skill library item was deleted")
        } catch ManagerError.conflict { }
        try store.removeSkill("review", from: claude)
        check(!fm.fileExists(atPath: claude.skillRoot.appendingPathComponent("review").path), "Skill link not removed")
        let managedLink = claude.skillRoot.appendingPathComponent("review")
        try store.deploySkill("review", to: claude, copy: false)
        try fm.removeItem(at: managedLink)
        try store.removeSkill("review", from: claude)
        check(!store.deployments().contains { $0.item == "review" && $0.targetID == claude.id }, "Missing link left a stale deployment")
        try store.deploySkill("review", to: claude, copy: false)
        try fm.removeItem(at: managedLink)
        let foreignDestination = root.appendingPathComponent("missing-foreign-skill")
        try fm.createSymbolicLink(at: managedLink, withDestinationURL: foreignDestination)
        do {
            try store.removeSkill("review", from: claude)
            preconditionFailure("Externally redirected dangling link was removed")
        } catch ManagerError.conflict { }
        check(try fm.destinationOfSymbolicLink(atPath: managedLink.path) == foreignDestination.path, "Foreign link was changed")
        try fm.removeItem(at: managedLink)
        try fm.createDirectory(at: managedLink, withIntermediateDirectories: true)
        do {
            try store.removeSkill("review", from: claude)
            preconditionFailure("External directory replacing a link was removed")
        } catch ManagerError.conflict { }
        try fm.removeItem(at: managedLink)
        try store.removeSkill("review", from: claude)
        try store.deploySkill("review", to: claude, copy: true)
        try fm.removeItem(at: managedLink)
        try store.removeSkill("review", from: claude)
        check(!store.deployments().contains { $0.item == "review" && $0.targetID == claude.id }, "Missing copy left a stale deployment")
        let external = claude.skillRoot.appendingPathComponent("manual")
        try fm.createDirectory(at: external, withIntermediateDirectories: true)
        try "# Manual".write(to: external.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try store.disableExistingSkill("manual", from: claude)
        check(!fm.fileExists(atPath: external.path), "Existing Skill not disabled")
        try store.restoreExistingSkill("manual", to: claude)
        check(fm.fileExists(atPath: external.appendingPathComponent("SKILL.md").path), "Existing Skill not restored")

        let cursor = Target(agent: .cursor, project: project.path)
        let jsonFile = cursor.mcpConfig.0
        try fm.createDirectory(at: jsonFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        let hostCommand = root.appendingPathComponent("Cursor.app/Contents/Resources/cua_node/bin/node_repl")
        try fm.createDirectory(at: hostCommand.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{\"mcpServers\":{\"existing\":{\"url\":\"https://example.com/mcp\"},\"node_repl\":{\"command\":\"\(hostCommand.path)\"}},\"otherSetting\":true}".write(to: jsonFile, atomically: true, encoding: .utf8)
        try store.importMCP(name: "new", definition: ["command": "npx", "args": ["-y", "package"]])
        try store.deployMCP("new", to: cursor)
        do {
            try store.deleteLibraryMCP("new")
            preconditionFailure("Active MCP library item was deleted")
        } catch ManagerError.conflict { }
        var json = try JSONSerialization.jsonObject(with: Data(contentsOf: jsonFile)) as! [String: Any]
        check(json["otherSetting"] as? Bool == true, "Unrelated JSON setting lost")
        check((json["mcpServers"] as! [String: Any]).count == 3, "MCP not added")
        check(store.installedMCP().first { $0.name == "node_repl" && $0.project == project.path }?.isSystemService == true, "App-bundled MCP was not marked as a system service")
        do {
            try store.disableExistingMCP("node_repl", from: cursor)
            preconditionFailure("System MCP was allowed to be disabled")
        } catch ManagerError.conflict { }
        try store.removeMCP("new", from: cursor)
        json = try JSONSerialization.jsonObject(with: Data(contentsOf: jsonFile)) as! [String: Any]
        check((json["mcpServers"] as! [String: Any])["existing"] != nil, "Existing MCP lost")
        try store.disableExistingMCP("existing", from: cursor)
        check(store.installedMCP().first { $0.name == "existing" && $0.project == project.path } == nil, "Existing MCP not disabled")
        try store.restoreExistingMCP("existing", to: cursor)
        check(store.installedMCP().first { $0.name == "existing" && $0.project == project.path } != nil, "Existing MCP not restored")

        // Test Chinese characters, spaces, and parentheses in MCP names
        let chineseMCPName = "Teambition 项目管理 (新)-MCP"
        try store.importMCP(name: chineseMCPName, definition: ["type": "streamable-http", "url": "https://mcp-gateway.com/sse"])
        check(store.libraryMCP().contains { $0.name == chineseMCPName }, "Chinese MCP name import failed")
        try store.deployMCP(chineseMCPName, to: cursor)
        check(store.installedMCP().contains { $0.name == chineseMCPName && $0.agent == .cursor }, "Chinese MCP deployment failed")
        try store.removeMCP(chineseMCPName, from: cursor)
        // Claude Code reads non-ASCII server names from config; only `claude mcp add` rejects them.
        try store.deployMCP(chineseMCPName, to: claude)
        check(store.installedMCP().contains { $0.name == chineseMCPName && $0.agent == .claude && $0.project == claude.project }, "Chinese MCP deployment to Claude failed")
        try store.removeMCP(chineseMCPName, from: claude)
        let clashingName = "Teambition 项目管理 (旧)-MCP"
        try store.importMCP(name: clashingName, definition: ["command": "node"])
        try store.deployMCP(chineseMCPName, to: claude)
        do {
            try store.deployMCP(clashingName, to: claude)
            preconditionFailure("Claude accepted two MCP names with the same tool prefix")
        } catch ManagerError.conflict { }
        try store.removeMCP(chineseMCPName, from: claude)
        let clashPlan = store.presetPlan(CapabilityPreset(name: "重名", skills: [], mcps: [chineseMCPName, clashingName]), targets: [claude], action: .enable)
        check(clashPlan.contains { $0.name == clashingName && $0.step == .blocked } && !clashPlan.contains(where: \.willChange),
              "Preset did not block Claude MCP tool-name clashes")
        try store.deleteLibraryMCP(clashingName)
        try store.deleteLibraryMCP(chineseMCPName)
        check(!store.libraryMCP().contains { $0.name == chineseMCPName }, "Chinese MCP deletion failed")

        let cursorReview = cursor.skillRoot.appendingPathComponent("review")
        try fm.createDirectory(at: cursorReview, withIntermediateDirectories: true)
        try "# Cursor's original review".write(to: cursorReview.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let preset = CapabilityPreset(name: "日常开发", skills: ["review"], mcps: ["new"])
        try store.savePreset(preset)
        check(ManagerStore(baseURL: store.base).presets().first == preset, "Preset was not persisted")
        let unavailableStore = ManagerStore(baseURL: root.appendingPathComponent("unavailable-app"), agentAvailability: { $0 != .qoder })
        try unavailableStore.importSkill(source)
        try unavailableStore.importMCP(name: "new", definition: ["command": "node"])
        let missingQoder = Target(agent: .qoder, project: project.path)
        let unavailablePlan = unavailableStore.presetPlan(preset, targets: [missingQoder], action: .enable)
        check(unavailablePlan.count == 1 && unavailablePlan[0].step == .blocked && !unavailablePlan[0].willChange,
              "Preset offered to configure an uninstalled client")
        let unavailableResult = unavailableStore.applyPreset(preset, targets: [missingQoder], action: .enable, copySkills: false)
        check(unavailableResult.changed.isEmpty && unavailableResult.failed.count == 1,
              "Preset applied to an uninstalled client")
        do {
            try unavailableStore.deploySkill("review", to: missingQoder, copy: false)
            preconditionFailure("Direct Skill deployment accepted an uninstalled client")
        } catch ManagerError.invalid { }
        do {
            try unavailableStore.deployMCP("new", to: missingQoder)
            preconditionFailure("Direct MCP deployment accepted an uninstalled client")
        } catch ManagerError.invalid { }
        check(!fm.fileExists(atPath: missingQoder.skillRoot.path) && !fm.fileExists(atPath: missingQoder.mcpConfig.0.path),
              "Preset created configuration files for an uninstalled client")
        let presetTargets = [claude, cursor]
        let preview = store.presetPlan(preset, targets: presetTargets, action: .enable)
        check(preview.filter(\.willChange).count == 7, "Preset replacement preview omitted removals or deployments")
        let applied = store.applyPreset(preset, targets: presetTargets, action: .enable, copySkills: false)
        check(applied.changed.count == 7 && applied.failed.isEmpty, "Preset did not replace target capabilities")
        check(!fm.fileExists(atPath: external.path), "Preset left an unrelated Skill active")
        check(!store.installedMCP().contains { $0.name == "existing" && $0.agent == .cursor && $0.project == project.path }, "Preset left an unrelated MCP active")
        check(store.installedMCP().contains { $0.name == "node_repl" && $0.agent == .cursor && $0.project == project.path }, "Preset removed a system MCP service")
        check((try? fm.destinationOfSymbolicLink(atPath: cursorReview.path)) != nil, "Preset did not replace the same-name external Skill")
        check(store.disabledItems().contains { $0.kind == "skill" && $0.item == "review" && $0.targetID == cursor.id }, "Original same-name Skill was not stashed")
        let repeated = store.applyPreset(preset, targets: presetTargets, action: .enable, copySkills: false)
        check(repeated.changed.isEmpty && repeated.skipped.count == 5, "Repeated preset replacement was not idempotent")
        let stopped = store.applyPreset(preset, targets: presetTargets, action: .disable, copySkills: false)
        check(stopped.changed.count == 4 && stopped.failed.isEmpty, "Preset did not stop managed deployments")
        let externalPreset = CapabilityPreset(name: "外部配置", skills: [], mcps: ["existing"])
        let externalStop = store.applyPreset(externalPreset, targets: [cursor], action: .disable, copySkills: false)
        check(externalStop.changed.isEmpty && externalStop.skipped.count == 1, "Preset stop did not skip external configuration")
        try store.restoreExistingSkill("manual", to: claude)
        try store.restoreExistingSkill("review", to: cursor)
        try store.restoreExistingMCP("existing", to: cursor)
        check(store.installedMCP().contains { $0.name == "existing" && $0.agent == .cursor && $0.project == project.path }, "Stashed external MCP could not be restored")
        try store.deleteExistingMCP("existing", from: cursor)
        check(!store.installedMCP().contains { $0.name == "existing" && $0.agent == .cursor && $0.project == project.path }, "User MCP could not be deleted")
        let deletedMCP = store.operationHistory().first { $0.action == "删除用户 MCP" }!
        try store.rollbackOperation(deletedMCP)
        check(store.installedMCP().contains { $0.name == "existing" && $0.agent == .cursor && $0.project == project.path }, "Deleted user MCP could not be rolled back")
        try store.deleteExistingSkill("manual", from: claude)
        check(!fm.fileExists(atPath: external.path), "User Skill could not be deleted")
        let deletedSkill = store.operationHistory().first { $0.action == "删除用户 Skill" }!
        try store.rollbackOperation(deletedSkill)
        check(fm.fileExists(atPath: external.appendingPathComponent("SKILL.md").path), "Deleted user Skill could not be rolled back")
        check(try String(contentsOf: cursorReview.appendingPathComponent("SKILL.md"), encoding: .utf8).contains("original review"), "Original same-name Skill could not be restored")
        try store.deletePreset(preset.id)
        check(store.presets().isEmpty && store.librarySkills().contains { $0.name == "review" }, "Preset deletion changed library contents")

        let codex = Target(agent: .codex, project: project.path)
        let tomlFile = codex.mcpConfig.0
        try fm.createDirectory(at: tomlFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "model = \"test\"\n".write(to: tomlFile, atomically: true, encoding: .utf8)
        try store.importMCP(name: "docs", definition: ["url": "https://example.com/mcp"])
        let checkpointBefore = store.synchronizationCheckpoint()
        let syncProject = root.appendingPathComponent("sync-project")
        try fm.createDirectory(at: syncProject, withIntermediateDirectories: true)
        try store.addProject(syncProject.path)
        check(store.synchronizationCheckpoint() != checkpointBefore, "Sync missed a newly registered project")
        for agent in Agent.allCases {
            let target = Target(agent: agent, project: syncProject.path)
            let file = target.mcpConfig.0
            try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let disabled = agent == .codex
                ? "model = \"test\"\n[mcp_servers.docs]\nurl = \"https://example.com/custom\"\nenabled = false\n"
                : "{\"otherSetting\":true,\"mcpServers\":{\"docs\":{\"url\":\"https://example.com/custom\",\"disabled\":true}}}"
            let checkpoint = store.synchronizationCheckpoint()
            try disabled.write(to: file, atomically: true, encoding: .utf8)
            check(store.synchronizationCheckpoint() != checkpoint, "Sync missed an external MCP configuration change")
            check(try store.capabilityState("docs", target: target, skill: false) == .disabled, "Client-disabled MCP displayed as active")
            try store.enableClientMCP("docs", target: target)
            check(try store.capabilityState("docs", target: target, skill: false) == .configured, "Client MCP was not enabled")
            check(try String(contentsOf: file, encoding: .utf8).contains("https://example.com/custom"), "Enabling MCP replaced the client's current endpoint")
            try fm.removeItem(at: file)
            check(try store.capabilityState("docs", target: target, skill: false) == .missing, "Removed MCP displayed as active")
            try store.deployMCP("docs", to: target)
            if agent == .codex {
                var text = try String(contentsOf: file, encoding: .utf8)
                text += "\nenabled = false\n"
                try text.write(to: file, atomically: true, encoding: .utf8)
            } else {
                var object = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String: Any]
                var servers = object["mcpServers"] as! [String: Any]
                var definition = servers["docs"] as! [String: Any]
                definition["disabled"] = true
                servers["docs"] = definition; object["mcpServers"] = servers
                try JSONSerialization.data(withJSONObject: object).write(to: file)
            }
            check(store.synchronizationStates()[syncKey("docs", target: target, skill: false)] == .disabled, "Deployment record overrode client's disabled switch")
            try store.enableClientMCP("docs", target: target)
            try store.removeMCP("docs", from: target)
            check(try store.capabilityState("docs", target: target, skill: false) == .missing, "Managed MCP could not be stopped after native re-enable")
            try store.deployMCP("docs", to: target)
            let latest = try String(contentsOf: file, encoding: .utf8).replacingOccurrences(of: "https://example.com/mcp", with: "https://example.com/client-edited")
            try latest.write(to: file, atomically: true, encoding: .utf8)
            try store.disableExistingMCP("docs", from: target, preserveManagedConfiguration: true)
            try store.restoreExistingMCP("docs", to: target)
            check(try String(contentsOf: file, encoding: .utf8).contains("https://example.com/client-edited"), "Stop/restore discarded the client's latest MCP edits")
            try fm.removeItem(at: file)
            if agent != .codex {
                try "invalid json".write(to: file, atomically: true, encoding: .utf8)
                check(store.synchronizationStates()[syncKey("docs", target: target, skill: false)] == .unknown, "Unreadable configuration displayed as missing")
                try fm.removeItem(at: file)
            }
        }
        let syncCodex = Target(agent: .codex, project: syncProject.path)
        try store.deploySkill("review", to: syncCodex, copy: false)
        let skillOverride = "[[skills.config]]\npath = \"\(syncCodex.skillRoot.appendingPathComponent("review").path)\"\nenabled = false\n"
        try skillOverride.write(to: syncCodex.mcpConfig.0, atomically: true, encoding: .utf8)
        check(try store.capabilityState("review", target: syncCodex, skill: true) == .disabled, "Codex Skill override was ignored")
        try store.enableClientSkill("review", target: syncCodex)
        check(try store.capabilityState("review", target: syncCodex, skill: true) == .configured, "Codex Skill override was not enabled")
        for path in [syncCodex.skillRoot.appendingPathComponent("review/SKILL.md"), store.skillsRoot.appendingPathComponent("review"), store.skillsRoot.appendingPathComponent("review/SKILL.md")] {
            let override = "[[skills.config]]\npath = \"\(path.path)\"\nenabled = false\n\n[[skills.config]]\npath = \"\(source.path)\"\nenabled = false\n"
            try override.write(to: syncCodex.mcpConfig.0, atomically: true, encoding: .utf8)
            check(try store.capabilityState("review", target: syncCodex, skill: true) == .disabled, "Skill file/canonical path override was ignored")
            try store.enableClientSkill("review", target: syncCodex)
            check(try store.capabilityState("review", target: syncCodex, skill: true) == .configured, "Skill file/canonical path override was not enabled")
            let updated = try String(contentsOf: syncCodex.mcpConfig.0, encoding: .utf8)
            check(updated.contains("path = \"\(source.path)\"\nenabled = false"), "Enabling a Skill changed another Skill's override")
        }
        try store.removeSkill("review", from: syncCodex)
        try store.removeProject(syncProject.path)
        for agent in [Agent.cursor, .codex] {
            let target = Target(agent: agent, project: root.appendingPathComponent("missing-mcp-\(agent.rawValue)").path)
            let file = target.mcpConfig.0
            let original = agent == .codex ? "model = \"test\"\n" : "{\"otherSetting\":true}"
            try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try original.write(to: file, atomically: true, encoding: .utf8)
            try store.deployMCP("docs", to: target)
            let deployed = try Data(contentsOf: file)
            let changed = String(data: deployed, encoding: .utf8)!.replacingOccurrences(of: "https://example.com/mcp", with: "https://example.com/changed")
            try changed.write(to: file, atomically: true, encoding: .utf8)
            do {
                try store.removeMCP("docs", from: target)
                preconditionFailure("Modified MCP was removed")
            } catch ManagerError.conflict { }
            check(try String(contentsOf: file, encoding: .utf8) == changed, "Modified MCP configuration changed")
            try original.write(to: file, atomically: true, encoding: .utf8)
            try store.removeMCP("docs", from: target)
            check(try String(contentsOf: file, encoding: .utf8) == original, "Missing MCP entry rewrote unrelated settings")
            check(!store.deployments().contains { $0.kind == "mcp" && $0.targetID == target.id }, "Missing MCP entry left a stale record")
            try store.deployMCP("docs", to: target)
            try fm.removeItem(at: file)
            try store.removeMCP("docs", from: target)
            check(!fm.fileExists(atPath: file.path), "Missing MCP configuration was recreated")
            check(!store.deployments().contains { $0.kind == "mcp" && $0.targetID == target.id }, "Missing MCP file left a stale record")
        }
        try store.deployMCP("docs", to: codex)
        check(try String(contentsOf: tomlFile, encoding: .utf8).contains("[mcp_servers.docs]"), "Codex MCP not added")
        try store.removeMCP("docs", from: codex)
        check(try String(contentsOf: tomlFile, encoding: .utf8) == "model = \"test\"\n", "Codex TOML not restored")
        let beforeRestore = store.configBackups()
        let restorePoint = try beforeRestore.first { record in
            guard record.originalPath == tomlFile.path else { return false }
            let data = try Data(contentsOf: store.backupRoot.appendingPathComponent(record.id))
            return String(data: data, encoding: .utf8)?.contains("[mcp_servers.docs]") == true
        }
        check(restorePoint != nil, "Config backup missing source path")
        try store.restoreConfigBackup(restorePoint!)
        check(try String(contentsOf: tomlFile, encoding: .utf8).contains("[mcp_servers.docs]"), "Config backup was not restored")
        check(store.configBackups().count > beforeRestore.count, "Current config was not backed up before restore")
        try "[mcp_servers.manual]\ncommand = \"node\"\n[mcp_servers.manual.env]\n\"API_KEY\" = \"sample\"\n".write(to: tomlFile, atomically: true, encoding: .utf8)
        check((store.installedMCP().first { $0.name == "manual" && $0.agent == .codex && $0.project == project.path }?.definition["env"] as? [String: String])?["API_KEY"] == "sample", "Codex env not parsed")
        try store.disableExistingMCP("manual", from: codex)
        check(try !String(contentsOf: tomlFile, encoding: .utf8).contains("mcp_servers.manual"), "Codex MCP not disabled")
        try store.restoreExistingMCP("manual", to: codex)
        check(try String(contentsOf: tomlFile, encoding: .utf8).contains("[mcp_servers.manual.env]"), "Codex MCP not restored")

        let secondProject = root.appendingPathComponent("another-project")
        try fm.createDirectory(at: secondProject, withIntermediateDirectories: true)
        try store.addProject(secondProject.path)
        let secondCodex = Target(agent: .codex, project: secondProject.path)
        try "[mcp_servers.complex]\nurl = \"https://example.com/mcp\"\nhttp_headers = { \"X-Test\" = \"value\" }\nenabled_tools = [\"search\"]\n[mcp_servers.complex.oauth]\nclient_id = \"example\"\n".write(to: tomlFile, atomically: true, encoding: .utf8)
        let complex = store.installedMCP().first { $0.name == "complex" && $0.project == project.path }
        check(complex != nil, "Complex Codex MCP was not discovered")
        try store.importMCP(name: "complex", definition: complex!.definition)
        try store.deployMCP("complex", to: secondCodex)
        let secondConfig = secondCodex.mcpConfig.0
        let copied = try String(contentsOf: secondConfig, encoding: .utf8)
        check(copied.contains("[mcp_servers.complex.oauth]") && copied.contains("http_headers ="), "Complex Codex fields were lost")
        let legacyRaw = "[mcp_servers.legacyType]\ncommand = \"node\"\ntype = \"stdio\"\n[mcp_servers.legacyType.env]\ntype = \"keep-env-value\"\n"
        try legacyRaw.write(to: tomlFile, atomically: true, encoding: .utf8)
        let legacyTypeItem = store.installedMCP().first { $0.name == "legacyType" && $0.project == project.path }!
        try store.importMCP(name: "legacyType", definition: legacyTypeItem.definition)
        try store.deployMCP("legacyType", to: secondCodex)
        let regenerated = try String(contentsOf: secondConfig, encoding: .utf8)
        check(!regenerated.contains("type = \"stdio\""), "Raw TOML passthrough wrote unsupported type")
        check(regenerated.contains("type = \"keep-env-value\""), "MCP environment variable named type was removed")
        check(try store.repairCodexMCPTransportTypes(codex) == 1, "Legacy Codex type was not repaired")
        let repaired = try String(contentsOf: tomlFile, encoding: .utf8)
        check(!repaired.contains("type = \"stdio\"") && repaired.contains("type = \"keep-env-value\""), "Repair removed unrelated fields")
        check(try store.repairCodexMCPTransportTypes(codex) == 0, "Codex type repair was not idempotent")

        try store.importMCP(name: "remoteAdvanced", definition: [
            "url": "https://example.com/mcp", "headers": ["X-Test": "value"],
            "enabled_tools": ["search"], "startup_timeout_sec": 20, "enabled": false
        ])
        try store.deployMCP("remoteAdvanced", to: secondCodex)
        let advanced = try String(contentsOf: secondConfig, encoding: .utf8)
        check(advanced.contains("http_headers = {\"X-Test\" = \"value\"}"), "HTTP headers were not converted")
        check(advanced.contains("startup_timeout_sec = 20") && advanced.contains("enabled = true"), "Deploy did not activate the Codex MCP")
        let reread = store.installedMCP().first { $0.name == "remoteAdvanced" && $0.project == secondProject.path }
        check((reread?.definition["http_headers"] as? [String: String])?["X-Test"] == "value", "Converted headers were not readable")

        try store.importMCP(name: "disabledSource", definition: [
            "type": "http", "url": "https://example.com/mcp", "disabled": true,
            "headers": ["X-Test": "sample"]
        ])
        try store.validateMCPDeployment("disabledSource", to: secondCodex)
        try store.deployMCP("disabledSource", to: secondCodex)
        let enabledCodex = try String(contentsOf: secondConfig, encoding: .utf8)
        check(enabledCodex.contains("[mcp_servers.disabledSource]\nenabled = true"), "Disabled JSON source did not become enabled in Codex")
        check(!enabledCodex.contains("disabled ="), "Unsupported disabled key was written to Codex")
        let secondCursor = Target(agent: .cursor, project: secondProject.path)
        try store.deployMCP("disabledSource", to: secondCursor)
        let enabledJSON = try JSONSerialization.jsonObject(with: Data(contentsOf: secondCursor.mcpConfig.0)) as! [String: Any]
        let enabledServer = (enabledJSON["mcpServers"] as! [String: Any])["disabledSource"] as! [String: Any]
        check(enabledServer["disabled"] == nil, "Disabled source flag was copied to active JSON deployment")
        try store.importMCP(name: "unsupportedSource", definition: ["url": "https://example.com/mcp", "unknown_option": true])
        let invalidPreset = CapabilityPreset(name: "不兼容", skills: [], mcps: ["unsupportedSource"])
        let invalidPlan = store.presetPlan(invalidPreset, targets: [secondCodex], action: .enable)
        check(invalidPlan.count == 1 && !invalidPlan[0].willChange && invalidPlan[0].status.contains("unknown_option"), "Preset preview did not catch unsupported Codex fields")
        let configBeforeInvalid = try Data(contentsOf: secondConfig)
        let invalidResult = store.applyPreset(invalidPreset, targets: [secondCodex], action: .enable, copySkills: false)
        check(invalidResult.changed.isEmpty && invalidResult.failed.count == 1, "Invalid preset changed the target")
        check(try Data(contentsOf: secondConfig) == configBeforeInvalid, "Invalid preset modified the MCP config")

        for agent in [Agent.cursor, .codex] {
            let project = root.appendingPathComponent("preset-reconcile-\(agent.rawValue)")
            try fm.createDirectory(at: project, withIntermediateDirectories: true)
            try store.addProject(project.path)
            let target = Target(agent: agent, project: project.path)
            try store.deploySkill("review", to: target, copy: false)
            try store.deployMCP("docs", to: target)
            try store.deployMCP("new", to: target)
            try fm.removeItem(at: target.skillRoot.appendingPathComponent("review"))
            try fm.removeItem(at: target.mcpConfig.0)
            let preset = CapabilityPreset(name: "失效记录", skills: ["review"], mcps: ["docs"])
            let before = try Data(contentsOf: store.deploymentsURL)
            let plan = store.presetPlan(preset, targets: [target], action: .enable)
            check(!plan.contains { $0.step == .blocked }, "Missing targets blocked the preset")
            check(plan.filter { $0.step == .reconcile }.count == 3, "Preset omitted stale record cleanup")
            check(try Data(contentsOf: store.deploymentsURL) == before, "Preset preview mutated deployment records")
            let applied = store.applyPreset(preset, targets: [target], action: .enable, copySkills: false)
            check(applied.failed.isEmpty && applied.changed.count == 5, "Preset did not clean and redeploy missing targets")
            check(!store.deployments().contains { $0.targetID == target.id && $0.item == "new" }, "Unwanted stale MCP record remained")
            let repeated = store.applyPreset(preset, targets: [target], action: .enable, copySkills: false)
            check(repeated.changed.isEmpty && repeated.failed.isEmpty, "Reconciled preset was not idempotent")
            check(store.rollbackPresetOperations(applied.operationIDs).isEmpty, "Stale preset cleanup could not be rolled back")
            check(try Data(contentsOf: store.deploymentsURL) == before, "Rollback did not restore stale deployment records")
            check(!fm.fileExists(atPath: target.mcpConfig.0.path), "Rollback recreated a missing client config")
            // A malformed config is unreadable, never proof that its MCP entries are absent.
            if agent == .cursor {
                try "invalid json".write(to: target.mcpConfig.0, atomically: true, encoding: .utf8)
                let blocked = store.applyPreset(preset, targets: [target], action: .enable, copySkills: false)
                check(blocked.changed.isEmpty && !blocked.failed.isEmpty, "Unreadable MCP config was automatically reconciled")
                check(try Data(contentsOf: store.deploymentsURL) == before, "Unreadable MCP config lost its deployment records")
            }
            try store.removeProject(project.path)
        }

        let sharedPlan = store.presetPlan(CapabilityPreset(name: "共享目录", skills: ["review"], mcps: []), targets: [secondCodex], action: .enable)
        let sharedDeploy = sharedPlan.first { $0.kind == "skill" && $0.step == .deploy }
        check(sharedDeploy?.sharedWith.contains(.antigravity) == true && sharedDeploy?.sharedWith.contains(.cursor) == true,
              "Preset did not disclose a new Skill deployment into a shared project directory")

        let managedReplacement = store.applyPreset(CapabilityPreset(name: "替换托管项", skills: [], mcps: ["new"]), targets: [secondCursor], action: .enable, copySkills: false)
        check(managedReplacement.failed.isEmpty && managedReplacement.changed.count == 2, "Preset did not replace an app-managed extra MCP")
        check(!store.installedMCP().contains { $0.name == "disabledSource" && $0.agent == .cursor && $0.project == secondProject.path },
              "Managed MCP outside the preset remained active")
        check(store.installedMCP().contains { $0.name == "new" && $0.agent == .cursor && $0.project == secondProject.path },
              "Preset MCP was not enabled after replacing the managed extra")

        let oldBackup = store.backupRoot.appendingPathComponent("legacy.toml-older.bak")
        try "legacy = true\n".write(to: oldBackup, atomically: true, encoding: .utf8)
        let legacy = store.configBackups().first { $0.id == oldBackup.lastPathComponent }
        check(legacy?.originalPath == nil, "Legacy backup should require a target")
        let legacyTarget = root.appendingPathComponent("legacy.toml")
        try store.restoreConfigBackup(legacy!, to: legacyTarget)
        check(try String(contentsOf: legacyTarget, encoding: .utf8) == "legacy = true\n", "Legacy backup restore failed")

        let historyStore = ManagerStore(baseURL: root.appendingPathComponent("history-app"), agentAvailability: { _ in true })
        check(historyStore.historyLimit == 50, "Default history limit is incorrect")
        try historyStore.importSkill(source)
        let imported = historyStore.operationHistory().first!
        check(imported.action == "导入 Skill" && imported.canRollback, "Skill import was not recorded")
        try historyStore.rollbackOperation(imported)
        check(!fm.fileExists(atPath: historyStore.skillsRoot.appendingPathComponent("review").path), "Skill import rollback failed")
        check(historyStore.operationHistory().contains { $0.id == imported.id && $0.status == "已回滚" }, "Rollback status missing")
        check(historyStore.operationHistory().contains { $0.action == "回滚：导入 Skill" }, "Rollback was not recorded")

        try historyStore.importSkill(source)
        let historyProject = root.appendingPathComponent("history-project")
        try fm.createDirectory(at: historyProject, withIntermediateDirectories: true)
        let historyClaude = Target(agent: .claude, project: historyProject.path)
        try historyStore.deploySkill("review", to: historyClaude, copy: false)
        let deployEntry = historyStore.operationHistory().first { $0.action == "链接启用 Skill" }!
        try historyStore.rollbackOperation(deployEntry)
        check((try? fm.destinationOfSymbolicLink(atPath: historyClaude.skillRoot.appendingPathComponent("review").path)) == nil, "Skill link rollback failed")
        check(historyStore.deployments().isEmpty, "Skill deployment record rollback failed")

        let manualSkill = historyClaude.skillRoot.appendingPathComponent("manual")
        try fm.createDirectory(at: manualSkill, withIntermediateDirectories: true)
        try "# Manual".write(to: manualSkill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try historyStore.disableExistingSkill("manual", from: historyClaude)
        let disableEntry = historyStore.operationHistory().first { $0.action == "停用现有 Skill" }!
        try historyStore.rollbackOperation(disableEntry)
        check(fm.fileExists(atPath: manualSkill.appendingPathComponent("SKILL.md").path), "Existing Skill rollback failed")
        check(historyStore.disabledItems().isEmpty, "Disabled Skill record rollback failed")

        try historyStore.importMCP(name: "safe", definition: ["command": "node"])
        let historyCursor = Target(agent: .cursor, project: historyProject.path)
        try historyStore.deployMCP("safe", to: historyCursor)
        let mcpDeployEntry = historyStore.operationHistory().first { $0.action == "启用 MCP" }!
        try historyStore.rollbackOperation(mcpDeployEntry)
        check(!fm.fileExists(atPath: historyCursor.mcpConfig.0.path), "MCP config rollback failed")
        check(historyStore.deployments().isEmpty, "MCP deployment record rollback failed")

        try historyStore.importMCP(name: "secret", definition: ["command": "node", "env": ["TOKEN": "never-log-this-value"]])
        let secretEntry = historyStore.operationHistory().first { $0.action == "导入 MCP" }!
        let metadata = try String(contentsOf: historyStore.historyRoot.appendingPathComponent(secretEntry.id + "/entry.json"), encoding: .utf8)
        check(!metadata.contains("never-log-this-value"), "History metadata exposed MCP secrets")
        let secretFile = historyStore.mcpRoot.appendingPathComponent("secret.json")
        try "changed externally".write(to: secretFile, atomically: true, encoding: .utf8)
        do {
            try historyStore.rollbackOperation(secretEntry)
            preconditionFailure("External change did not block rollback")
        } catch ManagerError.conflict { }
        check(try String(contentsOf: secretFile, encoding: .utf8) == "changed externally", "Conflict rollback overwrote external change")
        try historyStore.setHistoryLimit(20)
        check(historyStore.historyLimit == 20, "History retention setting not saved")
        let metadataPermissions = try fm.attributesOfItem(atPath: historyStore.historyRoot.appendingPathComponent(secretEntry.id + "/entry.json").path)[.posixPermissions] as? NSNumber
        check(metadataPermissions?.intValue == 0o600, "History metadata permissions are too broad")
        try historyStore.deleteLibrarySkill("review")
        check(!fm.fileExists(atPath: historyStore.skillsRoot.appendingPathComponent("review").path), "Inactive Skill library item was not deleted")
        try historyStore.deleteLibraryMCP("safe")
        check(!fm.fileExists(atPath: historyStore.mcpRoot.appendingPathComponent("safe.json").path), "Inactive MCP library item was not deleted")
        for index in 0..<24 {
            let folder = historyProject.appendingPathComponent("\(index)")
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            try historyStore.addProject(folder.path)
        }
        check(historyStore.operationHistory().count == 20, "Old history entries were not pruned")
        try await regressionChecks()
        try contentVersionChecks()
        print("Smoke checks passed")
    }
}

