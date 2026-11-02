import SwiftUI

private struct PresetLaunch: Identifiable {
    let id = UUID()
    let preset: CapabilityPreset
    let action: PresetAction
}

private struct PresetCreateButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "plus")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .background(
                    isHovered ? ManagerTheme.electricBlue.opacity(0.84) : ManagerTheme.electricBlue,
                    in: Capsule()
                )
                .shadow(color: ManagerTheme.electricBlue.opacity(isHovered ? 0.32 : 0.18), radius: isHovered ? 9 : 5, y: 3)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

private struct PresetModalButton: View {
    enum Tone { case primary, success, stop, secondary }

    let title: String
    let icon: String?
    let tone: Tone
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    init(_ title: String, icon: String? = nil, tone: Tone, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.tone = tone
        self.action = action
    }

    private var accent: Color {
        switch tone {
        case .primary: ManagerTheme.electricBlue
        case .success: ManagerTheme.enableGreen
        case .stop: ManagerTheme.stopOrange
        case .secondary: ManagerTheme.primaryText
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let icon { Image(systemName: icon).font(.system(size: 12, weight: .bold)) }
                Text(title)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(tone == .secondary ? ManagerTheme.primaryText : Color.white)
            .padding(.horizontal, 17)
            .frame(height: 36)
            .background(
                tone == .secondary
                    ? (isHovered ? ManagerTheme.activePillBg : Color.white)
                    : (isHovered ? accent.opacity(0.83) : accent),
                in: Capsule()
            )
            .overlay(Capsule().stroke(tone == .secondary ? ManagerTheme.borderLine : Color.clear))
            .shadow(color: tone == .secondary ? .clear : accent.opacity(isHovered ? 0.23 : 0.13), radius: 7, y: 2)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

private struct PresetScopeSelector: View {
    @Binding var scope: String
    let projects: [String]

    private var title: String {
        scope.isEmpty ? "全局" : URL(fileURLWithPath: scope).lastPathComponent
    }

    var body: some View {
        ManagerDropdown(
            title: title,
            icon: scope.isEmpty ? "globe" : "folder",
            accessibilityLabel: "作用域",
            options: [ManagerDropdownOption(id: "", title: "全局", detail: nil)] + projects.map {
                ManagerDropdownOption(id: $0, title: URL(fileURLWithPath: $0).lastPathComponent, detail: $0)
            },
            selectedID: scope
        ) { scope = $0 }
    }
}

struct PresetsView: View {
    @ObservedObject var vm: AgentManagerViewModel
    @State private var presets: [CapabilityPreset] = []
    @State private var editing: CapabilityPreset?
    @State private var launch: PresetLaunch?
    @State private var deleting: CapabilityPreset?
    @State private var hoveredPresetID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("我的组合 · \(presets.count)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)
                        Text("把中央库中的 Skill 和 MCP 组成一套，将选中客户端切换为这套配置。")
                            .font(.system(size: 12))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }
                    Spacer()
                    PresetCreateButton(title: "新建预设") {
                        editing = CapabilityPreset(name: "", skills: [], mcps: [])
                    }
                }

                if presets.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "square.stack.3d.up.badge.a")
                            .font(.system(size: 36))
                            .foregroundStyle(ManagerTheme.indigo)
                        Text("还没有预设组合")
                            .font(.system(size: 16, weight: .bold))
                        Text("先从中央库挑选 Skill 与 MCP，再选择要启用的客户端。")
                            .font(.system(size: 12))
                            .foregroundStyle(ManagerTheme.secondaryText)
                        PresetCreateButton(title: "创建第一个预设") {
                            editing = CapabilityPreset(name: "", skills: [], mcps: [])
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(ManagerTheme.borderLine))
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 380), spacing: 18)], spacing: 18) {
                        ForEach(presets) { preset in
                            presetCard(preset)
                        }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .onAppear(perform: refresh)
        .sheet(item: $editing) { preset in
            PresetEditorSheet(vm: vm, preset: preset) {
                refresh()
            }
        }
        .sheet(item: $launch) { value in
            PresetApplySheet(vm: vm, preset: value.preset, action: value.action)
        }
        .alert("删除预设？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除预设", role: .destructive) {
                if let preset = deleting {
                    do {
                        try ManagerStore.shared.deletePreset(preset.id)
                        refresh()
                        vm.showToast(title: "已删除预设", detail: "客户端中已启用的能力不受影响")
                    } catch { vm.showToast(title: "删除失败", detail: error.localizedDescription, isError: true) }
                }
                deleting = nil
            }
        } message: {
            Text("只删除组合清单，不会停用已部署的 Skill 或 MCP。")
        }
    }

    private func refresh() { presets = ManagerStore.shared.presets() }

    private func presetCard(_ preset: CapabilityPreset) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(ManagerTheme.indigo)
                    .frame(width: 36, height: 36)
                    .background(ManagerTheme.indigo.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                        .lineLimit(2)
                    Text("\(preset.skills.count) 个 Skill  ·  \(preset.mcps.count) 个 MCP")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }
                .contentShape(Rectangle())
                .onTapGesture { editing = preset }
                Spacer(minLength: 2)
                Menu {
                    Button("编辑组合", systemImage: "pencil") { editing = preset }
                    Button("停用组合…", systemImage: "pause.circle") { launch = PresetLaunch(preset: preset, action: .disable) }
                    Divider()
                    Button("删除预设", systemImage: "trash", role: .destructive) { deleting = preset }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .frame(width: 28)
            }

            VStack(alignment: .leading, spacing: 8) {
                if !preset.skills.isEmpty { itemSummary("Skill", names: preset.skills, color: ManagerTheme.indigo) }
                if !preset.mcps.isEmpty { itemSummary("MCP", names: preset.mcps, color: ManagerTheme.mint) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .onTapGesture { editing = preset }

            HStack {
                Button { editing = preset } label: {
                    Label("编辑组合", systemImage: "pencil")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(ManagerTheme.electricBlue)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    launch = PresetLaunch(preset: preset, action: .enable)
                } label: {
                    Label("应用组合", systemImage: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 32)
                        .background(ManagerTheme.enableGreen, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .contentShape(RoundedRectangle(cornerRadius: 16))
                .onTapGesture { editing = preset }
        }
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(hoveredPresetID == preset.id ? ManagerTheme.electricBlue.opacity(0.55) : ManagerTheme.borderLine))
        .shadow(color: Color.black.opacity(hoveredPresetID == preset.id ? 0.10 : 0.04), radius: hoveredPresetID == preset.id ? 13 : 8, y: 3)
        .onHover { hovering in hoveredPresetID = hovering ? preset.id : nil }
        .animation(.easeOut(duration: 0.15), value: hoveredPresetID)
    }

    private func itemSummary(_ label: String, names: [String], color: Color) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 34, alignment: .leading)
            Text(names.joined(separator: "、"))
                .font(.system(size: 11))
                .foregroundStyle(ManagerTheme.primaryText)
                .lineLimit(2)
                .truncationMode(.tail)
        }
    }
}

