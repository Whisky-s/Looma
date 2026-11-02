import { useState, useEffect } from "react";
import { invoke } from "@tauri-apps/api/core";
import {
  Boxes,
  Cpu,
  History,
  Terminal,
  Plus,
  Search,
  CheckCircle2,
  XCircle,
  Trash2,
  RefreshCw,
  FolderOpen
} from "lucide-react";

interface AgentStatus {
  agent: string;
  name: string;
  installed: boolean;
  global_skill_roots: string[];
  global_mcp_path: string;
}

interface SkillItem {
  id: string;
  name: string;
  description: string;
  path: string;
  source: string;
  agent?: string;
  project?: string;
  is_library: boolean;
}

interface McpItem {
  id: string;
  name: string;
  summary: string;
  definition: Record<string, any>;
  agent?: string;
  project?: string;
  source: string;
  is_library: boolean;
  is_system_service: boolean;
}

interface HistoryRecord {
  id: string;
  action: string;
  kind: string;
  target: string;
  timestamp: string;
  details?: string;
}

export default function App() {
  const [activeTab, setActiveTab] = useState<"skills" | "mcp" | "presets" | "agents" | "history">("skills");
  const [agents, setAgents] = useState<AgentStatus[]>([]);
  const [projects, setProjects] = useState<string[]>([]);
  const [librarySkills, setLibrarySkills] = useState<SkillItem[]>([]);
  const [installedSkills, setInstalledSkills] = useState<SkillItem[]>([]);
  const [libraryMcps, setLibraryMcps] = useState<McpItem[]>([]);
  const [installedMcps, setInstalledMcps] = useState<McpItem[]>([]);
  const [history, setHistory] = useState<HistoryRecord[]>([]);
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedAgentFilter, setSelectedAgentFilter] = useState<string | null>(null);

  // Dialogs
  const [showAddMcp, setShowAddMcp] = useState(false);
  const [newMcpName, setNewMcpName] = useState("");
  const [newMcpCommand, setNewMcpCommand] = useState("");
  const [newMcpArgs, setNewMcpArgs] = useState("");

  const [showAddProject, setShowAddProject] = useState(false);
  const [newProjectPath, setNewProjectPath] = useState("");

  const loadAll = async () => {
    try {
      const a = await invoke<AgentStatus[]>("get_agents");
      setAgents(a);
      const p = await invoke<string[]>("get_projects");
      setProjects(p);
      const ls = await invoke<SkillItem[]>("list_library_skills");
      setLibrarySkills(ls);
      const is = await invoke<SkillItem[]>("list_installed_skills");
      setInstalledSkills(is);
      const lm = await invoke<McpItem[]>("list_library_mcps");
      setLibraryMcps(lm);
      const im = await invoke<McpItem[]>("list_installed_mcps");
      setInstalledMcps(im);
      const h = await invoke<HistoryRecord[]>("get_history");
      setHistory(h);
    } catch (err) {
      console.warn("Backend invoke error (browser fallback?):", err);
    }
  };

  useEffect(() => {
    loadAll();
  }, []);

  const handleCreateMcp = async () => {
    if (!newMcpName.trim() || !newMcpCommand.trim()) return;
    try {
      const argsArray = newMcpArgs.trim() ? newMcpArgs.split(" ").map(s => s.trim()).filter(Boolean) : [];
      await invoke("save_mcp", {
        name: newMcpName.trim(),
        definition: {
          command: newMcpCommand.trim(),
          args: argsArray,
          env: {}
        }
      });
      setShowAddMcp(false);
      setNewMcpName("");
      setNewMcpCommand("");
      setNewMcpArgs("");
      await loadAll();
    } catch (e) {
      alert("创建失败: " + e);
    }
  };

  const handleDeleteMcp = async (name: string) => {
    if (!confirm(`确定要从中央库删除 MCP "${name}" 吗？`)) return;
    try {
      await invoke("delete_mcp", { name });
      await loadAll();
    } catch (e) {
      alert("删除失败: " + e);
    }
  };

  const handleAddProject = async () => {
    if (!newProjectPath.trim()) return;
    try {
      await invoke("add_project", { path: newProjectPath.trim() });
      setShowAddProject(false);
      setNewProjectPath("");
      await loadAll();
    } catch (e) {
      alert("添加项目失败: " + e);
    }
  };

  const allSkills = [...librarySkills, ...installedSkills];
  const filteredSkills = allSkills.filter(s => {
    const matchQuery = s.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                       s.description.toLowerCase().includes(searchQuery.toLowerCase());
    const matchAgent = selectedAgentFilter ? s.agent === selectedAgentFilter : true;
    return matchQuery && matchAgent;
  });

  const allMcps = [...libraryMcps, ...installedMcps];
  const filteredMcps = allMcps.filter(m => {
    const matchQuery = m.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
                       m.summary.toLowerCase().includes(searchQuery.toLowerCase());
    const matchAgent = selectedAgentFilter ? m.agent === selectedAgentFilter : true;
    return matchQuery && matchAgent;
  });

  return (
    <div className="flex h-screen w-screen bg-neutral-950 text-neutral-200 select-none overflow-hidden font-sans">
      {/* Sidebar */}
      <div className="w-64 border-r border-neutral-800 bg-neutral-900/60 flex flex-col justify-between shrink-0">
        <div>
          {/* Header */}
          <div className="px-5 py-4 border-b border-neutral-800/80 flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="w-8 h-8 rounded-lg bg-orange-500/20 text-orange-400 flex items-center justify-center font-bold text-lg border border-orange-500/30">
                🐱
              </div>
              <div>
                <div className="font-semibold text-neutral-100 text-sm tracking-wide">Looma</div>
                <div className="text-[10px] text-neutral-500">v0.1.0 · Windows Edition</div>
              </div>
            </div>
            <button
              onClick={loadAll}
              title="刷新配置"
              className="p-1.5 rounded-md hover:bg-neutral-800 text-neutral-400 hover:text-neutral-200 transition"
            >
              <RefreshCw className="w-4 h-4" />
            </button>
          </div>

          {/* Navigation Links */}
          <div className="p-3 space-y-1">
            <button
              onClick={() => { setActiveTab("skills"); setSelectedAgentFilter(null); }}
              className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                activeTab === "skills" && !selectedAgentFilter
                  ? "bg-neutral-800 text-white shadow-sm"
                  : "text-neutral-400 hover:text-neutral-200 hover:bg-neutral-800/50"
              }`}
            >
              <Boxes className="w-4 h-4 text-orange-400" />
              <span>中央库技能</span>
              <span className="ml-auto text-[10px] bg-neutral-800 px-1.5 py-0.5 rounded text-neutral-400">
                {librarySkills.length}
              </span>
            </button>

            <button
              onClick={() => { setActiveTab("mcp"); setSelectedAgentFilter(null); }}
              className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                activeTab === "mcp" && !selectedAgentFilter
                  ? "bg-neutral-800 text-white shadow-sm"
                  : "text-neutral-400 hover:text-neutral-200 hover:bg-neutral-800/50"
              }`}
            >
              <Cpu className="w-4 h-4 text-blue-400" />
              <span>中央库 MCP</span>
              <span className="ml-auto text-[10px] bg-neutral-800 px-1.5 py-0.5 rounded text-neutral-400">
                {libraryMcps.length}
              </span>
            </button>

            <button
              onClick={() => { setActiveTab("agents"); }}
              className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                activeTab === "agents"
                  ? "bg-neutral-800 text-white shadow-sm"
                  : "text-neutral-400 hover:text-neutral-200 hover:bg-neutral-800/50"
              }`}
            >
              <Terminal className="w-4 h-4 text-emerald-400" />
              <span>客户端环境</span>
              <span className="ml-auto text-[10px] bg-neutral-800 px-1.5 py-0.5 rounded text-neutral-400">
                {agents.filter(a => a.installed).length}/{agents.length}
              </span>
            </button>

            <button
              onClick={() => { setActiveTab("history"); }}
              className={`w-full flex items-center gap-2.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                activeTab === "history"
                  ? "bg-neutral-800 text-white shadow-sm"
                  : "text-neutral-400 hover:text-neutral-200 hover:bg-neutral-800/50"
              }`}
            >
              <History className="w-4 h-4 text-purple-400" />
              <span>操作历史</span>
            </button>
          </div>

          {/* Installed Clients Section */}
          <div className="px-5 pt-3 pb-2 text-[11px] font-semibold text-neutral-500 uppercase tracking-wider">
            已安装客户端
          </div>
          <div className="px-3 space-y-0.5">
            {agents.map(a => (
              <button
                key={a.name}
                onClick={() => {
                  setSelectedAgentFilter(selectedAgentFilter === a.name ? null : a.name);
                }}
                className={`w-full flex items-center gap-2 px-3 py-1.5 rounded-md text-xs transition ${
                  selectedAgentFilter === a.name
                    ? "bg-neutral-800 text-white font-medium"
                    : "text-neutral-400 hover:text-neutral-200 hover:bg-neutral-800/40"
                }`}
              >
                <div className={`w-2 h-2 rounded-full ${a.installed ? "bg-emerald-500 shadow-sm shadow-emerald-500/50" : "bg-neutral-600"}`} />
                <span className="truncate">{a.name}</span>
                {a.installed && (
                  <span className="ml-auto text-[10px] text-neutral-500">已就绪</span>
                )}
              </button>
            ))}
          </div>

          {/* Projects Section */}
          <div className="px-5 pt-4 pb-2 text-[11px] font-semibold text-neutral-500 uppercase tracking-wider flex items-center justify-between">
            <span>工作区项目 ({projects.length})</span>
            <button
              onClick={() => setShowAddProject(true)}
              className="text-neutral-400 hover:text-neutral-200"
              title="添加项目"
            >
              <Plus className="w-3.5 h-3.5" />
            </button>
          </div>
          <div className="px-3 space-y-0.5 overflow-y-auto max-h-36">
            {projects.length === 0 ? (
              <div className="px-3 py-1.5 text-[11px] text-neutral-600">未添加项目目录</div>
            ) : (
              projects.map(p => (
                <div key={p} className="flex items-center gap-2 px-3 py-1.5 text-xs text-neutral-400 hover:text-neutral-200 rounded-md hover:bg-neutral-800/30">
                  <FolderOpen className="w-3.5 h-3.5 shrink-0 text-neutral-500" />
                  <span className="truncate" title={p}>{p.split(/[\\/]/).pop()}</span>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Footer info */}
        <div className="p-4 border-t border-neutral-800/80 text-[11px] text-neutral-500 flex items-center justify-between">
          <span>跨平台配置已同步</span>
          <span className="text-[10px] px-1.5 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
            Active
          </span>
        </div>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col bg-neutral-950 overflow-hidden">
        {/* Top bar */}
        <div className="h-14 border-b border-neutral-800/80 px-6 flex items-center justify-between shrink-0">
          <div className="flex items-center gap-3">
            <h1 className="text-sm font-semibold text-neutral-100">
              {activeTab === "skills" && (selectedAgentFilter ? `${selectedAgentFilter} · 技能` : "中央库与已安装技能")}
              {activeTab === "mcp" && (selectedAgentFilter ? `${selectedAgentFilter} · MCP 服务` : "中央库与已安装 MCP")}
              {activeTab === "agents" && "已支持的 AI 客户端状态"}
              {activeTab === "history" && "本机操作审计与变更记录"}
            </h1>
            {selectedAgentFilter && (
              <button
                onClick={() => setSelectedAgentFilter(null)}
                className="text-[11px] px-2 py-0.5 rounded bg-neutral-800 text-neutral-400 hover:text-neutral-200"
              >
                清除筛选 ✕
              </button>
            )}
          </div>

          <div className="flex items-center gap-3">
            <div className="relative">
              <Search className="w-3.5 h-3.5 absolute left-2.5 top-2.5 text-neutral-500" />
              <input
                type="text"
                value={searchQuery}
                onChange={e => setSearchQuery(e.target.value)}
                placeholder="搜索能力与配置..."
                className="bg-neutral-900 border border-neutral-800 rounded-lg pl-8 pr-3 py-1.5 text-xs text-neutral-200 placeholder-neutral-500 focus:outline-none focus:border-neutral-700 w-56"
              />
            </div>

            {activeTab === "mcp" && (
              <button
                onClick={() => setShowAddMcp(true)}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-orange-600 hover:bg-orange-500 text-white text-xs font-medium transition shadow-sm"
              >
                <Plus className="w-3.5 h-3.5" />
                <span>新建 MCP</span>
              </button>
            )}
          </div>
        </div>

        {/* View Content */}
        <div className="flex-1 overflow-y-auto p-6">
          {/* TAB: Skills */}
          {activeTab === "skills" && (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {filteredSkills.map(skill => (
                <div
                  key={skill.id}
                  className="rounded-xl border border-neutral-800/80 bg-neutral-900/50 p-4 hover:border-neutral-700/80 transition flex flex-col justify-between group"
                >
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-2">
                        <div className="p-1.5 rounded-lg bg-orange-500/10 text-orange-400 border border-orange-500/20">
                          <Boxes className="w-4 h-4" />
                        </div>
                        <span className="font-semibold text-sm text-neutral-100">{skill.name}</span>
                      </div>
                      <span className={`text-[10px] px-2 py-0.5 rounded font-medium ${
                        skill.is_library ? "bg-orange-500/10 text-orange-400 border border-orange-500/20" : "bg-neutral-800 text-neutral-400"
                      }`}>
                        {skill.source}
                      </span>
                    </div>
                    <p className="text-xs text-neutral-400 line-clamp-2 mb-3 leading-relaxed">
                      {skill.description}
                    </p>
                  </div>
                  <div className="text-[11px] text-neutral-500 truncate pt-2 border-t border-neutral-800/60 font-mono">
                    {skill.path}
                  </div>
                </div>
              ))}
              {filteredSkills.length === 0 && (
                <div className="col-span-full py-16 text-center text-neutral-500 text-xs">
                  暂无匹配的 Skill 条目，可在中央库中添加或从 Git 仓库导入。
                </div>
              )}
            </div>
          )}

          {/* TAB: MCP */}
          {activeTab === "mcp" && (
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {filteredMcps.map(mcp => (
                <div
                  key={mcp.id}
                  className="rounded-xl border border-neutral-800/80 bg-neutral-900/50 p-4 hover:border-neutral-700/80 transition flex flex-col justify-between group"
                >
                  <div>
                    <div className="flex items-center justify-between mb-2">
                      <div className="flex items-center gap-2">
                        <div className="p-1.5 rounded-lg bg-blue-500/10 text-blue-400 border border-blue-500/20">
                          <Cpu className="w-4 h-4" />
                        </div>
                        <span className="font-semibold text-sm text-neutral-100">{mcp.name}</span>
                      </div>
                      <div className="flex items-center gap-1.5">
                        <span className={`text-[10px] px-2 py-0.5 rounded font-medium ${
                          mcp.is_library ? "bg-blue-500/10 text-blue-400 border border-blue-500/20" : "bg-neutral-800 text-neutral-400"
                        }`}>
                          {mcp.source}
                        </span>
                        {mcp.is_library && (
                          <button
                            onClick={() => handleDeleteMcp(mcp.name)}
                            className="opacity-0 group-hover:opacity-100 p-1 text-neutral-500 hover:text-red-400 transition"
                            title="从中央库删除"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        )}
                      </div>
                    </div>
                    <div className="bg-neutral-950/80 rounded-lg p-2.5 mb-3 border border-neutral-800/80">
                      <div className="text-[11px] font-mono text-neutral-300 truncate">
                        {mcp.summary}
                      </div>
                    </div>
                  </div>
                  <div className="flex items-center justify-between pt-2 border-t border-neutral-800/60 text-[11px] text-neutral-500">
                    <span>{mcp.definition.args ? `${mcp.definition.args.length} 参数` : "无参数"}</span>
                    <button
                      onClick={() => navigator.clipboard.writeText(JSON.stringify(mcp.definition, null, 2))}
                      className="hover:text-neutral-300 transition"
                    >
                      复制配置
                    </button>
                  </div>
                </div>
              ))}
              {filteredMcps.length === 0 && (
                <div className="col-span-full py-16 text-center text-neutral-500 text-xs">
                  暂无匹配的 MCP 条目，可点击右上角“新建 MCP”将其加入中央库。
                </div>
              )}
            </div>
          )}

          {/* TAB: Clients Environment */}
          {activeTab === "agents" && (
            <div className="space-y-4 max-w-4xl">
              {agents.map(a => (
                <div
                  key={a.name}
                  className="rounded-xl border border-neutral-800/80 bg-neutral-900/40 p-5 flex items-start justify-between"
                >
                  <div className="space-y-2">
                    <div className="flex items-center gap-3">
                      <div className="font-semibold text-base text-neutral-100">{a.name}</div>
                      <span className={`inline-flex items-center gap-1 px-2.5 py-0.5 rounded-full text-[11px] font-medium border ${
                        a.installed
                          ? "bg-emerald-500/10 text-emerald-400 border-emerald-500/20"
                          : "bg-neutral-800/60 text-neutral-500 border-neutral-700/40"
                      }`}>
                        {a.installed ? (
                          <>
                            <CheckCircle2 className="w-3 h-3 text-emerald-400" />
                            <span>已检测到安装</span>
                          </>
                        ) : (
                          <>
                            <XCircle className="w-3 h-3 text-neutral-500" />
                            <span>未检测到安装</span>
                          </>
                        )}
                      </span>
                    </div>

                    <div className="text-xs text-neutral-400 space-y-1">
                      <div>
                        <span className="text-neutral-500">全局 MCP 配置路径：</span>
                        <code className="text-neutral-300 font-mono text-[11px] ml-1 bg-neutral-950 px-1.5 py-0.5 rounded border border-neutral-800">
                          {a.global_mcp_path}
                        </code>
                      </div>
                      <div>
                        <span className="text-neutral-500">技能目录根路径：</span>
                        <code className="text-neutral-300 font-mono text-[11px] ml-1 bg-neutral-950 px-1.5 py-0.5 rounded border border-neutral-800">
                          {a.global_skill_roots.join(" , ")}
                        </code>
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          )}

          {/* TAB: History */}
          {activeTab === "history" && (
            <div className="space-y-2 max-w-4xl">
              {history.map(item => (
                <div
                  key={item.id}
                  className="rounded-lg border border-neutral-800/80 bg-neutral-900/30 px-4 py-3 flex items-center justify-between text-xs"
                >
                  <div className="flex items-center gap-3">
                    <span className="px-2 py-0.5 rounded bg-neutral-800 text-neutral-300 font-medium text-[10px]">
                      {item.action}
                    </span>
                    <span className="text-neutral-200 font-mono">{item.target}</span>
                  </div>
                  <span className="text-[11px] text-neutral-500">
                    {new Date(item.timestamp).toLocaleString()}
                  </span>
                </div>
              ))}
              {history.length === 0 && (
                <div className="py-16 text-center text-neutral-500 text-xs">
                  暂无操作审计记录。
                </div>
              )}
            </div>
          )}
        </div>
      </div>

      {/* Modal: New MCP */}
      {showAddMcp && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-neutral-900 border border-neutral-800 rounded-2xl w-full max-w-md p-6 space-y-4 shadow-xl">
            <h2 className="text-base font-semibold text-neutral-100">新建中央库 MCP</h2>
            <div className="space-y-3">
              <div>
                <label className="text-xs text-neutral-400 block mb-1">服务名称</label>
                <input
                  type="text"
                  placeholder="例如: sqlite-server"
                  value={newMcpName}
                  onChange={e => setNewMcpName(e.target.value)}
                  className="w-full bg-neutral-950 border border-neutral-800 rounded-lg px-3 py-2 text-xs text-neutral-200 focus:outline-none focus:border-neutral-700"
                />
              </div>
              <div>
                <label className="text-xs text-neutral-400 block mb-1">执行命令 (Command)</label>
                <input
                  type="text"
                  placeholder="例如: npx 或 node"
                  value={newMcpCommand}
                  onChange={e => setNewMcpCommand(e.target.value)}
                  className="w-full bg-neutral-950 border border-neutral-800 rounded-lg px-3 py-2 text-xs text-neutral-200 focus:outline-none focus:border-neutral-700"
                />
              </div>
              <div>
                <label className="text-xs text-neutral-400 block mb-1">参数列表 (空格隔开)</label>
                <input
                  type="text"
                  placeholder="-y @modelcontextprotocol/server-sqlite --db-path ./db.sqlite"
                  value={newMcpArgs}
                  onChange={e => setNewMcpArgs(e.target.value)}
                  className="w-full bg-neutral-950 border border-neutral-800 rounded-lg px-3 py-2 text-xs text-neutral-200 focus:outline-none focus:border-neutral-700"
                />
              </div>
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button
                onClick={() => setShowAddMcp(false)}
                className="px-4 py-2 rounded-lg text-xs text-neutral-400 hover:text-neutral-200 hover:bg-neutral-800 transition"
              >
                取消
              </button>
              <button
                onClick={handleCreateMcp}
                className="px-4 py-2 rounded-lg text-xs font-medium bg-orange-600 hover:bg-orange-500 text-white transition shadow-sm"
              >
                保存到中央库
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Modal: Add Project */}
      {showAddProject && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-xs flex items-center justify-center p-4 z-50">
          <div className="bg-neutral-900 border border-neutral-800 rounded-2xl w-full max-w-md p-6 space-y-4 shadow-xl">
            <h2 className="text-base font-semibold text-neutral-100">添加项目目录</h2>
            <div>
              <label className="text-xs text-neutral-400 block mb-1">项目绝对路径</label>
              <input
                type="text"
                placeholder="例如: C:\Users\Username\Projects\my-app"
                value={newProjectPath}
                onChange={e => setNewProjectPath(e.target.value)}
                className="w-full bg-neutral-950 border border-neutral-800 rounded-lg px-3 py-2 text-xs text-neutral-200 focus:outline-none focus:border-neutral-700"
              />
            </div>
            <div className="flex justify-end gap-2 pt-2">
              <button
                onClick={() => setShowAddProject(false)}
                className="px-4 py-2 rounded-lg text-xs text-neutral-400 hover:text-neutral-200 hover:bg-neutral-800 transition"
              >
                取消
              </button>
              <button
                onClick={handleAddProject}
                className="px-4 py-2 rounded-lg text-xs font-medium bg-orange-600 hover:bg-orange-500 text-white transition shadow-sm"
              >
                添加项目
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
