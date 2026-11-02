import SwiftUI

struct CapabilityTypeBadge: View {
    let label: String

    private var color: Color {
        switch label {
        case "系统服务": return ManagerTheme.secondaryText
        case "用户 MCP", "用户 Skill": return ManagerTheme.amber
        case "中央库 MCP", "中央库 Skill": return ManagerTheme.indigo
        default: return ManagerTheme.electricBlue
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct CapabilityOriginSummary: View {
    let item: DisplayItem

    var body: some View {
        HStack(spacing: 5) {
            if item.managedTargetCount > 0 {
                originPill(
                    label: originLabel("本应用分发", count: item.managedTargetCount),
                    color: ManagerTheme.enableGreen
                )
            }

            if item.externalTargetCount > 0 {
                originPill(
                    label: originLabel("客户端已有", count: item.externalTargetCount),
                    color: ManagerTheme.amber
                )
            }

            if item.systemTargetCount > 0 {
                originPill(
                    label: originLabel("系统服务", count: item.systemTargetCount),
                    color: ManagerTheme.secondaryText
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func originLabel(_ title: String, count: Int) -> String {
        count == 1 ? title : "\(title) · \(count)"
    }

    private func originPill(label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(color.opacity(0.11), in: Capsule())
    }
}

struct CapabilityOriginLine: View {
    let item: DisplayItem

    var body: some View {
        HStack(spacing: 5) {
            if item.managedTargetCount > 0 {
                segment("本应用", count: item.managedTargetCount, color: ManagerTheme.enableGreen)
            }
            if item.externalTargetCount > 0 {
                segment("客户端", count: item.externalTargetCount, color: ManagerTheme.amber)
            }
            if item.systemTargetCount > 0 {
                segment("系统", count: item.systemTargetCount, color: ManagerTheme.secondaryText)
            }
        }
        .font(.system(size: 9, weight: .semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private func segment(_ title: String, count: Int, color: Color) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 4, height: 4)
            Text(count == 1 ? title : "\(title) \(count)")
                .foregroundStyle(color)
        }
    }
}
