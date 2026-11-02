import AppKit
import Foundation
import SwiftUI

struct MCPPreset: Identifiable {
    let id: String
    let name: String
    let title: String
    let description: String
    let isRemote: Bool
    let command: String
    let args: [String]
    let env: [String: String]
    let url: String?
    let headers: [String: String]?

    init(
        id: String,
        name: String,
        title: String,
        description: String,
        isRemote: Bool = false,
        command: String = "npx",
        args: [String] = [],
        env: [String: String] = [:],
        url: String? = nil,
        headers: [String: String]? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.description = description
        self.isRemote = isRemote
        self.command = command
        self.args = args
        self.env = env
        self.url = url
        self.headers = headers
    }

    static let standardPresets: [MCPPreset] = [
        MCPPreset(
            id: "github",
            name: "github",
            title: "GitHub",
            description: "管理仓库、文件、PR、Issue 和代码搜索",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-github"],
            env: ["GITHUB_PERSONAL_ACCESS_TOKEN": "ghp_your_token_here"]
        ),
        MCPPreset(
            id: "postgres",
            name: "postgres",
            title: "PostgreSQL",
            description: "只读或读写连接 PostgreSQL 数据库并执行查询",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-postgres", "postgresql://localhost/mydb"],
            env: [:]
        ),
        MCPPreset(
            id: "sqlite",
            name: "sqlite",
            title: "SQLite",
            description: "读取与查询本地 SQLite 数据库文件",
            command: "uvx",
            args: ["mcp-server-sqlite", "--db-path", "~/database.db"],
            env: [:]
        ),
        MCPPreset(
            id: "filesystem",
            name: "filesystem",
            title: "Filesystem",
            description: "限制访问本地特定目录的文件系统 MCP",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-filesystem", "/Users/whisky/Desktop"],
            env: [:]
        ),
        MCPPreset(
            id: "remote-sse",
            name: "remote-sse-service",
            title: "Remote SSE Server",
            description: "通过 Server-Sent Events (SSE) 协议连接远程独立运行的 MCP 服务",
            isRemote: true,
            url: "http://localhost:8000/sse"
        ),
        MCPPreset(
            id: "cloud-mcp",
            name: "cloud-mcp-gateway",
            title: "Cloud MCP Gateway",
            description: "连接云端或内网统一网关，支持 Bearer Token 或 API Key 认证",
            isRemote: true,
            url: "https://mcp.company.internal/sse",
            headers: ["Authorization": "Bearer your_token_here"]
        ),
        MCPPreset(
            id: "brave",
            name: "brave-search",
            title: "Brave Search",
            description: "通过 Brave API 进行实时网络和本地搜索",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-brave-search"],
            env: ["BRAVE_API_KEY": "BSA_your_key_here"]
        ),
        MCPPreset(
            id: "fetch",
            name: "fetch",
            title: "Web Fetch",
            description: "抓取网页并转换为 Clean Markdown 文本",
            command: "uvx",
            args: ["mcp-server-fetch"],
            env: [:]
        ),
        MCPPreset(
            id: "memory",
            name: "memory",
            title: "Memory Graph",
            description: "构建持久化的知识图谱与长期记忆",
            command: "npx",
            args: ["-y", "@modelcontextprotocol/server-memory"],
            env: [:]
        )
    ]
}

struct MCPEditorSheet: View {
    @ObservedObject var vm: AgentManagerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode: Int = 0 // 0: Form, 1: JSON, 2: Presets
    @State private var name: String = ""
    @State private var transportType: Int = 0 // 0: Stdio (本地命令行), 1: SSE / Remote (远程服务)

    // Stdio Fields
    @State private var command: String = "npx"
    @State private var args: [String] = ["-y"]
    @State private var newArg: String = ""
    @State private var envPairs: [(key: String, value: String, masked: Bool)] = []
    @State private var newEnvKey: String = ""
    @State private var newEnvValue: String = ""

    // Remote / SSE Fields
    @State private var remoteTransport = "http"
    @State private var serverUrl: String = "http://localhost:8000/sse"
    @State private var headerPairs: [(key: String, value: String, masked: Bool)] = []
    @State private var newHeaderKey: String = ""
    @State private var newHeaderValue: String = ""

