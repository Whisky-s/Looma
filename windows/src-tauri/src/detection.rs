use std::path::PathBuf;
use crate::models::Agent;
use crate::paths::get_home_dir;

pub fn is_agent_installed(agent: Agent) -> bool {
    let commands: &[&str] = match agent {
        Agent::Claude => &["claude", "claude.cmd"],
        Agent::Codex => &["codex", "codex.exe", "codex.cmd"],
        Agent::Cursor => &["cursor", "cursor.cmd", "cursor.exe"],
        Agent::Antigravity => &["antigravity", "antigravity.exe", "antigravity.cmd"],
        Agent::Qoder => &["qoder", "qoder.exe", "qoder.cmd"],
        Agent::WorkBuddy => &["workbuddy", "workbuddy.exe", "workbuddy.cmd"],
    };

    // 1. Check in PATH environment variable
    if let Ok(path_var) = std::env::var("PATH") {
        #[cfg(target_os = "windows")]
        let sep = ';';
        #[cfg(not(target_os = "windows"))]
        let sep = ':';

        for dir_str in path_var.split(sep) {
            let dir = PathBuf::from(dir_str);
            for cmd in commands {
                if dir.join(cmd).is_file() {
                    return true;
                }
            }
        }
    }

    // 2. Check standard Windows LocalAppData install roots
    if let Some(local_app_data) = dirs::data_local_dir() {
        let programs = local_app_data.join("Programs");
        let app_names: &[&str] = match agent {
            Agent::Claude => &["Claude", "Claude Code"],
            Agent::Codex => &["Codex"],
            Agent::Cursor => &["cursor", "Cursor"],
            Agent::Antigravity => &["Antigravity", "Google Antigravity"],
            Agent::Qoder => &["Qoder"],
            Agent::WorkBuddy => &["WorkBuddy"],
        };
        for name in app_names {
            if programs.join(name).exists() {
                return true;
            }
        }
    }

    // 3. Check macOS /Applications (fallback for dev preview)
    #[cfg(target_os = "macos")]
    {
        let mac_names: &[&str] = match agent {
            Agent::Claude => &[],
            Agent::Codex => &["Codex.app"],
            Agent::Cursor => &["Cursor.app"],
            Agent::Antigravity => &["Antigravity.app"],
            Agent::Qoder => &["Qoder.app"],
            Agent::WorkBuddy => &["WorkBuddy.app"],
        };
        for name in mac_names {
            if PathBuf::from("/Applications").join(name).exists()
                || get_home_dir().join("Applications").join(name).exists()
            {
                return true;
            }
        }
    }

    // 4. Check if config/skill root already has contents as secondary indicator
    let roots = crate::paths::get_global_skill_roots(agent);
    for root in roots {
        if root.is_dir() {
            return true;
        }
    }
    let (mcp_path, _) = crate::paths::get_global_mcp_config(agent);
    if mcp_path.is_file() {
        return true;
    }

    false
}
