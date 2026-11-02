import AppKit
import Foundation
import SwiftUI

struct ProjectListView: View {
    @ObservedObject var vm: AgentManagerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                ForEach(vm.projects, id: \.self) { p in
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ManagerTheme.electricBlue.opacity(0.12))
                                .frame(width: 48, height: 48)

                            Image(systemName: "folder.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(ManagerTheme.electricBlue)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(URL(fileURLWithPath: p).lastPathComponent)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(ManagerTheme.primaryText)
                            Text(p)
                                .font(.system(size: 12))
                                .foregroundStyle(ManagerTheme.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            vm.selectedProject = p
                            vm.page = 0
                        } label: {
                            Text("查看该项目能力")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(ManagerTheme.electricBlue)
                                .padding(.horizontal, 16)
                                .frame(height: 34)
                                .background(ManagerTheme.activePillBg, in: Capsule())
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            vm.removeProject(path: p)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 13))
                                .foregroundStyle(ManagerTheme.secondaryText)
                                .padding(7)
                                .background(Color.black.opacity(0.04), in: Circle())
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .help("从列表移除")
                    }
                    .padding(16)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(ManagerTheme.borderLine, lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 2)
                }

                if vm.projects.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 44))
                            .foregroundStyle(ManagerTheme.electricBlue)

                        Text("尚未添加任何项目目录")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(ManagerTheme.primaryText)

                        Text("添加本地代码目录后，可针对该项目配置局部生效的专属 Skill 与 MCP")
                            .font(.system(size: 13))
                            .foregroundStyle(ManagerTheme.secondaryText)

                        Button {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            if panel.runModal() == .OK, let url = panel.url {
                                vm.addProject(url: url)
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .bold))
                                Text("添加项目目录")
                                    .font(.system(size: 13, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .frame(height: 38)
                            .background(ManagerTheme.electricBlue, in: Capsule())
                            .shadow(color: ManagerTheme.electricBlue.opacity(0.35), radius: 8, y: 3)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal, 28)
        }
    }
}
