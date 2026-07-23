//! Offline lookup layer for constant game data the client would normally resolve.
//!
//! SavedVariables store currency *amounts* keyed by id, never the name, icon or cap —
//! those live in DB2. The app ships as a single portable exe with no network access, so
//! the bundle is generated at CI time by `Tooling/update-static-data.ps1` and embedded here
//! rather than fetched. See that script (and `Tooling/UPDATING-static-data.md`) for provenance.
//!
//! Scope is currency only, on purpose: it is the one lookup with no Blizzard REST
//! equivalent (the Game Data API has no currency endpoint), so it stays wago-sourced
//! whatever the app does about API credentials later.

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

#[derive(Debug, Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct StaticData {
    /// Client build the bundle was generated from, e.g. `12.0.7.68453`.
    pub build: String,
    pub build_date: String,
    /// Keyed by currency id as a string — JSON object keys are always strings.
    #[serde(default)]
    pub currencies: HashMap<String, CurrencyMeta>,
}

impl StaticData {
    pub fn currency(&self, id: u32) -> Option<&CurrencyMeta> {
        self.currencies.get(&id.to_string())
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
}
