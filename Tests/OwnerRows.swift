import Foundation

@main struct OwnerRows {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("agent-manager-owner-rows-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ManagerStore(baseURL: root, userHomeURL: root, agentAvailability: { _ in true })
        let vm = AgentManagerViewModel(store: store)
        let definition: [String: Any] = ["command": "/Users/example/.codex/computer-use/Codex Computer Use.app/Contents/MacOS/mcp"]
        let codex = Target(agent: .codex, project: nil)
        let other = Target(agent: .antigravity, project: nil)
        vm.libraryMCP = [MCPItem(name: "computer-use", definition: definition, agent: nil, project: nil, source: root, isLibrary: true)]
        vm.installedMCP = [.init(name: "computer-use", definition: definition, agent: .codex, project: nil, source: root, isLibrary: false), .init(name: "computer-use", definition: definition, agent: .antigravity, project: nil, source: root, isLibrary: false)]
        vm.deployments = [.init(kind: "mcp", item: "computer-use", targetID: codex.id, path: root.path, fingerprint: "legacy")]
        for target in [codex, other] { vm.configurationStates[syncKey("computer-use", target: target, skill: false)] = .configured }
        let owner = vm.targetRow(for: "computer-use", target: codex, isSkill: false)
        precondition(owner.status == "系统服务" && owner.action == nil && !owner.managed, "Codex owner mislabeled as managed copy")
        let foreign = vm.targetRow(for: "computer-use", target: other, isSkill: false)
        precondition(foreign.action == "disable" && foreign.status == "已有配置", "Unmanaged foreign copy falsely protected")
        vm.deployments.append(.init(kind: "mcp", item: "computer-use", targetID: other.id, path: root.path, fingerprint: "legacy"))
        let managed = vm.targetRow(for: "computer-use", target: other, isSkill: false)
        precondition(managed.action == "remove" && managed.managed, "Managed foreign copy could not be stopped")
        let missing = vm.targetRow(for: "computer-use", target: Target(agent: .cursor, project: nil), isSkill: false)
        precondition(missing.action == nil && missing.status == "禁止跨应用分发", "Missing client falsely labeled as owner")
        vm.configurationStates[syncKey("computer-use", target: other, skill: false)] = .disabled
        precondition(vm.targetRow(for: "computer-use", target: other, isSkill: false).action == "remove", "Disabled foreign copy exposes re-enable")
        vm.page = 1
        let builtin = vm.displayItems.first { $0.name == "computer-use" }!
        precondition(!builtin.library && builtin.targets.count == 1 && builtin.targets.first?.target.agent == .codex, "Built-in item leaked central-library or foreign-client targets")
        vm.installedMCP.append(.init(name: "node_repl", definition: ["command": "/Applications/ChatGPT.app/Contents/Resources/node_repl"], agent: .codex, project: nil, source: root, isLibrary: false))
        vm.configurationStates[syncKey("node_repl", target: codex, skill: false)] = .configured
        vm.sourceFilter = 1
        vm.statusFilter = 1
        vm.navigateToClient(.codex)
        precondition(vm.sourceFilter == 0 && vm.page == 1, "Client navigation retained central-library filter")
        precondition(Set(vm.displayItems.map(\.name)) == Set(["computer-use", "node_repl"]), "Enabled client view hides built-in services")
        vm.sourceFilter = 1
        precondition(vm.displayItems.isEmpty, "Explicit central-library filter shows built-in services")

        // A WorkBuddy configuration recreated outside Looma must supersede its old stash.
        let workbuddy = Target(agent: .workbuddy, project: nil)
        let config = store.mcpConfig(for: workbuddy).0
        try FileManager.default.createDirectory(at: config.deletingLastPathComponent(), withIntermediateDirectories: true)
        let activeConfig = Data(#"{"mcpServers":{"sap-qas":{"url":"http://localhost:8080/mcp/QAS"}}}"#.utf8)
        try activeConfig.write(to: config)
        try store.disableExistingMCP("sap-qas", from: workbuddy)
        vm.disabledItems = store.disabledItems()
        vm.configurationStates = store.synchronizationStates()
        let stashed = vm.targetRow(for: "sap-qas", target: workbuddy, isSkill: false)
        precondition(stashed.status == "已停用" && stashed.action == "restore", "Missing configuration lost stash restore action")
        try activeConfig.write(to: config)
        vm.installedMCP = store.installedMCP()
        vm.configurationStates = store.synchronizationStates()
        let recreated = vm.targetRow(for: "sap-qas", target: workbuddy, isSkill: false)
        precondition(recreated.status == "已有配置" && recreated.isEnabled && recreated.action == "disable", "Old stash masks externally recreated WorkBuddy MCP")
        let scannedConfig = try Data(contentsOf: config)
        precondition(scannedConfig == activeConfig, "Status scan modified client configuration")
        try Data(#"{"mcpServers":{"sap-qas":{"url":"http://localhost:8080/mcp/QAS","disabled":true}}}"#.utf8).write(to: config)
        vm.installedMCP = store.installedMCP()
        vm.configurationStates = store.synchronizationStates()
        let clientDisabled = vm.targetRow(for: "sap-qas", target: workbuddy, isSkill: false)
        precondition(clientDisabled.status == "客户端已停用" && clientDisabled.action == "enableClientMCP", "Old stash masks current client disable switch")
        print("Owner row checks passed")
    }
}
