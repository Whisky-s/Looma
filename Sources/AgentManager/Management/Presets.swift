import Foundation

struct CapabilityPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var skills: [String]
    var mcps: [String]

    init(id: UUID = UUID(), name: String, skills: [String], mcps: [String]) {
        self.id = id
        self.name = name
        self.skills = Array(Set(skills)).sorted()
        self.mcps = Array(Set(mcps)).sorted()
    }

    var itemCount: Int { skills.count + mcps.count }
}

enum PresetAction { case enable, disable }

enum PresetStep {
    case keep
    case enableClient
    case deploy
    case removeManaged
    case stashExisting
    case reconcile
    case waiting
    case blocked
}

struct PresetPlanRow: Identifiable {
    let target: Target
    let kind: String
    let name: String
    let status: String
    let willChange: Bool
    let step: PresetStep
    let path: String?
    var sharedWith: [Agent] = []
    var id: String { "\(target.id)|\(kind)|\(name)|\(String(describing: step))|\(path ?? "")" }
}

struct PresetActionResult {
    var changed: [String] = []
    var skipped: [String] = []
    var failed: [String] = []
    var notRun: [String] = []
    var operationIDs: [String] = []
    var recoveryFailures: [String] = []
}

extension ManagerStore {
    var presetsURL: URL { base.appendingPathComponent("presets.json") }

