import SwiftUI

struct AdoptionSheet: View {
    @ObservedObject var vm: AgentManagerViewModel
    let requestedName: String?
    let candidates: [AdoptionCandidate]
    @Environment(\.dismiss) private var dismiss
    @State private var selected: [String: String] = [:]
    @State private var result: AdoptionResult?

    private var names: [String] { Array(Set(candidates.map(\.name))).sorted() }
    private var selection: [AdoptionCandidate] {
        names.compactMap { name in candidates.first { $0.name == name && $0.id == selected[name] } }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(requestedName == nil ? "从本机归档到中央库" : "选择入库来源")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    Text("同名能力可能来自不同客户端。确认来源后，才会复制到中央库；原配置保持原位。")
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

            HStack(spacing: 8) {
                Text("待入库 \(names.count) 项")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ManagerTheme.secondaryText)
                Text("·")
                    .foregroundStyle(ManagerTheme.secondaryText)
                Text("已选择 \(selection.count) 项")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(selection.isEmpty ? ManagerTheme.secondaryText : ManagerTheme.indigo)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(names, id: \.self) { name in
                        let variants = candidates.filter { $0.name == name }
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(name).font(.system(size: 14, weight: .bold))
                                if variants.count > 1 {
                                    Text(Set(variants.map(\.contentFingerprint)).count > 1
                                         ? "\(variants.count) 个来源 · 内容不同" : "\(variants.count) 个来源 · 内容相同")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(ManagerTheme.stopOrange)
                                }
                                if result?.imported.contains(name) == true {
                                    Text("已入库").font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(ManagerTheme.enableGreen)
                                }
                                Spacer()
                                if selected[name] != nil {
                                    skipButton(for: name)
                                }
                            }
                            ForEach(variants) { variant in
                                Button {
                                    selected[name] = variant.id
                                } label: {
                                    HStack(alignment: .top, spacing: 9) {
                                        Image(systemName: selected[name] == variant.id ? "largecircle.fill.circle" : "circle")
                                            .foregroundStyle(ManagerTheme.electricBlue)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(variant.source).font(.system(size: 12, weight: .semibold))
                                            Text(variant.path).font(.system(size: 10, design: .monospaced))
                                                .foregroundStyle(ManagerTheme.secondaryText)
                                                .textSelection(.enabled)
                                            Text(variant.summary).font(.system(size: 11))
                                                .foregroundStyle(ManagerTheme.secondaryText)
                                                .lineLimit(2)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(10)
                                    .background(selected[name] == variant.id ? ManagerTheme.activePillBg : ManagerTheme.insetBg,
                                                in: RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .disabled(result?.imported.contains(name) == true)
                                .accessibilityLabel("\(name)，\(variant.source)，\(variant.path)")
                            }
                        }
                        .padding(12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 11))
                    }
                }
            }
            .frame(maxHeight: 430)

            if let result {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已入库 \(result.imported.count) 项，失败 \(result.failed.count) 项")
                        .font(.system(size: 12, weight: .bold))
                    ForEach(result.failed, id: \.self) { failure in
                        Text(failure).font(.system(size: 11)).foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
            }

            HStack {
                if names.count > 1 && selected.count < names.count {
                    Text("未选择的能力将跳过。")
                        .font(.system(size: 11.5))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }
                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ManagerTheme.secondaryText)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(ManagerTheme.insetBg, in: Capsule())
                .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                .keyboardShortcut(.cancelAction)

                Button {
                    result = vm.adoptCandidates(selection)
                    for candidate in selection where result?.imported.contains(candidate.name) == true {
                        selected[candidate.name] = nil
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 12))
                        Text("归档选中的 \(selection.count) 项")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .frame(height: 38)
                    .background(selection.isEmpty ? Color.gray.opacity(0.35) : ManagerTheme.indigo, in: Capsule())
                    .shadow(color: selection.isEmpty ? Color.clear : ManagerTheme.indigo.opacity(0.35), radius: 8, y: 3)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(selection.isEmpty)
            }
        }
        .padding(22)
        .frame(width: 690, height: 650)
        .background(ManagerTheme.canvasBg)
        .onAppear {
            for name in names {
                let variants = candidates.filter { $0.name == name }
                if variants.count == 1 { selected[name] = variants[0].id }
            }
        }
    }

    private func skipButton(for name: String) -> some View {
        Button {
            selected[name] = nil
        } label: {
            Text("跳过")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ManagerTheme.secondaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 3.5)
                .background(ManagerTheme.insetBg, in: Capsule())
                .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
