import React from "react";

export const handleWindowDrag = async (e: React.MouseEvent) => {
  // Only trigger on primary left click
  if (e.button !== 0) return;
  const target = e.target as HTMLElement | null;
  if (!target) return;

  // Never drag when clicking interactive elements
  if (target.closest("button, input, textarea, select, a, [data-no-drag]")) {
    return;
  }

  try {
    const { getCurrentWindow } = await import("@tauri-apps/api/window");
    const win = getCurrentWindow();
    await win.startDragging();
  } catch (err) {
    console.warn("startDragging error:", err);
  }
};

export const handleWindowDoubleClick = async (e: React.MouseEvent) => {
  const target = e.target as HTMLElement | null;
  if (!target) return;

  if (target.closest("button, input, textarea, select, a, [data-no-drag]")) {
    return;
  }

  try {
    const { getCurrentWindow } = await import("@tauri-apps/api/window");
    const win = getCurrentWindow();
    await win.toggleMaximize();
  } catch (err) {
    console.warn("toggleMaximize error:", err);
  }
};
