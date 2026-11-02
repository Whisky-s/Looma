import SwiftUI

struct TargetActionButton: View {
    let action: String
    let onTap: () -> Void

    private var isStop: Bool { action == "remove" || action == "disable" }

    private var title: String {
        switch action {
        case "add", "enableClientSkill", "enableClientMCP": "启用"
        case "reconcile": "清理记录"
        case "restore": "恢复"
        default: "停用"
        }
    }

    private var accent: Color {
        switch action {
        case "add", "enableClientSkill", "enableClientMCP", "reconcile": ManagerTheme.enableGreen
        case "restore": ManagerTheme.electricBlue
        default: ManagerTheme.stopOrange
        }
    }

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isStop ? accent : Color.white)
                .padding(.horizontal, 12)
                .frame(minWidth: 50)
                .frame(height: 28)
                .background(isStop ? ManagerTheme.amber.opacity(0.14) : accent, in: Capsule())
                .overlay(Capsule().stroke(isStop ? ManagerTheme.amber.opacity(0.55) : Color.clear, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(title)
    }
}

struct TargetDeleteButton: View {
    let onTap: () -> Void
    @State private var showConfirmation = false

    var body: some View {
        Button { showConfirmation = true } label: {
            Image(systemName: "trash")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.red)
                .frame(width: 28, height: 28)
                .background(Color.red.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(Color.red.opacity(0.22), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
        .help("删除用户配置")
        .confirmationDialog("删除用户配置？", isPresented: $showConfirmation, titleVisibility: .visible) {
            Button("删除", role: .destructive, action: onTap)
            Button("取消", role: .cancel) { }
        } message: {
            Text("该配置会从客户端配置中移除，之后可在操作记录中回滚。")
        }
    }
}
