import React, { useState } from "react";
import { Dialog } from "./ui/Dialog";
import { Button } from "./ui/Button";
import { Input } from "./ui/Input";

interface NewMcpModalProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSubmit: (name: string, definition: Record<string, any>) => void;
}

export const NewMcpModal: React.FC<NewMcpModalProps> = ({
  open,
  onOpenChange,
  onSubmit,
}) => {
  const [type, setType] = useState<"stdio" | "sse">("stdio");
  const [name, setName] = useState("");
  const [command, setCommand] = useState("");
  const [args, setArgs] = useState("");
  const [url, setUrl] = useState("");
  const [envJson, setEnvJson] = useState("{}");

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    let envObj = {};
    try {
      if (envJson.trim()) {
        envObj = JSON.parse(envJson);
      }
    } catch {
      alert("环境变量 JSON 格式无效，请检查语法");
      return;
    }

    const definition: Record<string, any> = {};
    if (type === "stdio") {
      if (!command.trim()) {
        alert("请输入启动命令");
        return;
      }
      definition.command = command.trim();
      definition.args = args.trim()
        ? args
            .split(" ")
            .map((s) => s.trim())
            .filter(Boolean)
        : [];
      if (Object.keys(envObj).length > 0) {
        definition.env = envObj;
      }
    } else {
      if (!url.trim()) {
        alert("请输入服务 SSE URL");
        return;
      }
      definition.url = url.trim();
    }

    onSubmit(name.trim(), definition);
    setName("");
    setCommand("");
    setArgs("");
    setUrl("");
    setEnvJson("{}");
    onOpenChange(false);
  };

  return (
    <Dialog
      open={open}
      onOpenChange={onOpenChange}
      title="新建 MCP 服务"
      description="在本地中央库创建新的 Model Context Protocol 服务配置"
    >
      <form onSubmit={handleSubmit} className="space-y-4">
        {/* Protocol Type Selector */}
        <div>
          <label className="block text-xs font-semibold text-slate-700 mb-1.5">
            协议类型
          </label>
          <div className="grid grid-cols-2 gap-2">
            <button
              type="button"
              onClick={() => setType("stdio")}
              className={`py-2 px-3 rounded-lg text-xs font-semibold border transition cursor-pointer ${
                type === "stdio"
                  ? "bg-blue-50 border-[#2563eb] text-[#2563eb]"
                  : "bg-white border-slate-200 text-slate-600 hover:bg-slate-50"
              }`}
            >
              Stdio 进程通信
            </button>
            <button
              type="button"
              onClick={() => setType("sse")}
              className={`py-2 px-3 rounded-lg text-xs font-semibold border transition cursor-pointer ${
                type === "sse"
                  ? "bg-blue-50 border-[#2563eb] text-[#2563eb]"
                  : "bg-white border-slate-200 text-slate-600 hover:bg-slate-50"
              }`}
            >
              SSE 远程服务
            </button>
          </div>
        </div>

        {/* Server Name */}
        <div>
          <label className="block text-xs font-semibold text-slate-700 mb-1">
            服务名称 (唯一标识)
          </label>
          <Input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="例如：filesystem, fetch, sqlite"
            required
          />
        </div>

        {type === "stdio" ? (
          <>
            <div>
              <label className="block text-xs font-semibold text-slate-700 mb-1">
                执行命令 (Executable)
              </label>
              <Input
                value={command}
                onChange={(e) => setCommand(e.target.value)}
                placeholder="例如：npx, uvx, node, python"
                required
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-700 mb-1">
                命令参数 (Args，空格分隔)
              </label>
              <Input
                value={args}
                onChange={(e) => setArgs(e.target.value)}
                placeholder="例如：-y @modelcontextprotocol/server-filesystem C:\Work"
              />
            </div>

            <div>
              <label className="block text-xs font-semibold text-slate-700 mb-1">
                环境变量 (JSON 格式，可选)
              </label>
              <textarea
                value={envJson}
                onChange={(e) => setEnvJson(e.target.value)}
                rows={3}
                className="w-full bg-white border border-slate-200 rounded-lg p-2 text-xs font-mono text-slate-800 focus:outline-none focus:ring-1 focus:ring-blue-500"
                placeholder='{ "API_KEY": "xxx" }'
              />
            </div>
          </>
        ) : (
          <div>
            <label className="block text-xs font-semibold text-slate-700 mb-1">
              SSE 服务端点 URL
            </label>
            <Input
              value={url}
              onChange={(e) => setUrl(e.target.value)}
              placeholder="例如：http://localhost:8000/sse"
              required
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
          <Button type="submit">保存到中央库</Button>
        </div>
      </form>
    </Dialog>
  );
};
