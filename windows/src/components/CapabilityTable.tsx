import React from "react";
import { GitBranch, Trash2, ExternalLink, Plus } from "lucide-react";
import { DisplayItem, TargetStatus } from "../types";
import { AgentIcon } from "./AgentIcon";
import { Badge } from "./ui/Badge";

interface CapabilityTableProps {
  items: DisplayItem[];
  selectedAgent: string | null;
  onSelect: (item: DisplayItem) => void;
  onToggleTarget: (item: DisplayItem, target: TargetStatus) => void;
  onAdopt: (item: DisplayItem) => void;
  onDelete: (item: DisplayItem) => void;
}

export const CapabilityTable: React.FC<CapabilityTableProps> = ({
  items,
  selectedAgent,
  onSelect,
  onToggleTarget,
  onAdopt,
  onDelete,
}) => {
  return (
    <div className="bg-white rounded-xl border border-[#e2e7ed] overflow-hidden shadow-2xs">
      <table className="w-full text-left text-xs text-[#0f172a] border-collapse">
        <thead className="bg-[#f8fafd] border-b border-[#e2e7ed] text-[#64748b] text-[11px] font-semibold uppercase">
          <tr>
            <th className="py-2.5 px-4 w-10">状态</th>
            <th className="py-2.5 px-4">能力名称</th>
            <th className="py-2.5 px-4">类型</th>
            <th className="py-2.5 px-4">说明</th>
            <th className="py-2.5 px-4">客户端挂载</th>
            <th className="py-2.5 px-4 text-right">操作</th>
          </tr>
        </thead>
        <tbody className="divide-y divide-[#e2e7ed]">
          {items.map((item) => {
            const isActiveHere = selectedAgent
              ? item.targets.some((t) => t.agent === selectedAgent && t.isDeployed)
              : item.activeCount > 0;

            return (
              <tr key={item.id} className="hover:bg-slate-50/80 transition">
                <td className="py-3 px-4">
                  <span
                    className={`w-2 h-2 rounded-full inline-block ${
                      isActiveHere ? "bg-[#10b981]" : "bg-slate-300"
                    }`}
                  />
                </td>
                <td className="py-3 px-4 font-bold text-slate-900">
                  <div className="flex items-center gap-1.5">
                    <span
                      onClick={() => onSelect(item)}
                      className="cursor-pointer hover:text-[#2563eb] transition"
                    >
                      {item.name}
                    </span>
                    {item.gitSource && (
                      <Badge variant="blue" className="text-[9px] px-1.5 py-0">
                        <GitBranch className="w-2.5 h-2.5 mr-0.5 inline" />
                        Git
                      </Badge>
                    )}
                    {!item.isLibrary && (
                      <Badge variant="amber" className="text-[9px] px-1.5 py-0">
                        待入库
                      </Badge>
                    )}
                  </div>
                </td>
                <td className="py-3 px-4 text-slate-600">
                  <Badge variant="secondary" className="text-[10px]">
                    {item.typeLabel}
                  </Badge>
                </td>
                <td className="py-3 px-4 text-slate-500 max-w-xs truncate">
                  {item.description || "暂无描述"}
                </td>
                <td className="py-3 px-4">
                  {item.isLibrary ? (
                    <div className="flex items-center gap-1">
                      {item.targets.map((target) => (
                        <button
                          key={target.agent}
                          onClick={() => onToggleTarget(item, target)}
                          title={`${target.agentName} · ${
                            target.isDeployed ? "已启用" : "未分发"
                          }`}
                          className={`relative w-6 h-6 rounded-md border flex items-center justify-center transition cursor-pointer ${
                            target.isDeployed
                              ? "bg-slate-50 border-slate-300"
                              : "bg-white border-slate-200 opacity-60 hover:opacity-100"
                          }`}
                        >
                          <AgentIcon agent={target.agent} size={14} />
                          {target.isDeployed && (
                            <span className="absolute -bottom-0.5 -right-0.5 w-1.5 h-1.5 rounded-full bg-[#10b981]" />
                          )}
                        </button>
                      ))}
                    </div>
                  ) : (
                    <button
                      onClick={() => onAdopt(item)}
                      className="inline-flex items-center gap-1 px-2.5 py-0.5 bg-indigo-600 hover:bg-indigo-700 text-white rounded-full text-[11px] font-semibold transition cursor-pointer"
                    >
                      <Plus className="w-3 h-3" />
                      <span>入库</span>
                    </button>
                  )}
                </td>
                <td className="py-3 px-4 text-right">
                  <div className="inline-flex items-center gap-1">
                    <button
                      onClick={() => onSelect(item)}
                      title="详情"
                      className="p-1 rounded text-slate-400 hover:text-slate-700 transition cursor-pointer"
                    >
                      <ExternalLink className="w-3.5 h-3.5" />
                    </button>
                    {item.isLibrary && (
                      <button
                        onClick={() => onDelete(item)}
                        title="删除"
                        className="p-1 rounded text-slate-400 hover:text-red-600 transition cursor-pointer"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </div>
  );
};