    func presets() -> [CapabilityPreset] {
        guard let data = try? Data(contentsOf: presetsURL) else { return [] }
        return (try? JSONDecoder().decode([CapabilityPreset].self, from: data))?.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        } ?? []
    }

    func savePreset(_ preset: CapabilityPreset) throws {
        let clean = CapabilityPreset(id: preset.id, name: preset.name.trimmingCharacters(in: .whitespacesAndNewlines), skills: preset.skills, mcps: preset.mcps)
        guard !clean.name.isEmpty else { throw ManagerError.invalid("请输入预设名称") }
        guard clean.itemCount > 0 else { throw ManagerError.invalid("请至少选择一个 Skill 或 MCP") }
        var all = presets()
        guard !all.contains(where: { $0.id != clean.id && $0.name.localizedCaseInsensitiveCompare(clean.name) == .orderedSame }) else {
            throw ManagerError.conflict("已有同名预设：\(clean.name)")
        }
        if let index = all.firstIndex(where: { $0.id == clean.id }) { all[index] = clean }
        else { all.append(clean) }
        try withRecordedOperation(action: "保存预设", kind: "preset", target: clean.name, paths: [presetsURL]) {
            try JSONEncoder().encode(all).write(to: presetsURL, options: .atomic)
        }
    }

    func deletePreset(_ id: UUID) throws {
        let all = presets()
        guard let preset = all.first(where: { $0.id == id }) else { throw ManagerError.invalid("预设不存在") }
        try withRecordedOperation(action: "删除预设", kind: "preset", target: preset.name, paths: [presetsURL]) {
            try JSONEncoder().encode(all.filter { $0.id != id }).write(to: presetsURL, options: .atomic)
        }
    }

    func presetPlan(_ preset: CapabilityPreset, targets: [Target], action: PresetAction) -> [PresetPlanRow] {
        let skillNames = Set(librarySkills().map(\.name))
        let mcpNames = Set(libraryMCP().map(\.name))
        let installedSkillItems = installedSkills()
        let installedMCPItems = installedMCP()
        let active = deployments()
        let selectedAgents = Set(targets.map(\.agent))
        return targets.flatMap { target in
            if action == .enable && !agentAvailability(target.agent) {
                return [PresetPlanRow(target: target, kind: "client", name: target.agent.rawValue,
                    status: "未检测到客户端安装，无法应用", willChange: false, step: .blocked, path: nil)]
            }
            let skills = installedSkillItems.filter { $0.agent == target.agent && $0.project == target.project }
            let mcps = installedMCPItems.filter { $0.agent == target.agent && $0.project == target.project }
            var rows: [PresetPlanRow] = []

            if action == .disable {
                for (kind, names) in [("skill", preset.skills), ("mcp", preset.mcps)] {
                    for name in names {
                        let deployment = active.first { $0.kind == kind && $0.item == name && $0.targetID == target.id }
                        let exists = kind == "skill" ? skills.contains { $0.name == name } : mcps.contains { $0.name == name }
                        var removalError: String?
                        if deployment != nil {
                            do {
                                if kind == "skill" { _ = try validateManagedSkillRemoval(name, from: target) }
                                else { try validateManagedMCPRemoval(name, from: target) }
                            } catch { removalError = error.localizedDescription }
                        }
                        rows.append(PresetPlanRow(target: target, kind: kind, name: name,
                            status: removalError.map { "无法停用：\($0)" } ?? (deployment != nil ? "待停用" : (exists ? "外部配置，保留" : "未启用")),
                            willChange: deployment != nil && removalError == nil,
                            step: removalError != nil ? .blocked : (deployment != nil ? .removeManaged : .keep),
                            path: deployment?.path))
                    }
                }
                if rows.contains(where: { $0.step == .blocked }) {
                    return rows.map { row in
                        guard row.willChange else { return row }
                        return PresetPlanRow(target: row.target, kind: row.kind, name: row.name,
                            status: "等待解决冲突", willChange: false, step: .waiting, path: row.path)
                    }
                }
                return rows
            }

            for name in preset.skills where !skillNames.contains(name) {
                rows.append(PresetPlanRow(target: target, kind: "skill", name: name, status: "无法应用：中央库已缺失", willChange: false, step: .blocked, path: nil))
            }
            for name in preset.mcps {
                if !mcpNames.contains(name) {
                    rows.append(PresetPlanRow(target: target, kind: "mcp", name: name, status: "无法应用：中央库已缺失", willChange: false, step: .blocked, path: nil))
                } else {
                    do { try validateMCPDeployment(name, to: target) }
                    catch {
                        rows.append(PresetPlanRow(target: target, kind: "mcp", name: name, status: "无法应用：\(error.localizedDescription)", willChange: false, step: .blocked, path: nil))
                    }
                }
            }
            if target.agent == .claude {
                // 预设应用后同作用域只剩预设 MCP、受保护的系统服务，以及项目作用域下仍生效的全局配置。
                let remaining = mcps.filter { $0.isProtectedSystemService(in: .claude, managed: false) }
                    + (target.project == nil ? [] : installedMCPItems.filter { $0.agent == .claude && $0.project == nil })
                var seen: [String: String] = [:]
                for name in preset.mcps where mcpNames.contains(name) {
                    let key = claudeMCPToolKey(name)
                    if let other = seen[key] ?? claudeToolNameClash(name, target: target, among: remaining) {
                        rows.append(PresetPlanRow(target: target, kind: "mcp", name: name, status: "无法应用：\(claudeToolNameClashMessage(name, other))", willChange: false, step: .blocked, path: nil))
                    }
                    seen[key] = seen[key] ?? name
                }
            }
            for name in preset.skills {
                let destination = target.skillRoot.appendingPathComponent(name)
                let recognized = skills.contains { $0.url.standardizedFileURL.path == destination.standardizedFileURL.path }
                let occupied = fm.fileExists(atPath: destination.path) || (try? fm.destinationOfSymbolicLink(atPath: destination.path)) != nil
                if occupied && !recognized {
                    rows.append(PresetPlanRow(target: target, kind: "skill", name: name, status: "无法应用：目标路径已被占用", willChange: false, step: .blocked, path: destination.path))
                }
            }
            if !rows.isEmpty { return rows }

            let desiredSkills = Set(preset.skills)
            let desiredMCPs = Set(preset.mcps)
            var retainedSkills = Set<String>()
            var retainedMCPs = Set<String>()

            for item in skills.sorted(by: { $0.url.path < $1.url.path }) {
                let deployment = active.first { $0.kind == "skill" && URL(fileURLWithPath: $0.path).standardizedFileURL.path == item.url.standardizedFileURL.path }
                let desired = desiredSkills.contains(item.name)
                if desired, let deployment, deployment.targetID == target.id {
                    do {
                        _ = try validateManagedSkillRemoval(item.name, from: target)
                        retainedSkills.insert(item.name)
                        let disabled = try capabilityState(item.name, target: target, skill: true) == .disabled
                        rows.append(PresetPlanRow(target: target, kind: "skill", name: item.name, status: disabled ? "待恢复客户端启用" : "已由本应用启用", willChange: disabled, step: disabled ? .enableClient : .keep, path: item.url.path))
                    } catch {
                        rows.append(PresetPlanRow(target: target, kind: "skill", name: item.name, status: "无法应用：\(error.localizedDescription)", willChange: false, step: .blocked, path: item.url.path))
                    }
                    continue
                }
                if let deployment, deployment.targetID != target.id {
                    if desired && deployment.fingerprint == skillsRoot.appendingPathComponent(item.name).path &&
                       (try? fm.destinationOfSymbolicLink(atPath: item.url.path)) == deployment.fingerprint {
                        retainedSkills.insert(item.name)
                        rows.append(PresetPlanRow(target: target, kind: "skill", name: item.name, status: "共享中央库链接，保留", willChange: false, step: .keep, path: item.url.path))
                    } else {
                        rows.append(PresetPlanRow(target: target, kind: "skill", name: item.name, status: "无法应用：由其他客户端分发至共享目录", willChange: false, step: .blocked, path: item.url.path))
                    }
                    continue
                }
                let shared = otherAgentsUsingSkillPath(item.url, target: target, selectedAgents: selectedAgents)
                let detail = shared.isEmpty ? "" : " · 共享 \(shared.map(\.rawValue).joined(separator: "、"))"
                if deployment != nil {
                    do { _ = try validateManagedSkillRemoval(item.name, from: target) }
                    catch {
                        rows.append(PresetPlanRow(target: target, kind: "skill", name: item.name, status: "无法应用：\(error.localizedDescription)", willChange: false, step: .blocked, path: item.url.path))
                        continue
                    }
                }
                rows.append(PresetPlanRow(target: target, kind: "skill", name: item.name,
                    status: deployment != nil ? "待停用本应用分发\(detail)" : (desired ? "待暂存原配置\(detail)" : "待停用原配置\(detail)"),
                    willChange: true, step: deployment == nil ? .stashExisting : .removeManaged,
                    path: item.url.path, sharedWith: shared))
            }
            for item in mcps.sorted(by: { $0.name < $1.name }) {
                let deployment = active.first { $0.kind == "mcp" && $0.item == item.name && $0.targetID == target.id }
                let desired = desiredMCPs.contains(item.name)
                if item.isProtectedSystemService(in: target.agent, managed: deployment != nil) {
                    if desired { retainedMCPs.insert(item.name) }
                    rows.append(PresetPlanRow(target: target, kind: "mcp", name: item.name,
                        status: "系统服务，保留", willChange: false, step: .keep, path: item.source.path))
                    continue
                }
                if deployment != nil {
                    do { try validateManagedMCPRemoval(item.name, from: target) }
                    catch {
                        rows.append(PresetPlanRow(target: target, kind: "mcp", name: item.name, status: "无法应用：\(error.localizedDescription)", willChange: false, step: .blocked, path: item.source.path))
                        continue
                    }
                }
                if desired && deployment != nil {
                    retainedMCPs.insert(item.name)
                    rows.append(PresetPlanRow(target: target, kind: "mcp", name: item.name, status: "已由本应用启用", willChange: false, step: .keep, path: item.source.path))
                } else {
                    rows.append(PresetPlanRow(target: target, kind: "mcp", name: item.name,
                        status: desired ? "待暂存原配置" : "待停用原配置", willChange: true,
                        step: deployment == nil ? .stashExisting : .removeManaged, path: item.source.path))
                }
            }
            for deployment in active where deployment.targetID == target.id {
                let found = deployment.kind == "skill"
                    ? skills.contains { URL(fileURLWithPath: deployment.path).standardizedFileURL.path == $0.url.standardizedFileURL.path }
                    : mcps.contains { $0.name == deployment.item }
                if !found {
                    do {
                        try validateStalePresetDeployment(deployment, target: target)
                        rows.append(PresetPlanRow(target: target, kind: deployment.kind, name: deployment.item,
                            status: "待清理失效记录", willChange: true, step: .reconcile, path: deployment.path))
                    } catch {
                        rows.append(PresetPlanRow(target: target, kind: deployment.kind, name: deployment.item,
                            status: "无法应用：\(error.localizedDescription)", willChange: false, step: .blocked, path: deployment.path))
                    }
                }
            }
            for name in preset.skills where !retainedSkills.contains(name) {
                let destination = target.skillRoot.appendingPathComponent(name)
                let shared = otherAgentsUsingSkillPath(destination, target: target, selectedAgents: selectedAgents)
                let detail = shared.isEmpty ? "" : " · 共享 \(shared.map(\.rawValue).joined(separator: "、"))"
                rows.append(PresetPlanRow(target: target, kind: "skill", name: name, status: "待启用预设\(detail)", willChange: true, step: .deploy, path: destination.path, sharedWith: shared))
            }
            for name in preset.mcps where !retainedMCPs.contains(name) {
                rows.append(PresetPlanRow(target: target, kind: "mcp", name: name, status: "待启用预设", willChange: true, step: .deploy, path: mcpConfig(for: target).0.path))
            }
            if rows.contains(where: { $0.step == .blocked }) {
                return rows.map { row in
                    guard row.willChange else { return row }
                    return PresetPlanRow(target: row.target, kind: row.kind, name: row.name,
                        status: "等待解决冲突", willChange: false, step: .waiting, path: row.path, sharedWith: row.sharedWith)
                }
            }
            return rows
        }
    }

    func applyPreset(_ preset: CapabilityPreset, targets: [Target], action: PresetAction, copySkills: Bool) -> PresetActionResult {
        var result = PresetActionResult()
        for target in targets {
            let rows = presetPlan(preset, targets: [target], action: action)
            if rows.contains(where: { $0.step == .blocked }) {
                result.failed.append("\(target.label)：预设无法完整应用，请先处理预览中的冲突")
                result.notRun.append(contentsOf: rows.filter { $0.step != .keep }.map { "\($0.target.label) · \($0.kind == "skill" ? "Skill" : "MCP") \($0.name)" })
                continue
            }
            for (index, row) in rows.enumerated() {
                let label = "\(row.target.label) · \(row.kind == "skill" ? "Skill" : "MCP") \(row.name)"
                guard row.willChange else {
                    result.skipped.append("\(label)：\(row.status)")
                    continue
                }
                let beforeIDs = Set(operationHistory().map(\.id))
                do {
                    switch (row.kind, row.step) {
                    case ("skill", .reconcile), ("mcp", .reconcile):
                        guard let deployment = deployments().first(where: { $0.kind == row.kind && $0.item == row.name && $0.targetID == target.id }) else {
                            throw ManagerError.conflict("分发记录已变化，请刷新预览")
                        }
                        try validateStalePresetDeployment(deployment, target: target)
                        if row.kind == "skill" { try removeSkill(row.name, from: target) }
                        else { try removeMCP(row.name, from: target) }
                    case ("skill", .enableClient): try enableClientSkill(row.name, target: target)
                    case ("mcp", .enableClient): try enableClientMCP(row.name, target: target)
                    case ("skill", .deploy): try deploySkill(row.name, to: target, copy: copySkills)
                    case ("mcp", .deploy): try deployMCP(row.name, to: target)
                    case ("skill", .removeManaged): try removeSkill(row.name, from: target)
                    case ("mcp", .removeManaged): try removeMCP(row.name, from: target)
                    case ("skill", .stashExisting): try disableExistingSkill(row.name, from: target, at: row.path.map { URL(fileURLWithPath: $0) })
                    case ("mcp", .stashExisting): try disableExistingMCP(row.name, from: target)
                    default: throw ManagerError.invalid("未知的预设操作")
                    }
                    result.changed.append(label)
                    result.operationIDs.append(contentsOf: operationHistory().filter { !beforeIDs.contains($0.id) && $0.canRollback }.map(\.id))
                } catch {
                    result.failed.append("\(label)：\(error.localizedDescription)")
                    result.operationIDs.append(contentsOf: operationHistory().filter { !beforeIDs.contains($0.id) && $0.canRollback }.map(\.id))
                    result.notRun.append(contentsOf: rows.dropFirst(index + 1).filter(\.willChange).map {
                        "\($0.target.label) · \($0.kind == "skill" ? "Skill" : "MCP") \($0.name)"
                    })
                    break
                }
            }
        }
        return result
    }

    private func validateStalePresetDeployment(_ deployment: Deployment, target: Target) throws {
        if deployment.kind == "skill" {
            do {
                _ = try fm.attributesOfItem(atPath: deployment.path)
            } catch let error as CocoaError where error.code == .fileReadNoSuchFile || error.code == .fileNoSuchFile {
                return
            }
            throw ManagerError.conflict("Skill 路径仍存在，但未识别为有效 Skill，请检查目标文件")
        }
        guard deployment.kind == "mcp",
              URL(fileURLWithPath: deployment.path).standardizedFileURL == mcpConfig(for: target).0.standardizedFileURL,
              try mcpConfigurationState(deployment.item, target: target) == .missing else {
            throw ManagerError.conflict("目标配置仍存在或路径已变化，请刷新预览")
        }
    }

    func rollbackPresetOperations(_ ids: [String]) -> [String] {
        historyLock.lock()
        historyPruningSuspensions += 1
        defer {
            historyPruningSuspensions -= 1
            try? pruneHistory()
            historyLock.unlock()
        }
        var failures: [String] = []
        for id in ids.reversed() {
            guard let entry = operationHistory().first(where: { $0.id == id }) else {
                failures.append("操作记录已不在保留范围：\(id)")
                continue
            }
            do { try rollbackOperation(entry) }
            catch { failures.append("\(entry.target)：\(error.localizedDescription)") }
        }
        return failures
    }

    private func otherAgentsUsingSkillPath(_ skill: URL, target: Target, selectedAgents: Set<Agent>) -> [Agent] {
        let parent = skill.deletingLastPathComponent().standardizedFileURL.path
        return Agent.allCases.filter { agent in
            guard agent != target.agent && !selectedAgents.contains(agent) else { return false }
            let roots = target.project == nil ? agent.globalSkillRoots : agent.projectSkillRoots
            return roots.contains { resolve($0, project: target.project).standardizedFileURL.path == parent }
        }
    }
}
