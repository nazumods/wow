mod charorder;
mod combatlog;
mod model;
mod overview;
mod savedvars;
mod staticdata;
mod wow;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    // Keeps the pre-extraction override working now that the Bot Ops backend is the shared
    // `bot-ops` crate; it also honours the crate's own `BOT_OPS_CONFIG`.
    bot_ops::set_config_env_var("WARBANDEER_OPS_CONFIG");

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
            bot_ops::commands::ops_config,
            bot_ops::commands::bot_status,
            bot_ops::commands::bot_logs,
            bot_ops::commands::bot_restart,
            bot_ops::commands::bot_env_get,
            bot_ops::commands::bot_env_set,
            staticdata::get_currency_meta,
            staticdata::get_achievement_meta,
            staticdata::static_data_build,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
