pub mod detection;
pub mod models;
pub mod paths;
pub mod store;

use std::sync::Mutex;
use tauri::State;
use crate::models::*;
use crate::store::ManagerStore;

pub struct AppState {
    pub store: Mutex<ManagerStore>,
}

#[tauri::command]
fn get_agents(state: State<'_, AppState>) -> Vec<AgentStatus> {
    state.store.lock().unwrap().get_agent_statuses()
}

#[tauri::command]
fn get_projects(state: State<'_, AppState>) -> Vec<String> {
    state.store.lock().unwrap().get_projects()
}

#[tauri::command]
fn add_project(path: String, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().add_project(&path)
}

#[tauri::command]
fn remove_project(path: String, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().remove_project(&path)
}

#[tauri::command]
fn list_library_skills(state: State<'_, AppState>) -> Vec<SkillItem> {
    state.store.lock().unwrap().list_library_skills()
}

#[tauri::command]
fn list_installed_skills(state: State<'_, AppState>) -> Vec<SkillItem> {
    state.store.lock().unwrap().list_installed_skills()
}

#[tauri::command]
fn list_library_mcps(state: State<'_, AppState>) -> Vec<McpItem> {
    state.store.lock().unwrap().list_library_mcps()
}

#[tauri::command]
fn list_installed_mcps(state: State<'_, AppState>) -> Vec<McpItem> {
    state.store.lock().unwrap().list_installed_mcps()
}

#[tauri::command]
fn save_mcp(name: String, definition: serde_json::Value, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().save_mcp(&name, definition)
}

#[tauri::command]
fn delete_mcp(name: String, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().delete_mcp(&name)
}

#[tauri::command]
fn deploy_skill(name: String, agent: Agent, project: Option<String>, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().deploy_skill(&name, agent, project)
}

#[tauri::command]
fn remove_skill(name: String, agent: Agent, project: Option<String>, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().remove_skill(&name, agent, project)
}

#[tauri::command]
fn adopt_skill(name: String, src_path: String, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().adopt_skill(&name, &src_path)
}

#[tauri::command]
fn deploy_mcp(name: String, agent: Agent, project: Option<String>, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().deploy_mcp(&name, agent, project)
}

#[tauri::command]
fn remove_mcp(name: String, agent: Agent, project: Option<String>, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().remove_mcp(&name, agent, project)
}

#[tauri::command]
fn get_presets(state: State<'_, AppState>) -> Vec<Preset> {
    state.store.lock().unwrap().get_presets()
}

#[tauri::command]
fn save_preset(preset: Preset, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().save_preset(preset)
}

#[tauri::command]
fn get_history(state: State<'_, AppState>) -> Vec<HistoryRecord> {
    state.store.lock().unwrap().get_history()
}

#[tauri::command]
fn clear_history(state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().clear_history()
}

#[tauri::command]
fn get_preferences(state: State<'_, AppState>) -> UserPreferences {
    state.store.lock().unwrap().get_preferences()
}

#[tauri::command]
fn save_preferences(preferences: UserPreferences, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().save_preferences(preferences)
}

#[tauri::command]
fn list_backups(state: State<'_, AppState>) -> Vec<BackupRecord> {
    state.store.lock().unwrap().list_backups()
}

#[tauri::command]
fn create_backup(state: State<'_, AppState>) -> Result<BackupRecord, String> {
    state.store.lock().unwrap().create_backup()
}

#[tauri::command]
fn restore_backup(filename: String, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().restore_backup(&filename)
}

#[tauri::command]
fn open_path(path: String, state: State<'_, AppState>) -> Result<(), String> {
    state.store.lock().unwrap().open_path(&path)
}

#[tauri::command]
fn window_minimize(window: tauri::Window) {
    let _ = window.minimize();
}

#[tauri::command]
fn window_toggle_maximize(window: tauri::Window) {
    if let Ok(maximized) = window.is_maximized() {
        if maximized {
            let _ = window.unmaximize();
        } else {
            let _ = window.maximize();
        }
    }
}

#[tauri::command]
fn window_close(window: tauri::Window) {
    let _ = window.close();
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    let store = ManagerStore::new();
    let app_state = AppState {
        store: Mutex::new(store),
    };

    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .manage(app_state)
        .invoke_handler(tauri::generate_handler![
            get_agents,
            get_projects,
            add_project,
            remove_project,
            list_library_skills,
            list_installed_skills,
            list_library_mcps,
            list_installed_mcps,
            save_mcp,
            delete_mcp,
            deploy_skill,
            remove_skill,
            adopt_skill,
            deploy_mcp,
            remove_mcp,
            get_presets,
            save_preset,
            get_history,
            clear_history,
            get_preferences,
            save_preferences,
            list_backups,
            create_backup,
            restore_backup,
            open_path,
            window_minimize,
            window_toggle_maximize,
            window_close,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
