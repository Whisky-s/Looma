import React, { useState, useEffect } from "react";
import { invoke } from "@tauri-apps/api/core";
import { Minus, Square, Copy, X } from "lucide-react";

export const WindowControls: React.FC = () => {
  const [isMaximized, setIsMaximized] = useState(false);

  useEffect(() => {
    let unlisten: (() => void) | undefined;
    const checkMax = async () => {
      try {
        const { getCurrentWindow } = await import("@tauri-apps/api/window");
        const win = getCurrentWindow();
        setIsMaximized(await win.isMaximized());
        unlisten = await win.onResized(async () => {
          setIsMaximized(await win.isMaximized());
        });
      } catch (err) {
        console.warn(err);
      }
    };
    checkMax();
    return () => {
      if (unlisten) unlisten();
    };
  }, []);

  const handleMinimize = async (e: React.MouseEvent) => {
    e.stopPropagation();
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

  const handleToggleMaximize = async (e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      await invoke("window_toggle_maximize");
      setIsMaximized(!isMaximized);
    } catch {
      try {
        const { getCurrentWindow } = await import("@tauri-apps/api/window");
        const win = getCurrentWindow();
        await win.toggleMaximize();
        setIsMaximized(await win.isMaximized());
      } catch (err) {
        console.warn(err);
      }
    }
  };

  const handleClose = async (e: React.MouseEvent) => {
    e.stopPropagation();
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
      data-no-drag
      className="absolute top-0 right-0 flex items-center h-8 z-50 select-none"
    >
      <button
        onClick={handleMinimize}
        title="最小化"
        className="h-8 w-11 flex items-center justify-center text-slate-500 hover:text-slate-800 hover:bg-slate-200/80 active:bg-slate-300/80 transition cursor-pointer"
      >
        <Minus className="w-3.5 h-3.5" />
      </button>

      <button
        onClick={handleToggleMaximize}
        title={isMaximized ? "向下还原" : "最大化"}
        className="h-8 w-11 flex items-center justify-center text-slate-500 hover:text-slate-800 hover:bg-slate-200/80 active:bg-slate-300/80 transition cursor-pointer"
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
        className="h-8 w-12 flex items-center justify-center text-slate-500 hover:text-white hover:bg-[#e81123] active:bg-[#c4101f] transition cursor-pointer"
      >
        <X className="w-3.5 h-3.5" />
      </button>
    </div>
  );
};