    @State private var rawJSON: String = ""
    @State private var jsonError: String? = nil
    private let isEditing: Bool

    init(vm: AgentManagerViewModel, initialMCP: MCPItem? = nil) {
        self.vm = vm
        self.isEditing = initialMCP != nil
        if let initial = initialMCP {
            _name = State(initialValue: initial.name)
            let isRemote = initial.definition["url"] != nil || initial.definition["serverUrl"] != nil
            _transportType = State(initialValue: isRemote ? 1 : 0)
            _remoteTransport = State(initialValue: (initial.definition["type"] as? String) ?? "http")
            if isRemote {
                let u = (initial.definition["url"] as? String) ?? (initial.definition["serverUrl"] as? String) ?? ""
                _serverUrl = State(initialValue: u)
                if let hdrs = (initial.definition["headers"] as? [String: String]) ?? (initial.definition["http_headers"] as? [String: String]) {
                    _headerPairs = State(initialValue: hdrs.map { ($0.key, $0.value, $0.key.lowercased().contains("token") || $0.key.lowercased().contains("auth") || $0.key.lowercased().contains("key")) })
                }
            } else {
                let cmd = (initial.definition["command"] as? String) ?? "npx"
                _command = State(initialValue: cmd)
                let rawArgs = (initial.definition["args"] as? [String]) ?? []
                _args = State(initialValue: rawArgs)
                if let env = initial.definition["env"] as? [String: String] {
                    _envPairs = State(initialValue: env.map { ($0.key, $0.value, true) })
                }
            }
            if let data = try? JSONSerialization.data(withJSONObject: initial.definition, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
               let str = String(data: data, encoding: .utf8) {
                _rawJSON = State(initialValue: str)
            }
        } else {
            _rawJSON = State(initialValue: """
            {
              "command": "npx",
              "args": ["-y", "@modelcontextprotocol/server-example"],
              "env": {}
            }
            """)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "编辑 MCP Server 模板" : "新建 MCP Server 模板")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    Text("支持本地命令行（stdio）与远程流式（SSE / HTTP）服务模板")
                        .font(.system(size: 12))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }
                Spacer()

                // Mode Picker
                HStack(spacing: 4) {
                    tabPill("预设中心", value: 2)
                    tabPill("可视化表单", value: 0)
                    tabPill("Raw JSON", value: 1)
                }
                .padding(3)
                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 1))

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
                .padding(.leading, 6)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            // Content Area
            Group {
                if mode == 2 {
                    presetsView
                } else if mode == 0 {
                    formView
                } else {
                    jsonEditorView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(ManagerTheme.borderLine)
                .frame(height: 1)

            HStack {
                if let err = jsonError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                    Text(err)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.red)
                }
                Spacer()

                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(ManagerTheme.secondaryText)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .background(ManagerTheme.insetBg, in: Capsule())
                .overlay(Capsule().stroke(ManagerTheme.borderLine, lineWidth: 0.8))
                .keyboardShortcut(.cancelAction)

                Button {
                    save()
                } label: {
                    Text("保存到中央库")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .frame(height: 38)
                        .background(ManagerTheme.electricBlue, in: Capsule())
                        .shadow(color: ManagerTheme.electricBlue.opacity(0.35), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(mode == 1 ? (jsonError != nil || rawJSON.trimmingCharacters(in: .whitespaces).isEmpty) : name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 16)
        }
        .frame(minWidth: 700, minHeight: 540)
        .background(Color.white)
        .toastNotification(vm: vm)
    }

    private func tabPill(_ title: String, value: Int) -> some View {
        Button {
            mode = value
        } label: {
            Text(title)
                .font(.system(size: 12, weight: mode == value ? .bold : .medium))
                .foregroundStyle(mode == value ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                .padding(.horizontal, 14)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(mode == value ? Color.white : Color.white.opacity(0.001))
                        .shadow(color: mode == value ? Color.black.opacity(0.06) : Color.clear, radius: 3, y: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Presets View
    private var presetsView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 16)], spacing: 16) {
                ForEach(MCPPreset.standardPresets) { preset in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(preset.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(ManagerTheme.primaryText)
                            Spacer()
                            if preset.isRemote {
                                HStack(spacing: 4) {
                                    Image(systemName: "network")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("SSE 远程")
                                        .font(.system(size: 10.5, weight: .bold))
                                }
                                .foregroundStyle(ManagerTheme.indigo)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(ManagerTheme.indigo.opacity(0.12), in: Capsule())
                            } else {
                                Text(preset.command)
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(ManagerTheme.electricBlue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(ManagerTheme.electricBlue.opacity(0.12), in: Capsule())
                            }
                        }
                        Text(preset.description)
                            .font(.system(size: 12))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .lineLimit(2)
                            .frame(height: 34, alignment: .topLeading)

                        Rectangle()
                            .fill(ManagerTheme.borderLine)
                            .frame(height: 1)

                        HStack {
                            Text(preset.name)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(ManagerTheme.secondaryText)
                            Spacer()
                            Button("套用预设") {
                                applyPreset(preset)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(ManagerTheme.electricBlue)
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                            .background(ManagerTheme.activePillBg, in: Capsule())
                        }
                    }
                    .padding(16)
                    .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(ManagerTheme.borderLine, lineWidth: 1))
                }
            }
            .padding(24)
        }
    }

    private func applyPreset(_ p: MCPPreset) {
        self.name = p.name
        if p.isRemote {
            self.transportType = 1
            self.remoteTransport = p.id == "remote-sse" ? "sse" : "http"
            self.serverUrl = p.url ?? ""
            self.headerPairs = (p.headers ?? [:]).map { ($0.key, $0.value, false) }
        } else {
            self.transportType = 0
            self.command = p.command
            self.args = p.args
            self.envPairs = p.env.map { ($0.key, $0.value, true) }
        }
        syncFormToJSON()
        self.mode = 0
    }

    // MARK: - Form View
    private var formView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Name
                VStack(alignment: .leading, spacing: 7) {
                    Text("Server 名称")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    TextField("", text: $name, prompt: Text("例如 github, postgresql, remote-gateway").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 1))
                        .onChange(of: name) { syncFormToJSON() }
                    Text("支持中英文、数字、空格及连字符，不可包含路径分隔符 /")
                        .font(.system(size: 11))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }

                // Transport Type Selector
                VStack(alignment: .leading, spacing: 8) {
                    Text("协议与运行模式 (Transport Type)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)

                    HStack(spacing: 12) {
                        transportTypeCard(
                            title: "本地命令行 (stdio)",
                            subtitle: "本地独立子进程 · command / args / env",
                            icon: "terminal.fill",
                            selected: transportType == 0
                        ) {
                            transportType = 0
                            syncFormToJSON()
                        }

                        transportTypeCard(
                            title: "远程服务 (SSE / HTTP)",
                            subtitle: "网络长连接 · url / serverUrl / headers 鉴权",
                            icon: "network",
                            selected: transportType == 1
                        ) {
                            transportType = 1
                            syncFormToJSON()
                        }
                    }
                }

                if transportType == 0 {
                    stdioFormSection
                } else {
                    remoteFormSection
                }
            }
            .padding(26)
        }
    }

    private func transportTypeCard(title: String, subtitle: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(selected ? ManagerTheme.electricBlue : ManagerTheme.borderLine.opacity(0.4))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(selected ? .white : ManagerTheme.secondaryText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: selected ? .bold : .medium))
                        .foregroundStyle(selected ? ManagerTheme.primaryText : ManagerTheme.secondaryText)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(ManagerTheme.secondaryText.opacity(0.85))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(selected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText.opacity(0.4))
            }
            .padding(12)
            .background(selected ? ManagerTheme.activePillBg.opacity(0.6) : ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? ManagerTheme.electricBlue : ManagerTheme.borderLine, lineWidth: selected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Stdio Form Section
    private var stdioFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Command
            VStack(alignment: .leading, spacing: 7) {
                Text("可执行命令 (Command)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ManagerTheme.primaryText)
                HStack(spacing: 8) {
                    TextField("", text: $command, prompt: Text("例如 npx, uvx, node").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .padding(10)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 1))
                        .onChange(of: command) { syncFormToJSON() }

                    ForEach(["npx", "uvx", "node", "python3"], id: \.self) { cmd in
                        Button(cmd) {
                            command = cmd
                            syncFormToJSON()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                    }
                }
            }

            // Arguments
            VStack(alignment: .leading, spacing: 7) {
                Text("参数列表 (Arguments)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ManagerTheme.primaryText)

                ForEach(args.indices, id: \.self) { idx in
                    HStack {
                        Text("\(idx + 1).")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(ManagerTheme.secondaryText)
                            .frame(width: 24, alignment: .leading)

                        TextField("", text: $args[idx])
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                            .onChange(of: args[idx]) { syncFormToJSON() }

                        Button {
                            args.remove(at: idx)
                            syncFormToJSON()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Color.red.opacity(0.8))
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("", text: $newArg, prompt: Text("新增参数...").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                        .onSubmit { addArg() }

                    Button("添加") {
                        addArg()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(ManagerTheme.electricBlue, in: Capsule())
                    .disabled(newArg.isEmpty)
                }
            }

            // Environment Variables
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("环境变量 (Environment Variables)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    Spacer()
                    Text("仅安全保存于本机配置中")
                        .font(.system(size: 11))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }

                ForEach(envPairs.indices, id: \.self) { idx in
                    HStack {
                        TextField("", text: $envPairs[idx].key, prompt: Text("KEY").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .frame(width: 180)
                            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                            .onChange(of: envPairs[idx].key) { syncFormToJSON() }

                        Text("=").font(.system(size: 12)).foregroundStyle(ManagerTheme.secondaryText)

                        if envPairs[idx].masked {
                            SecureField("", text: $envPairs[idx].value, prompt: Text("VALUE").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                                .onChange(of: envPairs[idx].value) { syncFormToJSON() }
                        } else {
                            TextField("", text: $envPairs[idx].value, prompt: Text("VALUE").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                                .onChange(of: envPairs[idx].value) { syncFormToJSON() }
                        }

                        Button {
                            envPairs[idx].masked.toggle()
                        } label: {
                            Image(systemName: envPairs[idx].masked ? "eye.slash" : "eye")
                                .foregroundStyle(ManagerTheme.secondaryText)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)

                        Button {
                            envPairs.remove(at: idx)
                            syncFormToJSON()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Color.red.opacity(0.8))
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("", text: $newEnvKey, prompt: Text("KEY (如 API_KEY)").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .frame(width: 180)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))

                    TextField("", text: $newEnvValue, prompt: Text("VALUE").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                        .onSubmit { addEnv() }

                    Button("添加变量") {
                        addEnv()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(ManagerTheme.electricBlue, in: Capsule())
                    .disabled(newEnvKey.isEmpty)
                }
            }
        }
    }

    // MARK: - Remote Form Section
    private var remoteFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("传输协议 (Protocol)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(ManagerTheme.primaryText)
                Spacer()
                HStack(spacing: 3) {
                    ForEach(["http", "sse", "ws"], id: \.self) { proto in
                        let isSelected = remoteTransport == proto
                        Button {
                            remoteTransport = proto
                            syncFormToJSON()
                        } label: {
                            Text(proto.uppercased())
                                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(isSelected ? ManagerTheme.electricBlue : ManagerTheme.secondaryText)
                                .padding(.horizontal, 12)
                                .frame(height: 26)
                                .background(isSelected ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                                .shadow(color: isSelected ? Color.black.opacity(0.06) : Color.clear, radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 0.8))
            }
            // Service URL
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("远程服务地址 (Service URL)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    Spacer()
                    Text("支持标准 SSE / HTTP 流式传输")
                        .font(.system(size: 11))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }

                TextField("", text: $serverUrl, prompt: Text("例如 http://localhost:8000/sse 或 https://api.mcp.run/sse").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(ManagerTheme.borderLine, lineWidth: 1))
                    .onChange(of: serverUrl) { syncFormToJSON() }

                HStack(spacing: 10) {
                    Text("快捷填充:")
                        .font(.system(size: 11))
                        .foregroundStyle(ManagerTheme.secondaryText)

                    Button("http://localhost:8000/sse") {
                        serverUrl = "http://localhost:8000/sse"
                        syncFormToJSON()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ManagerTheme.electricBlue)

                    Button("https://") {
                        if !serverUrl.hasPrefix("https://") {
                            serverUrl = "https://"
                        }
                        syncFormToJSON()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ManagerTheme.electricBlue)
                }
            }

            // Headers
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("自定义请求头 (Headers)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ManagerTheme.primaryText)
                    Spacer()
                    Text("用于 Bearer Token 或 API Key 认证")
                        .font(.system(size: 11))
                        .foregroundStyle(ManagerTheme.secondaryText)
                }

                ForEach(headerPairs.indices, id: \.self) { idx in
                    HStack {
                        TextField("", text: $headerPairs[idx].key, prompt: Text("Header 名称 (如 Authorization)").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .padding(8)
                            .frame(width: 200)
                            .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                            .onChange(of: headerPairs[idx].key) { syncFormToJSON() }

                        Text(":").font(.system(size: 12, weight: .bold)).foregroundStyle(ManagerTheme.secondaryText)

                        if headerPairs[idx].masked {
                            SecureField("", text: $headerPairs[idx].value, prompt: Text("Header 值 (如 Bearer token)").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                                .onChange(of: headerPairs[idx].value) { syncFormToJSON() }
                        } else {
                            TextField("", text: $headerPairs[idx].value, prompt: Text("Header 值 (如 Bearer token)").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .padding(8)
                                .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                                .onChange(of: headerPairs[idx].value) { syncFormToJSON() }
                        }

                        Button {
                            headerPairs[idx].masked.toggle()
                        } label: {
                            Image(systemName: headerPairs[idx].masked ? "eye.slash" : "eye")
                                .foregroundStyle(ManagerTheme.secondaryText)
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)

                        Button {
                            headerPairs.remove(at: idx)
                            syncFormToJSON()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Color.red.opacity(0.8))
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("", text: $newHeaderKey, prompt: Text("Header 名称 (如 Authorization)").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .frame(width: 200)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))

                    TextField("", text: $newHeaderValue, prompt: Text("Header 值 (如 Bearer token)").foregroundColor(ManagerTheme.secondaryText.opacity(0.8)))
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(8)
                        .background(ManagerTheme.insetBg, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(ManagerTheme.borderLine, lineWidth: 1))
                        .onSubmit { addHeader() }

                    Button("添加 Header") {
                        addHeader()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(ManagerTheme.electricBlue, in: Capsule())
                    .disabled(newHeaderKey.isEmpty)
                }

                HStack(spacing: 8) {
                    Text("快速添加:")
                        .font(.system(size: 11))
                        .foregroundStyle(ManagerTheme.secondaryText)

                    Button("+ Authorization (Bearer)") {
                        headerPairs.append(("Authorization", "Bearer ", true))
                        syncFormToJSON()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(ManagerTheme.electricBlue)

                    Button("+ X-API-Key") {
                        headerPairs.append(("X-API-Key", "", true))
                        syncFormToJSON()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(ManagerTheme.electricBlue)
                }
            }
        }
    }

    private func addArg() {
        guard !newArg.isEmpty else { return }
        args.append(newArg)
        newArg = ""
        syncFormToJSON()
    }

    private func addEnv() {
        guard !newEnvKey.isEmpty else { return }
        envPairs.append((newEnvKey, newEnvValue, true))
        newEnvKey = ""
        newEnvValue = ""
        syncFormToJSON()
    }

    private func addHeader() {
        guard !newHeaderKey.isEmpty else { return }
        headerPairs.append((newHeaderKey, newHeaderValue, true))
        newHeaderKey = ""
        newHeaderValue = ""
        syncFormToJSON()
    }

    // MARK: - JSON Editor View
    private var jsonEditorView: some View {
        VStack(spacing: 0) {
            TextEditor(text: $rawJSON)
                .font(.system(size: 12, design: .monospaced))
                .padding(14)
                .background(ManagerTheme.insetBg)
                .onChange(of: rawJSON) {
                    validateJSON(rawJSON)
                }
        }
    }

    private func syncFormToJSON() {
        var dict = (rawJSON.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }) ?? [:]
        if let servers = dict["mcpServers"] as? [String: Any], servers.count == 1, let definition = servers.values.first as? [String: Any] { dict = definition }
        let env = envPairs.reduce(into: [String: String]()) { if !$1.key.isEmpty { $0[$1.key] = $1.value } }
        let headers = headerPairs.reduce(into: [String: String]()) { if !$1.key.isEmpty { $0[$1.key] = $1.value } }
        dict = mcpFormDefinition(existing: dict, command: command, args: args, env: env, url: transportType == 0 ? nil : serverUrl, transport: remoteTransport, headers: headers)
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
           let str = String(data: data, encoding: .utf8) {
            rawJSON = str
            jsonError = nil
        }
    }

    private func validateJSON(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            jsonError = "无法以 UTF-8 解码"
            return
        }
        do {
            guard var obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                jsonError = "顶层必须为 JSON 对象 {}"
                return
            }

            if let servers = obj["mcpServers"] as? [String: Any], servers.count != 1 {
                jsonError = "请每次导入一个 MCP 服务，避免遗漏其他服务"
                return
            }
            // 智能解包：用户可能复制了整段包含 mcpServers 的完整配置或单服务包装
            if let servers = obj["mcpServers"] as? [String: Any], let firstKey = servers.keys.first, let firstVal = servers[firstKey] as? [String: Any] {
                if self.name.isEmpty { self.name = firstKey }
                obj = firstVal
            } else if obj.count == 1, let firstKey = obj.keys.first, firstKey != "command" && firstKey != "url" && firstKey != "serverUrl", let firstVal = obj[firstKey] as? [String: Any] {
                if self.name.isEmpty { self.name = firstKey }
                obj = firstVal
            }

            let hasCommand = obj["command"] != nil
            let hasUrl = obj["url"] != nil || obj["serverUrl"] != nil

            guard hasCommand || hasUrl else {
                jsonError = "缺少必要配置：请提供 command（本地命令）或 url（远程服务地址）"
                return
            }
            jsonError = nil

            if hasUrl {
                self.transportType = 1
                self.remoteTransport = (obj["type"] as? String) ?? "http"
                if let u = (obj["url"] as? String) ?? (obj["serverUrl"] as? String) {
                    self.serverUrl = u
                }
                if let hdrs = (obj["headers"] as? [String: String]) ?? (obj["http_headers"] as? [String: String]) {
                    self.headerPairs = hdrs.map { ($0.key, $0.value, $0.key.lowercased().contains("token") || $0.key.lowercased().contains("auth") || $0.key.lowercased().contains("key")) }
                }
            } else {
                self.transportType = 0
                if let cmd = obj["command"] as? String { self.command = cmd }
                if let arr = obj["args"] as? [String] { self.args = arr }
                if let env = obj["env"] as? [String: String] {
                    self.envPairs = env.map { ($0.key, $0.value, true) }
                }
            }
        } catch {
            jsonError = "JSON 格式错误: \(error.localizedDescription)"
        }
    }

    // MARK: - Save
    private func save() {
        if mode == 0 {
            syncFormToJSON()
        }

        guard let data = rawJSON.data(using: .utf8),
              var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            jsonError = "无法解析保存的内容，请检查 JSON 格式"
            return
        }

        if let servers = dict["mcpServers"] as? [String: Any], servers.count != 1 {
            jsonError = "请每次导入一个 MCP 服务"
            return
        }
        var effectiveName = name.trimmingCharacters(in: .whitespaces)

        // 智能解包
        if let servers = dict["mcpServers"] as? [String: Any], let firstKey = servers.keys.first, let firstVal = servers[firstKey] as? [String: Any] {
            dict = firstVal
            if effectiveName.isEmpty || mode == 1 {
                effectiveName = firstKey
                self.name = firstKey
            }
        } else if dict.count == 1, let firstKey = dict.keys.first, firstKey != "command" && firstKey != "url" && firstKey != "serverUrl" && firstKey != "type", let firstVal = dict[firstKey] as? [String: Any] {
            dict = firstVal
            if effectiveName.isEmpty || mode == 1 {
                effectiveName = firstKey
                self.name = firstKey
            }
        }

        guard !effectiveName.isEmpty else {
            jsonError = "请输入 MCP Server 名称，或在 JSON 中指定服务名"
            return
        }

        guard dict["command"] is String || dict["url"] is String || dict["serverUrl"] is String else {
            jsonError = "缺少必要配置：请提供 command（本地命令）或 url（远程服务）"
            return
        }

        do {
            try ManagerStore.shared.importMCP(name: effectiveName, definition: dict)
            vm.showToast(title: "MCP 模板已创建", detail: effectiveName)
            Task { await vm.reloadAll() }
            dismiss()
        } catch {
            jsonError = error.localizedDescription
        }
    }
}
