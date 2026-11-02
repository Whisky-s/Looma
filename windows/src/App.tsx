import { useState, useEffect, useMemo } from "react";
import { invoke } from "@tauri-apps/api/core";
import {
  AgentStatus,
  SkillItem,
  McpItem,
  Preset,
  HistoryRecord,
  DisplayItem,
  TargetStatus,
} from "./types";
import { Sidebar } from "./components/Sidebar";
import { Header } from "./components/Header";
import { Toolbar } from "./components/Toolbar";
import { CapabilityCard } from "./components/CapabilityCard";
import { CapabilityTable } from "./components/CapabilityTable";
import { PresetsView } from "./components/PresetsView";
import { ProjectsView } from "./components/ProjectsView";
import { SettingsView } from "./components/SettingsView";
import { DetailModal } from "./components/DetailModal";
import { NewMcpModal } from "./components/NewMcpModal";
import { ImportModal } from "./components/ImportModal";
import { TitleBar } from "./components/TitleBar";

const DEFAULT_AGENTS: AgentStatus[] = [
  { agent: "claude", name: "Claude", installed: true, global_skill_roots: [], global_mcp_path: "~/.claude.json" },
  { agent: "cursor", name: "Cursor", installed: true, global_skill_roots: [], global_mcp_path: "~/.cursor/mcp.json" },
  { agent: "codex", name: "Codex", installed: true, global_skill_roots: [], global_mcp_path: "~/.codex/config.toml" },
  { agent: "antigravity", name: "Antigravity", installed: true, global_skill_roots: [], global_mcp_path: "~/.gemini/config/mcp_config.json" },
  { agent: "qoder", name: "Qoder", installed: false, global_skill_roots: [], global_mcp_path: "~/.qoder/settings.json" },
  { agent: "workbuddy", name: "WorkBuddy", installed: false, global_skill_roots: [], global_mcp_path: "~/.workbuddy/mcp.json" },
];

