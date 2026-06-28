//! Compute the Overview payload from the parsed SavedVariables. Mirrors the logic
//! in Warbandeer/views/Overview.lua + views/overview/TopAlts.lua + FactionBars.lua,
//! using only data that's persisted to SavedVariables.

use crate::model::{CharDb, Character};
use crate::{savedvars, wow};
use serde::Serialize;
use std::collections::HashMap;

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OverviewStats {
    pub wealth_copper: f64,
    pub weekly_gold_made_copper: f64,
    pub total_playtime_secs: f64,
    pub patch_playtime_secs: f64,
    pub char_count: usize,
    pub top_ilvl: i64,
    pub current_patch: Option<String>,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct FactionStanding {
    pub name: String,
    pub label: String,
    pub pct: f64,
    pub done: bool,
    pub paragon: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TopCharacter {
    pub name: String,
    pub realm: Option<String>,
    pub class_key: String,
    pub class_id: i64,
    pub level: i64,
    pub ilvl: i64,
    pub is_alliance: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Overview {
    pub account: Option<String>,
    pub db_version: Option<i64>,
    pub stats: OverviewStats,
    pub reputations: Vec<FactionStanding>,
    pub top_characters: Vec<TopCharacter>,
}

fn ilvl_of(c: &Character) -> f64 {
    c.equipment.as_ref().and_then(|e| e.ilvl).unwrap_or(0.0)
}

/// Naive WoW patch-version compare ("12.0.7" > "12.0.5"), numeric per dotted part.
fn version_gt(a: &str, b: &str) -> bool {
    let pa = a.split('.').map(|p| p.parse::<i64>().unwrap_or(0));
    let pb: Vec<i64> = b.split('.').map(|p| p.parse::<i64>().unwrap_or(0)).collect();
    for (i, x) in pa.enumerate() {
        let y = pb.get(i).copied().unwrap_or(0);
        if x != y {
            return x > y;
        }
    }
    false
}

/// `byLevelIlvl`: level desc, then ilvl desc, then name asc.
fn cmp_by_level_ilvl(a: &Character, an: &str, b: &Character, bn: &str) -> std::cmp::Ordering {
    use std::cmp::Ordering;
    let la = a.basic.level as i64;
    let lb = b.basic.level as i64;
    if la != lb {
        return lb.cmp(&la);
    }
    let ia = ilvl_of(a);
    let ib = ilvl_of(b);
    if ia != ib {
        return ib.partial_cmp(&ia).unwrap_or(Ordering::Equal);
    }
    an.cmp(bn)
}

fn build(db: &CharDb, account: Option<String>) -> Overview {
    // ── stats ────────────────────────────────────────────────────────────────
    let mut wealth = db.warband.bank_gold;
    let mut total_play = 0.0;
    let mut top_ilvl = 0.0;
    let mut count = 0usize;

    // current patch = newest byPatch key seen across all characters.
    let mut current_patch: Option<String> = None;
    for c in db.characters.values() {
        if let Some(pt) = &c.playtime {
            for k in pt.by_patch.keys() {
                if current_patch.as_deref().map(|cur| version_gt(k, cur)).unwrap_or(true) {
                    current_patch = Some(k.clone());
                }
            }
        }
    }

    let mut patch_play = 0.0;
    for c in db.characters.values() {
        count += 1;
        if let Some(cur) = &c.currency {
            wealth += cur.gold;
        }
        if let Some(pt) = &c.playtime {
            total_play += pt.total;
            if let Some(p) = &current_patch {
                if let Some(snap) = pt.by_patch.get(p) {
                    patch_play += pt.total - snap;
                }
            }
        }
        let il = ilvl_of(c);
        if il > top_ilvl {
            top_ilvl = il;
        }
    }

    let weekly_made = db
        .warband
        .week
        .as_ref()
        .map(|w| wealth - w.baseline)
        .unwrap_or(0.0);

    let stats = OverviewStats {
        wealth_copper: wealth,
        weekly_gold_made_copper: weekly_made,
        total_playtime_secs: total_play,
        patch_playtime_secs: patch_play,
        char_count: count,
        top_ilvl: top_ilvl.round() as i64,
        current_patch,
    };

    // ── top character per class ──────────────────────────────────────────────
    let mut best: HashMap<String, (&str, &Character)> = HashMap::new();
    for (name, c) in &db.characters {
        let key = c.class_key.clone().unwrap_or_default();
        if key.is_empty() {
            continue;
        }
        match best.get(&key) {
            Some((bn, bc)) if cmp_by_level_ilvl(c, name, bc, bn) != std::cmp::Ordering::Less => {}
            _ => {
                best.insert(key, (name.as_str(), c));
            }
        }
    }
    let mut top: Vec<TopCharacter> = best
        .into_values()
        .map(|(name, c)| TopCharacter {
            name: name.to_string(),
            realm: c.realm.clone(),
            class_key: c.class_key.clone().unwrap_or_default(),
            class_id: c.class_id as i64,
            level: c.basic.level as i64,
            ilvl: ilvl_of(c).round() as i64,
            is_alliance: c.is_alliance,
        })
        .collect();
    top.sort_by(|a, b| {
        b.level
            .cmp(&a.level)
            .then(b.ilvl.cmp(&a.ilvl))
            .then(a.name.cmp(&b.name))
    });

    // ── reputations: best standing per faction, account-wide ─────────────────
    // Offline analogue of the Overview's live rep bars: across every character,
    // keep the highest standing reached for each faction (done first, then rank).
    struct Best {
        name: String,
        label: String,
        rank: f64,
        done: bool,
        paragon: bool,
    }
    let mut reps: HashMap<i64, Best> = HashMap::new();
    for c in db.characters.values() {
        let Some(r) = &c.reputations else { continue };
        for (fid, f) in &r.factions {
            let Some(fname) = f.name.clone().filter(|n| !n.is_empty()) else {
                continue;
            };
            let cand = Best {
                name: fname,
                label: f.label.clone().unwrap_or_default(),
                rank: f.rank,
                done: f.done,
                paragon: f.paragon,
            };
            let take = match reps.get(fid) {
                None => true,
                Some(cur) => {
                    (cand.done, cand.rank) > (cur.done, cur.rank)
                        || (cand.paragon && !cur.paragon)
                }
            };
            if take {
                reps.insert(*fid, cand);
            }
        }
    }
    let mut rep_list: Vec<Best> = reps.into_values().collect();
    // done/paragon first, then by rank desc, then name.
    rep_list.sort_by(|a, b| {
        b.done
            .cmp(&a.done)
            .then(b.paragon.cmp(&a.paragon))
            .then(b.rank.partial_cmp(&a.rank).unwrap_or(std::cmp::Ordering::Equal))
            .then(a.name.cmp(&b.name))
    });
    rep_list.truncate(16);

    // Relative bar fill: capped/paragon are full; in-progress are rank/maxRank
    // among the shown in-progress factions (a real comparison, not invented precision).
    let max_rank = rep_list
        .iter()
        .filter(|r| !(r.done || r.paragon))
        .map(|r| r.rank)
        .fold(0.0_f64, f64::max)
        .max(1.0);
    let reputations = rep_list
        .into_iter()
        .map(|r| FactionStanding {
            pct: if r.done || r.paragon {
                1.0
            } else {
                (r.rank / max_rank).clamp(0.0, 1.0)
            },
            name: r.name,
            label: r.label,
            done: r.done,
            paragon: r.paragon,
        })
        .collect();

    Overview {
        account,
        db_version: db.version.map(|v| v as i64),
        stats,
        reputations,
        top_characters: top,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // End-to-end against the live install if present (mlua deserialize of the real
    // SavedVariables is the riskiest path). Skips cleanly when no install is found.
    #[test]
    fn real_data_pipeline() {
        let Some(retail) = wow::find_retail_dir(None) else {
            eprintln!("no WoW install found — skipping");
            return;
        };
        let Some((account, path)) = wow::find_saved_var(&retail, "Warbandeer_Characters.lua")
        else {
            eprintln!("no Warbandeer_Characters.lua — skipping");
            return;
        };
        let db = savedvars::load_char_db(&path).expect("load char db");
        let ov = build(&db, Some(account));
        assert!(ov.stats.char_count > 0, "expected some characters");
        eprintln!(
            "account={:?} chars={} topIlvl={} wealthG={} reps={} top={}",
            ov.account,
            ov.stats.char_count,
            ov.stats.top_ilvl,
            (ov.stats.wealth_copper / 10000.0) as i64,
            ov.reputations.len(),
            ov.top_characters.len(),
        );
        for t in ov.top_characters.iter().take(5) {
            eprintln!("  {:>3} {:<14} ilvl {}", t.level, t.name, t.ilvl);
        }
    }
}

#[tauri::command]
pub fn get_overview(wow_dir: Option<String>) -> Result<Overview, String> {
    let retail = wow::find_retail_dir(wow_dir.as_deref())
        .ok_or("Couldn't find a WoW _retail_ folder (no WTF/Account). Set WOW_DIR.")?;
    let (account, path) = wow::find_saved_var(&retail, "Warbandeer_Characters.lua")
        .ok_or("No Warbandeer_Characters.lua found under any account's SavedVariables.")?;
    let db = savedvars::load_char_db(&path)?;
    Ok(build(&db, Some(account)))
}
