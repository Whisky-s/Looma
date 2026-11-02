use std::fs;
use std::path::{Path, PathBuf};
use chrono::Utc;
use serde_json::Value;
use crate::models::*;
use crate::paths::*;

pub struct ManagerStore {
    pub base: PathBuf,
}

impl ManagerStore {
    pub fn new() -> Self {
        let base = get_base_dir();
        let store = Self { base };
        store.ensure_directories();
        store
    }

    fn ensure_directories(&self) {
        let _ = fs::create_dir_all(self.skills_root());
        let _ = fs::create_dir_all(self.mcp_root());
        let _ = fs::create_dir_all(self.disabled_root());
        let _ = fs::create_dir_all(self.history_root());
    }

    pub fn skills_root(&self) -> PathBuf { self.base.join("skills") }
    pub fn mcp_root(&self) -> PathBuf { self.base.join("mcp") }
    pub fn disabled_root(&self) -> PathBuf { self.base.join("disabled") }
    pub fn history_root(&self) -> PathBuf { self.base.join("history") }
    pub fn projects_file(&self) -> PathBuf { self.base.join("projects.json") }
    pub fn deployments_file(&self) -> PathBuf { self.base.join("deployments.json") }
    pub fn disabled_file(&self) -> PathBuf { self.base.join("disabled.json") }
    pub fn presets_file(&self) -> PathBuf { self.base.join("presets.json") }
    pub fn history_file(&self) -> PathBuf { self.base.join("history.json") }

    // --- Projects ---
    pub fn get_projects(&self) -> Vec<String> {
        if let Ok(data) = fs::read_to_string(self.projects_file()) {
            serde_json::from_str(&data).unwrap_or_default()
        } else {
            Vec::new()
        }
    }

    pub fn add_project(&self, path: &str) -> Result<(), String> {
        let mut list = self.get_projects();
        if !list.contains(&path.to_string()) {
            list.push(path.to_string());
            let data = serde_json::to_string_pretty(&list).map_err(|e| e.to_string())?;
            fs::write(self.projects_file(), data).map_err(|e| e.to_string())?;
            self.record_history("添加项目", "project", path, None);
        }
        Ok(())
    }

    pub fn remove_project(&self, path: &str) -> Result<(), String> {
        let mut list = self.get_projects();
        list.retain(|p| p != path);
        let data = serde_json::to_string_pretty(&list).map_err(|e| e.to_string())?;
        fs::write(self.projects_file(), data).map_err(|e| e.to_string())?;
        self.record_history("移除项目", "project", path, None);
        Ok(())
    }

    // --- Agents Status ---
    pub fn get_agent_statuses(&self) -> Vec<AgentStatus> {
        Agent::all()
            .iter()
            .map(|&agent| {
                let installed = crate::detection::is_agent_installed(agent);
                let (mcp_path, _) = get_global_mcp_config(agent);
                let roots = get_global_skill_roots(agent)
                    .into_iter()
                    .map(|p| p.to_string_lossy().to_string())
                    .collect();
                AgentStatus {
                    agent,
                    name: agent.name().to_string(),
                    installed,
                    global_skill_roots: roots,
                    global_mcp_path: mcp_path.to_string_lossy().to_string(),
                }
            })
            .collect()
    }

