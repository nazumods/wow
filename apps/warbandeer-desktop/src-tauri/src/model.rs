//! Typed subset of `WarbandeerCharDB` — only the fields the Overview needs.
//!
//! All numerics are `f64`: WoW's Lua 5.1 has no integer subtype, so saved numbers
//! round-trip as doubles. serde's float visitor accepts integers too, so `f64` is
//! the one type that deserializes every numeric cell without "invalid type" errors.
//! Unknown fields (the bulk of each character record) are ignored.

use serde::Deserialize;
use std::collections::HashMap;

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct CharDb {
    pub version: Option<f64>,
    pub warband: Warband,
    pub characters: HashMap<String, Character>,
    /// Account-wide, so it hangs off the DB root rather than a character — the addon
    /// stores it at `db.achievements` (Warbandeer_Characters/data/achievements.lua).
    /// A save written before that shipped has no key at all, which `#[serde(default)]`
    /// renders as "not captured yet" instead of failing the whole parse.
    pub achievements: Achievements,
}

/// `db.achievements` — the account-wide completion snapshot plus the point total.
#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Achievements {
    /// Keyed by achievement id as an INTEGER. The addon writes a Lua numeric key, and mlua's
    /// deserializer preserves that — unlike `staticdata`'s maps, which are string-keyed only
    /// because JSON object keys always are. Typing this `String` parses every other save fine
    /// and then fails on the first one that actually has achievements captured.
    pub snapshot: HashMap<i64, AchievementEntry>,
    #[serde(rename = "totalPoints")]
    pub total_points: f64,
}

/// One tracked achievement's persisted state.
///
/// `wasEarnedByMe` is deliberately NOT surfaced: the addon documents it as
/// last-captured-character-wins rather than per-alt, so exposing it here would invite a
/// per-character reading the data cannot support.
#[derive(Deserialize, Default)]
#[serde(default)]
pub struct AchievementEntry {
    pub completed: bool,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Warband {
    #[serde(rename = "bankGold")]
    pub bank_gold: f64,
    pub week: Option<Week>,
    pub history: Vec<WeekRecord>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Week {
    pub baseline: f64,
}

/// One closed week of wealth history (`db.warband.history`, oldest first).
#[derive(Deserialize, Default)]
#[serde(default)]
pub struct WeekRecord {
    pub ending: f64,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Character {
    pub realm: Option<String>,
    pub guid: Option<String>,
    #[serde(rename = "classKey")]
    pub class_key: Option<String>,
    #[serde(rename = "classId")]
    pub class_id: f64,
    #[serde(rename = "className")]
    pub class_name: Option<String>,
    #[serde(rename = "isAlliance")]
    pub is_alliance: bool,
    pub basic: Basic,
    pub equipment: Option<Equipment>,
    pub currency: Option<Currency>,
    pub playtime: Option<Playtime>,
    pub reputations: Option<Reputations>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Basic {
    pub level: f64,
    pub specialization: Option<Specialization>,
    pub professions: Option<Professions>,
}

/// `role` is Blizzard's `GetSpecializationRoleByID` token: `"TANK"`/`"HEALER"`/`"DAMAGER"`.
/// `active` is the current spec's display name (e.g. `"Frost"`); `key` is the same name as
/// a stable token, used as a fallback for older saves that predate `active`.
#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Specialization {
    pub role: Option<String>,
    pub active: Option<String>,
    pub key: Option<String>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Professions {
    pub primary: Option<ProfessionSlot>,
    pub secondary: Option<ProfessionSlot>,
}

/// `Player:GetProfessions()`'s per-slot `:GetInfo()` result — only `name` is needed here.
#[derive(Deserialize, Default)]
#[serde(default)]
pub struct ProfessionSlot {
    pub name: Option<String>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Equipment {
    pub ilvl: Option<f64>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Currency {
    pub gold: f64,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Playtime {
    pub total: f64,
    #[serde(rename = "byPatch")]
    pub by_patch: HashMap<String, f64>,
    /// Logged-in seconds per local calendar day ("YYYY-MM-DD"); absent on old saves.
    #[serde(rename = "byDay")]
    pub by_day: HashMap<String, f64>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Reputations {
    pub factions: HashMap<i64, Faction>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Faction {
    pub name: Option<String>,
    pub label: Option<String>,
    pub rank: f64,
    pub done: bool,
    pub paragon: bool,
}
