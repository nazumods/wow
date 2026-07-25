//! Offline lookup layer for constant game data the client would normally resolve.
//!
//! SavedVariables store ids, not the constants behind them — a currency *amount* keyed by
//! id, an achievement's completed bit keyed by id — while the name, icon, cap and points
//! live in DB2. The app ships as a single portable exe with no network access, so the
//! bundle is generated at CI time by `Tooling/update-static-data.ps1` and embedded here
//! rather than fetched. See that script (and `Tooling/UPDATING-static-data.md`) for provenance.
//!
//! Scope is what the addon does *not* persist, on purpose. Currencies, because there is no
//! Blizzard REST equivalent at all (the Game Data API has no currency endpoint), so they stay
//! wago-sourced whatever the app does about API credentials later. Achievements, because
//! `Warbandeer_Characters/data/achievements.lua` deliberately snapshots only the completed /
//! earned-by-me bits and leaves display metadata to be looked up here. Everything else the
//! app renders — title catalog, keystone and mastery names, pet species — the addon persists
//! itself, and is deliberately absent.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::OnceLock;

/// The generated bundle, compiled into the exe — a sidecar file would break the
/// single-portable-exe property (`bundle.active: false`).
const BUNDLE_JSON: &str = include_str!("../data/static-data.json");

#[derive(Debug, Deserialize, Serialize, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct CurrencyMeta {
    pub name: String,
    /// Bare icon name (`inv_misc_coin_01`), not a path. `None` when DB2 carries no
    /// icon for the currency, or the FileDataID is absent from the community listfile.
    pub icon: Option<String>,
    /// 0 means uncapped.
    pub max_qty: i64,
    pub quality: i64,
}

#[derive(Debug, Deserialize, Serialize, Clone, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct AchievementMeta {
    pub name: String,
    /// Bare icon name, as [`CurrencyMeta::icon`].
    pub icon: Option<String>,
    pub points: i64,
}

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct StaticData {
    /// Client build the bundle was generated from, e.g. `12.0.7.68453`.
    pub build: String,
    pub build_date: String,
    /// Keyed by currency id as a string — JSON object keys are always strings.
    #[serde(default)]
    pub currencies: HashMap<String, CurrencyMeta>,
    /// Keyed by achievement id as a string. Covers only the ids Warbandeer's views track
    /// (`Warbandeer_Characters/data/achievementcatalog.lua`), not all of `Achievement.db2` —
    /// so a miss means "not tracked", not "unknown to the client".
    #[serde(default)]
    pub achievements: HashMap<String, AchievementMeta>,
}

impl StaticData {
    pub fn currency(&self, id: u32) -> Option<&CurrencyMeta> {
        self.currencies.get(&id.to_string())
    }

    pub fn achievement(&self, id: u32) -> Option<&AchievementMeta> {
        self.achievements.get(&id.to_string())
    }
}

/// Parse a bundle. Split out from [`get`] so malformed input is testable — the embedded
/// asset itself is generated and CI-validated, so it cannot fail in a shipped build.
fn parse(json: &str) -> Result<StaticData, String> {
    serde_json::from_str(json).map_err(|e| format!("static-data.json: {e}"))
}

/// The embedded bundle, parsed once.
pub fn get() -> &'static StaticData {
    static DATA: OnceLock<StaticData> = OnceLock::new();
    DATA.get_or_init(|| parse(BUNDLE_JSON).expect("embedded static-data.json is malformed"))
}

#[tauri::command]
pub fn get_currency_meta(id: u32) -> Option<CurrencyMeta> {
    get().currency(id).cloned()
}

#[tauri::command]
pub fn get_achievement_meta(id: u32) -> Option<AchievementMeta> {
    get().achievement(id).cloned()
}

