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
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Warband {
    #[serde(rename = "bankGold")]
    pub bank_gold: f64,
    pub week: Option<Week>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Week {
    pub baseline: f64,
}

#[derive(Deserialize, Default)]
#[serde(default)]
pub struct Character {
    pub realm: Option<String>,
    #[serde(rename = "classKey")]
    pub class_key: Option<String>,
    #[serde(rename = "classId")]
    pub class_id: f64,
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
