import React from "react";
import { HelpCircle } from "lucide-react";
import { AgentStatus } from "../types";

interface HeaderProps {
  page: "skills" | "mcp" | "presets" | "projects" | "settings";
  selectedAgent: string | null;
  selectedProject: string | null;
  agents: AgentStatus[];
}

export const Header: React.FC<HeaderProps> = ({
  page,
  selectedAgent,
  selectedProject,
  agents,
}) => {
  const getTitle = () => {
    switch (page) {
      case "skills":
        return "Skills 技能库";
      case "mcp":
        return "MCP 服务库";
      case "presets":
        return "预设能力组合";
      case "projects":
        return "项目工作区管理";
      case "settings":
        return "全局设置";
      default:
        return "能力库";
    }
  };

  const getSubtitle = () => {
    switch (page) {
      case "skills":
        return "管理全局与项目工作区的技能扩展，支持跨客户端一键分发与版本同步";
      case "mcp":
        return "统一管理 Model Context Protocol 服务配置，支持 stdio、sse 快速挂载";
      case "presets":
        return "一键将预设技能与服务组合应用到指定客户端或项目";
      case "projects":
        return "注册与管理本地代码仓库，启用项目隔离的 Skills 与 MCP 配置";
      case "settings":
        return "查看中央库数据根目录、客户端检测详情及应用版本信息";
      default:
        return "";
    }
  };

  const agentName = selectedAgent
    ? agents.find((a) => a.agent === selectedAgent)?.name || selectedAgent
    : "全部客户端";
  const projectName = selectedProject
    ? selectedProject.split(/[\\/]/).filter(Boolean).pop()
    : null;
  const targetLabel = projectName ? `项目 · ${projectName}` : "全局";

  return (
    <div className="flex items-center justify-between px-8 pt-8 pb-4 shrink-0">
      <div>
        <div className="flex items-center gap-2.5">
          <h1 className="text-2xl font-bold tracking-tight text-[#0f172a]">{getTitle()}</h1>
          <span title={getSubtitle()} className="cursor-help">
            <HelpCircle className="w-4 h-4 text-[#64748b] hover:text-[#0f172a] transition" />
          </span>
        </div>
        <p className="text-xs text-[#64748b] mt-1">{getSubtitle()}</p>

        {(page === "skills" || page === "mcp") && (
          <div className="mt-1 text-[11px] font-semibold text-[#2563eb]">
            操作目标：{targetLabel} · {agentName}
          </div>
        )}
      </div>

      {/* Looma badge */}
      <div className="flex items-center gap-2 px-3 py-1.5 bg-white rounded-full border border-[#e2e7ed] shadow-xs">
        <span className="w-2 h-2 rounded-full bg-[#10b981]" />
        <span className="text-xs font-bold text-[#0f172a]">Looma</span>
        <span className="text-[11px] font-semibold font-mono text-[#2563eb]">v0.1.4</span>
      </div>
    </div>
  );
};
