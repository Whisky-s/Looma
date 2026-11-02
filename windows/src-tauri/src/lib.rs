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
            get_presets,
            save_preset,
            get_history,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
