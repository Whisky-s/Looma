import React, { useState } from "react";
import { AgentId } from "../types";

interface AgentIconProps {
  agent: AgentId | string;
  size?: number;
  className?: string;
}

const AGENT_ASSET_MAP: Record<string, string> = {
  claude: "/agent-icons/claude_code.svg",
  cursor: "/agent-icons/cursor.png",
  codex: "/agent-icons/codex.svg",
  antigravity: "/agent-icons/antigravity.png",
  qoder: "/agent-icons/qoder.svg",
  workbuddy: "/agent-icons/workbuddy.png",
};

const AGENT_FALLBACK_LABELS: Record<string, string> = {
  claude: "Cl",
  cursor: "Cu",
  codex: "Cx",
  antigravity: "Ag",
  qoder: "Qd",
  workbuddy: "Wb",
};

export const AgentIcon: React.FC<AgentIconProps> = ({ agent, size = 18, className = "" }) => {
  const [error, setError] = useState(false);
  const normalized = agent.toLowerCase();
  const src = AGENT_ASSET_MAP[normalized];

  if (!src || error) {
    return (
      <div
        style={{ width: size, height: size }}
        className={`flex items-center justify-center font-bold text-[10px] bg-slate-100 text-slate-700 rounded ${className}`}
      >
        {AGENT_FALLBACK_LABELS[normalized] || agent.slice(0, 2).toUpperCase()}
      </div>
    );
  }

  return (
    <img
      src={src}
      alt={agent}
      style={{ width: size, height: size }}
      className={`object-contain ${className}`}
      onError={() => setError(true)}
    />
  );
};
