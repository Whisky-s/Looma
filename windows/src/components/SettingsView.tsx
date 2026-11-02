import React from "react";
import { Folder, Terminal, Info, History } from "lucide-react";
import { AgentStatus, HistoryRecord } from "../types";
import { AgentIcon } from "./AgentIcon";
import { Badge } from "./ui/Badge";

interface SettingsViewProps {
  agents: AgentStatus[];
  history: HistoryRecord[];
}

export const SettingsView: React.FC<SettingsViewProps> = ({ agents, history }) => {
  return (
    <div className="flex-1 overflow-y-auto px-8 py-4 space-y-6">
      {/* Central Library Roots */}
      <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-4">
        <div className="flex items-center gap-2">
          <Folder className="w-4 h-4 text-[#2563eb]" />
          <h2 className="text-sm font-bold text-[#0f172a]">中央库存储路径</h2>
        </div>

        <div className="space-y-3 text-xs">
          <div className="p-3 bg-[#f8fafd] border border-slate-100 rounded-lg">
            <div className="font-semibold text-slate-700">Windows 数据根目录</div>
            <div className="font-mono text-slate-500 mt-1 select-text">
              %APPDATA%\AgentManager
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div className="p-3 bg-[#f8fafd] border border-slate-100 rounded-lg">
              <div className="font-semibold text-slate-700">Skills 技能存储库</div>
              <div className="font-mono text-slate-500 mt-1 select-text">
                %APPDATA%\AgentManager\skills
              </div>
            </div>
            <div className="p-3 bg-[#f8fafd] border border-slate-100 rounded-lg">
              <div className="font-semibold text-slate-700">MCP 服务配置库</div>
              <div className="font-mono text-slate-500 mt-1 select-text">
                %APPDATA%\AgentManager\mcp
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Agents Detection Status */}
      <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-4">
        <div className="flex items-center gap-2">
          <Terminal className="w-4 h-4 text-[#10b981]" />
          <h2 className="text-sm font-bold text-[#0f172a]">客户端环境检测</h2>
        </div>

        <div className="grid grid-cols-2 gap-3">
          {agents.map((agent) => (
            <div
              key={agent.agent}
              className="p-3.5 bg-[#f8fafd] border border-slate-100 rounded-xl flex items-center justify-between"
            >
              <div className="flex items-center gap-3">
                <AgentIcon agent={agent.agent} size={24} />
                <div>
                  <div className="text-xs font-bold text-[#0f172a]">{agent.name}</div>
                  <div className="text-[10px] text-slate-400 font-mono truncate max-w-[200px]">
                    {agent.global_mcp_path}
                  </div>
                </div>
              </div>

              <Badge
                variant={agent.installed ? "mint" : "secondary"}
                className="text-[10px]"
              >
                {agent.installed ? "已安装" : "未检测到"}
              </Badge>
            </div>
          ))}
        </div>
      </div>

      {/* History Records */}
      {history.length > 0 && (
        <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-3">
          <div className="flex items-center gap-2">
            <History className="w-4 h-4 text-purple-600" />
            <h2 className="text-sm font-bold text-[#0f172a]">近期操作历史 ({history.length})</h2>
          </div>
          <div className="space-y-1.5 max-h-48 overflow-y-auto pr-1">
            {history.slice(0, 15).map((record) => (
              <div
                key={record.id}
                className="p-2.5 bg-[#f8fafd] border border-slate-100 rounded-lg text-xs flex items-center justify-between"
              >
                <div className="flex items-center gap-2">
                  <Badge variant="secondary" className="text-[10px]">
                    {record.action}
                  </Badge>
                  <span className="font-semibold text-slate-800">{record.target}</span>
                  {record.details && <span className="text-slate-400">({record.details})</span>}
                </div>
                <span className="text-[10px] text-slate-400 font-mono">
                  {new Date(record.timestamp).toLocaleTimeString()}
                </span>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* About Box */}
      <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-3">
        <div className="flex items-center gap-2">
          <Info className="w-4 h-4 text-[#2563eb]" />
          <h2 className="text-sm font-bold text-[#0f172a]">关于 Looma</h2>
        </div>

        <div className="text-xs text-slate-600 space-y-2">
          <p>
            Looma 是一款跨平台的 AI 技能与 MCP 服务管理器，为 Claude Code、Cursor、OpenAI Codex、Antigravity、Qoder、WorkBuddy 等客户端提供统一的一站式能力分发与版本控制。
          </p>
          <div className="flex items-center gap-3 pt-2 text-[11px] text-slate-500 font-medium">
            <span>版本：v0.1.3 (Windows Edition)</span>
            <span>·</span>
            <span>架构：Tauri 2.0 (Rust + React + Tailwind)</span>
            <span>·</span>
            <span>作者：Whisky</span>
          </div>
        </div>
      </div>
    </div>
  );
};
