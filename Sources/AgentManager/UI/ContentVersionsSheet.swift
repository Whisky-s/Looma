import AppKit
import SwiftUI

struct ContentVersionsSheet: View {
    @ObservedObject var vm: AgentManagerViewModel
    let item: DisplayItem
    @Environment(\.dismiss) private var dismiss
    @State private var versions: [ContentVersion] = []
    @State private var sourceID = ""
    @State private var targetID = ""
    @State private var archiveName = ""
    @State private var busy = false
    @State private var message: String?
    @State private var confirmReplacement = false

    private var source: ContentVersion? { versions.first { $0.id == sourceID } }
    private var target: ContentVersion? { versions.first { $0.id == targetID } }
    private var differences: [String]? {
        guard let source, let target else { return nil }
        return source.differences(from: target)
    }

    private var canReplace: Bool {
        !busy && !sourceID.isEmpty && !targetID.isEmpty && sourceID != targetID && differences?.isEmpty == false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            headerBar

            // Main Stage: Source Pane vs Destination Pane
            HStack(alignment: .top, spacing: 14) {
                versionCard(
                    title: "来源版本 (复制从此配置)",
                    icon: "arrow.up.forward.circle.fill",
                    selection: $sourceID,
                    version: source
                )
                versionCard(
                    title: "目标版本 (将被替换 / 对比)",
                    icon: "arrow.down.forward.circle.fill",
                    selection: $targetID,
                    version: target
                )
            }

            // Differences Preview
            diffSection

            // Footnote Explanation
            Text(item.isSkill
                 ? "比较包含隐藏资源和链接指向的内容；忽略 .git、.git-source.json 和 .DS_Store。替换共享目录会被阻止，可另存后分别部署。"
                 : "统一处理 JSON/TOML、服务地址及请求头别名；环境变量、超时、范围等实际差异会保留。凭据仅提示字段差异并脱敏显示。")
                .font(.system(size: 11))
                .foregroundStyle(ManagerTheme.secondaryText)

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            // Bottom Actions Bar
            bottomBar

            if let message {
                HStack(spacing: 6) {
                    Image(systemName: message.contains("完成") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(message.contains("完成") ? ManagerTheme.enableGreen : Color.red)
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.primaryText)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
            }
        }
        .padding(22)
        .frame(width: 960, height: 780)
        .background(ManagerTheme.canvasBg)
        .environment(\.colorScheme, .light)
        .task {
            archiveName = item.name
            await refresh()
        }
        .confirmationDialog("确认替换这一处内容？", isPresented: $confirmReplacement, titleVisibility: .visible) {
            Button("备份并替换目标", role: .destructive) {
                guard let source, let target else { return }
                Task { await run { try await vm.replaceContentVersion(from: source, to: target) } }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("来源：\(source?.label ?? "") (\(source?.path.path ?? ""))\n目标：\(target?.label ?? "") (\(target?.path.path ?? ""))\n\n将用来源的整份内容覆盖目标配置。旧配置已建立安全快照，可在「设置 - 操作记录」中随时一键回滚。")
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill((item.library ? ManagerTheme.indigo : ManagerTheme.amber).opacity(0.12))
                    .frame(width: 40, height: 40)

                Image(systemName: item.isSkill ? "square.stack.3d.up.fill" : "point.3.connected.trianglepath.dotted")
                    .font(.system(size: 19))
                    .foregroundStyle(item.library ? ManagerTheme.indigo : ManagerTheme.amber)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("\(item.name) · 版本比较与替换")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)

                    CapabilityTypeBadge(label: item.typeLabel)

                    if item.hasContentDifferences {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 8.5, weight: .bold))
                            Text("同名不同内容")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(ManagerTheme.stopOrange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ManagerTheme.amber.opacity(0.15), in: Capsule())
                    }
                }

                Text("启停状态与内容一致性分别判断。明确选择来源和目标，只修改选中的客户端位置；旧内容自动备份。")
                    .font(.system(size: 12))
                    .foregroundStyle(ManagerTheme.secondaryText)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    Task { await refresh() }
                } label: {
                    HStack(spacing: 5) {
                        if busy {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10.5, weight: .bold))
                        }
                        Text("刷新")
                            .font(.system(size: 11.5, weight: .bold))
                    }
                    .foregroundStyle(ManagerTheme.electricBlue)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(ManagerTheme.activePillBg, in: Capsule())
                    .overlay(Capsule().stroke(ManagerTheme.electricBlue.opacity(0.25), lineWidth: 0.8))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(busy)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .padding(7)
                        .background(Color.black.opacity(0.04), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Version Card (Left & Right)
    private func versionCard(title: String, icon: String, selection: Binding<String>, version: ContentVersion?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Card Header: Title + Version Picker
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(ManagerTheme.electricBlue)
                    Text(title)
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }

                Spacer()

                Menu {
                    ForEach(versions) { entry in
                        Button {
                            selection.wrappedValue = entry.id
                        } label: {
                            HStack {
                                Text(entry.label + (entry.isSkill ? " · " + entry.path.deletingLastPathComponent().lastPathComponent : ""))
                                if entry.id == selection.wrappedValue {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if let target = version?.target {
                            AgentLogo(agent: target.agent, size: 14)
                        } else {
                            Image(systemName: "building.columns.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(ManagerTheme.indigo)
                        }
                        Text(version?.label ?? "请选择版本")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(ManagerTheme.primaryText)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(ManagerTheme.secondaryText)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
            }

            if let version {
                // Status line & badges
                HStack(spacing: 6) {
                    if let target = version.target {
                        let row = vm.targetRow(for: item.name, target: target, isSkill: item.isSkill)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(row.isEnabled ? ManagerTheme.mint : (row.status.contains("停用") ? ManagerTheme.amber : Color.gray.opacity(0.3)))
                                .frame(width: 6, height: 6)
                            Text(row.status)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ManagerTheme.secondaryText)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ManagerTheme.insetBg, in: Capsule())

                        if let rel = contentRelation(versions, target: target) {
                            Text(rel)
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundStyle(rel.contains("不同") ? ManagerTheme.stopOrange : (rel.contains("一致") ? ManagerTheme.enableGreen : ManagerTheme.secondaryText))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((rel.contains("不同") ? ManagerTheme.amber : (rel.contains("一致") ? ManagerTheme.mint : Color.gray)).opacity(0.12), in: Capsule())
                        }
                    } else {
                        Text("中央库基准版本")
                            .font(.system(size: 10.5, weight: .bold))
                            .foregroundStyle(ManagerTheme.indigo)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ManagerTheme.indigo.opacity(0.12), in: Capsule())
                    }

                    Spacer()

                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([version.path])
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "folder")
                                .font(.system(size: 9.5, weight: .semibold))
                            Text("在访达中显示")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .foregroundStyle(ManagerTheme.secondaryText)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(ManagerTheme.insetBg, in: Capsule())
                        .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                }

                // Path
                Text(version.path.path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                if let error = version.error {
                    Text(error).font(.system(size: 11)).foregroundStyle(.red)
                }

                // Content View (Markdown for Skill, Formatted Redacted JSON for MCP)
                VStack(spacing: 0) {
                    if version.isSkill {
                        SkillMarkdownPreviewView(fileURL: version.path.appendingPathComponent("SKILL.md"), fallbackText: "无法读取 SKILL.md")
                            .id(version.id + (version.digest ?? ""))
                    } else if let definition = version.definition {
                        ScrollView {
                            Text(ManagerStore.shared.redactedMCPContent(definition))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(ManagerTheme.primaryText)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                Spacer()
                Text("请从上方下拉框选择要查看的来源。")
                    .font(.system(size: 12))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ManagerTheme.borderLine, lineWidth: 1))
    }

    // MARK: - Differences Section
    private var diffSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: differences?.isEmpty == false ? "arrow.left.arrow.right" : "checkmark.seal.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(differences?.isEmpty == false ? ManagerTheme.stopOrange : ManagerTheme.mint)

                    Text("差异对比与变更预览")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                }

                Spacer()

                if let differences {
                    if differences.isEmpty {
                        Text("内容完全一致")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ManagerTheme.enableGreen)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(ManagerTheme.mint.opacity(0.12), in: Capsule())
                    } else {
                        Text("\(differences.count) 处差异")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(ManagerTheme.stopOrange)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(ManagerTheme.amber.opacity(0.14), in: Capsule())
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if let differences {
                        if differences.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(ManagerTheme.mint)
                                Text("两份版本内容规范化后完全一致。客户端启停开关不计入内容差异。")
                                    .font(.system(size: 12))
                                    .foregroundStyle(ManagerTheme.secondaryText)
                            }
                            .padding(6)
                        } else {
                            ForEach(differences, id: \.self) { path in
                                HStack {
                                    Text(path.isEmpty ? "/" : path)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(ManagerTheme.primaryText)
                                        .textSelection(.enabled)
                                    Spacer()
                                    diffLabelBadge(changeLabel(path))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    } else {
                        Text("请选择可正常读取的来源与目标以开始对比。")
                            .font(.system(size: 12))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .padding(6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 105)
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ManagerTheme.borderLine, lineWidth: 1))
    }

    private func diffLabelBadge(_ label: String) -> some View {
        let isAdd = label.contains("新增")
        let isRemove = label.contains("移除")
        let color = isAdd ? ManagerTheme.enableGreen : (isRemove ? Color.red : ManagerTheme.stopOrange)
        let bg = isAdd ? ManagerTheme.mint : (isRemove ? Color.red : ManagerTheme.amber)
        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(bg.opacity(0.12), in: Capsule())
    }

    // MARK: - Bottom Actions Bar
    private var bottomBar: some View {
        HStack(spacing: 12) {
            // Save as New Central Library Version
            HStack(spacing: 6) {
                TextField("新版本名称", text: $archiveName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .frame(width: 170, height: 32)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 0.8))

                Button {
                    guard let source else { return }
                    Task { await run { try await vm.saveContentVersion(source, as: archiveName) } }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.square")
                            .font(.system(size: 11, weight: .bold))
                        Text("另存来源到中央库")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(ManagerTheme.indigo)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .background(ManagerTheme.indigo.opacity(0.1), in: Capsule())
                    .overlay(Capsule().stroke(ManagerTheme.indigo.opacity(0.3), lineWidth: 0.8))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(busy || source?.digest == nil || archiveName.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Spacer()

            // Cancel Button
            Button {
                dismiss()
            } label: {
                Text("关闭")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(ManagerTheme.secondaryText)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(ManagerTheme.insetBg, in: Capsule())
                    .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)

            // Replace Target Button
            Button {
                confirmReplacement = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11.5, weight: .bold))
                    Text("用来源替换目标…")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .frame(height: 34)
                .background(canReplace ? ManagerTheme.indigo : Color.gray.opacity(0.35), in: Capsule())
                .shadow(color: canReplace ? ManagerTheme.indigo.opacity(0.35) : .clear, radius: 5, y: 2)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canReplace)
        }
    }

    private func changeLabel(_ path: String) -> String {
        if source?.manifest?[path] == nil { return "替换时移除" }
        if target?.manifest?[path] == nil { return "替换时新增" }
        return "内容不同"
    }

    @MainActor private func refresh() async {
        busy = true
        versions = await vm.loadContentVersions(for: item)
        if !versions.contains(where: { $0.id == sourceID }) { sourceID = versions.first?.id ?? "" }
        if !versions.contains(where: { $0.id == targetID }) { targetID = versions.first { $0.id != sourceID }?.id ?? sourceID }
        busy = false
    }

    @MainActor private func run(_ action: () async throws -> Void) async {
        busy = true
        do {
            try await action()
            message = "操作完成。已刷新各版本数据，可在「设置 - 操作记录」中回滚。"
        } catch {
            message = error.localizedDescription
        }
        await refresh()
    }
}
