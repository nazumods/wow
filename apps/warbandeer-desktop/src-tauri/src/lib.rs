mod combatlog;
mod model;
mod overview;
mod savedvars;
mod wow;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            overview::get_overview,
            combatlog::list_combat_logs,
            combatlog::summarize_combat_log,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
