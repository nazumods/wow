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
    /// Week-end wealth (copper) for up to the last 11 closed weeks, oldest first,
    /// with the current live wealth appended — a ≤12-point trend series.
    pub wealth_history_copper: Vec<f64>,
    /// Logged-in seconds per local calendar day ("YYYY-MM-DD"), summed across all
    /// characters. The frontend windows this into its activity grid.
    pub playtime_by_day: HashMap<String, f64>,
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

/// One checklist row: the persisted completion bit joined to the bundled display metadata.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AchievementRow {
    pub id: u32,
    /// `None` when the id isn't in the bundle — a catalog/bundle skew rather than an error.
    /// The frontend renders the bare id in that case, so the skew is visible instead of silent.
    pub name: Option<String>,
    /// Bare icon name for the `wbicon` scheme, or `None` when the bundle carries no icon for
    /// the id. Sent even though it duplicates the bundle, for the same reason `name` is: the
    /// alternative is an IPC round trip per row.
    pub icon: Option<String>,
    pub points: i64,
    pub completed: bool,
}

/// The checklist for one expansion, in the catalog's own order.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AchievementGroup {
    /// Catalog key (`wwi` / `midnight` / `dragonflight`); the frontend owns label + order.
    pub key: String,
    pub rows: Vec<AchievementRow>,
    pub completed_count: usize,
}

/// The Achievements column.
///
/// Joined HERE rather than in the frontend: `get_achievement_meta` is a per-id command, and this
/// column spans ~35 ids across three groups — one pre-joined payload beats 35 IPC round trips.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OverviewAchievements {
    pub groups: Vec<AchievementGroup>,
    pub total_points: i64,
    /// False when the save has no `db.achievements` at all — i.e. it predates the addon-side
    /// snapshot. Distinguishes "nothing captured yet" from "captured, nothing completed".
    pub captured: bool,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Overview {
    pub account: Option<String>,
    pub db_version: Option<i64>,
    pub stats: OverviewStats,
    pub reputations: Vec<FactionStanding>,
    pub top_characters: Vec<TopCharacter>,
    pub achievements: OverviewAchievements,
    /// The Currencies TAB's grid, not an Overview column. It rides along on this one command
    /// because it comes out of the same parsed save: a command of its own would mean a second
    /// mlua exec of a multi-megabyte SavedVariables file on every load, and would sit outside
    /// the ⟳ refresh the frontend already wires to this payload.
    pub currencies: crate::currencies::Currencies,
}

/// Expansion keys in the order the in-game Overview lists them
/// (`Warbandeer/views/Overview.lua`'s `EXPANSIONS`). A key the bundle doesn't carry yields an
/// empty group rather than being dropped, so a catalog addition shows up as a visible hole.
const EXPANSION_ORDER: [&str; 3] = ["midnight", "wwi", "dragonflight"];

