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
    /// Absent on a character the currency broker has never run for; `Currency::get` then
    /// reports every field as "never captured", which is a render case, not an error.
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

/// One entry of `toon.currency`, in every shape the broker writes.
///
/// `Warbandeer_Characters/data/currency.lua` stores four scalar fields (`gold`,
/// `RestoredCofferKey`, `FieldAccolade`, `UnalloyedAbundance`) and six tables, the tables
/// themselves in four different shapes depending on which caps the currency has. One
/// all-defaulted [`CurrencyTable`] collapses those four; the `Scalar` arm covers the plain
/// numbers **and** the legacy `NebulousVoidcore`, which real saves can still hold as a bare
/// count from before it became a table (the addon's own `reset` carries a `type(c) ==
/// "number"` branch for exactly this).
#[derive(Deserialize, Clone, Debug)]
#[serde(untagged)]
pub enum CurrencyValue {
    Scalar(f64),
    Table(CurrencyTable),
}

impl CurrencyValue {
    /// The held amount, whichever shape the broker wrote it in.
    pub fn quantity(&self) -> f64 {
        match self {
            CurrencyValue::Scalar(n) => *n,
            CurrencyValue::Table(t) => t.quantity,
        }
    }
}

/// The table-shaped currency entries. Every key is optional because no single broker field
/// writes all of them: `max` is a hold cap, `weeklyMax` a weekly earn cap, and only
/// `ShardOfDundun` carries both.
#[derive(Deserialize, Default, Clone, Debug)]
#[serde(default)]
pub struct CurrencyTable {
    pub quantity: f64,
    pub earned: f64,
    pub max: f64,
    #[serde(rename = "weeklyMax")]
    pub weekly_max: f64,
    pub capped: bool,
}

/// `toon.currency` — kept as the raw field map rather than named fields.
///
/// The keys are the broker's hand-written field names, and the map from those to currency ids
/// lives in the static-data bundle (`currencyFields`), not here — so naming them in Rust would
/// duplicate a table that already has one source of truth, and would silently drop any field
/// added to the broker later. `gold` is the one field with no currency id behind it: it is
/// `GetMoney()` in copper.
#[derive(Deserialize, Default)]
#[serde(transparent)]
pub struct Currency {
    pub fields: HashMap<String, CurrencyValue>,
}

/// The broker's money field: the one key with no currency id behind it.
pub const GOLD_FIELD: &str = "gold";

impl Currency {
    /// The character's money in copper. Absent (never captured) reads as 0, which is what
    /// summing warband wealth wants.
    pub fn gold(&self) -> f64 {
        self.fields.get(GOLD_FIELD).map_or(0.0, CurrencyValue::quantity)
    }
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
