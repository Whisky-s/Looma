import React from "react";
import { GitBranch, Trash2, ExternalLink, Plus } from "lucide-react";
import { DisplayItem, TargetStatus } from "../types";
import { AgentIcon } from "./AgentIcon";
import { Badge } from "./ui/Badge";

interface CapabilityCardProps {
  item: DisplayItem;
  selectedAgent: string | null;
  onSelect: (item: DisplayItem) => void;
  onToggleTarget: (item: DisplayItem, target: TargetStatus) => void;
  onAdopt: (item: DisplayItem) => void;
  onDelete: (item: DisplayItem) => void;
}

export const CapabilityCard: React.FC<CapabilityCardProps> = ({
  item,
  selectedAgent,
  onSelect,
  onToggleTarget,
  onAdopt,
  onDelete,
}) => {
  const isTargetEnabled = (target: TargetStatus) => target.isDeployed;

  // Active state relative to current selection
  const isActiveHere = selectedAgent
    ? item.targets.some((t) => t.agent === selectedAgent && isTargetEnabled(t))
    : item.activeCount > 0;

  return (
    <div className="bg-white rounded-xl border border-[#e2e7ed] p-4 shadow-2xs hover:shadow-md transition-all duration-150 flex flex-col justify-between group">
      <div>
        {/* Header row */}
        <div className="flex items-center justify-between gap-2">
          <div className="flex items-center gap-2 min-w-0 flex-1">
            <span
              className={`w-2 h-2 rounded-full shrink-0 ${
                isActiveHere ? "bg-[#10b981]" : "bg-slate-300"
              }`}
            />
            <span
              onClick={() => onSelect(item)}
              className="text-sm font-bold text-[#0f172a] truncate cursor-pointer hover:text-[#2563eb] transition"
              title={item.name}
            >
              {item.name}
            </span>
          </div>

          <div className="flex items-center gap-1.5 shrink-0">
            {/* Capability type badge */}
            <Badge variant="secondary" className="text-[10px] px-2 py-0.5">
              {item.typeLabel}
            </Badge>

            {/* Git badge */}
            {item.gitSource && (
              <Badge variant="blue" className="text-[10px] gap-1 px-1.5 py-0.5">
                <GitBranch className="w-2.5 h-2.5" />
                <span>Git</span>
              </Badge>
            )}

            {/* Unadopted badge */}
            {!item.isLibrary && !item.isSystemService && (
              <Badge variant="amber" className="text-[10px] px-2 py-0.5">
                待入库
              </Badge>
            )}
          </div>
        </div>

        {/* Description box */}
        <div
          onClick={() => onSelect(item)}
          className="mt-3 p-2.5 bg-[#f8fafd] border border-slate-100 rounded-lg text-xs text-[#64748b] line-clamp-2 min-h-[46px] cursor-pointer hover:bg-blue-50/40 transition"
        >
          {item.description || "暂无描述"}
        </div>
      </div>

      {/* Footer divider & actions */}
      <div className="mt-3 pt-3 border-t border-[#e2e7ed]">
        <div className="flex items-center justify-between gap-2">
          {/* Left: Agent quick toggle buttons or Unadopted action */}
          {item.isLibrary ? (
            <div className="flex items-center gap-1.5">
              {item.targets.map((target) => {
                const isSelected = selectedAgent === target.agent;
                const deployed = target.isDeployed;

                return (
                  <button
                    key={target.agent}
                    onClick={() => onToggleTarget(item, target)}
                    title={`${target.agentName} · ${
                      deployed ? "已启用 (点击停用)" : "未分发 (点击一键部署)"
                    }`}
                    className={`relative w-7 h-7 rounded-lg border flex items-center justify-center transition cursor-pointer ${
                      isSelected
                        ? "bg-blue-50 border-[#2563eb]"
                        : deployed
                        ? "bg-slate-50 border-slate-300 hover:border-slate-400"
                        : "bg-white border-slate-200 opacity-60 hover:opacity-100 hover:border-blue-400"
                    }`}
                  >
                    <AgentIcon agent={target.agent} size={15} />

                    {/* Corner status dot */}
                    {deployed && (
                      <span className="absolute -bottom-0.5 -right-0.5 w-2 h-2 rounded-full bg-[#10b981] border border-white" />
                    )}
                  </button>
                );
              })}

              {item.activeCount > 0 && (
                <span className="ml-1 text-[10px] font-semibold text-[#10b981] bg-emerald-50 border border-emerald-200 px-2 py-0.5 rounded-full">
                  {item.activeCount} 处启用
                </span>
              )}
            </div>
          ) : (
            <div className="flex items-center gap-2">
              <span className="text-[11px] text-[#64748b]">
                发现 · {item.externalPaths.length || 1} 处来源
              </span>
              <button
                onClick={() => onAdopt(item)}
                className="inline-flex items-center gap-1 px-3 py-1 bg-indigo-600 hover:bg-indigo-700 text-white rounded-full text-xs font-semibold shadow-xs transition cursor-pointer"
              >
                <Plus className="w-3 h-3" />
                <span>入中央库</span>
              </button>
            </div>
          )}

          {/* Right: Actions menu */}
          <div className="flex items-center gap-1">
            <button
              onClick={() => onSelect(item)}
              title="查看详情与配置"
              className="p-1 rounded-md text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition cursor-pointer"
            >
              <ExternalLink className="w-3.5 h-3.5" />
            </button>

            {item.isLibrary && (
              <button
                onClick={() => onDelete(item)}
                title="从中央库删除"
                className="p-1 rounded-md text-slate-400 hover:text-red-600 hover:bg-red-50 transition cursor-pointer"
              >
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