/// Join `db.achievements` against the bundled catalog into the per-expansion checklist.
fn build_achievements(db: &CharDb) -> OverviewAchievements {
    let bundle = crate::staticdata::get();
    let snapshot = &db.achievements.snapshot;
    let groups = EXPANSION_ORDER
        .iter()
        .map(|key| {
            let rows: Vec<AchievementRow> = bundle
                .achievement_group(key)
                .iter()
                .map(|&id| {
                    let meta = bundle.achievement(id);
                    AchievementRow {
                        id,
                        name: meta.map(|m| m.name.clone()),
                        icon: meta.and_then(|m| m.icon.clone()),
                        points: meta.map_or(0, |m| m.points),
                        completed: snapshot.get(&(id as i64)).is_some_and(|e| e.completed),
                    }
                })
                .collect();
            AchievementGroup {
                key: (*key).to_string(),
                completed_count: rows.iter().filter(|r| r.completed).count(),
                rows,
            }
        })
        .collect();

    OverviewAchievements {
        groups,
        total_points: db.achievements.total_points as i64,
        captured: !snapshot.is_empty(),
    }
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

/// `byLevelIlvl`: level desc, then ilvl desc, then name asc. Shared with the Currencies grid,
/// which orders its rows the same way the in-game Summary view does.
pub fn cmp_by_level_ilvl(a: &Character, an: &str, b: &Character, bn: &str) -> std::cmp::Ordering {
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
    let mut playtime_by_day: HashMap<String, f64> = HashMap::new();
    for c in db.characters.values() {
        count += 1;
        if let Some(cur) = &c.currency {
            wealth += cur.gold();
        }
        if let Some(pt) = &c.playtime {
            total_play += pt.total;
            if let Some(p) = &current_patch {
                if let Some(snap) = pt.by_patch.get(p) {
                    patch_play += pt.total - snap;
                }
            }
            for (day, secs) in &pt.by_day {
                *playtime_by_day.entry(day.clone()).or_insert(0.0) += secs;
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

    let hist = &db.warband.history;
    let mut wealth_history: Vec<f64> = hist[hist.len().saturating_sub(11)..]
        .iter()
        .map(|r| r.ending)
        .collect();
    wealth_history.push(wealth);

    let stats = OverviewStats {
        wealth_copper: wealth,
        weekly_gold_made_copper: weekly_made,
        wealth_history_copper: wealth_history,
        playtime_by_day,
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
        achievements: build_achievements(db),
        currencies: crate::currencies::build(db),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{AchievementEntry, Achievements};

    /// A save written before the addon-side snapshot shipped has no `db.achievements` at all.
    /// That must render as "not captured", never fail the parse or the join — this is the case
    /// that regresses if the field stops being `#[serde(default)]`.
    #[test]
    fn absent_achievements_yield_an_uncaptured_column() {
        let db = CharDb::default();
        let a = build_achievements(&db);
        assert!(!a.captured, "no snapshot means not captured");
        assert_eq!(a.total_points, 0);
        // The groups still exist, so the column renders its structure rather than vanishing.
        assert_eq!(a.groups.len(), EXPANSION_ORDER.len());
        assert!(a.groups.iter().all(|g| g.completed_count == 0));
    }

    /// A populated snapshot joins onto the bundled catalog: completion comes from the save,
    /// name and points from the bundle, and the per-group tally counts only completed rows.
    #[test]
    fn present_achievements_join_against_the_bundle() {
        let bundle = crate::staticdata::get();
        // Drive the test off whatever the catalog actually declares, so it can't rot when the
        // checklist changes — a hardcoded id would.
        let key = "midnight";
        let ids = bundle.achievement_group(key);
        assert!(!ids.is_empty(), "the bundle should carry a {key} checklist");
        let done = ids[0];

        let db = CharDb {
            achievements: Achievements {
                snapshot: [(done as i64, AchievementEntry { completed: true })]
                    .into_iter()
                    .collect(),
                total_points: 1234.0,
            },
            ..Default::default()
        };

        let a = build_achievements(&db);
        assert!(a.captured);
        assert_eq!(a.total_points, 1234);
        let group = a.groups.iter().find(|g| g.key == key).expect("group");
        assert_eq!(group.rows.len(), ids.len());
        assert_eq!(group.completed_count, 1);
        let row = group.rows.iter().find(|r| r.id == done).expect("row");
        assert!(row.completed);
        assert!(row.name.is_some(), "a tracked id resolves against the bundle");

        // Every checklist row carries its icon NAME through to the frontend — unlike
        // currencies, every tracked achievement has one in DB2, so a null is a plumbing bug.
        //
        // Serving it is a weaker claim on purpose: a few names are indexed with no image
        // because the source has none for them (all of them names with a literal space, e.g.
        // "ui_majorfaction_ vines"). That is the graceful-fallback case the UI has to render
        // anyway, so this pins the bulk rather than demanding every single one.
        let mut servable = 0;
        for r in &group.rows {
            let icon = r.icon.as_deref().expect("a tracked achievement carries an icon");
            if crate::icons::get().image(icon).is_some() {
                servable += 1;
            }
        }
        assert!(
            servable * 10 >= group.rows.len() * 9,
            "only {servable}/{} checklist icons resolve to an image",
            group.rows.len()
        );
    }

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

        // The currency grid runs over the same real save. The unit tests cover the shapes with
        // hand-built values; this is the one place the untagged enum meets what mlua actually
        // hands back — including a legacy bare-number entry, if this account still has one.
        let cur = &ov.currencies;
        assert!(!cur.columns.is_empty(), "expected currency columns");
        assert_eq!(cur.rows.len(), ov.stats.char_count, "a row per character");
        assert!(
            cur.rows.iter().all(|r| r.cells.len() == cur.columns.len()),
            "every row must be as wide as the header"
        );
        let captured = cur
            .rows
            .iter()
            .flat_map(|r| &r.cells)
            .filter(|c| c.quantity.is_some())
            .count();
        eprintln!(
            "currencies: {} columns x {} rows, {captured} cells captured",
            cur.columns.len(),
            cur.rows.len(),
        );
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
