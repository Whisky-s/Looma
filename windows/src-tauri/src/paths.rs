use std::path::{Path, PathBuf};
use crate::models::{Agent, ConfigFormat};

pub fn get_home_dir() -> PathBuf {
    dirs::home_dir().unwrap_or_else(|| PathBuf::from("."))
}

pub fn get_base_dir() -> PathBuf {
    if let Some(config_dir) = dirs::data_dir() {
        config_dir.join("AgentManager")
    } else {
        get_home_dir().join(".agent-manager")
    }
}

pub fn resolve_path(path_str: &str, project: Option<&str>) -> PathBuf {
    let clean = path_str.trim();
    if clean.starts_with("~/") || clean.starts_with("~\\") {
        return get_home_dir().join(&clean[2..]);
    }
    if let Some(proj) = project {
        return Path::new(proj).join(clean);
    }
    PathBuf::from(clean)
}

pub fn get_global_skill_roots(agent: Agent) -> Vec<PathBuf> {
    let home = get_home_dir();
    match agent {
        Agent::Claude => vec![home.join(".claude").join("skills")],
        Agent::Codex => vec![
            home.join(".codex").join("skills"),
            home.join(".agents").join("skills"),
        ],
        Agent::Cursor => vec![home.join(".cursor").join("skills")],
        Agent::Antigravity => vec![
            home.join(".gemini").join("config").join("skills"),
            home.join(".gemini").join("antigravity-cli").join("skills"),
        ],
        Agent::Qoder => vec![home.join(".qoder").join("skills")],
        Agent::WorkBuddy => vec![home.join(".workbuddy").join("skills")],
    }
}

pub fn get_project_skill_roots(agent: Agent, project_root: &Path) -> Vec<PathBuf> {
    match agent {
        Agent::Claude => vec![project_root.join(".claude").join("skills")],
        Agent::Codex => vec![project_root.join(".agents").join("skills")],
        Agent::Cursor => vec![
            project_root.join(".cursor").join("skills"),
            project_root.join(".agents").join("skills"),
        ],
        Agent::Antigravity => vec![project_root.join(".agents").join("skills")],
        Agent::Qoder => vec![project_root.join(".qoder").join("skills")],
        Agent::WorkBuddy => vec![project_root.join(".workbuddy").join("skills")],
    }
}

pub fn get_global_mcp_config(agent: Agent) -> (PathBuf, ConfigFormat) {
    let home = get_home_dir();
    match agent {
        Agent::Claude => (home.join(".claude.json"), ConfigFormat::Json),
        Agent::Codex => (home.join(".codex").join("config.toml"), ConfigFormat::Toml),
        Agent::Cursor => (home.join(".cursor").join("mcp.json"), ConfigFormat::Json),
        Agent::Antigravity => (
            home.join(".gemini").join("config").join("mcp_config.json"),
            ConfigFormat::Json,
        ),
        Agent::Qoder => (home.join(".qoder").join("settings.json"), ConfigFormat::Json),
        Agent::WorkBuddy => (home.join(".workbuddy").join("mcp.json"), ConfigFormat::Json),
    }
}

pub fn get_project_mcp_config(agent: Agent, project_root: &Path) -> (PathBuf, ConfigFormat) {
    match agent {
        Agent::Claude => (project_root.join(".mcp.json"), ConfigFormat::Json),
        Agent::Codex => (
            project_root.join(".codex").join("config.toml"),
            ConfigFormat::Toml,
        ),
        Agent::Cursor => (project_root.join(".cursor").join("mcp.json"), ConfigFormat::Json),
        Agent::Antigravity => (
            project_root.join(".agents").join("mcp_config.json"),
            ConfigFormat::Json,
        ),
        Agent::Qoder => (
            project_root.join(".qoder").join("settings.json"),
            ConfigFormat::Json,
        ),
        Agent::WorkBuddy => (
            project_root.join(".workbuddy").join("mcp.json"),
            ConfigFormat::Json,
        ),
    }
}

/// Link directory using Windows Junction (or Unix symlink in dev), with fallback to copy
pub fn link_or_copy_dir(src: &Path, dst: &Path, prefer_symlink: bool) -> std::io::Result<()> {
    if dst.exists() {
        return Err(std::io::Error::new(
            std::io::ErrorKind::AlreadyExists,
            "Target path already exists",
        ));
    }

    if prefer_symlink {
        #[cfg(target_os = "windows")]
        {
            // Try creating NTFS Directory Junction via mklink /J (requires no admin privileges)
            let status = std::process::Command::new("cmd")
                .args(["/C", "mklink", "/J", dst.to_str().unwrap(), src.to_str().unwrap()])
                .status();
            if let Ok(s) = status {
                if s.success() {
                    return Ok(());
                }
            }
        }

        #[cfg(unix)]
        {
            if std::os::unix::fs::symlink(src, dst).is_ok() {
                return Ok(());
            }
        }
    }

    // Fallback to independent recursive copy
    copy_dir_recursive(src, dst)
}

pub fn copy_dir_recursive(src: &Path, dst: &Path) -> std::io::Result<()> {
    std::fs::create_dir_all(dst)?;
    for entry in std::fs::read_dir(src)? {
        let entry = entry?;
        let entry_type = entry.file_type()?;
        let dest_child = dst.join(entry.file_name());
        if entry_type.is_dir() {
            copy_dir_recursive(&entry.path(), &dest_child)?;
        } else {
            std::fs::copy(entry.path(), dest_child)?;
        }
    }
    Ok(())
}
