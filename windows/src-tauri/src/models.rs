use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Agent {
    #[serde(rename = "Claude Code")]
    Claude,
    #[serde(rename = "Codex")]
    Codex,
    #[serde(rename = "Cursor")]
    Cursor,
    #[serde(rename = "Antigravity")]
    Antigravity,
    #[serde(rename = "Qoder")]
    Qoder,
    #[serde(rename = "WorkBuddy")]
    WorkBuddy,
}

impl Agent {
    pub fn all() -> &'static [Agent] {
        &[
            Agent::Claude,
            Agent::Codex,
            Agent::Cursor,
            Agent::Antigravity,
            Agent::Qoder,
            Agent::WorkBuddy,
        ]
    }

    pub fn name(&self) -> &'static str {
        match self {
            Agent::Claude => "Claude Code",
            Agent::Codex => "Codex",
            Agent::Cursor => "Cursor",
            Agent::Antigravity => "Antigravity",
            Agent::Qoder => "Qoder",
            Agent::WorkBuddy => "WorkBuddy",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConfigFormat {
    Json,
    Toml,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentStatus {
    pub agent: Agent,
    pub name: String,
    pub installed: bool,
    pub global_skill_roots: Vec<String>,
    pub global_mcp_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitSourceInfo {
    pub repo: String,
    pub branch: Option<String>,
    pub subpath: Option<String>,
    pub installed_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SkillItem {
    pub id: String,
    pub name: String,
    pub description: String,
    pub path: String,
    pub source: String,
    pub agent: Option<Agent>,
    pub project: Option<String>,
    pub is_library: bool,
    pub git_source: Option<GitSourceInfo>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct McpItem {
    pub id: String,
    pub name: String,
    pub summary: String,
    pub definition: Value,
    pub agent: Option<Agent>,
    pub project: Option<String>,
    pub source: String,
    pub is_library: bool,
    pub is_system_service: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Target {
    pub agent: Agent,
    pub project: Option<String>,
    pub id: String,
    pub scope_name: String,
    pub label: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Deployment {
    pub kind: String,
    pub item: String,
    pub target_id: String,
    pub path: String,
    pub fingerprint: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DisabledItem {
    pub kind: String,
    pub item: String,
    pub target_id: String,
    pub original_path: String,
    pub stash_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Preset {
    pub name: String,
    pub skills: Vec<String>,
    pub mcps: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HistoryRecord {
    pub id: String,
    pub action: String,
    pub kind: String,
    pub target: String,
    pub timestamp: DateTime<Utc>,
    pub details: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserPreferences {
    pub detail_presentation_mode: String,
    pub default_markdown_mode: String,
    pub skill_deployment_mode: String,
    pub default_git_branch: String,
    pub enable_shallow_clone: bool,
    pub history_limit: usize,
}

impl Default for UserPreferences {
    fn default() -> Self {
        Self {
            detail_presentation_mode: "modal".to_string(),
            default_markdown_mode: "preview".to_string(),
            skill_deployment_mode: "link".to_string(),
            default_git_branch: "main".to_string(),
            enable_shallow_clone: true,
            history_limit: 50,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupRecord {
    pub id: String,
    pub created_at: DateTime<Utc>,
    pub filename: String,
    pub size_bytes: u64,
    pub skill_count: usize,
    pub mcp_count: usize,
}
