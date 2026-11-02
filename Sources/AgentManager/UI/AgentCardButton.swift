import AppKit
import Foundation
import SwiftUI

struct AgentCardButton: View {
    let row: DisplayTarget
    let item: DisplayItem
    @ObservedObject var vm: AgentManagerViewModel
    var isSelectedAgent: Bool = false
    var size: CGFloat = 28

    @State private var isHovered = false

    private var isManaged: Bool { row.managed && row.isEnabled }
    private var isExternal: Bool { row.status == "已有配置" }
    private var isDisabled: Bool { row.status == "已停用" || row.status == "客户端已停用" }
    private var isEnabled: Bool { isManaged || isExternal }
    private var isAvailable: Bool { row.status != "未安装" }
    private var canPerformAction: Bool { row.action != nil }

    var body: some View {
        Button {
            if let action = row.action {
                vm.performAction(item: item, row: row, mode: action)
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                // Background & border box
                RoundedRectangle(cornerRadius: size > 24 ? 7 : 5)
                    .fill(backgroundColor)
                    .frame(width: size, height: size)
                    .overlay(
                        RoundedRectangle(cornerRadius: size > 24 ? 7 : 5)
                            .stroke(borderColor, lineWidth: isSelectedAgent ? 1.6 : isEnabled ? 1.2 : 0.8)
                    )

                // App Icon
                AgentLogo(agent: row.target.agent, size: size > 24 ? 16 : 13)
                    .frame(width: size, height: size)
                    .opacity(logoOpacity)
                    .scaleEffect(isHovered && canPerformAction ? 1.08 : 1.0)

                // Corner indicator dot
                if isEnabled {
                    Circle()
                        .fill(isManaged ? ManagerTheme.mint : ManagerTheme.amber)
                        .frame(width: size > 24 ? 6.5 : 5, height: size > 24 ? 6.5 : 5)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.2))
                        .offset(x: 1.5, y: 1.5)
                        .shadow(color: Color.black.opacity(0.12), radius: 1, y: 0.5)
                } else if isDisabled {
                    Circle()
                        .fill(Color.red.opacity(0.85))
                        .frame(width: size > 24 ? 6 : 4.5, height: size > 24 ? 6 : 4.5)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .offset(x: 1.5, y: 1.5)
                } else if isHovered && canPerformAction {
                    // Light blue hint dot on hover when available to deploy
                    Circle()
                        .fill(ManagerTheme.electricBlue)
                        .frame(width: size > 24 ? 6 : 4.5, height: size > 24 ? 6 : 4.5)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1))
                        .offset(x: 1.5, y: 1.5)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canPerformAction)
        .onHover { isHovered = $0 }
        .help(tooltipText)
        .accessibilityLabel("\(row.target.agent.rawValue)，\(row.target.project == nil ? "全局" : "项目")，\(row.status)，\(tooltipText)")
        .animation(.easeInOut(duration: 0.14), value: isHovered)
    }

    private var backgroundColor: Color {
        if isSelectedAgent {
            return ManagerTheme.electricBlue.opacity(0.12)
        }
        if isEnabled {
            return isManaged ? ManagerTheme.mint.opacity(0.09) : ManagerTheme.amber.opacity(0.09)
        }
        if isDisabled {
            return Color.red.opacity(0.06)
        }
        if isHovered && canPerformAction {
            return ManagerTheme.electricBlue.opacity(0.08)
        }
        return ManagerTheme.insetBg
    }

    private var borderColor: Color {
        if isSelectedAgent {
            return ManagerTheme.electricBlue
        }
        if isEnabled {
            return isManaged ? ManagerTheme.mint.opacity(0.65) : ManagerTheme.amber.opacity(0.65)
        }
        if isDisabled {
            return Color.red.opacity(0.28)
        }
        if isHovered && canPerformAction {
            return ManagerTheme.electricBlue.opacity(0.45)
        }
        return ManagerTheme.borderLine.opacity(0.7)
    }

    private var logoOpacity: Double {
        if !isAvailable { return 0.25 }
        if isEnabled || isSelectedAgent { return 1.0 }
        if isHovered && canPerformAction { return 0.95 }
        return 0.42
    }

    private var tooltipText: String {
        let name = row.target.agent.rawValue
        if row.status == "状态未知" { return "\(name): 配置无法读取，暂不允许操作" }
        if row.status == "目标已移除" { return "\(name): 客户端目标已移除 (点击清理记录)" }
        if isManaged {
            return "\(name): 配置已启用 · 本应用分发 (点击停用)"
        } else if isExternal {
            return "\(name): 客户端已有配置 (点击停用)"
        } else if isDisabled {
            return "\(name): 已停用 (点击恢复配置)"
        } else if row.status == "未安装" {
            return "\(name): 未检测到该客户端"
        } else if item.library {
            return "\(name): 未启用 (点击一键部署)"
        } else {
            return "\(name): 待入库 (请先归档到中央库)"
        }
    }
}