private struct PresetEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: AgentManagerViewModel
    let preset: CapabilityPreset
    let onSave: () -> Void
    @State private var name: String
    @State private var selectedSkills: Set<String>
    @State private var selectedMCPs: Set<String>
    @State private var search = ""
    @State private var tab = 0

    init(vm: AgentManagerViewModel, preset: CapabilityPreset, onSave: @escaping () -> Void) {
        self.vm = vm
        self.preset = preset
        self.onSave = onSave
        _name = State(initialValue: preset.name)
        _selectedSkills = State(initialValue: Set(preset.skills))
        _selectedMCPs = State(initialValue: Set(preset.mcps))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name.isEmpty ? "新建预设" : "编辑预设")
                        .font(.system(size: 20, weight: .bold))
                    Text("预设只保存中央库条目的引用，不复制 MCP 密钥。")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .padding(8)
                        .background(Color.black.opacity(0.04), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
            TextField("预设名称，例如：日常开发", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(ManagerTheme.borderLine))
            HStack {
                SettingsSegmentedControl(selection: $tab, options: [
                    SettingsSegmentedOption(0, title: "Skills（\(selectedSkills.count)）", icon: "square.stack.3d.up"),
                    SettingsSegmentedOption(1, title: "MCP（\(selectedMCPs.count)）", icon: "point.3.connected.trianglepath.dotted")
                ])
                Spacer(minLength: 0)
                TextField("搜索中央库", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .frame(height: 38)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(ManagerTheme.borderLine))
                    .frame(width: 210)
            }
            HStack(spacing: 8) {
                Text(search.isEmpty ? "当前分类" : "当前搜索结果")
                    .font(.system(size: 11))
                    .foregroundStyle(ManagerTheme.secondaryText)
                Spacer()
                PresetModalButton("全选", icon: "checkmark.circle", tone: .secondary) {
                    updateSelection(.selectAll)
                }
                .disabled(visibleLibraryNames.isEmpty || visibleLibraryNames.isSubset(of: currentSelection))
                PresetModalButton("取消全选", tone: .secondary) {
                    updateSelection(.deselectAll)
                }
                .disabled(visibleSelectedNames.isEmpty)
                PresetModalButton("反选", icon: "arrow.triangle.2.circlepath", tone: .secondary) {
                    updateSelection(.invert)
                }
                .disabled(visibleLibraryNames.isEmpty && visibleSelectedNames.isEmpty)
            }
            ScrollView {
                LazyVStack(spacing: 6) {
                    if tab == 0 {
                        ForEach(vm.librarySkills.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in
                            selectionRow(item.name, detail: item.description, selected: selectedSkills.contains(item.name)) {
                                toggle(item.name, in: &selectedSkills)
                            }
                        }
                        ForEach(selectedSkills.subtracting(Set(vm.librarySkills.map(\.name))).sorted().filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { missing in
                            selectionRow(missing, detail: "中央库已缺失 · 点击移出预设", selected: true) {
                                selectedSkills.remove(missing)
                            }
                        }
                    } else {
                        ForEach(vm.libraryMCP.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }) { item in
                            selectionRow(item.name, detail: item.summary, selected: selectedMCPs.contains(item.name)) {
                                toggle(item.name, in: &selectedMCPs)
                            }
                        }
                        ForEach(selectedMCPs.subtracting(Set(vm.libraryMCP.map(\.name))).sorted().filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }, id: \.self) { missing in
                            selectionRow(missing, detail: "中央库已缺失 · 点击移出预设", selected: true) {
                                selectedMCPs.remove(missing)
                            }
                        }
                    }
                }
            }
            .frame(minHeight: 280)
            HStack {
                Text("已选 \(selectedSkills.count + selectedMCPs.count) 项")
                    .font(.system(size: 12))
                    .foregroundStyle(ManagerTheme.secondaryText)
                Spacer()
                PresetModalButton("取消", tone: .secondary) { dismiss() }
                PresetModalButton("保存预设", icon: "checkmark", tone: .primary) {
                    do {
                        try ManagerStore.shared.savePreset(CapabilityPreset(id: preset.id, name: name, skills: Array(selectedSkills), mcps: Array(selectedMCPs)))
                        onSave()
                        dismiss()
                        vm.showToast(title: "预设已保存")
                    } catch { vm.showToast(title: "保存失败", detail: error.localizedDescription, isError: true) }
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedSkills.isEmpty && selectedMCPs.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 680, height: 590)
        .foregroundStyle(ManagerTheme.primaryText)
        .background(ManagerTheme.canvasBg)
        .environment(\.colorScheme, .light)
    }

    private enum SelectionAction { case selectAll, deselectAll, invert }

    private var currentSelection: Set<String> {
        tab == 0 ? selectedSkills : selectedMCPs
    }

    private var visibleLibraryNames: Set<String> {
        let names = tab == 0 ? vm.librarySkills.map(\.name) : vm.libraryMCP.map(\.name)
        return Set(names.filter(matchesSearch))
    }

    private var visibleSelectedNames: Set<String> {
        Set(currentSelection.filter(matchesSearch))
    }

    private func matchesSearch(_ name: String) -> Bool {
        search.isEmpty || name.localizedCaseInsensitiveContains(search)
    }

    private func updateSelection(_ action: SelectionAction) {
        var selection = currentSelection
        switch action {
        case .selectAll:
            selection.formUnion(visibleLibraryNames)
        case .deselectAll:
            selection.subtract(visibleSelectedNames)
        case .invert:
            // Missing library entries can be removed, but never selected in bulk.
            let newlySelected = visibleLibraryNames.subtracting(selection)
            selection.subtract(visibleSelectedNames)
            selection.formUnion(newlySelected)
        }
        if tab == 0 { selectedSkills = selection }
        else { selectedMCPs = selection }
    }

    private func selectionRow(_ name: String, detail: String, selected: Bool, action: @escaping () -> Void) -> some View {
        ManagerSelectionRow(title: name, detail: detail, selected: selected, action: action)
    }

    private func toggle(_ name: String, in set: inout Set<String>) {
        if set.contains(name) { set.remove(name) } else { set.insert(name) }
    }
}

