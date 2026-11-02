import React, { useState } from "react";
import { FolderGit2, Plus, Trash2, ArrowRight } from "lucide-react";
import { Button } from "./ui/Button";
import { Input } from "./ui/Input";

interface ProjectsViewProps {
  projects: string[];
  onAddProject: (path: string) => void;
  onRemoveProject: (path: string) => void;
  onSelectProject: (path: string) => void;
}

export const ProjectsView: React.FC<ProjectsViewProps> = ({
  projects,
  onAddProject,
  onRemoveProject,
  onSelectProject,
}) => {
  const [newPath, setNewPath] = useState("");

  const handleAdd = () => {
    if (!newPath.trim()) return;
    onAddProject(newPath.trim());
    setNewPath("");
  };

  return (
    <div className="flex-1 overflow-y-auto px-8 py-4 space-y-6">
      {/* Top action card */}
      <div className="bg-white rounded-xl border border-[#e2e7ed] p-5 shadow-2xs">
        <h2 className="text-sm font-bold text-[#0f172a]">注册本地项目代码库</h2>
        <p className="text-xs text-[#64748b] mt-1">
          添加本地项目工作区后，可在该项目中按客户端独立配置 Skills 与 MCP，实现项目级别的配置隔离
        </p>

        <div className="flex items-center gap-3 mt-4">
          <Input
            value={newPath}
            onChange={(e) => setNewPath(e.target.value)}
            placeholder="输入项目本地绝对路径 (例如: C:\Users\Username\Projects\my-project)"
            className="flex-1"
          />
          <Button onClick={handleAdd} className="gap-1.5 shrink-0">
            <Plus className="w-3.5 h-3.5" />
            <span>添加项目</span>
          </Button>
        </div>
      </div>

      {/* Projects list */}
      <div className="space-y-3">
        <h3 className="text-xs font-bold text-slate-700 uppercase tracking-wider">
          已注册项目 ({projects.length})
        </h3>

        {projects.length === 0 ? (
          <div className="bg-white rounded-xl border border-dashed border-slate-300 p-8 text-center text-xs text-slate-400">
            暂无已注册项目，请在上方输入代码仓库绝对路径进行添加
          </div>
        ) : (
          <div className="grid grid-cols-1 gap-3">
            {projects.map((projectPath) => {
              const folderName =
                projectPath.split(/[\\/]/).filter(Boolean).pop() || projectPath;

              return (
                <div
                  key={projectPath}
                  className="bg-white rounded-xl border border-[#e2e7ed] p-4 shadow-2xs flex items-center justify-between hover:shadow-xs transition"
                >
                  <div className="flex items-center gap-3 min-w-0">
                    <div className="w-10 h-10 rounded-xl bg-blue-50 border border-blue-100 flex items-center justify-center shrink-0">
                      <FolderGit2 className="w-5 h-5 text-[#2563eb]" />
                    </div>
                    <div className="min-w-0">
                      <div className="text-sm font-bold text-[#0f172a] truncate">
                        {folderName}
                      </div>
                      <div className="text-xs font-mono text-[#64748b] truncate mt-0.5">
                        {projectPath}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-2 shrink-0">
                    <Button
                      variant="outline"
                      size="sm"
                      onClick={() => onSelectProject(projectPath)}
                      className="gap-1.5"
                    >
                      <span>切换到此项目</span>
                      <ArrowRight className="w-3.5 h-3.5" />
                    </Button>
                    <button
                      onClick={() => onRemoveProject(projectPath)}
                      title="移除此项目"
                      className="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition cursor-pointer"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
};
