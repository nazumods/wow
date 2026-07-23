mod botops;
mod charorder;
mod combatlog;
mod model;
mod overview;
mod savedvars;
mod staticdata;
mod wow;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![
            overview::get_overview,
            combatlog::list_combat_logs,
            combatlog::summarize_combat_log,
            charorder::list_order_accounts,
            charorder::get_character_order,
            charorder::save_character_order,
            charorder::get_remembered_order,
            charorder::remember_character_order,
            botops::ops_config,
            botops::bot_status,
            botops::bot_logs,
            botops::bot_restart,
            botops::bot_env_get,
            botops::bot_env_set,
            staticdata::get_currency_meta,
            staticdata::static_data_build,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
