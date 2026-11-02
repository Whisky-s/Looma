import React, { useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { Minus, Square, Copy, X } from "lucide-react";

export const TitleBar: React.FC = () => {
  const [isMaximized, setIsMaximized] = useState(false);

  const handleMinimize = async () => {
    try {
      await invoke("window_minimize");
    } catch {
      try {
        const { getCurrentWindow } = await import("@tauri-apps/api/window");
        getCurrentWindow().minimize();
      } catch (err) {
        console.warn(err);
      }
    }
  };

  const handleToggleMaximize = async () => {
    try {
      await invoke("window_toggle_maximize");
      setIsMaximized(!isMaximized);
    } catch {
      try {
        const { getCurrentWindow } = await import("@tauri-apps/api/window");
        getCurrentWindow().toggleMaximize();
        setIsMaximized(!isMaximized);
      } catch (err) {
        console.warn(err);
      }
    }
  };

  const handleClose = async () => {
    try {
      await invoke("window_close");
    } catch {
      try {
        const { getCurrentWindow } = await import("@tauri-apps/api/window");
        getCurrentWindow().close();
      } catch (err) {
        console.warn(err);
      }
    }
  };

  return (
    <div
      data-tauri-drag-region
      onDoubleClick={handleToggleMaximize}
      className="h-[32px] w-full flex items-center justify-between select-none shrink-0 z-50 bg-[#ecedf0] border-b border-[#e2e7ed]/60"
    >
      {/* Left side brand / drag area */}
      <div
        data-tauri-drag-region
        className="flex items-center gap-2 px-3 h-full w-[240px] border-r border-[#e2e7ed]/60 shrink-0"
      >
        <span className="w-2.5 h-2.5 rounded-full bg-slate-300 inline-block pointer-events-none" />
        <span className="text-[11px] font-bold text-slate-500 font-mono tracking-wide pointer-events-none">
          Looma
        </span>
      </div>

      {/* Middle flexible drag region */}
      <div
        data-tauri-drag-region
        className="flex-1 h-full bg-[#f4f6f9] flex items-center justify-center text-[10px] text-slate-400 font-medium"
      >
        {/* Empty draggable area */}
      </div>

      {/* Right side window control buttons */}
      <div className="flex items-center h-full bg-[#f4f6f9] shrink-0">
        <button
          onClick={handleMinimize}
          title="最小化"
          className="h-full w-10 flex items-center justify-center text-slate-500 hover:text-slate-800 hover:bg-slate-200/70 transition cursor-pointer"
        >
          <Minus className="w-3.5 h-3.5" />
        </button>

        <button
          onClick={handleToggleMaximize}
          title={isMaximized ? "向下还原" : "最大化"}
          className="h-full w-10 flex items-center justify-center text-slate-500 hover:text-slate-800 hover:bg-slate-200/70 transition cursor-pointer"
        >
          {isMaximized ? (
            <Copy className="w-3 h-3 rotate-180" />
          ) : (
            <Square className="w-3 h-3" />
          )}
        </button>

        <button
          onClick={handleClose}
          title="关闭"
          className="h-full w-11 flex items-center justify-center text-slate-500 hover:text-white hover:bg-red-500 transition cursor-pointer"
        >
          <X className="w-3.5 h-3.5" />
        </button>
      </div>
    </div>
  );
};