private struct PresetApplySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: AgentManagerViewModel
    let preset: CapabilityPreset
    let action: PresetAction
    @State private var scope = ""
    @State private var agents: Set<Agent> = []
    @State private var isWorking = false
    @State private var result: PresetActionResult?
    @State private var confirmedSharedImpact = false
    @State private var recoveryAttempted = false
    @State private var plan: [PresetPlanRow] = []
    @State private var availability: [Agent: Bool] = [:]

    private var targets: [Target] { Agent.allCases.filter { agents.contains($0) }.map { Target(agent: $0, project: scope.isEmpty ? nil : scope) } }

    // 预览需要扫描客户端配置，只在条件变化或执行后重新计算，避免每次重绘都读文件系统。
    private func refreshPlan() {
        plan = ManagerStore.shared.presetPlan(preset, targets: targets, action: action)
    }

    private func statusParts(_ status: String) -> (summary: String, reason: String?) {
        for prefix in ["无法应用：", "无法停用："] where status.hasPrefix(prefix) {
            return (String(prefix.dropLast()), String(status.dropFirst(prefix.count)))
        }
        return (status, nil)
    }
    private var isEnable: Bool { action == .enable }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(isEnable ? "应用" : "停用") · \(preset.name)")
                        .font(.system(size: 20, weight: .bold))
                    Text(isEnable ? "把所选客户端的 Skill 与 MCP 切换为这套预设。" : "选择作用域和客户端，预览后停用。")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .padding(8)
                        .background(Color.black.opacity(0.04), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(isEnable ? ManagerTheme.electricBlue : ManagerTheme.stopOrange)
                Text(isEnable
                     ? "预设外的现有能力会停用；同名外部配置会先暂存，再由中央库版本替换。操作可在设置的记录中逐项回滚。"
                     : "只停用这套预设中由 Looma 分发的条目；原配置不会自动恢复，可在客户端能力卡片中恢复暂存项。")
                    .foregroundStyle(ManagerTheme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 12, weight: .medium))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isEnable ? ManagerTheme.activePillBg : ManagerTheme.amber.opacity(0.11), in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                Text("作用域").font(.system(size: 12, weight: .semibold))
                PresetScopeSelector(scope: $scope, projects: vm.projects)
                    .frame(maxWidth: .infinity)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("客户端 · 仅可选择本机已安装的应用").font(.system(size: 12, weight: .semibold))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 8)], spacing: 8) {
                    ForEach(Agent.allCases) { agent in
                        let available = availability[agent] ?? false
                        ManagerSelectionRow(title: agent.rawValue, detail: available ? nil : "未检测到安装", selected: agents.contains(agent), isEnabled: available) {
                            if agents.contains(agent) { agents.remove(agent) } else { agents.insert(agent) }
                        }
                    }
                }
            }

            let rows = plan
            let changing = rows.filter(\.willChange).count
            let stopping = rows.filter { $0.willChange && ($0.step == .removeManaged || $0.step == .stashExisting) }.count
            let deploying = rows.filter { $0.willChange && $0.step == .deploy }.count
            let blocked = rows.filter { $0.step == .blocked }.count
            let waiting = rows.filter { $0.step == .waiting }.count
            let cleaning = rows.filter { $0.willChange && $0.step == .reconcile }.count
            let kept = rows.filter { $0.step == .keep }.count
            let sharedAgents = Array(Set(rows.flatMap(\.sharedWith))).sorted { $0.rawValue < $1.rawValue }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("执行预览")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                    Text("停用 \(stopping)\(isEnable ? " · 启用 \(deploying)" : "") · 保留 \(kept)\(cleaning > 0 ? " · 清理 \(cleaning)" : "")\(blocked > 0 ? " · 冲突 \(blocked)" : "")\(waiting > 0 ? " · 等待 \(waiting)" : "")")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(rows) { row in
                            let previousFailure = result?.failed.first { $0.hasPrefix("\(row.target.label) · \(row.kind == "skill" ? "Skill" : "MCP") \(row.name)：") }
                            let parts = statusParts(row.status)
                            let failureReason = previousFailure.map { String($0.split(separator: "：", maxSplits: 1).last ?? "") } ?? parts.reason
                            let isProblem = previousFailure != nil || row.step == .blocked
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 10) {
                                    Circle()
                                        .fill(isProblem ? Color.red : row.willChange ? (isEnable ? ManagerTheme.enableGreen : ManagerTheme.stopOrange) : ManagerTheme.secondaryText.opacity(0.45))
                                        .frame(width: 6, height: 6)
                                    Text(row.target.agent.rawValue)
                                        .frame(width: 100, alignment: .leading)
                                    Text(row.kind == "skill" ? "Skill" : row.kind == "mcp" ? "MCP" : "客户端")
                                        .foregroundStyle(ManagerTheme.secondaryText)
                                        .frame(width: 44, alignment: .leading)
                                    Text(row.name).lineLimit(1).truncationMode(.middle).help(row.name)
                                    Spacer(minLength: 12)
                                    Text(previousFailure == nil ? parts.summary : "上次执行失败")
                                        .foregroundStyle(isProblem ? Color.red : row.willChange ? (isEnable ? ManagerTheme.enableGreen : ManagerTheme.stopOrange) : ManagerTheme.secondaryText)
                                        .lineLimit(1)
                                        .help(row.status)
                                }
                                if let failureReason, isProblem {
                                    Text(failureReason)
                                        .foregroundStyle(Color.red.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                        .textSelection(.enabled)
                                        .padding(.leading, 16)
                                }
                            }
                            .font(.system(size: 11))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            Divider()
                        }
                    }
                }
                .frame(height: 180)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            }

            if isEnable && !sharedAgents.isEmpty {
                ManagerSelectionRow(
                    title: "共享 Skills 目录也会影响 \(sharedAgents.map(\.rawValue).joined(separator: "、"))",
                    detail: "我已了解并继续替换共享目录中的条目",
                    selected: confirmedSharedImpact
                ) {
                    confirmedSharedImpact.toggle()
                }
            }

            if let result {
                ScrollView {
                    VStack(alignment: .leading, spacing: 7) {
                    Text("\(recoveryAttempted && result.recoveryFailures.isEmpty ? "已恢复" : "已完成") \(result.changed.count) 项 · 未执行 \(result.notRun.count) 项 · 失败 \(result.failed.count) 项")
                        .font(.system(size: 12, weight: .bold))
                    ForEach(result.changed, id: \.self) { item in
                        Text("✓ 已完成 · \(item)").font(.system(size: 11)).foregroundStyle(ManagerTheme.enableGreen)
                    }
                    ForEach(result.notRun, id: \.self) { item in
                        Text("— 未执行 · \(item)").font(.system(size: 11)).foregroundStyle(ManagerTheme.secondaryText)
                    }
                    ForEach(result.failed, id: \.self) { failure in
                        Text(failure).font(.system(size: 11)).foregroundStyle(.red)
                    }
                    ForEach(result.recoveryFailures, id: \.self) { failure in
                        Text("恢复失败 · \(failure)").font(.system(size: 11)).foregroundStyle(.red)
                    }
                    if !result.operationIDs.isEmpty && !recoveryAttempted {
                        PresetModalButton("尝试恢复本次变更", icon: "arrow.uturn.backward", tone: .stop) {
                            isWorking = true
                            let ids = result.operationIDs
                            Task.detached {
                                let failures = ManagerStore.shared.rollbackPresetOperations(ids)
                                await MainActor.run {
                                    self.result?.recoveryFailures = failures
                                    recoveryAttempted = true
                                    isWorking = false
                                    refreshPlan()
                                    vm.showToast(title: failures.isEmpty ? "已恢复本次操作" : "部分操作未能恢复",
                                                 detail: failures.isEmpty ? "已按相反顺序回滚" : "请查看结果与设置中的操作记录",
                                                 isError: !failures.isEmpty)
                                    Task { await vm.reloadAll() }
                                }
                            }
                        }
                        .disabled(isWorking)
                        Text("目标文件若又被修改，恢复会停止并列出失败项。")
                            .font(.system(size: 11))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }
                    }
                }
                .frame(maxHeight: 150)
            }

            HStack {
                Text(blocked > 0 ? "有 \(blocked) 项冲突，处理后才能\(isEnable ? "应用" : "停用")；其余条目暂不执行。"
                     : agents.isEmpty ? "请至少选择一个客户端。"
                     : "每项操作都会写入操作记录，可在设置中逐项回滚。")
                    .font(.system(size: 11))
                    .foregroundStyle(blocked > 0 ? Color.red : ManagerTheme.secondaryText)
                Spacer()
                PresetModalButton("取消", tone: .secondary) { dismiss() }
                PresetModalButton(isWorking ? "处理中…" : (result?.failed.isEmpty == false ? "重试应用组合" : isEnable ? "应用组合 · \(changing) 项变更" : "停用 \(changing) 项"), icon: isEnable ? "checkmark" : "pause.fill", tone: isEnable ? .success : .stop) {
                    isWorking = true
                    let currentTargets = targets
                    let currentAction = action
                    let copy = vm.skillDeploymentMode == .copy
                    Task.detached {
                        let outcome = ManagerStore.shared.applyPreset(preset, targets: currentTargets, action: currentAction, copySkills: copy)
                        await MainActor.run {
                            if let previous = result, !recoveryAttempted {
                                var combined = outcome
                                combined.changed = previous.changed + outcome.changed
                                combined.operationIDs = previous.operationIDs + outcome.operationIDs
                                result = combined
                            } else {
                                result = outcome
                            }
                            recoveryAttempted = false
                            isWorking = false
                            refreshPlan()
                            vm.showToast(title: "组合处理完成", detail: "完成 \(outcome.changed.count) · 跳过 \(outcome.skipped.count) · 失败 \(outcome.failed.count)", isError: !outcome.failed.isEmpty)
                            Task { await vm.reloadAll() }
                        }
                    }
                }
                .disabled(isWorking || changing == 0 ||
                          (recoveryAttempted && result?.recoveryFailures.isEmpty == false) ||
                          (isEnable && !sharedAgents.isEmpty && !confirmedSharedImpact))
            }
        }
        .padding(24)
        .frame(width: 720)
        .foregroundStyle(ManagerTheme.primaryText)
        .background(ManagerTheme.canvasBg)
        .environment(\.colorScheme, .light)
        .onAppear {
            availability = Dictionary(uniqueKeysWithValues: Agent.allCases.map { ($0, ManagerStore.shared.agentAvailability($0)) })
            if let selected = vm.selectedAgent, availability[selected] == true { agents = [selected] }
            else if let firstAvailable = Agent.allCases.first(where: { availability[$0] == true }) { agents = [firstAvailable] }
            if let project = vm.selectedProject { scope = project }
            refreshPlan()
        }
        .onChange(of: scope) { _, _ in result = nil; confirmedSharedImpact = false; refreshPlan() }
        .onChange(of: agents) { _, _ in result = nil; confirmedSharedImpact = false; refreshPlan() }
    }
}