    // --- Skills ---
    pub fn list_library_skills(&self) -> Vec<SkillItem> {
        let mut result = Vec::new();
        if let Ok(entries) = fs::read_dir(self.skills_root()) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.is_dir() {
                    let skill_file = path.join("SKILL.md");
                    let readme_file = path.join("README.md");
                    if skill_file.exists() || readme_file.exists() {
                        let name = path.file_name().unwrap_or_default().to_string_lossy().to_string();
                        let desc = Self::parse_skill_description(&path);
                        let git_src = Self::parse_git_source(&path);
                        result.push(SkillItem {
                            id: format!("library|{}", name),
                            name,
                            description: desc,
                            path: path.to_string_lossy().to_string(),
                            source: "中央库".to_string(),
                            agent: None,
                            project: None,
                            is_library: true,
                            git_source: git_src,
                        });
                    }
                }
            }
        }
        result.sort_by(|a, b| a.name.cmp(&b.name));
        result
    }

    pub fn list_installed_skills(&self) -> Vec<SkillItem> {
        let mut result = Vec::new();
        let projects = self.get_projects();

        for &agent in Agent::all() {
            // Global
            for root in get_global_skill_roots(agent) {
                if let Ok(entries) = fs::read_dir(root) {
                    for entry in entries.flatten() {
                        let path = entry.path();
                        if path.is_dir() && path.join("SKILL.md").exists() {
                            let name = path.file_name().unwrap_or_default().to_string_lossy().to_string();
                            let desc = Self::parse_skill_description(&path);
                            result.push(SkillItem {
                                id: format!("installed|{}|global|{}", agent.name(), name),
                                name,
                                description: desc,
                                path: path.to_string_lossy().to_string(),
                                source: format!("{} · 全局", agent.name()),
                                agent: Some(agent),
                                project: None,
                                is_library: false,
                                git_source: None,
                            });
                        }
                    }
                }
            }

            // Project-level
            for proj_str in &projects {
                let proj_path = Path::new(proj_str);
                let proj_name = proj_path.file_name().unwrap_or_default().to_string_lossy().to_string();
                for root in get_project_skill_roots(agent, proj_path) {
                    if let Ok(entries) = fs::read_dir(root) {
                        for entry in entries.flatten() {
                            let path = entry.path();
                            if path.is_dir() && path.join("SKILL.md").exists() {
                                let name = path.file_name().unwrap_or_default().to_string_lossy().to_string();
                                let desc = Self::parse_skill_description(&path);
                                result.push(SkillItem {
                                    id: format!("installed|{}|{}|{}", agent.name(), proj_str, name),
                                    name,
                                    description: desc,
                                    path: path.to_string_lossy().to_string(),
                                    source: format!("{} · {}", agent.name(), proj_name),
                                    agent: Some(agent),
                                    project: Some(proj_str.clone()),
                                    is_library: false,
                                    git_source: None,
                                });
                            }
                        }
                    }
                }
            }
        }
        result
    }

    fn parse_skill_description(skill_dir: &Path) -> String {
        let file = skill_dir.join("SKILL.md");
        if let Ok(content) = fs::read_to_string(file) {
            for line in content.lines() {
                if line.trim().starts_with("description:") {
                    return line.replace("description:", "").trim().to_string();
                }
            }
        }
        "无描述".to_string()
    }

    fn parse_git_source(skill_dir: &Path) -> Option<GitSourceInfo> {
        let file = skill_dir.join(".git-source.json");
        if let Ok(data) = fs::read_to_string(file) {
            serde_json::from_str(&data).ok()
        } else {
            None
        }
    }

    // --- MCP Items ---
    pub fn list_library_mcps(&self) -> Vec<McpItem> {
        let mut result = Vec::new();
        if let Ok(entries) = fs::read_dir(self.mcp_root()) {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().map_or(false, |ext| ext == "json") {
                    let name = path.file_stem().unwrap_or_default().to_string_lossy().to_string();
                    if let Ok(content) = fs::read_to_string(&path) {
                        if let Ok(def) = serde_json::from_str::<Value>(&content) {
                            let summary = Self::mcp_summary(&def);
                            result.push(McpItem {
                                id: format!("library|mcp|{}", name),
                                name,
                                summary,
                                definition: def,
                                agent: None,
                                project: None,
                                source: "中央库".to_string(),
                                is_library: true,
                                is_system_service: false,
                            });
                        }
                    }
                }
            }
        }
        result.sort_by(|a, b| a.name.cmp(&b.name));
        result
    }

    pub fn list_installed_mcps(&self) -> Vec<McpItem> {
        let mut result = Vec::new();
        let projects = self.get_projects();

        for &agent in Agent::all() {
            // Global
            let (mcp_path, format) = get_global_mcp_config(agent);
            Self::read_mcps_from_config(&mcp_path, format, agent, None, &mut result);

            // Project-level
            for proj_str in &projects {
                let proj_path = Path::new(proj_str);
                let (p_mcp_path, p_format) = get_project_mcp_config(agent, proj_path);
                Self::read_mcps_from_config(&p_mcp_path, p_format, agent, Some(proj_str.clone()), &mut result);
            }
        }
        result
    }

    fn read_mcps_from_config(
        path: &Path,
        format: ConfigFormat,
        agent: Agent,
        project: Option<String>,
        out: &mut Vec<McpItem>,
    ) {
        if !path.is_file() {
            return;
        }
        let content = match fs::read_to_string(path) {
            Ok(c) => c,
            Err(_) => return,
        };

        let scope = match &project {
            Some(p) => Path::new(p).file_name().unwrap_or_default().to_string_lossy().to_string(),
            None => "全局".to_string(),
        };

        match format {
            ConfigFormat::Json => {
                if let Ok(json_val) = serde_json::from_str::<Value>(&content) {
                    let servers = json_val.get("mcpServers").or_else(|| json_val.get("servers"));
                    if let Some(Value::Object(map)) = servers {
                        for (key, def) in map {
                            let summary = Self::mcp_summary(def);
                            out.push(McpItem {
                                id: format!("installed|{}|{}|{}", agent.name(), scope, key),
                                name: key.clone(),
                                summary,
                                definition: def.clone(),
                                agent: Some(agent),
                                project: project.clone(),
                                source: format!("{} · {}", agent.name(), scope),
                                is_library: false,
                                is_system_service: false,
                            });
                        }
                    }
                }
            }
            ConfigFormat::Toml => {
                if let Ok(toml_val) = toml::from_str::<toml::Value>(&content) {
                    if let Some(toml::Value::Table(mcp_table)) = toml_val.get("mcp_servers") {
                        for (key, def) in mcp_table {
                            if let Ok(json_def) = serde_json::to_value(def) {
                                let summary = Self::mcp_summary(&json_def);
                                out.push(McpItem {
                                    id: format!("installed|{}|{}|{}", agent.name(), scope, key),
                                    name: key.clone(),
                                    summary,
                                    definition: json_def,
                                    agent: Some(agent),
                                    project: project.clone(),
                                    source: format!("{} · {}", agent.name(), scope),
                                    is_library: false,
                                    is_system_service: false,
                                });
                            }
                        }
                    }
                }
            }
        }
    }

    fn mcp_summary(def: &Value) -> String {
        if let Some(cmd) = def.get("command").and_then(|v| v.as_str()) {
            return cmd.to_string();
        }
        if let Some(url) = def.get("url").or_else(|| def.get("serverUrl")).and_then(|v| v.as_str()) {
            return url.to_string();
        }
        "配置条目".to_string()
    }

    pub fn save_mcp(&self, name: &str, definition: Value) -> Result<(), String> {
        let file = self.mcp_root().join(format!("{}.json", name));
        let data = serde_json::to_string_pretty(&definition).map_err(|e| e.to_string())?;
        fs::write(file, data).map_err(|e| e.to_string())?;
        self.record_history("保存 MCP", "mcp", name, None);
        Ok(())
    }

    pub fn delete_mcp(&self, name: &str) -> Result<(), String> {
        let file = self.mcp_root().join(format!("{}.json", name));
        if file.exists() {
            fs::remove_file(file).map_err(|e| e.to_string())?;
            self.record_history("删除 MCP", "mcp", name, None);
        }
        Ok(())
    }

    pub fn deploy_skill(&self, name: &str, agent: Agent, project: Option<String>) -> Result<(), String> {
        let src = self.skills_root().join(name);
        if !src.exists() {
            return Err(format!("技能 {} 不存在于中央库", name));
        }
        let roots = match &project {
            Some(proj) => get_project_skill_roots(agent, Path::new(proj)),
            None => get_global_skill_roots(agent),
        };
        if roots.is_empty() {
            return Err("未找到客户端技能根目录".to_string());
        }
        let target_dir = &roots[0];
        let dst = target_dir.join(name);
        if dst.exists() {
            return Err("目标客户端已存在同名配置".to_string());
        }
        if let Some(parent) = dst.parent() {
            let _ = fs::create_dir_all(parent);
        }
        link_or_copy_dir(&src, &dst, true).map_err(|e| format!("分发失败: {}", e))?;
        self.record_history("分发技能", "skill", name, Some(&format!("至 {}", agent.name())));
        Ok(())
    }

    pub fn remove_skill(&self, name: &str, agent: Agent, project: Option<String>) -> Result<(), String> {
        let roots = match &project {
            Some(proj) => get_project_skill_roots(agent, Path::new(proj)),
            None => get_global_skill_roots(agent),
        };
        for root in roots {
            let dst = root.join(name);
            if dst.exists() {
                let _ = fs::remove_dir_all(&dst);
            }
        }
        self.record_history("停用技能", "skill", name, Some(&format!("从 {}", agent.name())));
        Ok(())
    }

    pub fn adopt_skill(&self, name: &str, src_path: &str) -> Result<(), String> {
        let src = Path::new(src_path);
        if !src.exists() {
            return Err("来源路径不存在".to_string());
        }
        let dst = self.skills_root().join(name);
        if dst.exists() {
            return Err("中央库中已存在同名技能".to_string());
        }
        copy_dir_recursive(src, &dst).map_err(|e| format!("入库失败: {}", e))?;
        self.record_history("入库技能", "skill", name, Some(src_path));
        Ok(())
    }

    pub fn deploy_mcp(&self, name: &str, agent: Agent, project: Option<String>) -> Result<(), String> {
        let mcp_file = self.mcp_root().join(format!("{}.json", name));
        if !mcp_file.exists() {
            return Err(format!("MCP {} 不存在于中央库", name));
        }
        let def_str = fs::read_to_string(&mcp_file).map_err(|e| e.to_string())?;
        let def: Value = serde_json::from_str(&def_str).map_err(|e| e.to_string())?;

        let (cfg_path, format) = match &project {
            Some(proj) => get_project_mcp_config(agent, Path::new(proj)),
            None => get_global_mcp_config(agent),
        };

        if let Some(parent) = cfg_path.parent() {
            let _ = fs::create_dir_all(parent);
        }

        match format {
            ConfigFormat::Json => {
                let mut root: Value = if cfg_path.exists() {
                    let content = fs::read_to_string(&cfg_path).unwrap_or_else(|_| "{}".to_string());
                    serde_json::from_str(&content).unwrap_or_else(|_| serde_json::json!({}))
                } else {
                    serde_json::json!({})
                };

                let servers_key = if root.get("servers").is_some() {
                    "servers"
                } else {
                    "mcpServers"
                };

                if root.get(servers_key).is_none() {
                    root[servers_key] = serde_json::json!({});
                }

                if let Some(obj) = root.get_mut(servers_key).and_then(|v| v.as_object_mut()) {
                    obj.insert(name.to_string(), def);
                }

                let new_content = serde_json::to_string_pretty(&root).map_err(|e| e.to_string())?;
                fs::write(&cfg_path, new_content).map_err(|e| e.to_string())?;
            }
            ConfigFormat::Toml => {
                let mut root: toml::Value = if cfg_path.exists() {
                    let content = fs::read_to_string(&cfg_path).unwrap_or_else(|_| "".to_string());
                    toml::from_str(&content).unwrap_or_else(|_| toml::Value::Table(toml::map::Map::new()))
                } else {
                    toml::Value::Table(toml::map::Map::new())
                };

                if let toml::Value::Table(ref mut map) = root {
                    let servers_entry = map.entry("mcp_servers".to_string()).or_insert_with(|| toml::Value::Table(toml::map::Map::new()));
                    if let toml::Value::Table(s_map) = servers_entry {
                        let toml_def: toml::Value = serde_json::from_value(def).map_err(|e| e.to_string())?;
                        s_map.insert(name.to_string(), toml_def);
                    }
                }
                let new_content = toml::to_string_pretty(&root).map_err(|e| e.to_string())?;
                fs::write(&cfg_path, new_content).map_err(|e| e.to_string())?;
            }
        }
        self.record_history("分发 MCP", "mcp", name, Some(&format!("至 {}", agent.name())));
        Ok(())
    }

    pub fn remove_mcp(&self, name: &str, agent: Agent, project: Option<String>) -> Result<(), String> {
        let (cfg_path, format) = match &project {
            Some(proj) => get_project_mcp_config(agent, Path::new(proj)),
            None => get_global_mcp_config(agent),
        };
        if !cfg_path.exists() {
            return Ok(());
        }

        match format {
            ConfigFormat::Json => {
                if let Ok(content) = fs::read_to_string(&cfg_path) {
                    if let Ok(mut root) = serde_json::from_str::<Value>(&content) {
                        for k in ["mcpServers", "servers"] {
                            if let Some(obj) = root.get_mut(k).and_then(|v| v.as_object_mut()) {
                                obj.remove(name);
                            }
                        }
                        if let Ok(new_content) = serde_json::to_string_pretty(&root) {
                            let _ = fs::write(&cfg_path, new_content);
                        }
                    }
                }
            }
            ConfigFormat::Toml => {
                if let Ok(content) = fs::read_to_string(&cfg_path) {
                    if let Ok(mut root) = toml::from_str::<toml::Value>(&content) {
                        if let toml::Value::Table(ref mut map) = root {
                            if let Some(toml::Value::Table(s_map)) = map.get_mut("mcp_servers") {
                                s_map.remove(name);
                            }
                        }
                        if let Ok(new_content) = toml::to_string_pretty(&root) {
                            let _ = fs::write(&cfg_path, new_content);
                        }
                    }
                }
            }
        }
        self.record_history("移除 MCP", "mcp", name, Some(&format!("从 {}", agent.name())));
        Ok(())
    }

    // --- Presets ---
    pub fn get_presets(&self) -> Vec<Preset> {
        if let Ok(data) = fs::read_to_string(self.presets_file()) {
            serde_json::from_str(&data).unwrap_or_default()
        } else {
            Vec::new()
        }
    }

    pub fn save_preset(&self, preset: Preset) -> Result<(), String> {
        let mut list = self.get_presets();
        list.retain(|p| p.name != preset.name);
        list.push(preset.clone());
        let data = serde_json::to_string_pretty(&list).map_err(|e| e.to_string())?;
        fs::write(self.presets_file(), data).map_err(|e| e.to_string())?;
        self.record_history("保存预设", "preset", &preset.name, None);
        Ok(())
    }

    // --- History ---
    pub fn get_history(&self) -> Vec<HistoryRecord> {
        if let Ok(data) = fs::read_to_string(self.history_file()) {
            serde_json::from_str(&data).unwrap_or_default()
        } else {
            Vec::new()
        }
    }

    pub fn record_history(&self, action: &str, kind: &str, target: &str, details: Option<&str>) {
        let mut list = self.get_history();
        let record = HistoryRecord {
            id: uuid::Uuid::new_v4().to_string(),
            action: action.to_string(),
            kind: kind.to_string(),
            target: target.to_string(),
            timestamp: Utc::now(),
            details: details.map(|s| s.to_string()),
        };
        list.insert(0, record);
        if list.len() > 100 {
            list.truncate(100);
        }
        if let Ok(data) = serde_json::to_string_pretty(&list) {
            let _ = fs::write(self.history_file(), data);
        }
    }
}