export default function App() {
  // Navigation & Filtering
  const [page, setPage] = useState<"skills" | "mcp" | "presets" | "projects" | "settings">("skills");
  const [sourceFilter, setSourceFilter] = useState<"all" | "library" | "unadopted">("all");
  const [statusFilter, setStatusFilter] = useState<"all" | "enabled" | "available">("all");
  const [selectedAgent, setSelectedAgent] = useState<string | null>(null);
  const [selectedProject, setSelectedProject] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [viewMode, setViewMode] = useState<"grid" | "table">("grid");

  // Raw Backend Data
  const [agents, setAgents] = useState<AgentStatus[]>(DEFAULT_AGENTS);
  const [projects, setProjects] = useState<string[]>([]);
  const [librarySkills, setLibrarySkills] = useState<SkillItem[]>([]);
  const [installedSkills, setInstalledSkills] = useState<SkillItem[]>([]);
  const [libraryMcps, setLibraryMcps] = useState<McpItem[]>([]);
  const [installedMcps, setInstalledMcps] = useState<McpItem[]>([]);
  const [presets, setPresets] = useState<Preset[]>([]);
  const [history, setHistory] = useState<HistoryRecord[]>([]);

  // Dialogs
  const [newMcpOpen, setNewMcpOpen] = useState(false);
  const [importLocalOpen, setImportLocalOpen] = useState(false);
  const [importGitOpen, setImportGitOpen] = useState(false);
  const [detailItem, setDetailItem] = useState<DisplayItem | null>(null);

  // Load all data from Tauri backend
  const loadAll = async () => {
    try {
      const a = await invoke<AgentStatus[]>("get_agents");
      if (a && a.length > 0) setAgents(a);
      const p = await invoke<string[]>("get_projects");
      setProjects(p || []);
      const ls = await invoke<SkillItem[]>("list_library_skills");
      setLibrarySkills(ls || []);
      const is = await invoke<SkillItem[]>("list_installed_skills");
      setInstalledSkills(is || []);
      const lm = await invoke<McpItem[]>("list_library_mcps");
      setLibraryMcps(lm || []);
      const im = await invoke<McpItem[]>("list_installed_mcps");
      setInstalledMcps(im || []);
      const pr = await invoke<Preset[]>("get_presets");
      setPresets(pr || []);
      const h = await invoke<HistoryRecord[]>("get_history");
      setHistory(h || []);
    } catch (err) {
      console.warn("Backend invoke error (fallback mode):", err);
    }
  };

  useEffect(() => {
    loadAll();
  }, []);

  // Consolidate Skills into DisplayItem[]
  const consolidatedSkills = useMemo(() => {
    const itemMap = new Map<string, DisplayItem>();

    // 1. Central library skills
    for (const skill of librarySkills) {
      const targets: TargetStatus[] = agents.map((a) => {
        const isDeployed = installedSkills.some(
          (s) =>
            s.name === skill.name &&
            s.agent === a.agent &&
            (selectedProject ? s.project === selectedProject : s.project === null || s.project === undefined)
        );
        return {
          agent: a.agent,
          agentName: a.name,
          isAgentInstalled: a.installed,
          isDeployed,
          status: isDeployed ? "已启用" : "未分发",
        };
      });

      const activeCount = targets.filter((t) => t.isDeployed).length;

      itemMap.set(skill.name, {
        id: `skill|${skill.name}`,
        name: skill.name,
        kind: "skill",
        typeLabel: "标准 Skill",
        description: skill.description || "无详细描述",
        isLibrary: true,
        isSystemService: false,
        gitSource: skill.git_source,
        targets,
        activeCount,
        rawSkill: skill,
        externalPaths: [],
      });
    }

    // 2. Installed skills discovered from clients
    for (const is of installedSkills) {
      if (itemMap.has(is.name)) {
        const existing = itemMap.get(is.name)!;
        existing.externalPaths.push(is.path);
        continue;
      }

      const targets: TargetStatus[] = agents.map((a) => {
        const isDeployed = installedSkills.some(
          (s) =>
            s.name === is.name &&
            s.agent === a.agent &&
            (selectedProject ? s.project === selectedProject : s.project === null || s.project === undefined)
        );
        return {
          agent: a.agent,
          agentName: a.name,
          isAgentInstalled: a.installed,
          isDeployed,
          status: isDeployed ? "已启用" : "未分发",
        };
      });

      const activeCount = targets.filter((t) => t.isDeployed).length;

      itemMap.set(is.name, {
        id: `discovered|skill|${is.name}`,
        name: is.name,
        kind: "skill",
        typeLabel: "外部 Skill",
        description: is.description || "客户端发现的技能",
        isLibrary: false,
        isSystemService: false,
        targets,
        activeCount,
        rawSkill: is,
        externalPaths: [is.path],
      });
    }

    return Array.from(itemMap.values()).sort((a, b) => a.name.localeCompare(b.name));
  }, [librarySkills, installedSkills, agents, selectedProject]);

  // Consolidate MCPs into DisplayItem[]
  const consolidatedMcps = useMemo(() => {
    const itemMap = new Map<string, DisplayItem>();

    // 1. Central library mcps
    for (const mcp of libraryMcps) {
      const targets: TargetStatus[] = agents.map((a) => {
        const isDeployed = installedMcps.some(
          (m) =>
            m.name === mcp.name &&
            m.agent === a.agent &&
            (selectedProject ? m.project === selectedProject : m.project === null || m.project === undefined)
        );
        return {
          agent: a.agent,
          agentName: a.name,
          isAgentInstalled: a.installed,
          isDeployed,
          status: isDeployed ? "已启用" : "未分发",
        };
      });

      const activeCount = targets.filter((t) => t.isDeployed).length;
      const isSse = Boolean(mcp.definition?.url || mcp.definition?.serverUrl);

      itemMap.set(mcp.name, {
        id: `mcp|${mcp.name}`,
        name: mcp.name,
        kind: "mcp",
        typeLabel: isSse ? "SSE MCP" : "Stdio MCP",
        description: mcp.summary || (isSse ? "SSE 远程服务" : "本地 stdio 进程服务"),
        isLibrary: true,
        isSystemService: mcp.is_system_service,
        targets,
        activeCount,
        rawMcp: mcp,
        externalPaths: [],
      });
    }

    // 2. Installed mcps discovered from client configs
    for (const im of installedMcps) {
      if (itemMap.has(im.name)) {
        continue;
      }

      const targets: TargetStatus[] = agents.map((a) => {
        const isDeployed = installedMcps.some(
          (m) =>
            m.name === im.name &&
            m.agent === a.agent &&
            (selectedProject ? m.project === selectedProject : m.project === null || m.project === undefined)
        );
        return {
          agent: a.agent,
          agentName: a.name,
          isAgentInstalled: a.installed,
          isDeployed,
          status: isDeployed ? "已启用" : "未分发",
        };
      });

      const activeCount = targets.filter((t) => t.isDeployed).length;
      const isSse = Boolean(im.definition?.url || im.definition?.serverUrl);

      itemMap.set(im.name, {
        id: `discovered|mcp|${im.name}`,
        name: im.name,
        kind: "mcp",
        typeLabel: isSse ? "SSE 外部" : "Stdio 外部",
        description: im.summary || "外部客户端配置",
        isLibrary: false,
        isSystemService: im.is_system_service,
        targets,
        activeCount,
        rawMcp: im,
        externalPaths: [],
      });
    }

    return Array.from(itemMap.values()).sort((a, b) => a.name.localeCompare(b.name));
  }, [libraryMcps, installedMcps, agents, selectedProject]);

  // Current items based on page (skills vs mcp)
  const currentItems = page === "skills" ? consolidatedSkills : consolidatedMcps;

  // Filter items
  const filteredItems = useMemo(() => {
    return currentItems.filter((item) => {
      // 1. Source filter
      if (sourceFilter === "library" && !item.isLibrary) return false;
      if (sourceFilter === "unadopted" && item.isLibrary) return false;

      // 2. Selected agent filter
      if (selectedAgent) {
        const hasAgent = item.targets.some((t) => t.agent === selectedAgent && t.isDeployed);
        // In library view, allow seeing all items but highlight target agent; in overview, filter
        if (sourceFilter === "all" && !hasAgent) {
          // If filtering by agent in overview, require deployed
          return false;
        }
      }

      // 3. Status filter
      if (statusFilter === "enabled" && item.activeCount === 0) return false;
      if (statusFilter === "available" && item.activeCount > 0) return false;

      // 4. Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchName = item.name.toLowerCase().includes(q);
        const matchDesc = item.description.toLowerCase().includes(q);
        if (!matchName && !matchDesc) return false;
      }

      return true;
    });
  }, [currentItems, sourceFilter, selectedAgent, statusFilter, searchQuery]);

  // Target toggle handler (deploy / remove)
  const handleToggleTarget = async (item: DisplayItem, target: TargetStatus) => {
    try {
      if (item.kind === "skill") {
        if (target.isDeployed) {
          await invoke("remove_skill", {
            name: item.name,
            agent: target.agent,
            project: selectedProject,
          });
        } else {
          await invoke("deploy_skill", {
            name: item.name,
            agent: target.agent,
            project: selectedProject,
          });
        }
      } else {
        if (target.isDeployed) {
          await invoke("remove_mcp", {
            name: item.name,
            agent: target.agent,
            project: selectedProject,
          });
        } else {
          await invoke("deploy_mcp", {
            name: item.name,
            agent: target.agent,
            project: selectedProject,
          });
        }
      }
      await loadAll();
    } catch (err) {
      alert(`操作失败: ${err}`);
    }
  };

  // Adopt unadopted item to central library
  const handleAdopt = async (item: DisplayItem) => {
    try {
      if (item.kind === "skill") {
        const srcPath = item.externalPaths[0] || item.rawSkill?.path;
        if (!srcPath) {
          alert("未找到技能来源文件路径");
          return;
        }
        await invoke("adopt_skill", { name: item.name, srcPath });
      } else {
        if (!item.rawMcp) return;
        await invoke("save_mcp", {
          name: item.name,
          definition: item.rawMcp.definition,
        });
      }
      await loadAll();
    } catch (err) {
      alert(`入库失败: ${err}`);
    }
  };

  // Delete item from central library
  const handleDelete = async (item: DisplayItem) => {
    if (!confirm(`确定要从中央库删除 ${item.kind === "skill" ? "技能" : "MCP 服务"} "${item.name}" 吗？`)) {
      return;
    }
    try {
      if (item.kind === "mcp") {
        await invoke("delete_mcp", { name: item.name });
      }
      await loadAll();
    } catch (err) {
      alert(`删除失败: ${err}`);
    }
  };

  // Create new MCP
  const handleCreateMcp = async (name: string, definition: Record<string, any>) => {
    try {
      await invoke("save_mcp", { name, definition });
      await loadAll();
    } catch (err) {
      alert(`创建 MCP 失败: ${err}`);
    }
  };

  // Apply preset
  const handleApplyPreset = async (preset: Preset, agentId: string) => {
    try {
      for (const s of preset.skills) {
        await invoke("deploy_skill", { name: s, agent: agentId, project: selectedProject }).catch(() => {});
      }
      for (const m of preset.mcps) {
        await invoke("deploy_mcp", { name: m, agent: agentId, project: selectedProject }).catch(() => {});
      }
      await loadAll();
      alert(`预设 "${preset.name}" 已成功分发至客户端`);
    } catch (err) {
      alert(`应用预设失败: ${err}`);
    }
  };

  // Save preset
  const handleSavePreset = async (preset: Preset) => {
    try {
      await invoke("save_preset", { preset });
      await loadAll();
    } catch (err) {
      alert(`保存预设失败: ${err}`);
    }
  };

  // Add project
  const handleAddProject = async (path: string) => {
    try {
      await invoke("add_project", { path });
      await loadAll();
    } catch (err) {
      alert(`添加项目失败: ${err}`);
    }
  };

  // Remove project
  const handleRemoveProject = async (path: string) => {
    try {
      await invoke("remove_project", { path });
      if (selectedProject === path) setSelectedProject(null);
      await loadAll();
    } catch (err) {
      alert(`移除项目失败: ${err}`);
    }
  };

  // Counts
  const librarySkillCount = librarySkills.length;
  const libraryMcpCount = libraryMcps.length;
  const totalSkillCount = consolidatedSkills.length;
  const totalMcpCount = consolidatedMcps.length;
  const unadoptedSkillCount = consolidatedSkills.filter((s) => !s.isLibrary).length;
  const unadoptedMcpCount = consolidatedMcps.filter((m) => !m.isLibrary).length;

  return (
    <div className="flex flex-col h-screen w-screen bg-[#f4f6f9] text-[#0f172a] select-none overflow-hidden font-sans border border-slate-300/70 rounded-xl shadow-lg">
      {/* Sleek Custom Frameless TitleBar */}
      <TitleBar />

      <div className="flex flex-1 h-[calc(100vh-32px)] overflow-hidden">
        {/* Left Sidebar */}
        <Sidebar
          page={page}
          setPage={setPage}
          sourceFilter={sourceFilter}
          setSourceFilter={setSourceFilter}
          selectedAgent={selectedAgent}
          setSelectedAgent={setSelectedAgent}
          selectedProject={selectedProject}
          setSelectedProject={setSelectedProject}
          agents={agents}
          projects={projects}
          librarySkillCount={librarySkillCount}
          libraryMcpCount={libraryMcpCount}
          totalSkillCount={totalSkillCount}
          totalMcpCount={totalMcpCount}
          unadoptedSkillCount={unadoptedSkillCount}
          unadoptedMcpCount={unadoptedMcpCount}
          onRefresh={loadAll}
        />

        {/* Main Content Area */}
        <main className="flex-1 flex flex-col h-full overflow-hidden bg-[#f4f6f9]">
          {/* Top Header */}
          <Header
            page={page}
            selectedAgent={selectedAgent}
            selectedProject={selectedProject}
            agents={agents}
          />

          {/* Views */}
          {page === "skills" || page === "mcp" ? (
            <>
              <Toolbar
                page={page}
                setPage={setPage}
                sourceFilter={sourceFilter}
                setSourceFilter={setSourceFilter}
                statusFilter={statusFilter}
                setStatusFilter={setStatusFilter}
                searchQuery={searchQuery}
                setSearchQuery={setSearchQuery}
                viewMode={viewMode}
                setViewMode={setViewMode}
                totalCount={page === "skills" ? totalSkillCount : totalMcpCount}
                libraryCount={page === "skills" ? librarySkillCount : libraryMcpCount}
                unadoptedCount={page === "skills" ? unadoptedSkillCount : unadoptedMcpCount}
                displayCount={filteredItems.length}
                onNewMcp={() => setNewMcpOpen(true)}
                onImportLocal={() => setImportLocalOpen(true)}
                onImportGit={() => setImportGitOpen(true)}
              />

              {/* Content Grid or Table */}
              <div className="flex-1 overflow-y-auto px-8 pb-8">
                {filteredItems.length === 0 ? (
                  <div className="bg-white rounded-xl border border-slate-200/80 p-12 text-center text-xs text-slate-400 mt-2">
                    未匹配到任何能力条目
                  </div>
                ) : viewMode === "grid" ? (
                  <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {filteredItems.map((item) => (
                      <CapabilityCard
                        key={item.id}
                        item={item}
                        selectedAgent={selectedAgent}
                        onSelect={(it) => setDetailItem(it)}
                        onToggleTarget={handleToggleTarget}
                        onAdopt={handleAdopt}
                        onDelete={handleDelete}
                      />
                    ))}
                  </div>
                ) : (
                  <CapabilityTable
                    items={filteredItems}
                    selectedAgent={selectedAgent}
                    onSelect={(it) => setDetailItem(it)}
                    onToggleTarget={handleToggleTarget}
                    onAdopt={handleAdopt}
                    onDelete={handleDelete}
                  />
                )}
              </div>
            </>
          ) : page === "presets" ? (
            <PresetsView
              presets={presets}
              agents={agents}
              onApplyPreset={handleApplyPreset}
              onSavePreset={handleSavePreset}
            />
          ) : page === "projects" ? (
            <ProjectsView
              projects={projects}
              onAddProject={handleAddProject}
              onRemoveProject={handleRemoveProject}
              onSelectProject={(p) => {
                setSelectedProject(p);
                setPage("skills");
              }}
            />
          ) : (
            <SettingsView
              agents={agents}
              history={history}
              librarySkillCount={librarySkillCount}
              libraryMcpCount={libraryMcpCount}
              projectCount={projects.length}
              onRefreshAll={loadAll}
            />
          )}
        </main>
      </div>

      {/* Modals */}
      <NewMcpModal
        open={newMcpOpen}
        onOpenChange={setNewMcpOpen}
        onSubmit={handleCreateMcp}
      />

      <ImportModal
        open={importLocalOpen}
        onOpenChange={setImportLocalOpen}
        mode="local"
        kind={page === "skills" ? "skill" : "mcp"}
        onImport={(path) => {
          alert(`本地导入路径：${path} 已加入扫描队列`);
          loadAll();
        }}
      />

      <ImportModal
        open={importGitOpen}
        onOpenChange={setImportGitOpen}
        mode="git"
        kind="skill"
        onImport={(url, branch) => {
          alert(`Git 仓库：${url} ${branch ? `(分支: ${branch})` : ""} 已加入导入队列`);
          loadAll();
        }}
      />

      <DetailModal
        item={detailItem}
        open={Boolean(detailItem)}
        onOpenChange={(open) => {
          if (!open) setDetailItem(null);
        }}
        onToggleTarget={handleToggleTarget}
      />
    </div>
  );
}
