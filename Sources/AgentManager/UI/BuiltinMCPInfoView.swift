import AppKit
import SwiftUI

struct BuiltinMCPInfoView: View {
    let item: DisplayItem
    let rows: [DisplayTarget]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("客户端内置能力")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(ManagerTheme.secondaryText)
            field("所属客户端", item.rawMCP?.bundledOwner?.rawValue ?? "未识别的应用")
            field("配置状态", rows.first?.status ?? "已发现")
            if let source = item.rawMCP?.source {
                field("配置文件", source.path)
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([source])
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 11, weight: .semibold))
                        Text("在访达中查看配置")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(ManagerTheme.electricBlue)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(ManagerTheme.activePillBg, in: Capsule())
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Text("由所属客户端提供，只读展示，不进入中央库，不参与预设或跨应用分发。")
                .font(.system(size: 12))
                .foregroundStyle(ManagerTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func field(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(ManagerTheme.secondaryText)
            Text(value).font(.system(size: 13)).foregroundStyle(ManagerTheme.primaryText)
                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}
