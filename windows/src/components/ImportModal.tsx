import React, { useState } from "react";
import { Dialog } from "./ui/Dialog";
import { Button } from "./ui/Button";
import { Input } from "./ui/Input";

interface ImportModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  mode: "git" | "local";
  kind: "skill" | "mcp";
  onImport: (pathOrUrl: string, branch?: string) => void;
}

export const ImportModal: React.FC<ImportModalProps> = ({
  open,
  onOpenChange,
  mode,
  kind,
  onImport,
}) => {
  const [value, setValue] = useState("");
  const [branch, setBranch] = useState("");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!value.trim()) return;
    onImport(value.trim(), branch.trim() || undefined);
    setValue("");
    setBranch("");
    onOpenChange(false);
  };

  const title =
    mode === "git"
      ? `从 Git 仓库导入 ${kind === "skill" ? "Skill 技能" : "MCP 服务"}`
      : `从本地目录导入 ${kind === "skill" ? "Skill 技能" : "MCP 服务"}`;

  const description =
    mode === "git"
      ? "输入 Git 仓库地址进行克隆或引用"
      : "输入本机已存在的目录路径将其收录至中央库";

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title={title}
      description={description}
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-xs font-semibold text-slate-700 mb-1">
            {mode === "git" ? "Git 仓库 URL" : "本地文件目录绝对路径"}
          </label>
          <Input
            value={value}
            onChange={(e) => setValue(e.target.value)}
            placeholder={
              mode === "git"
                ? "https://github.com/example/my-skill.git"
                : "C:\\Users\\username\\.agents\\skills\\my-skill"
            }
            required
          />
        </div>

        {mode === "git" && (
          <div>
            <label className="block text-xs font-semibold text-slate-700 mb-1">
              分支 / Tag (可选)
            </label>
            <Input
              value={branch}
              onChange={(e) => setBranch(e.target.value)}
              placeholder="main 或 v1.0.0"
            />
          </div>
        )}

        <div className="flex justify-end gap-2 pt-2 border-t border-slate-100">
          <Button
            type="button"
            variant="ghost"
            onClick={() => onOpenChange(false)}
          >
            取消
          </Button>
          <Button type="submit">开始导入</Button>
        </div>
      </form>
    </Dialog>
  );
};
