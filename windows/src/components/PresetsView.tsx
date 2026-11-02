import React, { useState } from "react";
import { Layers, Plus, Play } from "lucide-react";
import { Preset, AgentStatus } from "../types";
import { Button } from "./ui/Button";
import { Badge } from "./ui/Badge";
import { AgentIcon } from "./AgentIcon";

interface PresetsViewProps {
  presets: Preset[];
  agents: AgentStatus[];
  onApplyPreset: (preset: Preset, agentId: string) => void;
  onSavePreset: (preset: Preset) => void;
}

export const PresetsView: React.FC<PresetsViewProps> = ({
  presets,
  agents,
  onApplyPreset,
  onSavePreset,
}) => {
  const [targetAgent, setTargetAgent] = useState<string>("claude");
  const [showCreate, setShowCreate] = useState(false);
  const [newName, setNewName] = useState("");
  const [newDesc, setNewDesc] = useState("");
  const [newSkills, setNewSkills] = useState("");
  const [newMcps, setNewMcps] = useState("");

  const handleCreate = () => {
    if (!newName.trim()) return;
    const skills = newSkills
      .split(/[,，\n]/)
      .map((s) => s.trim())
      .filter(Boolean);
    const mcps = newMcps
      .split(/[,，\n]/)
      .map((m) => m.trim())
      .filter(Boolean);
    onSavePreset({
      name: newName.trim(),
      description: newDesc.trim() || "自定义能力预设",
      skills,
      mcps,
    });
    setNewName("");
    setNewDesc("");
    setNewSkills("");
    setNewMcps("");
    setShowCreate(false);
  };

  return (
    <div className="flex-1 overflow-y-auto px-8 py-4 space-y-6">
      {/* Top action bar */}
      <div className="flex items-center justify-between bg-white rounded-xl border border-[#e2e7ed] p-4 shadow-2xs">
        <div>
          <h2 className="text-sm font-bold text-[#0f172a]">预设能力组合方案</h2>
          <p className="text-xs text-[#64748b] mt-0.5">
            预先搭配好的 Skills 技能与 MCP 服务方案，可针对不同项目或目标客户端一键部署
          </p>
        </div>

        <div className="flex items-center gap-3">
          <div className="flex items-center gap-2 text-xs text-slate-700">
            <span>目标客户端:</span>
            <select
              value={targetAgent}
              onChange={(e) => setTargetAgent(e.target.value)}
              className="bg-slate-50 border border-slate-200 rounded-lg px-2.5 py-1 text-xs font-semibold text-slate-800 focus:outline-none focus:ring-1 focus:ring-blue-500"
            >
              {agents.map((a) => (
                <option key={a.agent} value={a.agent}>
                  {a.name}
                </option>
              ))}
            </select>
          </div>

          <Button size="sm" onClick={() => setShowCreate(!showCreate)} className="gap-1.5">
            <Plus className="w-3.5 h-3.5" />
            <span>新建预设</span>
          </Button>
        </div>
      </div>

      {showCreate && (
        <div className="bg-white rounded-xl border border-blue-200 p-5 shadow-sm space-y-3">
          <h3 className="text-xs font-bold text-slate-900">创建新预设组合</h3>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-[11px] font-semibold text-slate-600 mb-1">预设名称</label>
              <input
                type="text"
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                placeholder="例如：Web 前端开发包"
                className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-[11px] font-semibold text-slate-600 mb-1">方案说明</label>
              <input
                type="text"
                value={newDesc}
                onChange={(e) => setNewDesc(e.target.value)}
                placeholder="简述该组合适用场景"
                className="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </div>
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-[11px] font-semibold text-slate-600 mb-1">
                包含的技能名称 (逗号或换行分隔)
              </label>
              <textarea
                value={newSkills}
                onChange={(e) => setNewSkills(e.target.value)}
                rows={3}
                placeholder="git-workflow, prd-generator"
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2.5 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </div>
            <div>
              <label className="block text-[11px] font-semibold text-slate-600 mb-1">
                包含的 MCP 名称 (逗号或换行分隔)
              </label>
              <textarea
                value={newMcps}
                onChange={(e) => setNewMcps(e.target.value)}
                rows={3}
                placeholder="filesystem, fetch, memory"
                className="w-full bg-slate-50 border border-slate-200 rounded-lg p-2.5 text-xs text-slate-800 focus:outline-none focus:ring-1 focus:ring-blue-500"
              />
            </div>
          </div>
          <div className="flex justify-end gap-2 pt-2">
            <Button variant="ghost" size="sm" onClick={() => setShowCreate(false)}>
              取消
            </Button>
            <Button size="sm" onClick={handleCreate}>
              保存预设
            </Button>
          </div>
        </div>
      )}

      {/* Presets grid */}
      <div className="grid grid-cols-2 gap-4">
        {presets.map((preset) => (
          <div
            key={preset.name}
            className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs hover:shadow-md transition-all flex flex-col justify-between"
          >
            <div>
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Layers className="w-4 h-4 text-[#2563eb]" />
                  <h3 className="text-sm font-bold text-[#0f172a]">{preset.name}</h3>
                </div>
                <Badge variant="blue" className="text-[10px]">
                  预设组合
                </Badge>
              </div>

              <p className="text-xs text-[#64748b] mt-2">{preset.description}</p>

              <div className="mt-4 space-y-2">
                <div>
                  <div className="text-[11px] font-semibold text-slate-500">Skills ({preset.skills.length})</div>
                  <div className="flex flex-wrap gap-1 mt-1">
                    {preset.skills.length > 0 ? (
                      preset.skills.map((s) => (
                        <Badge key={s} variant="secondary" className="text-[10px]">
                          {s}
                        </Badge>
                      ))
                    ) : (
                      <span className="text-[11px] text-slate-400">无技能</span>
                    )}
                  </div>
                </div>

                <div>
                  <div className="text-[11px] font-semibold text-slate-500">MCP 服务 ({preset.mcps.length})</div>
                  <div className="flex flex-wrap gap-1 mt-1">
                    {preset.mcps.length > 0 ? (
                      preset.mcps.map((m) => (
                        <Badge key={m} variant="secondary" className="text-[10px]">
                          {m}
                        </Badge>
                      ))
                    ) : (
                      <span className="text-[11px] text-slate-400">无 MCP</span>
                    )}
                  </div>
                </div>
              </div>
            </div>

            <div className="mt-5 pt-3 border-t border-[#e2e7ed] flex items-center justify-between">
              <div className="flex items-center gap-1.5 text-xs text-slate-500">
                <AgentIcon agent={targetAgent} size={16} />
                <span>目标: {agents.find((a) => a.agent === targetAgent)?.name || targetAgent}</span>
              </div>

              <Button
                size="sm"
                onClick={() => onApplyPreset(preset, targetAgent)}
                className="gap-1.5"
              >
                <Play className="w-3 h-3 fill-current" />
                <span>全量应用</span>
              </Button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
