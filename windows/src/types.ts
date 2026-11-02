export type AgentId = "claude" | "cursor" | "codex" | "antigravity" | "qoder" | "workbuddy";

export interface AgentStatus {
  agent: AgentId;
  name: string;
  installed: boolean;
  global_skill_roots: string[];
  global_mcp_path: string;
}

export interface GitSourceInfo {
  repo: string;
  branch?: string;
  commit?: string;
  subdir?: string;
}

export interface SkillItem {
  id: string;
  name: string;
  description: string;
  path: string;
  source: string;
  agent?: AgentId;
  project?: string;
  is_library: boolean;
  git_source?: GitSourceInfo;
}

export interface McpItem {
  id: string;
  name: string;
  summary: string;
  definition: Record<string, any>;
  agent?: AgentId;
  project?: string;
  source: string;
  is_library: boolean;
  is_system_service: boolean;
}

export interface Preset {
  name: string;
  description: string;
  skills: string[];
  mcps: string[];
}

export interface HistoryRecord {
  id: string;
  action: string;
  kind: string;
  target: string;
  timestamp: string;
  details?: string;
}

export interface TargetStatus {
  agent: AgentId;
  agentName: string;
  isAgentInstalled: boolean;
  isDeployed: boolean;
  status: "已启用" | "未分发" | "未安装";
}

export interface DisplayItem {
  id: string;
  name: string;
  kind: "skill" | "mcp";
  typeLabel: string;
  description: string;
  isLibrary: boolean;
  isSystemService: boolean;
  gitSource?: GitSourceInfo;
  targets: TargetStatus[];
  activeCount: number;
  rawSkill?: SkillItem;
  rawMcp?: McpItem;
  externalPaths: string[];
}
