import React from "react";
import {
  Search,
  X,
  LayoutGrid,
  List,
  Plus,
  GitBranch,
  FolderDown,
  Layers,
  Cpu,
} from "lucide-react";
import { Button } from "./ui/Button";

interface ToolbarProps {
  page: "skills" | "mcp";
  setPage: (page: "skills" | "mcp") => void;
  sourceFilter: "all" | "library" | "unadopted";
  setSourceFilter: (filter: "all" | "library" | "unadopted") => void;
  statusFilter: "all" | "enabled" | "available";
  setStatusFilter: (filter: "all" | "enabled" | "available") => void;
  searchQuery: string;
  setSearchQuery: (q: string) => void;
  viewMode: "grid" | "table";
  setViewMode: (mode: "grid" | "table") => void;
  totalCount: number;
  libraryCount: number;
  unadoptedCount: number;
  displayCount: number;
  onNewMcp: () => void;
  onImportLocal: () => void;
  onImportGit: () => void;
}

export const Toolbar: React.FC<ToolbarProps> = ({
  page,
  setPage,
  sourceFilter,
  setSourceFilter,
  statusFilter,
  setStatusFilter,
  searchQuery,
  setSearchQuery,
  viewMode,
  setViewMode,
  totalCount,
  libraryCount,
  unadoptedCount,
  displayCount,
  onNewMcp,
  onImportLocal,
  onImportGit,
}) => {
  return (
    <div className="px-8 pb-4 space-y-3 shrink-0">
      {/* Category Tabs & Source Filters */}
      <div className="flex items-center justify-between">
        {/* Category switcher */}
        <div className="inline-flex p-1 bg-white/70 rounded-xl border border-[#e2e7ed] shadow-2xs">
          <button
            onClick={() => setPage("skills")}
            className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition cursor-pointer ${
              page === "skills"
                ? "bg-[#2563eb] text-white shadow-xs"
                : "text-[#64748b] hover:text-[#0f172a]"
            }`}
          >
            <Layers className="w-3.5 h-3.5" />
            <span>Skills 技能库</span>
          </button>
          <button
            onClick={() => setPage("mcp")}
            className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold transition cursor-pointer ${
              page === "mcp"
                ? "bg-[#2563eb] text-white shadow-xs"
                : "text-[#64748b] hover:text-[#0f172a]"
            }`}
          >
            <Cpu className="w-3.5 h-3.5" />
            <span>MCP 服务库</span>
          </button>
        </div>

        {/* Source filter pills */}
        <div className="inline-flex p-1 bg-white/70 rounded-full border border-[#e2e7ed] shadow-2xs space-x-1">
          <button
            onClick={() => setSourceFilter("all")}
            className={`px-3 py-1 rounded-full text-xs font-semibold transition cursor-pointer ${
              sourceFilter === "all"
                ? "bg-[#2563eb] text-white shadow-xs"
                : "text-[#64748b] hover:text-[#0f172a]"
            }`}
          >
            全部能力 ({totalCount})
          </button>
          <button
            onClick={() => setSourceFilter("library")}
            className={`px-3 py-1 rounded-full text-xs font-semibold transition cursor-pointer ${
              sourceFilter === "library"
                ? "bg-[#2563eb] text-white shadow-xs"
                : "text-[#64748b] hover:text-[#0f172a]"
            }`}
          >
            仅中央库 ({libraryCount})
          </button>
          <button
            onClick={() => setSourceFilter("unadopted")}
            className={`px-3 py-1 rounded-full text-xs font-semibold transition cursor-pointer ${
              sourceFilter === "unadopted"
                ? "bg-[#f59e0b] text-white shadow-xs"
                : "text-[#64748b] hover:text-[#0f172a]"
            }`}
          >
            待入库发现 ({unadoptedCount})
          </button>
        </div>
      </div>

      {/* Search Bar & Action Buttons */}
      <div className="flex items-center gap-3">
        {/* Search input box */}
        <div className="flex-1 flex items-center gap-2 px-3 py-1.5 bg-[#f8fafd] rounded-xl border border-[#e2e7ed] focus-within:border-[#2563eb] focus-within:ring-1 focus-within:ring-[#2563eb] transition">
          <Search className="w-4 h-4 text-[#64748b] shrink-0" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="搜索能力名称、指令参数或详细说明..."
            className="flex-1 bg-transparent text-xs text-[#0f172a] placeholder:text-slate-400 focus:outline-none"
          />
          {searchQuery && (
            <button
              onClick={() => setSearchQuery("")}
              className="text-[#64748b] hover:text-[#0f172a]"
            >
              <X className="w-3.5 h-3.5" />
            </button>
          )}
          <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-black/5 text-[#64748b]">
            {displayCount} 项
          </span>
        </div>

        {/* View mode toggle */}
        <div className="flex items-center p-1 bg-[#f8fafd] rounded-xl border border-[#e2e7ed]">
          <button
            onClick={() => setViewMode("grid")}
            className={`p-1.5 rounded-lg transition cursor-pointer ${
              viewMode === "grid"
                ? "bg-white text-[#0f172a] shadow-xs"
                : "text-[#64748b] hover:text-[#0f172a]"
            }`}
            title="网格视图"
          >
            <LayoutGrid className="w-3.5 h-3.5" />
          </button>
          <button
            onClick={() => setViewMode("table")}
            className={`p-1.5 rounded-lg transition cursor-pointer ${
              viewMode === "table"
                ? "bg-white text-[#0f172a] shadow-xs"
                : "text-[#64748b] hover:text-[#0f172a]"
            }`}
            title="表格视图"
          >
            <List className="w-3.5 h-3.5" />
          </button>
        </div>

        {/* Status filters */}
        <div className="flex items-center gap-1.5">
          <button
            onClick={() => setStatusFilter("all")}
            className={`px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
              statusFilter === "all"
                ? "bg-[#2563eb] text-white font-semibold"
                : "bg-white border border-[#e2e7ed] text-[#64748b] hover:text-[#0f172a]"
            }`}
          >
            全部
          </button>
          <button
            onClick={() => setStatusFilter("enabled")}
            className={`px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
              statusFilter === "enabled"
                ? "bg-[#2563eb] text-white font-semibold"
                : "bg-white border border-[#e2e7ed] text-[#64748b] hover:text-[#0f172a]"
            }`}
          >
            已启用
          </button>
          <button
            onClick={() => setStatusFilter("available")}
            className={`px-2.5 py-1.5 rounded-lg text-xs font-medium transition cursor-pointer ${
              statusFilter === "available"
                ? "bg-[#2563eb] text-white font-semibold"
                : "bg-white border border-[#e2e7ed] text-[#64748b] hover:text-[#0f172a]"
            }`}
          >
            可启用
          </button>
        </div>

        <div className="w-px h-6 bg-[#e2e7ed]" />

        {/* Primary Action Buttons */}
        {page === "skills" ? (
          <div className="flex items-center gap-2">
            <Button variant="outline" size="sm" onClick={onImportGit} className="gap-1.5">
              <GitBranch className="w-3.5 h-3.5 text-[#2563eb]" />
              <span>从 Git 导入</span>
            </Button>
            <Button variant="outline" size="sm" onClick={onImportLocal} className="gap-1.5">
              <FolderDown className="w-3.5 h-3.5 text-[#64748b]" />
              <span>本地导入</span>
            </Button>
          </div>
        ) : (
          <div className="flex items-center gap-2">
            <Button variant="default" size="sm" onClick={onNewMcp} className="gap-1.5">
              <Plus className="w-3.5 h-3.5" />
              <span>新建 MCP</span>
            </Button>
            <Button variant="outline" size="sm" onClick={onImportLocal} className="gap-1.5">
              <FolderDown className="w-3.5 h-3.5 text-[#64748b]" />
              <span>本地导入</span>
            </Button>
          </div>
        )}
      </div>
    </div>
  );
};
