import Foundation

extension Smoke {
    static func regressionChecks() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("agent-manager-regressions-" + UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let project = root.appendingPathComponent("project")
        let home = root.appendingPathComponent("home")
        try fm.createDirectory(at: project, withIntermediateDirectories: true)
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        let store = ManagerStore(baseURL: root.appendingPathComponent("library"), userHomeURL: home, agentAvailability: { _ in true })
        try store.addProject(project.path)
        let linkedSource = root.appendingPathComponent("cc-switch-source")
        try fm.createDirectory(at: linkedSource, withIntermediateDirectories: true)
        try "independent skill".write(to: linkedSource.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        let linkedAsset = root.appendingPathComponent("asset.txt")
        try "asset content".write(to: linkedAsset, atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: linkedSource.appendingPathComponent(".asset"), withDestinationURL: linkedAsset)
        let importLink = root.appendingPathComponent("linked-skill")
        try fm.createSymbolicLink(at: importLink, withDestinationURL: linkedSource)
        try store.importSkill(importLink)
        let oldLink = store.skillsRoot.appendingPathComponent("legacy-linked-skill")
        try fm.createSymbolicLink(at: oldLink, withDestinationURL: linkedSource)
        check(store.materializeLibrarySkillLinks().count == 1, "Legacy central link not materialized")
        let broken = store.skillsRoot.appendingPathComponent("broken-link")
        try fm.createSymbolicLink(at: broken, withDestinationURL: root.appendingPathComponent("missing-source"))
        check(store.materializeLibrarySkillLinks().first?.hasPrefix("未转换") == true, "Broken link falsely reported repaired")
        check((try? fm.destinationOfSymbolicLink(atPath: broken.path)) != nil, "Broken source entry was destroyed")
        try fm.removeItem(at: linkedSource)
        try fm.removeItem(at: linkedAsset)
        for name in ["linked-skill", "legacy-linked-skill"] {
            let archived = store.skillsRoot.appendingPathComponent(name)
            check((try? fm.destinationOfSymbolicLink(atPath: archived.path)) == nil, "Central archive remains linked")
            check(try String(contentsOf: archived.appendingPathComponent("SKILL.md"), encoding: .utf8) == "independent skill", "Source deletion lost archived Skill")
            check(try String(contentsOf: archived.appendingPathComponent(".asset"), encoding: .utf8) == "asset content", "Nested hidden link was not materialized")
        }
        let loop = root.appendingPathComponent("loop-skill")
        try fm.createDirectory(at: loop, withIntermediateDirectories: true)
        try "loop".write(to: loop.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try fm.createSymbolicLink(at: loop.appendingPathComponent("cycle"), withDestinationURL: loop)
        do { try store.importSkill(loop); preconditionFailure("Cycle imported") } catch ManagerError.invalid { }
        check(!fm.fileExists(atPath: store.skillsRoot.appendingPathComponent("loop-skill").path), "Failed import left partial archive")
        let codex = Target(agent: .codex, project: project.path)
        let claude = Target(agent: .claude, project: project.path)
        let file = codex.mcpConfig.0
        try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        for name in ["a.b", "中文.服务", "space name"] {
            try store.importMCP(name: name, definition: ["command": "echo"])
            try store.deployMCP(name, to: codex)
            check(try store.mcpConfigurationState(name, target: codex) == .configured, "Quoted MCP name not recognized")
            try store.removeMCP(name, from: codex)
            check(try store.mcpConfigurationState(name, target: codex) == .missing, "Quoted MCP name not removed")
        }
        let commented = "model = \"test\"\n[mcp_servers.\"a.b\"] # valid comment\ncommand = \"echo\"\n[mcp_servers.\"a.b\".env] # nested\nTEST = \"sample\"\n[other]\nkeep = true\n"
        try commented.write(to: file, atomically: true, encoding: .utf8)
        let dotted = store.installedMCP().first { $0.name == "a.b" && $0.project == project.path && $0.agent == .codex }!
        check((dotted.definition["env"] as? [String: String])?["TEST"] == "sample", "Quoted nested table not parsed")
        try store.disableExistingMCP("a.b", from: codex)
        check(try String(contentsOf: file, encoding: .utf8) == "model = \"test\"\n[other]\nkeep = true\n", "TOML removal changed adjacent settings")
        try store.restoreExistingMCP("a.b", to: codex)
        check(try store.mcpConfigurationState("a.b", target: codex) == .configured, "Quoted MCP restore failed")

        try store.importMCP(name: "remote", definition: ["url": "https://example.com/mcp", "http_headers": ["X-Test": "sample"]])
        try store.deployMCP("remote", to: claude)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: claude.mcpConfig.0)) as! [String: Any]
        let remote = (json["mcpServers"] as! [String: Any])["remote"] as! [String: Any]
        check(remote["type"] as? String == "http", "Claude remote transport not adapted")
        check(remote["http_headers"] == nil && (remote["headers"] as? [String: String])?["X-Test"] == "sample", "Claude headers not adapted")
        try store.importMCP(name: "sse", definition: ["type": "sse", "url": "https://example.com/sse"])
        do { try store.validateMCPDeployment("sse", to: codex); preconditionFailure("Unsupported SSE silently converted to HTTP") } catch ManagerError.invalid { }
        let edited = mcpFormDefinition(existing: ["type": "http", "oauth": ["clientId": "test"], "tool_timeout_sec": 60], command: "echo", args: [], env: [:], url: "https://example.com/new", transport: "http", headers: [:])
        check(edited["type"] as? String == "http" && edited["oauth"] != nil && edited["tool_timeout_sec"] as? Int == 60, "Form lost protocol or extra fields")

        let skill = root.appendingPathComponent("review")
        try fm.createDirectory(at: skill, withIntermediateDirectories: true)
        try "---\nname: review\ndescription: test\n---\n".write(to: skill.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
        try store.importSkill(skill)
        try store.deploySkill("review", to: claude, copy: true)
        let hidden = claude.skillRoot.appendingPathComponent("review/.user-data")
        try "user modification".write(to: hidden, atomically: true, encoding: .utf8)
        do { try store.removeSkill("review", from: claude); preconditionFailure("Modified hidden file was removed") } catch ManagerError.conflict { }
        check(fm.fileExists(atPath: hidden.path), "Modified hidden file not protected")
        try store.deploySkill("review", to: codex, copy: false)
        try fm.removeItem(at: file)
        try "[[skills.config]]\npath = \"\(codex.skillRoot.appendingPathComponent("review/SKILL.md").path)\"\nenabled = false\n".write(to: file, atomically: true, encoding: .utf8)
        let applied = store.applyPreset(CapabilityPreset(name: "review", skills: ["review"], mcps: []), targets: [codex], action: .enable, copySkills: false)
        check(applied.failed.isEmpty && applied.changed.count == 1, "Preset did not restore disabled Skill")
        check(try store.capabilityState("review", target: codex, skill: true) == .configured, "Preset left Skill disabled")

        let local: [String: Any] = ["preferences": ["keep": true], "mcpServers": ["global": ["command": "echo"]], "projects": [project.path: ["other": true, "mcpServers": ["local": ["type": "http", "url": "https://example.com/local", "disabled": true]]], "/other/project": ["mcpServers": ["other": ["command": "echo"]]]]]
        try JSONSerialization.data(withJSONObject: local).write(to: store.claudeUserConfig)
        check(store.installedMCP().contains { $0.name == "local" && $0.project == project.path }, "Claude local MCP not scanned")
        try store.enableClientMCP("local", target: claude)
        check(try store.mcpConfigurationState("local", target: claude) == .configured, "Claude local MCP not enabled")
        try store.disableExistingMCP("local", from: claude)
        check(try store.mcpConfigurationState("local", target: claude) == .missing, "Claude local MCP not stashed")
        try store.restoreExistingMCP("local", to: claude)
        check(try store.mcpConfigurationState("local", target: claude) == .configured, "Claude local MCP not restored")
        let kept = try JSONSerialization.jsonObject(with: Data(contentsOf: store.claudeUserConfig)) as! [String: Any]
        check((kept["mcpServers"] as? [String: Any])?["global"] != nil && (kept["projects"] as? [String: Any])?["/other/project"] != nil && kept["preferences"] != nil, "Claude local operation changed other scopes")
        try store.deleteExistingMCP("local", from: claude)
        check(try store.mcpConfigurationState("local", target: claude) == .missing, "Claude local deletion failed")

        // Upgrade compatibility: an old copy can be removed only when its full
        // contents still match the library; a changed hidden file remains protected.
        let legacySource = root.appendingPathComponent("legacy")
        try fm.copyItem(at: skill, to: legacySource)
        try "original".write(to: legacySource.appendingPathComponent(".metadata"), atomically: true, encoding: .utf8)
        try store.importSkill(legacySource)
        for modified in [false, true] {
            try store.deploySkill("legacy", to: claude, copy: true)
            let records = store.deployments().map { d -> Deployment in
                guard d.kind == "skill" && d.item == "legacy" else { return d }
                let old = d.fingerprint.components(separatedBy: "|").filter { !$0.hasPrefix("/.") }.joined(separator: "|")
                return Deployment(kind: d.kind, item: d.item, targetID: d.targetID, path: d.path, fingerprint: old)
            }
            try store.saveDeployments(records)
            if modified {
                try "modified".write(to: claude.skillRoot.appendingPathComponent("legacy/.metadata"), atomically: true, encoding: .utf8)
                do { try store.removeSkill("legacy", from: claude); preconditionFailure("Legacy hidden modification not protected") } catch ManagerError.conflict { }
            } else { try store.removeSkill("legacy", from: claude) }
        }

        // Legacy bundled configurations stay removable when managed by this app.
        let appCommand = root.appendingPathComponent("Claude.app/Contents/MacOS/mcp")
        try fm.createDirectory(at: appCommand.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bundledDefinition: [String: Any] = ["command": appCommand.path]
        do { try store.importMCP(name: "bundled", definition: bundledDefinition); preconditionFailure("Bundled MCP import was allowed") } catch ManagerError.invalid { }
        let thirdPartyCommand: [String: Any] = ["command": "/Applications/TablePlus.app/Contents/MacOS/tableplus-mcp"]
        check(!MCPItem(name: "tableplus", definition: thirdPartyCommand, agent: nil, project: nil, source: root, isLibrary: true).isSystemService, "Third-party app MCP treated as client built-in")
        try store.importMCP(name: "tableplus", definition: thirdPartyCommand)
        let legacyTemplate = store.mcpRoot.appendingPathComponent("bundled.json")
        try JSONSerialization.data(withJSONObject: bundledDefinition).write(to: legacyTemplate)
        do { try store.deployMCP("bundled", to: claude); preconditionFailure("Legacy bundled template redistributed") } catch ManagerError.invalid { }
        check(store.presetPlan(CapabilityPreset(name: "blocked", skills: [], mcps: ["bundled"]), targets: [claude], action: .enable).contains { $0.step == .blocked }, "Preset allowed bundled redistribution")
        let cursor = Target(agent: .cursor, project: project.path)
        try fm.createDirectory(at: cursor.mcpConfig.0.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: ["other": true, "mcpServers": ["bundled": bundledDefinition, "original": ["command": root.appendingPathComponent("Cursor.app/Contents/MacOS/mcp").path]]]).write(to: cursor.mcpConfig.0)
        let deployed = Deployment(kind: "mcp", item: "bundled", targetID: cursor.id, path: cursor.mcpConfig.0.path, fingerprint: store.mcpDeploymentFingerprint(bundledDefinition))
        try store.saveDeployments(store.deployments() + [deployed])
        try store.disableExistingMCP("bundled", from: cursor, preserveManagedConfiguration: true)
        check(try store.mcpConfigurationState("bundled", target: cursor) == .missing, "Managed bundled copy could not be disabled")
        do { try store.restoreExistingMCP("bundled", to: cursor); preconditionFailure("Stashed bundled copy could be re-enabled") } catch ManagerError.invalid { }
        let removal = store.operationHistory().first { $0.action == "停用现有 MCP" && $0.target.contains("bundled") }!
        try store.rollbackOperation(removal)
        let stopped = store.applyPreset(CapabilityPreset(name: "stop", skills: [], mcps: ["bundled"]), targets: [cursor], action: .disable, copySkills: false)
        check(stopped.failed.isEmpty && stopped.changed.count == 1, "Preset could not stop managed bundled copy")
        do { try store.disableExistingMCP("original", from: cursor); preconditionFailure("Original bundled service lost protection") } catch ManagerError.conflict { }
        check(try store.mcpConfigurationState("original", target: cursor) == .configured, "Original bundled service changed")
        let codexBuiltin: [String: Any] = ["command": root.appendingPathComponent(".codex/computer-use/Codex Computer Use.app/Contents/MacOS/mcp").path]
        try JSONSerialization.data(withJSONObject: codexBuiltin).write(to: store.mcpRoot.appendingPathComponent("codex-builtin.json"))
        let codexItem = MCPItem(name: "codex-builtin", definition: codexBuiltin, agent: .codex, project: project.path, source: file, isLibrary: false)
        check(codexItem.bundledOwner == .codex, "Codex service owner not recognized")
        check(codexItem.isProtectedSystemService(in: .codex, managed: true), "Legacy record removed owner protection")
        check(!codexItem.isProtectedSystemService(in: .antigravity, managed: false), "Foreign copy falsely protected as Antigravity system service")
        try JSONSerialization.data(withJSONObject: ["mcpServers": ["codex-builtin": codexBuiltin]]).write(to: cursor.mcpConfig.0)
        try store.disableExistingMCP("codex-builtin", from: cursor)
        check(try store.mcpConfigurationState("codex-builtin", target: cursor) == .missing, "Unmanaged foreign copy could not be disabled")
        try "[mcp_servers.codex-builtin]\ncommand = \"\(codexBuiltin["command"] as! String)\"\n".write(to: file, atomically: true, encoding: .utf8)
        let builtinRecord = Deployment(kind: "mcp", item: "codex-builtin", targetID: codex.id, path: file.path, fingerprint: "legacy")
        try store.saveDeployments(store.deployments() + [builtinRecord])
        do { try store.disableExistingMCP("codex-builtin", from: codex, preserveManagedConfiguration: true); preconditionFailure("Codex native service could be stopped") } catch ManagerError.conflict { }
        do { try store.removeMCP("codex-builtin", from: codex); preconditionFailure("Owner protection bypassed by managed removal") } catch ManagerError.conflict { }
        let ownerPlan = store.presetPlan(CapabilityPreset(name: "protect owner", skills: [], mcps: []), targets: [codex], action: .enable)
        check(ownerPlan.contains { $0.name == "codex-builtin" && $0.step == .keep }, "Preset did not retain owner-native service")

        // A removed host app must not turn its internal executable into a portable template.
        try fm.removeItem(at: root.appendingPathComponent("Claude.app"))
        do { try store.validateMCPDeployment("bundled", to: claude); preconditionFailure("Missing app bypassed redistribution protection") } catch ManagerError.invalid { }

        let historyStore = ManagerStore(baseURL: root.appendingPathComponent("history"), agentAvailability: { _ in true })
        try historyStore.setHistoryLimit(20)
        var ids: [String] = []
        for i in 0..<20 {
            let path = root.appendingPathComponent("history-\(i)")
            try historyStore.withRecordedOperation(action: "regression", kind: "test", target: String(i), paths: [path]) { try Data("x".utf8).write(to: path) }
            ids.append(historyStore.operationHistory().first!.id)
        }
        check(historyStore.rollbackPresetOperations(ids).isEmpty, "Batch rollback pruned pending records")
        check(historyStore.operationHistory().count == 20, "History limit not restored after rollback")

        let repo = root.appendingPathComponent("repo")
        try fm.createDirectory(at: repo.appendingPathComponent("skills/real"), withIntermediateDirectories: true)
        try "# Repository".write(to: repo.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "# Skills".write(to: repo.appendingPathComponent("skills/README.md"), atomically: true, encoding: .utf8)
        try "---\nname: real\n---".write(to: repo.appendingPathComponent("skills/real/SKILL.md"), atomically: true, encoding: .utf8)
        let git = GitSkillService(store: store)
        let lower = root.appendingPathComponent("lowercase")
        try fm.createDirectory(at: lower, withIntermediateDirectories: true)
        try "---\nname: lowercase\n---".write(to: lower.appendingPathComponent("skill.md"), atomically: true, encoding: .utf8)
        try git.installSkill(from: lower, skillName: "lowercase", repoURL: repo.path, branch: nil, subpath: nil)
        // A dangling legacy archive still occupies its name, and must be replaceable and recoverable.
        let brokenArchive = store.skillsRoot.appendingPathComponent("broken")
        let missingTarget = root.appendingPathComponent("removed-legacy-source")
        try fm.createSymbolicLink(at: brokenArchive, withDestinationURL: missingTarget)
        let brokenSkill = DiscoveredGitSkill(name: "broken", description: "", relativePath: "skills/broken", fullURL: lower)
        check(git.archiveState(for: brokenSkill, repoURL: repo.path, branch: nil)?.label == "失效链接 · 将修复", "Dangling archive status missing")
        try git.installSkill(from: lower, skillName: "broken", repoURL: repo.path, branch: nil, subpath: "skills/broken")
        check(fm.fileExists(atPath: brokenArchive.appendingPathComponent("SKILL.md").path), "Dangling archive was not replaced")
        let repairedEntry = store.operationHistory().first { $0.target == "broken" }!
        try store.rollbackOperation(repairedEntry)
        check(try fm.destinationOfSymbolicLink(atPath: brokenArchive.path) == missingTarget.path, "Repair rollback lost old link")

        // Mixed batches continue after failure and do not silently overwrite duplicate destinations.
        let invalidSkill = DiscoveredGitSkill(name: "invalid", description: "", relativePath: "invalid", fullURL: root.appendingPathComponent("absent"))
        let newSkill = DiscoveredGitSkill(name: "new-skill", description: "", relativePath: "new", fullURL: lower)
        let batch = git.installSkills([brokenSkill, invalidSkill, newSkill], repoURL: repo.path, branch: nil, progress: { _, _ in })
        check(batch.map { $0.error == nil } == [true, false, true], "Mixed batch stopped after a failed item")
        check(git.archiveState(for: brokenSkill, repoURL: repo.path, branch: nil)?.label == "已归档 · 可更新", "Imported source status missing")
        let duplicate = DiscoveredGitSkill(name: "new-skill", description: "", relativePath: "another", fullURL: lower)
        let duplicateBatch = git.installSkills([newSkill, duplicate], repoURL: repo.path, branch: nil, progress: { _, _ in })
        check(duplicateBatch[0].error == nil && duplicateBatch[1].error != nil, "Duplicate batch destination silently overwritten")
        try git.installSkill(from: lower, skillName: "custom-archive", repoURL: "https://example.com/repo.git", branch: "main", subpath: "renamed")
        let renamed = DiscoveredGitSkill(name: "upstream-name", description: "", relativePath: "renamed", fullURL: lower)
        let renamedBatch = git.installSkills([renamed], repoURL: "https://example.com/repo/", branch: "main", progress: { _, _ in })
        check(renamedBatch[0].archiveName == "custom-archive" && renamedBatch[0].error == nil, "Reimport lost custom archive name")

        // Recent repositories survive restarting the service, deduplicate, and exclude HTTP secrets.
        try git.rememberRepository(repoURL: "https://user:secret@example.com/private.git?token=hidden#ref", branch: "main", subpath: "skills")
        try git.rememberRepository(repoURL: "https://example.com/private.git", branch: "main", subpath: "skills")
        let restartedGit = GitSkillService(store: store)
        let visits = restartedGit.recentRepositories()
        check(visits.first?.repoURL == "https://example.com/private.git" && visits.first?.subpath == "skills", "Repository history not restored")
        check(visits.filter { $0.repoURL == "https://example.com/private.git" }.count == 1, "Repository history duplicated")
        let historyJSON = try String(contentsOf: store.base.appendingPathComponent("git-repositories.json"), encoding: .utf8)
        check(!historyJSON.contains("secret") && !historyJSON.contains("hidden"), "Repository history persisted HTTP credentials")
        check(visits.contains { $0.repoURL == "https://example.com/repo/" }, "Existing Git archives did not seed history")
        let names = try fm.contentsOfDirectory(atPath: store.skillsRoot.appendingPathComponent("lowercase").path)
        check(names.contains("SKILL.md"), "Git import did not normalize Skill filename")
        check(git.scanForSkills(in: repo, repoURL: repo.path).map(\.relativePath) == ["skills/real"], "README hid real Skill")
        try runGitTest(["init", "-b", "main", repo.path])
        try runGitTest(["-C", repo.path, "add", "."])
        try runGitTest(["-C", repo.path, "-c", "user.name=Regression", "-c", "user.email=test@example.com", "commit", "-m", "fixture"])
        do { _ = try await git.cloneAndDiscover(repoURL: repo.absoluteString, branch: "missing", shallowClone: false, progress: { _ in }); preconditionFailure("Missing branch fell back to main") } catch ManagerError.invalid { }
        let clone = try await git.cloneAndDiscover(repoURL: repo.absoluteString, branch: nil, shallowClone: false, progress: { _ in })
        defer { try? fm.removeItem(at: clone.tempRoot) }
        check(!fm.fileExists(atPath: clone.tempRoot.appendingPathComponent(".git/shallow").path), "Full clone setting ignored")
        let shallow = try await git.cloneAndDiscover(repoURL: repo.absoluteString, branch: nil, shallowClone: true, progress: { _ in })
        defer { try? fm.removeItem(at: shallow.tempRoot) }
        check(fm.fileExists(atPath: shallow.tempRoot.appendingPathComponent(".git/shallow").path), "Shallow clone setting ignored")
        try git.installSkill(from: clone.discovered[0].fullURL, skillName: "real", repoURL: repo.absoluteString, branch: nil, subpath: "skills/real")
        try fm.createDirectory(at: repo.appendingPathComponent("wrong"), withIntermediateDirectories: true)
        try "---\nname: real\n---\nwrong source".write(to: repo.appendingPathComponent("wrong/SKILL.md"), atomically: true, encoding: .utf8)
        try "---\nname: renamed\n---\ncorrect source".write(to: repo.appendingPathComponent("skills/real/SKILL.md"), atomically: true, encoding: .utf8)
        try runGitTest(["-C", repo.path, "add", "."])
        try runGitTest(["-C", repo.path, "-c", "user.name=Regression", "-c", "user.email=test@example.com", "commit", "-m", "rename"])
        try await git.updateSkillFromGit(name: "real", progress: { _ in })
        check(try String(contentsOf: store.skillsRoot.appendingPathComponent("real/SKILL.md"), encoding: .utf8).contains("correct source"), "Git update selected another same-name Skill")
        try fm.removeItem(at: repo.appendingPathComponent("skills/real"))
        try runGitTest(["-C", repo.path, "add", "."])
        try runGitTest(["-C", repo.path, "-c", "user.name=Regression", "-c", "user.email=test@example.com", "commit", "-m", "remove original"])
        do { try await git.updateSkillFromGit(name: "real", progress: { _ in }); preconditionFailure("Missing source replaced by same-name Skill") } catch ManagerError.invalid { }
        check(try String(contentsOf: store.skillsRoot.appendingPathComponent("real/SKILL.md"), encoding: .utf8).contains("correct source"), "Failed Git update damaged original")
        let nativeBefore = try Data(contentsOf: file)
        let portableSameName: [String: Any] = ["url": "https://example.com/ordinary"]
        try JSONSerialization.data(withJSONObject: ["mcpServers": ["codex-builtin": portableSameName]]).write(to: cursor.mcpConfig.0)
        let portableRecord = Deployment(kind: "mcp", item: "codex-builtin", targetID: cursor.id, path: cursor.mcpConfig.0.path, fingerprint: store.mcpDeploymentFingerprint(portableSameName))
        try store.saveDeployments(store.deployments() + [portableRecord])
        let portableBefore = try Data(contentsOf: cursor.mcpConfig.0)
        _ = try store.cleanupBundledMCPArtifacts()
        check(try Data(contentsOf: file) == nativeBefore, "Cleanup changed owner's original config")
        check(try Data(contentsOf: cursor.mcpConfig.0) == portableBefore, "Cleanup deleted ordinary same-name MCP")
        check(store.deployments().contains { $0.item == "codex-builtin" && $0.targetID == cursor.id }, "Cleanup deleted ordinary deployment metadata")
        check(!store.libraryMCP().contains(where: \.isSystemService), "Cleanup left built-in central-library items")
        check(!store.disabledItems().contains { $0.item == "codex-builtin" && $0.targetID == cursor.id }, "Cleanup left stashed foreign copy")
        print("Regression checks passed")
    }

    private static func runGitTest(_ args: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        check(process.terminationStatus == 0, "Git fixture failed")
    }
}
