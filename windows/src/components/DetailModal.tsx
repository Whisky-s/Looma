import React, { useState } from "react";
import { Copy, Check } from "lucide-react";
import { DisplayItem, TargetStatus } from "../types";
import { Dialog } from "./ui/Dialog";
import { Badge } from "./ui/Badge";
import { Button } from "./ui/Button";
import { AgentIcon } from "./AgentIcon";

interface DetailModalProps {
  item: DisplayItem | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onToggleTarget: (item: DisplayItem, target: TargetStatus) => void;
}

export const DetailModal: React.FC<DetailModalProps> = ({
  item,
  open,
  onOpenChange,
  onToggleTarget,
}) => {
  const [copied, setCopied] = useState(false);

  if (!item) return null;

  const handleCopy = () => {
    let text = "";
    if (item.kind === "mcp" && item.rawMcp) {
      text = JSON.stringify(item.rawMcp.definition, null, 2);
    } else if (item.rawSkill) {
      text = item.rawSkill.description;
    }
    navigator.clipboard.writeText(text);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={item.name}
      description={item.kind === "skill" ? "Skill 技能详情与客户端挂载" : "MCP 服务配置与客户端挂载"}
      maxWidth="max-w-xl"
    >
      <div className="space-y-4">
        {/* Badges Row */}
        <div className="flex items-center gap-2">
          <Badge variant="secondary">{item.typeLabel}</Badge>
          {item.isLibrary ? (
            <Badge variant="mint">已在中央库</Badge>
          ) : (
            <Badge variant="amber">外部发现 · 待入库</Badge>
          )}
          {item.gitSource && <Badge variant="blue">Git 关联</Badge>}
        </div>

        {/* Description */}
        <div className="text-xs text-slate-700 bg-[#f8fafd] border border-slate-100 rounded-lg p-3">
          <div className="font-semibold text-slate-900 mb-1">功能描述</div>
          <div className="leading-relaxed">{item.description || "暂无描述"}</div>
        </div>

        {/* Configuration or Code definition */}
        {item.kind === "mcp" && item.rawMcp && (
          <div>
            <div className="flex items-center justify-between mb-1.5">
              <span className="text-xs font-semibold text-slate-700">配置定义 (JSON)</span>
              <button
                onClick={handleCopy}
                className="inline-flex items-center gap-1 text-[11px] text-[#2563eb] hover:underline cursor-pointer"
              >
                {copied ? <Check className="w-3 h-3 text-emerald-600" /> : <Copy className="w-3 h-3" />}
                <span>{copied ? "已复制" : "复制代码"}</span>
              </button>
            </div>
            <pre className="bg-slate-900 text-slate-100 p-3 rounded-xl text-[11px] font-mono overflow-x-auto max-h-48">
              {JSON.stringify(item.rawMcp.definition, null, 2)}
            </pre>
          </div>
        )}

        {/* Client Deployments Switch List */}
        <div>
          <div className="text-xs font-semibold text-slate-700 mb-2">
            客户端分发与挂载状态
          </div>
          <div className="space-y-1.5">
            {item.targets.map((target) => {
              const deployed = target.isDeployed;

              return (
                <div
                  key={target.agent}
                  className="flex items-center justify-between p-2.5 rounded-lg border border-slate-100 bg-[#f8fafd]"
                >
                  <div className="flex items-center gap-2.5">
                    <AgentIcon agent={target.agent} size={20} />
                    <div>
                      <div className="text-xs font-bold text-slate-900">{target.agentName}</div>
                      <div className="text-[10px] text-slate-400">
                        {target.isAgentInstalled ? "客户端已就绪" : "客户端未检测到"}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2">
                    <span
                      className={`text-[11px] font-semibold ${
                        deployed ? "text-[#10b981]" : "text-slate-400"
                      }`}
                    >
                      {deployed ? "已分发挂载" : "未挂载"}
                    </span>
                    <button
                      onClick={() => onToggleTarget(item, target)}
                      className={`px-3 py-1 rounded-full text-xs font-semibold transition cursor-pointer ${
                        deployed
                          ? "bg-red-50 text-red-600 hover:bg-red-100 border border-red-200"
                          : "bg-blue-600 text-white hover:bg-blue-700"
                      }`}
                    >
                      {deployed ? "停用" : "一键部署"}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        </div>

        <div className="flex justify-end pt-3 border-t border-slate-100">
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            关闭
          </Button>
        </div>
      </div>
    </Dialog>
  );
};