/// Which client build the embedded lookups describe — shown in diagnostics so a stale
/// bundle is visible rather than silently wrong.
#[tauri::command]
pub fn static_data_build() -> String {
    get().build.clone()
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE: &str = r#"{
      "source": "wago.tools",
      "product": "wow",
      "build": "12.0.7.68453",
      "buildDate": "2026-07-06",
      "currencies": {
        "1792": { "name": "Honor", "icon": "achievement_legionpvptier4", "maxQty": 15000, "quality": 3 },
        "2230": { "name": "Darkmoon Prize Ticket (Void)", "icon": null, "maxQty": 0, "quality": 1 }
      },
      "achievements": {
        "158": { "name": "Me and the Cappin' Makin' It Happen", "icon": "achievement_bg_takexflags_ab", "points": 10 },
        "62386": { "name": "Light Up the Night", "icon": null, "points": 0 }
      }
    }"#;

    #[test]
    fn parses_a_bundle() {
        let d = parse(SAMPLE).expect("sample should parse");
        assert_eq!(d.build, "12.0.7.68453");
        assert_eq!(d.build_date, "2026-07-06");
        assert_eq!(d.currencies.len(), 2);
    }

    #[test]
    fn looks_up_a_known_currency() {
        let d = parse(SAMPLE).unwrap();
        let honor = d.currency(1792).expect("1792 is in the sample");
        assert_eq!(honor.name, "Honor");
        assert_eq!(honor.icon.as_deref(), Some("achievement_legionpvptier4"));
        assert_eq!(honor.max_qty, 15000);
        assert_eq!(honor.quality, 3);
    }

    #[test]
    fn missing_icon_is_none_not_empty() {
        let d = parse(SAMPLE).unwrap();
        assert_eq!(d.currency(2230).unwrap().icon, None);
    }

    #[test]
    fn unknown_currency_is_none() {
        let d = parse(SAMPLE).unwrap();
        assert!(d.currency(999_999).is_none());
    }

    #[test]
    fn looks_up_a_known_achievement() {
        let d = parse(SAMPLE).unwrap();
        let a = d.achievement(158).expect("158 is in the sample");
        assert_eq!(a.name, "Me and the Cappin' Makin' It Happen");
        assert_eq!(a.icon.as_deref(), Some("achievement_bg_takexflags_ab"));
        assert_eq!(a.points, 10);
    }

    #[test]
    fn untracked_achievement_is_none() {
        // The extract is filtered to the tracked catalog, so a real-but-untracked id
        // must miss rather than resolve — the app has to render that case.
        let d = parse(SAMPLE).unwrap();
        assert!(d.achievement(9999).is_none());
    }

    #[test]
    fn currency_and_achievement_id_spaces_do_not_collide() {
        // Both maps are keyed by bare id, so a lookup must not fall through to the other.
        let d = parse(SAMPLE).unwrap();
        assert!(d.currency(158).is_none());
        assert!(d.achievement(1792).is_none());
    }

    #[test]
    fn ignores_unknown_fields() {
        // The generator may add fields ahead of the Rust side; that must not break loading.
        let json = r#"{ "build": "1", "buildDate": "d", "someFutureField": 42, "currencies": {} }"#;
        assert!(parse(json).is_ok());
    }

    #[test]
    fn malformed_json_is_an_error_not_a_panic() {
        assert!(parse("{ not json").is_err());
    }

    #[test]
    fn embedded_bundle_parses_and_is_populated() {
        // Guards against committing a truncated or malformed generated asset.
        let d = get();
        assert!(!d.build.is_empty(), "bundle must record its build");
        assert!(
            d.currencies.len() > 1000,
            "expected the full currency table, got {}",
            d.currencies.len()
        );
    }

    #[test]
    fn embedded_bundle_resolves_a_real_currency() {
        // Honor is a stable, long-lived id — a sanity check that the join to the
        // listfile actually produced icon names rather than nulls across the board.
        let honor = get().currency(1792).expect("Honor (1792) should be present");
        assert_eq!(honor.name, "Honor");
        assert!(honor.icon.is_some(), "Honor should have resolved an icon");
    }

    #[test]
    fn embedded_bundle_covers_the_tracked_achievements() {
        // The generator aborts if any tracked id is missing, so the count only moves when
        // achievementcatalog.lua does. A floor guards against shipping a gutted extract.
        let d = get();
        assert!(
            d.achievements.len() >= 90,
            "expected the tracked achievement catalog, got {}",
            d.achievements.len()
        );
    }

    #[test]
    fn embedded_bundle_resolves_a_real_achievement() {
        // 16585 "Loremaster of the Dragon Isles" — a shipped, long-settled id from the
        // checklist. Asserts the Title_lang/Points/IconFileID join actually landed.
        let a = get()
            .achievement(16585)
            .expect("Loremaster of the Dragon Isles (16585) is in the tracked catalog");
        assert!(!a.name.is_empty(), "achievement name must not be blank");
        assert!(a.icon.is_some(), "16585 should have resolved an icon");
        assert!(a.points > 0, "16585 should carry points");
    }
}
