import React, { useState, useEffect } from "react";
import { invoke } from "@tauri-apps/api/core";
import {
  SlidersHorizontal,
  HardDrive,
  Clock,
  LayoutGrid,
  Folder,
  FolderOpen,
  Sparkles,
  RefreshCw,
  RotateCcw,
  Plus,
  Trash2,
  Check,
} from "lucide-react";
import { AgentStatus, HistoryRecord, BackupRecord, UserPreferences } from "../types";
import { AgentIcon } from "./AgentIcon";
import { Badge } from "./ui/Badge";
import { Button } from "./ui/Button";

interface SettingsViewProps {
  agents: AgentStatus[];
  history: HistoryRecord[];
  librarySkillCount: number;
  libraryMcpCount: number;
  projectCount: number;
  onRefreshAll: () => void;
}

const DEFAULT_PREFERENCES: UserPreferences = {
  detail_presentation_mode: "modal",
  default_markdown_mode: "preview",
  skill_deployment_mode: "link",
  default_git_branch: "main",
  enable_shallow_clone: true,
  history_limit: 50,
};

export const SettingsView: React.FC<SettingsViewProps> = ({
  agents,
  history,
  librarySkillCount,
  libraryMcpCount,
  projectCount,
  onRefreshAll,
}) => {
  const [selectedTab, setSelectedTab] = useState<"general" | "data" | "history" | "clients">("general");
  const [preferences, setPreferences] = useState<UserPreferences>(DEFAULT_PREFERENCES);
  const [backups, setBackups] = useState<BackupRecord[]>([]);
  const [loadingBackups, setLoadingBackups] = useState(false);
  const [cleaningCache, setCleaningCache] = useState(false);
  const [savedHint, setSavedHint] = useState(false);

  // Load preferences and backups
  const loadPreferencesAndBackups = async () => {
    try {
      const prefs = await invoke<UserPreferences>("get_preferences");
      if (prefs) setPreferences(prefs);
      const bList = await invoke<BackupRecord[]>("list_backups");
      setBackups(bList || []);
    } catch (err) {
      console.warn("Error loading settings info:", err);
    }
  };

  useEffect(() => {
    loadPreferencesAndBackups();
  }, [selectedTab]);

  const updatePreference = async <K extends keyof UserPreferences>(key: K, value: UserPreferences[K]) => {
    const next = { ...preferences, [key]: value };
    setPreferences(next);
    try {
      await invoke("save_preferences", { preferences: next });
      setSavedHint(true);
      setTimeout(() => setSavedHint(false), 2000);
    } catch (err) {
      console.warn("Failed to save preferences:", err);
    }
  };

  const handleOpenPath = async (path: string) => {
    try {
      await invoke("open_path", { path });
    } catch (err) {
      alert(`无法打开路径: ${err}`);
    }
  };

  const handleCreateBackup = async () => {
    try {
      setLoadingBackups(true);
      const newBackup = await invoke<BackupRecord>("create_backup");
      setBackups((prev) => [newBackup, ...prev]);
      alert(`配置快照 "${newBackup.filename}" 已成功创建！`);
      onRefreshAll();
    } catch (err) {
      alert(`创建备份失败: ${err}`);
    } finally {
      setLoadingBackups(false);
    }
  };

  const handleRestoreBackup = async (filename: string) => {
    if (!confirm(`确定要从备份快照 "${filename}" 恢复全量配置吗？当前未保存的临时改动可能会被覆盖。`)) {
      return;
    }
    try {
      await invoke("restore_backup", { filename });
      alert("配置恢复成功！正在重新加载...");
      onRefreshAll();
      loadPreferencesAndBackups();
    } catch (err) {
      alert(`恢复失败: ${err}`);
    }
  };

  const handleClearHistory = async () => {
    if (!confirm("确定要清空全部近期操作日志记录吗？")) return;
    try {
      await invoke("clear_history");
      onRefreshAll();
    } catch (err) {
      alert(`清空失败: ${err}`);
    }
  };

  const handleCleanTempGitCache = () => {
    setCleaningCache(true);
    setTimeout(() => {
      setCleaningCache(false);
      alert("Git 临时浅克隆与工作缓存已清理完毕！");
    }, 400);
  };

  const handleResetPreferences = async () => {
    if (!confirm("确定要将全部交互偏好重置为默认值吗？")) return;
    setPreferences(DEFAULT_PREFERENCES);
    try {
      await invoke("save_preferences", { preferences: DEFAULT_PREFERENCES });
      alert("偏好设置已重置为默认值");
    } catch (err) {
      alert(`重置失败: ${err}`);
    }
  };

  const tabs = [
    { id: "general", label: "常规", icon: SlidersHorizontal },
    { id: "data", label: "数据与备份", icon: HardDrive },
    { id: "history", label: "操作记录", icon: Clock },
    { id: "clients", label: "客户端与关于", icon: LayoutGrid },
  ] as const;

  return (
    <div className="flex-1 flex flex-col h-full overflow-hidden bg-[#f4f6f9]">
      {/* Top Tab Bar */}
      <div className="bg-white border-b border-[#e2e7ed] px-8 pt-3 pb-2.5 flex items-center justify-between shrink-0">
        <div className="flex items-center gap-2">
          {tabs.map((tab) => {
            const isSelected = selectedTab === tab.id;
            const Icon = tab.icon;
            return (
              <button
                key={tab.id}
                onClick={() => setSelectedTab(tab.id)}
                className={`inline-flex items-center gap-2 px-4 py-2 rounded-lg text-xs font-semibold transition cursor-pointer ${
                  isSelected
                    ? "bg-[#e0eeff] text-[#0266ee]"
                    : "text-[#64748b] hover:text-[#0f172a] hover:bg-slate-100/70"
                }`}
              >
                <Icon className={`w-4 h-4 ${isSelected ? "text-[#0266ee]" : "text-[#64748b]"}`} />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </div>

        {savedHint && (
          <div className="flex items-center gap-1.5 text-xs text-[#10b981] font-medium animate-in fade-in">
            <Check className="w-3.5 h-3.5" />
            <span>设置已自动保存</span>
          </div>
        )}
      </div>

      {/* Main Tab Content */}
      <div className="flex-1 overflow-y-auto px-8 py-6 space-y-6">
        {/* ================= Tab 1: 常规 ================= */}
        {selectedTab === "general" && (
          <div className="space-y-6 max-w-4xl">
            {/* 交互与展现偏好 */}
            <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-4">
              <div className="flex items-center gap-2 border-b border-slate-100 pb-3">
                <SlidersHorizontal className="w-4 h-4 text-indigo-600" />
                <h3 className="text-sm font-bold text-[#0f172a]">交互与展现偏好</h3>
              </div>

              <div>
                <div className="text-xs font-bold text-slate-800">能力详情交互方式</div>
                <div className="text-xs text-slate-500 mt-0.5">
                  设置点击 Skill 或 MCP 卡片时的呈现形式。默认为独立居中弹窗卡片模式。
                </div>

                <div className="grid grid-cols-2 gap-4 mt-3">
                  <div
                    onClick={() => updatePreference("detail_presentation_mode", "modal")}
                    className={`p-4 rounded-xl border-2 transition cursor-pointer ${
                      preferences.detail_presentation_mode === "modal"
                        ? "border-[#2563eb] bg-blue-50/40"
                        : "border-slate-200 bg-white hover:border-slate-300"
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-slate-900">弹窗卡片模式</span>
                      <Badge variant="blue" className="text-[10px]">推荐 · 默认</Badge>
                    </div>
                    <div className="text-xs text-slate-500 mt-2 leading-relaxed">
                      在独立宽屏弹窗中沉浸展示，可舒适阅读 SKILL.md 详细文档，主列表不受挤压。
                    </div>
                  </div>

                  <div
                    onClick={() => updatePreference("detail_presentation_mode", "sidebar")}
                    className={`p-4 rounded-xl border-2 transition cursor-pointer ${
                      preferences.detail_presentation_mode === "sidebar"
                        ? "border-[#2563eb] bg-blue-50/40"
                        : "border-slate-200 bg-white hover:border-slate-300"
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span className="text-xs font-bold text-slate-900">右侧抽屉栏模式</span>
                    </div>
                    <div className="text-xs text-slate-500 mt-2 leading-relaxed">
                      在主窗口右侧滑出抽屉边栏，主列表随之紧凑排布，适合边看边随同操作。
                    </div>
                  </div>
                </div>
              </div>

              <div className="h-px bg-slate-100" />

              {/* Markdown 初始阅读视图 */}
              <div className="flex items-center justify-between">
                <div>
                  <div className="text-xs font-bold text-slate-800">SKILL.md 初始阅读视图</div>
                  <div className="text-xs text-slate-500 mt-0.5">
                    打开技能详情时默认呈现的排版形式
                  </div>
                </div>

                <div className="inline-flex p-1 bg-slate-100 rounded-lg border border-slate-200">
                  <button
                    onClick={() => updatePreference("default_markdown_mode", "preview")}
                    className={`px-3 py-1.5 rounded-md text-xs font-semibold transition cursor-pointer ${
                      preferences.default_markdown_mode === "preview"
                        ? "bg-white text-[#2563eb] shadow-xs"
                        : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    富文本渲染预览
                  </button>
                  <button
                    onClick={() => updatePreference("default_markdown_mode", "source")}
                    className={`px-3 py-1.5 rounded-md text-xs font-semibold transition cursor-pointer ${
                      preferences.default_markdown_mode === "source"
                        ? "bg-white text-[#2563eb] shadow-xs"
                        : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    原始 Markdown 源码
                  </button>
                </div>
              </div>
            </div>

            {/* Skill 启用方式 */}
            <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-4">
              <div className="flex items-center gap-2 border-b border-slate-100 pb-3">
                <HardDrive className="w-4 h-4 text-[#2563eb]" />
                <h3 className="text-sm font-bold text-[#0f172a]">Skill 启用分发方式</h3>
              </div>

              <div className="flex items-center justify-between">
                <div>
                  <div className="text-xs font-bold text-slate-800">默认部署机制</div>
                  <div className="text-xs text-slate-500 mt-0.5">
                    向指定客户端启用 Skill 时使用的文件系统分发机制
                  </div>
                </div>

                <div className="inline-flex p-1 bg-slate-100 rounded-lg border border-slate-200">
                  <button
                    onClick={() => updatePreference("skill_deployment_mode", "link")}
                    className={`px-3 py-1.5 rounded-md text-xs font-semibold transition cursor-pointer ${
                      preferences.skill_deployment_mode === "link"
                        ? "bg-white text-[#2563eb] shadow-xs"
                        : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    目录联接 (Junction / 软链)
                  </button>
                  <button
                    onClick={() => updatePreference("skill_deployment_mode", "copy")}
                    className={`px-3 py-1.5 rounded-md text-xs font-semibold transition cursor-pointer ${
                      preferences.skill_deployment_mode === "copy"
                        ? "bg-white text-[#2563eb] shadow-xs"
                        : "text-slate-600 hover:text-slate-900"
                    }`}
                  >
                    独立副本 (Copy)
                  </button>
                </div>
              </div>

              <div className="p-3 bg-[#f8fafd] border border-slate-100 rounded-lg text-xs text-slate-600 leading-relaxed">
                {preferences.skill_deployment_mode === "link"
                  ? "✓ 目录联接（Junction / 软链接）：直接链接中央库物理目录，中央库内容更新后，各大客户端无须重新拷贝即可实时同步最新指令。"
                  : "✓ 独立副本（Copy）：在客户端目标目录完全拷贝独立文件夹，中央库更新不会影响已分发文件，适合需要针对客户端二次个性化微调的场景。"}
              </div>
            </div>

            {/* Git 导入与克隆规则 */}
            <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-4">
              <div className="flex items-center gap-2 border-b border-slate-100 pb-3">
                <Sparkles className="w-4 h-4 text-[#2563eb]" />
                <h3 className="text-sm font-bold text-[#0f172a]">Git 导入与克隆规则</h3>
              </div>

              <div className="flex items-center justify-between">
                <div>
                  <div className="text-xs font-bold text-slate-800">默认克隆分支 (Default Branch)</div>
                  <div className="text-xs text-slate-500 mt-0.5">
                    从 Git 导入新技能时预填的分支名称 (例如 main, master)
                  </div>
                </div>

                <input
                  type="text"
                  value={preferences.default_git_branch}
                  onChange={(e) => updatePreference("default_git_branch", e.target.value)}
                  className="w-32 bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs font-mono text-slate-800 focus:outline-none focus:ring-1 focus:ring-blue-500"
                />
              </div>

              <div className="h-px bg-slate-100" />

              <div className="flex items-center justify-between">
                <div>
                  <div className="text-xs font-bold text-slate-800">启用浅克隆优化 (--depth 1)</div>
                  <div className="text-xs text-slate-500 mt-0.5">
                    仅拉取最新一次提交代码，跳过历史 commit 记录，显著提升克隆速度并节省空间
                  </div>
                </div>

                <input
                  type="checkbox"
                  checked={preferences.enable_shallow_clone}
                  onChange={(e) => updatePreference("enable_shallow_clone", e.target.checked)}
                  className="w-4 h-4 text-[#2563eb] rounded focus:ring-blue-500 cursor-pointer"
                />
              </div>

              <div className="h-px bg-slate-100" />

              <div className="flex items-center justify-between">
                <div>
                  <div className="text-xs font-bold text-slate-800">临时克隆缓存</div>
                  <div className="text-xs text-slate-500 mt-0.5">
                    清理历史浅克隆与导入过程中产生的临时工作目录缓存
                  </div>
                </div>

                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleCleanTempGitCache}
                  disabled={cleaningCache}
                  className="gap-1.5"
                >
                  <Sparkles className="w-3.5 h-3.5 text-amber-500" />
                  <span>{cleaningCache ? "清理中..." : "立即清理缓存"}</span>
                </Button>
              </div>
            </div>
          </div>
        )}

        {/* ================= Tab 2: 数据与备份 ================= */}
        {selectedTab === "data" && (
          <div className="space-y-6 max-w-4xl">
            {/* 资产统计 */}
            <div className="grid grid-cols-3 gap-4">
              <div className="bg-white rounded-xl border border-[#e2e7ed] p-4 shadow-2xs flex items-center gap-3.5">
                <div className="w-10 h-10 rounded-xl bg-indigo-50 border border-indigo-100 flex items-center justify-center shrink-0">
                  <Folder className="w-5 h-5 text-indigo-600" />
                </div>
                <div>
                  <div className="text-xs text-slate-500">已归档 Skills</div>
                  <div className="text-lg font-bold text-[#0f172a] mt-0.5">{librarySkillCount} 个</div>
                </div>
              </div>

              <div className="bg-white rounded-xl border border-[#e2e7ed] p-4 shadow-2xs flex items-center gap-3.5">
                <div className="w-10 h-10 rounded-xl bg-amber-50 border border-amber-100 flex items-center justify-center shrink-0">
                  <Sparkles className="w-5 h-5 text-amber-600" />
                </div>
                <div>
                  <div className="text-xs text-slate-500">已归档 MCP 服务</div>
                  <div className="text-lg font-bold text-[#0f172a] mt-0.5">{libraryMcpCount} 个</div>
                </div>
              </div>

              <div className="bg-white rounded-xl border border-[#e2e7ed] p-4 shadow-2xs flex items-center gap-3.5">
                <div className="w-10 h-10 rounded-xl bg-blue-50 border border-blue-100 flex items-center justify-center shrink-0">
                  <LayoutGrid className="w-5 h-5 text-[#2563eb]" />
                </div>
                <div>
                  <div className="text-xs text-slate-500">接入本地项目</div>
                  <div className="text-lg font-bold text-[#0f172a] mt-0.5">{projectCount} 个</div>
                </div>
              </div>
            </div>

            {/* 本地中央库存储目录 */}
            <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-4">
              <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                <div className="flex items-center gap-2">
                  <FolderOpen className="w-4 h-4 text-[#10b981]" />
                  <h3 className="text-sm font-bold text-[#0f172a]">本地中央库资产管理</h3>
                </div>

                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => handleOpenPath("base")}
                  className="gap-1.5"
                >
                  <FolderOpen className="w-3.5 h-3.5 text-[#2563eb]" />
                  <span>在资源管理器中打开数据根目录</span>
                </Button>
              </div>

              <div className="grid grid-cols-2 gap-4 text-xs">
                <div className="p-3.5 bg-[#f8fafd] border border-slate-100 rounded-xl space-y-1">
                  <div className="font-bold text-slate-800">Skills 中央存储根目录</div>
                  <div className="font-mono text-slate-500 select-all truncate">%APPDATA%\AgentManager\skills</div>
                  <button
                    onClick={() => handleOpenPath("skills")}
                    className="text-[11px] text-[#2563eb] hover:underline pt-1 inline-block cursor-pointer"
                  >
                    打开 Skills 文件夹 →
                  </button>
                </div>

                <div className="p-3.5 bg-[#f8fafd] border border-slate-100 rounded-xl space-y-1">
                  <div className="font-bold text-slate-800">MCP 服务配置根目录</div>
                  <div className="font-mono text-slate-500 select-all truncate">%APPDATA%\AgentManager\mcp</div>
                  <button
                    onClick={() => handleOpenPath("mcp")}
                    className="text-[11px] text-[#2563eb] hover:underline pt-1 inline-block cursor-pointer"
                  >
                    打开 MCP 文件夹 →
                  </button>
                </div>
              </div>
            </div>

            {/* 配置备份与快照 */}
            <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-4">
              <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                <div>
                  <h3 className="text-sm font-bold text-[#0f172a]">配置备份快照</h3>
                  <p className="text-xs text-slate-500 mt-0.5">
                    随时生成全量中央库能力配置快照，并在需要时一键完整恢复
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={loadPreferencesAndBackups}
                    className="gap-1"
                  >
                    <RefreshCw className="w-3.5 h-3.5" />
                    <span>刷新</span>
                  </Button>

                  <Button
                    size="sm"
                    onClick={handleCreateBackup}
                    disabled={loadingBackups}
                    className="gap-1.5"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>立即创建备份快照</span>
                  </Button>
                </div>
              </div>

              {backups.length === 0 ? (
                <div className="text-center py-8 text-xs text-slate-400">
                  暂无配置快照。点击上方“立即创建备份快照”即可存档当前配置状态。
                </div>
              ) : (
                <div className="space-y-2">
                  {backups.map((b) => (
                    <div
                      key={b.id}
                      className="p-3 bg-[#f8fafd] border border-slate-100 rounded-xl flex items-center justify-between hover:bg-slate-50 transition"
                    >
                      <div className="space-y-0.5">
                        <div className="text-xs font-bold font-mono text-slate-900">{b.filename}</div>
                        <div className="text-[11px] text-slate-500 flex items-center gap-3">
                          <span>包含 {b.skill_count} 个 Skills · {b.mcp_count} 个 MCP 服务</span>
                          <span>·</span>
                          <span>大小 {(b.size_bytes / 1024).toFixed(1)} KB</span>
                          <span>·</span>
                          <span>{new Date(b.created_at).toLocaleString()}</span>
                        </div>
                      </div>

                      <Button
                        variant="pill"
                        size="sm"
                        onClick={() => handleRestoreBackup(b.filename)}
                        className="gap-1"
                      >
                        <RotateCcw className="w-3 h-3" />
                        <span>恢复此快照</span>
                      </Button>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {/* ================= Tab 3: 操作记录 ================= */}
        {selectedTab === "history" && (
          <div className="space-y-6 max-w-4xl">
            <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-4">
              <div className="flex items-center justify-between border-b border-slate-100 pb-3">
                <div>
                  <h3 className="text-sm font-bold text-[#0f172a]">操作记录审计</h3>
                  <p className="text-xs text-slate-500 mt-0.5">
                    保留近期的能力分发、挂载、入库与配置变动记录
                  </p>
                </div>

                <div className="flex items-center gap-2">
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={onRefreshAll}
                    className="gap-1"
                  >
                    <RefreshCw className="w-3.5 h-3.5" />
                    <span>刷新</span>
                  </Button>

                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={handleClearHistory}
                    className="gap-1 text-red-600 hover:bg-red-50"
                  >
                    <Trash2 className="w-3.5 h-3.5" />
                    <span>清空历史</span>
                  </Button>
                </div>
              </div>

              {history.length === 0 ? (
                <div className="text-center py-10 text-xs text-slate-400">
                  暂无操作记录
                </div>
              ) : (
                <div className="divide-y divide-slate-100">
                  {history.map((h) => (
                    <div key={h.id} className="py-2.5 flex items-center justify-between text-xs">
                      <div className="flex items-center gap-3">
                        <Badge
                          variant={
                            h.action.includes("分发") || h.action.includes("创建")
                              ? "mint"
                              : h.action.includes("停用") || h.action.includes("移除")
                              ? "destructive"
                              : "secondary"
                          }
                          className="text-[10px]"
                        >
                          {h.action}
                        </Badge>
                        <span className="font-bold text-slate-900">{h.target}</span>
                        {h.details && <span className="text-slate-400 font-mono text-[11px]">{h.details}</span>}
                      </div>

                      <div className="text-[11px] font-mono text-slate-400">
                        {new Date(h.timestamp).toLocaleString()}
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        )}

        {/* ================= Tab 4: 客户端与关于 ================= */}
        {selectedTab === "clients" && (
          <div className="space-y-6 max-w-4xl">
            {/* 客户端与配置位置 */}
            <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs space-y-4">
              <div className="border-b border-slate-100 pb-3">
                <h3 className="text-sm font-bold text-[#0f172a]">客户端检测与配置路径</h3>
                <p className="text-xs text-slate-500 mt-0.5">
                  查看各 AI 客户端在本机的安装识别状态及全局/项目工作区配置路径映射
                </p>
              </div>

              <div className="grid grid-cols-2 gap-4">
                {agents.map((agent) => (
                  <div
                    key={agent.agent}
                    className="p-4 bg-[#f8fafd] border border-slate-100 rounded-xl space-y-3"
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2.5">
                        <AgentIcon agent={agent.agent} size={24} />
                        <span className="text-sm font-bold text-[#0f172a]">{agent.name}</span>
                      </div>

                      <Badge
                        variant={agent.installed ? "mint" : "secondary"}
                        className="text-[10px]"
                      >
                        {agent.installed ? "已安装" : "未检测到"}
                      </Badge>
                    </div>

                    <div className="space-y-2 text-[11px] font-mono text-slate-600">
                      <div>
                        <div className="font-sans font-semibold text-slate-500 text-[10px]">全局 MCP 配置文件:</div>
                        <div
                          onClick={() => handleOpenPath(agent.global_mcp_path)}
                          title="点击在资源管理器中定位"
                          className="text-slate-700 bg-white border border-slate-200/80 rounded px-2 py-1 mt-0.5 truncate cursor-pointer hover:border-blue-400"
                        >
                          {agent.global_mcp_path}
                        </div>
                      </div>

                      <div>
                        <div className="font-sans font-semibold text-slate-500 text-[10px]">全局 Skills 扫描目录:</div>
                        <div className="text-slate-700 bg-white border border-slate-200/80 rounded px-2 py-1 mt-0.5 truncate">
                          {agent.global_skill_roots.length > 0 ? agent.global_skill_roots.join(" | ") : "默认客户端规范目录"}
                        </div>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* 关于 Looma */}
            <div className="bg-white rounded-xl border border-[#e2e7ed] p-6 shadow-2xs space-y-4">
              <div className="flex items-center gap-4">
                <img
                  src="/app-icon.png"
                  alt="Looma"
                  className="w-14 h-14 rounded-2xl shadow-sm border border-slate-200 object-cover"
                />
                <div>
                  <div className="flex items-center gap-2">
                    <h2 className="text-lg font-bold text-[#0f172a]">Looma</h2>
                    <Badge variant="blue" className="text-[11px]">v0.1.5 Windows Edition</Badge>
                  </div>
                  <p className="text-xs text-slate-500 mt-1">
                    全 Agent 生态生产力技能与 MCP 工具统一管理平台 · 高效分发与版本同步
                  </p>
                </div>
              </div>

              <div className="text-xs text-slate-600 leading-relaxed border-t border-slate-100 pt-4 space-y-2">
                <p>
                  Looma Windows 版本基于 Tauri 2.0 (Rust) + React 构建，全面接入 NTFS Junction 目录联接与客户端配置热挂载，支持与 macOS 原生版无缝配合使用。
                </p>
                <div className="flex items-center justify-between pt-2">
                  <div className="text-[11px] text-slate-400">
                    作者：Whisky · 遵循 MIT 开源协议 · GitHub: Whisky-s/Looma
                  </div>

                  <Button
                    variant="outline"
                    size="sm"
                    onClick={handleResetPreferences}
                    className="text-red-600 hover:bg-red-50 border-red-200"
                  >
                    重置为默认偏好设置
                  </Button>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
