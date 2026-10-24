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

#[tauri::command(async)]
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
    out.sort_by_key(|f| std::cmp::Reverse(f.modified_secs));
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

#[tauri::command(async)]
pub fn summarize_combat_log(path: String) -> Result<CombatLogSummary, String> {
    let file = std::fs::File::open(&path).map_err(|e| format!("open: {e}"))?;
    summarize_reader(BufReader::new(file), path)
}

fn summarize_reader<R: BufRead>(mut reader: R, path: String) -> Result<CombatLogSummary, String> {
    let mut lines = 0u64;
    let mut encounters: Vec<String> = Vec::new();
    let mut damage: HashMap<String, i64> = HashMap::new();

    let mut buf = Vec::new();
    loop {
        buf.clear();
        // Read raw bytes so a stray invalid-UTF-8 line is lossily decoded instead of ending the parse.
        match reader.read_until(b'\n', &mut buf) {
            Ok(0) => break,
            Ok(_) => {}
            Err(e) => return Err(format!("read: {e}")),
        }
        let line = String::from_utf8_lossy(&buf);
        let line = line.trim_end_matches(['\n', '\r']);
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

    let mut rows: Vec<DamageRow> =
        damage.into_iter().map(|(name, amount)| DamageRow { name, amount }).collect();
    rows.sort_by_key(|r| std::cmp::Reverse(r.amount));
    rows.truncate(10);

    encounters.truncate(20);

    Ok(CombatLogSummary { path, lines, encounters, top_damage: rows })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn run(bytes: &[u8]) -> CombatLogSummary {
        summarize_reader(bytes, "t".into()).unwrap()
    }

    const SWING: &str = "10/24 20:00:01.000  SWING_DAMAGE,Player-1-A,\"Thrall,Of-Realm\",0x511,0x0,Creature-0-B,\"Boss\",0x10a48,0x0,100,0,1,0,0,0,0,0,0,0";
    const SPELL: &str = "10/24 20:00:02.000  SPELL_DAMAGE,Player-1-B,\"Jaina-Realm\",0x511,0x0,Creature-0-B,\"Boss\",0x10a48,0x0,116,Fireball,0x4,50,0,4,0,0,0,0,0,0,0";

    #[test]
    fn counts_encounter_swing_and_spell_with_quoted_comma() {
        let log = format!(
            "10/24 20:00:00.000  ENCOUNTER_START,2902,\"Ulgrax, the Devourer\",15,20,2657\n{SWING}\n{SPELL}\n"
        );
        let s = run(log.as_bytes());
        assert_eq!(s.lines, 3);
        assert_eq!(s.encounters, vec!["Ulgrax, the Devourer"]);
        assert_eq!(s.top_damage[0].name, "Thrall,Of-Realm");
        assert_eq!(s.top_damage[0].amount, 100);
        assert_eq!(s.top_damage[1].name, "Jaina-Realm");
        assert_eq!(s.top_damage[1].amount, 50);
    }

    #[test]
    fn invalid_utf8_line_does_not_stop_the_parse() {
        let mut log = b"10/24 20:00:00.000  COMBAT_LOG_VERSION,\xff\xfe\n".to_vec();
        log.extend_from_slice(SWING.as_bytes());
        log.push(b'\n');
        let s = run(&log);
        assert_eq!(s.lines, 2);
        assert_eq!(s.top_damage[0].amount, 100);
    }
}
