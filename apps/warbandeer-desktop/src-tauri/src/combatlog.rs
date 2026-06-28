//! Combat-log listing + a lightweight CLEU summary (no full damage-meter math).

use crate::wow;
use serde::Serialize;
use std::collections::HashMap;
use std::io::{BufRead, BufReader};
use std::time::UNIX_EPOCH;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CombatLogFile {
    pub name: String,
    pub path: String,
    pub size_bytes: u64,
    pub modified_secs: u64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DamageRow {
    pub name: String,
    pub amount: i64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CombatLogSummary {
    pub path: String,
    pub lines: u64,
    pub encounters: Vec<String>,
    pub top_damage: Vec<DamageRow>,
}

#[tauri::command]
pub fn list_combat_logs(wow_dir: Option<String>) -> Result<Vec<CombatLogFile>, String> {
    let retail = wow::find_retail_dir(wow_dir.as_deref())
        .ok_or("Couldn't find a WoW _retail_ folder. Set WOW_DIR.")?;
    let dir = wow::logs_dir(&retail);
    let mut out = Vec::new();
    let Ok(rd) = std::fs::read_dir(&dir) else {
        return Ok(out); // no Logs dir yet → empty list, not an error
    };
    for entry in rd.flatten() {
        let name = entry.file_name().to_string_lossy().into_owned();
        if !(name.starts_with("WoWCombatLog") && name.ends_with(".txt")) {
            continue;
        }
        let meta = entry.metadata().map_err(|e| e.to_string())?;
        let modified = meta
            .modified()
            .ok()
            .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
            .map(|d| d.as_secs())
            .unwrap_or(0);
        out.push(CombatLogFile {
            name,
            path: entry.path().to_string_lossy().into_owned(),
            size_bytes: meta.len(),
            modified_secs: modified,
        });
    }
    // newest first
    out.sort_by(|a, b| b.modified_secs.cmp(&a.modified_secs));
    Ok(out)
}

/// Split a CLEU payload on commas, respecting double-quoted fields, stripping quotes.
fn split_fields(payload: &str) -> Vec<String> {
    let mut fields = Vec::new();
    let mut cur = String::new();
    let mut in_quotes = false;
    for ch in payload.chars() {
        match ch {
            '"' => in_quotes = !in_quotes,
            ',' if !in_quotes => {
                fields.push(std::mem::take(&mut cur));
            }
            _ => cur.push(ch),
        }
    }
    fields.push(cur);
    fields
}

fn is_damage_event(event: &str) -> bool {
    matches!(event, "SWING_DAMAGE" | "SWING_DAMAGE_LANDED" | "RANGE_DAMAGE")
        || (event.ends_with("_DAMAGE") && event.starts_with("SPELL"))
        || event.ends_with("_DAMAGE_LANDED")
}

#[tauri::command]
pub fn summarize_combat_log(path: String) -> Result<CombatLogSummary, String> {
    let file = std::fs::File::open(&path).map_err(|e| format!("open: {e}"))?;
    let reader = BufReader::new(file);

    let mut lines = 0u64;
    let mut encounters: Vec<String> = Vec::new();
    let mut damage: HashMap<String, i64> = HashMap::new();

    for line in reader.lines() {
        let Ok(line) = line else { break };
        lines += 1;

        // timestamp and payload are separated by two spaces.
        let Some(idx) = line.find("  ") else { continue };
        let payload = line[idx + 2..].trim_start();
        if payload.is_empty() {
            continue;
        }
        // cheap event sniff before the full split.
        let event_end = payload.find(',').unwrap_or(payload.len());
        let event = &payload[..event_end];

        if event == "ENCOUNTER_START" {
            let f = split_fields(payload);
            if let Some(name) = f.get(2) {
                if !name.is_empty() && !encounters.iter().any(|e| e == name) {
                    encounters.push(name.clone());
                }
            }
            continue;
        }

        if is_damage_event(event) {
            let f = split_fields(payload);
            // Damage suffix is a fixed 10 trailing fields:
            // amount, overkill, school, resisted, blocked, absorbed, crit, glancing, crushing, isOffHand.
            // sourceName is the 3rd field (event, sourceGUID, sourceName, ...).
            if f.len() >= 13 {
                let amount = f[f.len() - 10].parse::<i64>().unwrap_or(0);
                if amount > 0 {
                    let src = f[2].clone();
                    if !src.is_empty() {
                        *damage.entry(src).or_insert(0) += amount;
                    }
                }
            }
        }
    }

    let mut rows: Vec<DamageRow> = damage
        .into_iter()
        .map(|(name, amount)| DamageRow { name, amount })
        .collect();
    rows.sort_by(|a, b| b.amount.cmp(&a.amount));
    rows.truncate(10);

    encounters.truncate(20);

    Ok(CombatLogSummary {
        path,
        lines,
        encounters,
        top_damage: rows,
    })
}
