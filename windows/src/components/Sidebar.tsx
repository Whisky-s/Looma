import React from "react";
import {
  Folder,
  Cpu,
  Layers,
  Sparkles,
  LayoutGrid,
  Settings,
  RefreshCw,
  FolderPlus,
  FolderGit2,
} from "lucide-react";
import { AgentStatus } from "../types";
import { AgentIcon } from "./AgentIcon";

interface SidebarProps {
  page: "skills" | "mcp" | "presets" | "projects" | "settings";
  setPage: (page: "skills" | "mcp" | "presets" | "projects" | "settings") => void;
  sourceFilter: "all" | "library" | "unadopted";
  setSourceFilter: (filter: "all" | "library" | "unadopted") => void;
  selectedAgent: string | null;
  setSelectedAgent: (agent: string | null) => void;
  selectedProject: string | null;
  setSelectedProject: (project: string | null) => void;
  agents: AgentStatus[];
  projects: string[];
  librarySkillCount: number;
  libraryMcpCount: number;
  totalSkillCount: number;
  totalMcpCount: number;
  unadoptedSkillCount: number;
  unadoptedMcpCount: number;
  onRefresh: () => void;
}

export const Sidebar: React.FC<SidebarProps> = ({
  page,
  setPage,
  sourceFilter,
  setSourceFilter,
  selectedAgent,
  setSelectedAgent,
  selectedProject,
  setSelectedProject,
  agents,
  projects,
  librarySkillCount,
  libraryMcpCount,
  totalSkillCount,
  totalMcpCount,
  unadoptedSkillCount,
  unadoptedMcpCount,
  onRefresh,
}) => {
  const isLibrarySkillsActive =
    page === "skills" && sourceFilter === "library" && !selectedAgent && !selectedProject;
  const isLibraryMcpActive =
    page === "mcp" && sourceFilter === "library" && !selectedAgent && !selectedProject;
  const isPresetsActive = page === "presets";
  const isAllOverviewActive =
    (page === "skills" || page === "mcp") &&
    sourceFilter === "all" &&
    !selectedAgent &&
    !selectedProject;
  const isUnadoptedActive =
    (page === "skills" || page === "mcp") &&
    sourceFilter === "unadopted" &&
    !selectedAgent &&
    !selectedProject;

  const currentUnadopted = page === "skills" ? unadoptedSkillCount : unadoptedMcpCount;

  return (
    <aside className="w-[240px] h-full bg-[#ecedf0] border-r border-[#e2e7ed] flex flex-col justify-between shrink-0 select-none">
      <div className="flex flex-col h-full overflow-hidden">
        {/* App Header */}
        <div className="pt-3.5 pb-3.5 px-4 flex items-center justify-between border-b border-[#e2e7ed]/60">
          <div className="flex items-center gap-3">
            <img
              src="/app-icon.png"
              alt="Looma"
              className="w-9 h-9 rounded-xl shadow-xs object-cover border border-slate-200"
            />
            <div className="leading-tight">
              <div className="text-[14px] font-bold text-[#0f172a]">Looma</div>
              <div className="text-[11px] font-medium text-[#64748b]">AI 能力控制台</div>
            </div>
          </div>
          <button
            onClick={onRefresh}
            title="重新扫描并刷新"
            className="p-1.5 rounded-lg text-slate-500 hover:text-slate-900 hover:bg-slate-200/60 transition cursor-pointer"
          >
            <RefreshCw className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* Navigation list */}
        <div className="flex-1 overflow-y-auto px-3 py-3 space-y-4">
          {/* Section: 本地中央库 */}
          <div>
            <div className="px-2 pb-1.5 text-[10px] font-bold tracking-wider text-[#64748b] uppercase">
              本地中央库
            </div>
            <div className="space-y-1">
              <button
                onClick={() => {
                  setPage("skills");
                  setSourceFilter("library");
                  setSelectedAgent(null);
                  setSelectedProject(null);
                }}
                className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
                  isLibrarySkillsActive
                    ? "bg-[#e0eeff] text-[#0266ee] font-semibold"
                    : "text-[#0f172a] hover:bg-black/5"
                }`}
              >
                <Folder className={`w-4 h-4 ${isLibrarySkillsActive ? "text-[#0266ee]" : "text-[#64748b]"}`} />
                <span>中央库 Skills</span>
                <span
                  className={`ml-auto text-[11px] font-bold px-2 py-0.5 rounded-full ${
                    isLibrarySkillsActive
                      ? "bg-white/60 text-[#0266ee]"
                      : "bg-black/5 text-[#64748b]"
                  }`}
                >
                  {librarySkillCount}
                </span>
              </button>

              <button
                onClick={() => {
                  setPage("mcp");
                  setSourceFilter("library");
                  setSelectedAgent(null);
                  setSelectedProject(null);
                }}
                className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
                  isLibraryMcpActive
                    ? "bg-[#e0eeff] text-[#0266ee] font-semibold"
                    : "text-[#0f172a] hover:bg-black/5"
                }`}
              >
                <Cpu className={`w-4 h-4 ${isLibraryMcpActive ? "text-[#0266ee]" : "text-[#64748b]"}`} />
                <span>中央库 MCP</span>
                <span
                  className={`ml-auto text-[11px] font-bold px-2 py-0.5 rounded-full ${
                    isLibraryMcpActive
                      ? "bg-white/60 text-[#0266ee]"
                      : "bg-black/5 text-[#64748b]"
                  }`}
                >
                  {libraryMcpCount}
                </span>
              </button>

              <button
                onClick={() => {
                  setPage("presets");
                  setSelectedAgent(null);
                  setSelectedProject(null);
                }}
                className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
                  isPresetsActive
                    ? "bg-[#e0eeff] text-[#0266ee] font-semibold"
                    : "text-[#0f172a] hover:bg-black/5"
                }`}
              >
                <Layers className={`w-4 h-4 ${isPresetsActive ? "text-[#0266ee]" : "text-[#64748b]"}`} />
                <span>预设组合</span>
              </button>
            </div>
          </div>

          <div className="h-px bg-[#e2e7ed]/70 mx-1" />

          {/* Section: 本机全部能力 */}
          <div>
            <div className="px-2 pb-1.5 text-[10px] font-bold tracking-wider text-[#64748b] uppercase">
              本机全部能力
            </div>
            <div className="space-y-1">
              <button
                onClick={() => {
                  setSourceFilter("all");
                  setSelectedAgent(null);
                  setSelectedProject(null);
                }}
                className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
                  isAllOverviewActive
                    ? "bg-[#e0eeff] text-[#0266ee] font-semibold"
                    : "text-[#0f172a] hover:bg-black/5"
                }`}
              >
                <LayoutGrid className={`w-4 h-4 ${isAllOverviewActive ? "text-[#0266ee]" : "text-[#64748b]"}`} />
                <span>全部能力总览</span>
                <span
                  className={`ml-auto text-[11px] font-bold px-2 py-0.5 rounded-full ${
                    isAllOverviewActive
                      ? "bg-white/60 text-[#0266ee]"
                      : "bg-black/5 text-[#64748b]"
                  }`}
                >
                  {page === "skills" ? totalSkillCount : totalMcpCount}
                </span>
              </button>

              <button
                onClick={() => {
                  setSourceFilter("unadopted");
                  setSelectedAgent(null);
                  setSelectedProject(null);
                }}
                className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
                  isUnadoptedActive
                    ? "bg-[#e0eeff] text-[#0266ee] font-semibold"
                    : "text-[#0f172a] hover:bg-black/5"
                }`}
              >
                <Sparkles
                  className={`w-4 h-4 ${
                    isUnadoptedActive
                      ? "text-[#0266ee]"
                      : currentUnadopted > 0
                      ? "text-[#f59e0b]"
                      : "text-[#64748b]"
                  }`}
                />
                <span>待入库外部发现</span>
                <span
                  className={`ml-auto text-[11px] font-bold px-2 py-0.5 rounded-full ${
                    isUnadoptedActive
                      ? "bg-white/60 text-[#0266ee]"
                      : currentUnadopted > 0
                      ? "bg-amber-100 text-[#f59e0b]"
                      : "bg-black/5 text-[#64748b]"
                  }`}
                >
                  {currentUnadopted}
                </span>
              </button>
            </div>
          </div>

          <div className="h-px bg-[#e2e7ed]/70 mx-1" />

          {/* Section: 客户端全局能力 */}
          <div>
            <div className="px-2 pb-1.5 text-[10px] font-bold tracking-wider text-[#64748b] uppercase">
              客户端全局能力
            </div>
            <div className="space-y-1">
              {agents.map((a) => {
                const isActive = selectedAgent === a.agent && !selectedProject;
                return (
                  <button
                    key={a.agent}
                    onClick={() => {
                      if (isActive) {
                        setSelectedAgent(null);
                      } else {
                        setSelectedAgent(a.agent);
                        setSelectedProject(null);
                      }
                    }}
                    className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
                      isActive
                        ? "bg-[#e0eeff] text-[#0266ee] font-semibold"
                        : "text-[#0f172a] hover:bg-black/5"
                    }`}
                  >
                    <AgentIcon agent={a.agent} size={18} />
                    <span className="truncate">{a.name}</span>
                    <span className="ml-auto flex items-center">
                      <span
                        className={`w-2 h-2 rounded-full ${
                          a.installed ? "bg-[#10b981]" : "bg-slate-300"
                        }`}
                        title={a.installed ? "已安装客户端" : "未安装客户端"}
                      />
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="h-px bg-[#e2e7ed]/70 mx-1" />

          {/* Section: 项目工作区 */}
          <div>
            <div className="px-2 pb-1.5 text-[10px] font-bold tracking-wider text-[#64748b] uppercase">
              项目工作区
            </div>
            <div className="space-y-1">
              {projects.map((p) => {
                const folderName = p.split(/[\\/]/).filter(Boolean).pop() || p;
                const isActive = selectedProject === p;
                return (
                  <button
                    key={p}
                    onClick={() => {
                      if (isActive) {
                        setSelectedProject(null);
                      } else {
                        setSelectedProject(p);
                        setSelectedAgent(null);
                      }
                    }}
                    title={p}
                    className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
                      isActive
                        ? "bg-[#e0eeff] text-[#0266ee] font-semibold"
                        : "text-[#0f172a] hover:bg-black/5"
                    }`}
                  >
                    <FolderGit2 className="w-4 h-4 text-[#64748b] shrink-0" />
                    <span className="truncate text-left">{folderName}</span>
                  </button>
                );
              })}

              <button
                onClick={() => {
                  setPage("projects");
                  setSelectedAgent(null);
                  setSelectedProject(null);
                }}
                className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
                  page === "projects"
                    ? "bg-[#e0eeff] text-[#0266ee] font-semibold"
                    : "text-[#64748b] hover:bg-black/5 hover:text-[#0f172a]"
                }`}
              >
                <FolderPlus className="w-4 h-4" />
                <span>项目管理</span>
                <span className="ml-auto text-[11px] font-bold px-1.5 py-0.5 rounded-full bg-black/5 text-[#64748b]">
                  {projects.length}
                </span>
              </button>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-3 border-t border-[#e2e7ed]/70 space-y-1">
          <button
            onClick={() => {
              setPage("settings");
              setSelectedAgent(null);
              setSelectedProject(null);
            }}
            className={`w-full flex items-center gap-2.5 px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
              page === "settings"
                ? "bg-[#e0eeff] text-[#0266ee] font-semibold"
                : "text-[#0f172a] hover:bg-black/5"
            }`}
          >
            <Settings className="w-4 h-4 text-[#64748b]" />
            <span>设置</span>
          </button>

          <div className="flex items-center gap-2 px-2.5 py-1.5 text-[11px] font-medium text-[#64748b]">
            <span className="w-2 h-2 rounded-full bg-[#10b981]" />
            <span>本机扫描正常</span>
          </div>
        </div>
      </div>
    </aside>
  );
};
