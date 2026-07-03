//! Reorders a WoW account's character-select list by editing `character-list-order.txt`
//! directly — ported from the standalone WarbandeerCharacterSort app. WoW only reads this
//! file at the character-select (glue) screen, so writing it while the client is closed is
//! safe; the addon sandbox has no access to this screen or file at all (see the app README).
//!
//! Resolution cross-references each order-file row's `<realmID>-<lowGUID>` fragment against
//! `WarbandeerCharDB.characters[name].guid` (a `"Player-<realmID>-<lowGUID>"` UnitGUID,
//! captured every login since DB v30). A character never logged into since that update has
//! no `guid` and shows up unresolved — kept, not dropped, so nothing in the file is lost.

use crate::model::{CharDb, Character};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::Path;

const ORDER_FILE: &str = "character-list-order.txt";

#[derive(Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct ResolvedCharacter {
    pub name: String,
    pub realm: String,
    /// The `<realmID>-<lowGUID>` fragment as stored in the order file, e.g. `"47-098A25AB"`.
    pub realm_guid: String,
    pub class_id: i64,
    pub class_key: String,
    pub class_name: String,
    pub level: i64,
    /// Display role from the played spec: `"Tank"`/`"Healer"`/`"DPS"`, or `"?"` when unknown.
    pub role: String,
    /// Average equipped item level; 0 when unknown (frontend shows blank instead of a bare 0).
    pub item_level: i64,
    /// Primary-slot profession name; empty when untrained or unknown.
    pub profession1: String,
    /// Second-slot profession name; empty when untrained or unknown.
    pub profession2: String,
    /// Current position (1-based) — the sort key Blizzard reads.
    pub position: i64,
    /// Leading flag column, preserved verbatim (always `"0"` observed so far; meaning unknown).
    pub flag: String,
}

impl ResolvedCharacter {
    /// Unresolved rows (no matching Warbandeer record) always have `class_id == 0` — there's
    /// nothing meaningful to sort them by until the owning character next logs in.
    pub fn is_unresolved(&self) -> bool {
        self.class_id == 0
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CharacterOrderPayload {
    pub account: String,
    pub db_version: Option<i64>,
    pub characters: Vec<ResolvedCharacter>,
    pub unresolved_count: usize,
}

/// What the frontend sends back to write a new order: just the two fields the file format
/// actually stores per row. Position is recomputed from array order on write.
#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct OrderLine {
    pub flag: String,
    pub realm_guid: String,
}

struct OrderEntry {
    flag: String,
    realm_guid: String,
}

fn role_display(raw: Option<&str>) -> String {
    match raw {
        Some("TANK") => "Tank",
        Some("HEALER") => "Healer",
        Some("DAMAGER") => "DPS",
        _ => "?",
    }
    .to_string()
}

/// Parses `character-list-order.txt`: a `Version: 2` header line, then one
/// `{flag} {realmID}-{lowGUID} {position}` line per character. Position values aren't
/// necessarily contiguous (a sort key, not an index) — file order is what we read by.
fn parse_order_file(text: &str) -> Vec<OrderEntry> {
    text.lines()
        .skip(1) // "Version: 2" header
        .filter(|line| !line.trim().is_empty())
        .filter_map(|line| {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() != 3 {
                return None;
            }
            Some(OrderEntry {
                flag: parts[0].to_string(),
                realm_guid: parts[1].to_string(),
            })
        })
        .collect()
}

fn resolve(char_db: &CharDb, entries: &[OrderEntry]) -> Vec<ResolvedCharacter> {
    let mut by_guid: HashMap<&str, (&str, &Character)> = HashMap::new();
    for (name, c) in &char_db.characters {
        if let Some(guid) = c.guid.as_deref() {
            by_guid.insert(guid, (name.as_str(), c));
        }
    }

    entries
        .iter()
        .enumerate()
        .map(|(i, e)| {
            let position = (i + 1) as i64;
            let full_guid = format!("Player-{}", e.realm_guid);

            match by_guid.get(full_guid.as_str()) {
                Some((name, c)) => {
                    let profession = |slot: Option<&crate::model::ProfessionSlot>| {
                        slot.and_then(|p| p.name.clone()).unwrap_or_default()
                    };
                    ResolvedCharacter {
                        name: name.to_string(),
                        realm: c.realm.clone().unwrap_or_else(|| "?".into()),
                        realm_guid: e.realm_guid.clone(),
                        class_id: c.class_id as i64,
                        class_key: c.class_key.clone().unwrap_or_default(),
                        class_name: c.class_name.clone().unwrap_or_else(|| "Unknown".into()),
                        level: c.basic.level as i64,
                        role: role_display(
                            c.basic.specialization.as_ref().and_then(|s| s.role.as_deref()),
                        ),
                        item_level: c
                            .equipment
                            .as_ref()
                            .and_then(|eq| eq.ilvl)
                            .unwrap_or(0.0) as i64,
                        profession1: profession(
                            c.basic.professions.as_ref().and_then(|p| p.primary.as_ref()),
                        ),
                        profession2: profession(
                            c.basic.professions.as_ref().and_then(|p| p.secondary.as_ref()),
                        ),
                        position,
                        flag: e.flag.clone(),
                    }
                }
                None => ResolvedCharacter {
                    name: format!("(unknown {})", e.realm_guid),
                    realm: "?".into(),
                    realm_guid: e.realm_guid.clone(),
                    class_id: 0,
                    class_key: String::new(),
                    class_name: "Unknown".into(),
                    level: 0,
                    role: "?".into(),
                    item_level: 0,
                    profession1: String::new(),
                    profession2: String::new(),
                    position,
                    flag: e.flag.clone(),
                },
            }
        })
        .collect()
}

/// Load + resolve an account's character order, given its `WTF/Account/<name>/` directory.
/// `Ok` even when Warbandeer's SavedVariables file is missing (every row comes back
/// unresolved — nothing to cross-reference against yet).
pub fn load(account_dir: &Path, account_name: &str) -> Result<CharacterOrderPayload, String> {
    let order_path = account_dir.join(ORDER_FILE);
    let order_text = std::fs::read_to_string(&order_path)
        .map_err(|e| format!("read {order_path:?}: {e}"))?;
    let entries = parse_order_file(&order_text);

    let sv_path = account_dir
        .join("SavedVariables")
        .join("Warbandeer_Characters.lua");
    let char_db = if sv_path.is_file() {
        crate::savedvars::load_char_db(&sv_path)?
    } else {
        CharDb::default()
    };

    let characters = resolve(&char_db, &entries);
    let unresolved_count = characters.iter().filter(|c| c.is_unresolved()).count();

    Ok(CharacterOrderPayload {
        account: account_name.to_string(),
        db_version: char_db.version.map(|v| v as i64),
        unresolved_count,
        characters,
    })
}

/// Backs up the existing file (timestamped, alongside the original — local time, since it's
/// shown to the user browsing their account folder) then writes the new order. Refuses to
/// overwrite an existing backup of the same name (e.g. two saves within the same second)
/// rather than silently discarding one — matches the standalone app's `overwrite: false`.
pub fn save(account_dir: &Path, ordered: &[OrderLine]) -> Result<String, String> {
    let order_path = account_dir.join(ORDER_FILE);

    let stamp = chrono::Local::now().format("%Y%m%d-%H%M%S");
    let backup_path = account_dir.join(format!("character-list-order.backup-{stamp}.txt"));
    if backup_path.exists() {
        return Err(format!(
            "Backup {backup_path:?} already exists — wait a second and try again."
        ));
    }
    std::fs::copy(&order_path, &backup_path)
        .map_err(|e| format!("backup to {backup_path:?}: {e}"))?;

    let mut out_lines = vec!["Version: 2".to_string()];
    for (i, line) in ordered.iter().enumerate() {
        out_lines.push(format!("{} {} {}", line.flag, line.realm_guid, i + 1));
    }
    let text = out_lines.join("\r\n") + "\r\n";

    std::fs::write(&order_path, text).map_err(|e| format!("write {order_path:?}: {e}"))?;

    Ok(backup_path.to_string_lossy().into_owned())
}

#[tauri::command]
pub fn list_order_accounts(wow_dir: Option<String>) -> Result<Vec<String>, String> {
    let retail = crate::wow::find_retail_dir(wow_dir.as_deref())
        .ok_or("Couldn't find a WoW _retail_ folder. Set WOW_DIR.")?;
    Ok(crate::wow::list_order_accounts(&retail))
}

#[tauri::command]
pub fn get_character_order(
    account: String,
    wow_dir: Option<String>,
) -> Result<CharacterOrderPayload, String> {
    let retail = crate::wow::find_retail_dir(wow_dir.as_deref())
        .ok_or("Couldn't find a WoW _retail_ folder. Set WOW_DIR.")?;
    load(&crate::wow::account_dir(&retail, &account), &account)
}

#[tauri::command]
pub fn save_character_order(
    account: String,
    ordered: Vec<OrderLine>,
    wow_dir: Option<String>,
) -> Result<String, String> {
    let retail = crate::wow::find_retail_dir(wow_dir.as_deref())
        .ok_or("Couldn't find a WoW _retail_ folder. Set WOW_DIR.")?;
    save(&crate::wow::account_dir(&retail, &account), &ordered)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{Basic, Equipment, Professions, ProfessionSlot, Specialization};

    fn char_db_with(name: &str, guid: &str) -> CharDb {
        let mut characters = HashMap::new();
        characters.insert(
            name.to_string(),
            Character {
                realm: Some("Stormrage".to_string()),
                guid: Some(guid.to_string()),
                class_key: Some("Mage".to_string()),
                class_id: 8.0,
                class_name: Some("Mage".to_string()),
                is_alliance: true,
                basic: Basic {
                    level: 80.0,
                    specialization: Some(Specialization {
                        role: Some("DAMAGER".to_string()),
                    }),
                    professions: Some(Professions {
                        primary: Some(ProfessionSlot {
                            name: Some("Tailoring".to_string()),
                        }),
                        secondary: None,
                    }),
                },
                equipment: Some(Equipment { ilvl: Some(650.0) }),
                currency: None,
                playtime: None,
                reputations: None,
            },
        );
        CharDb {
            version: Some(30.0),
            warband: Default::default(),
            characters,
        }
    }

    #[test]
    fn resolves_matching_guid() {
        let db = char_db_with("Arcanix", "Player-47-098A25AB");
        let entries = parse_order_file("Version: 2\n0 47-098A25AB 1\n");
        let resolved = resolve(&db, &entries);

        assert_eq!(resolved.len(), 1);
        assert_eq!(resolved[0].name, "Arcanix");
        assert_eq!(resolved[0].class_id, 8);
        assert_eq!(resolved[0].level, 80);
        assert_eq!(resolved[0].role, "DPS");
        assert_eq!(resolved[0].item_level, 650);
        assert_eq!(resolved[0].profession1, "Tailoring");
        assert_eq!(resolved[0].profession2, "");
        assert!(!resolved[0].is_unresolved());
    }

    #[test]
    fn keeps_unresolved_rows_as_placeholders() {
        let db = char_db_with("Arcanix", "Player-47-098A25AB");
        let entries = parse_order_file("Version: 2\n0 99-DEADBEEF 1\n");
        let resolved = resolve(&db, &entries);

        assert_eq!(resolved.len(), 1);
        assert_eq!(resolved[0].name, "(unknown 99-DEADBEEF)");
        assert!(resolved[0].is_unresolved());
    }

    #[test]
    fn parse_skips_header_and_blank_lines() {
        let entries = parse_order_file("Version: 2\n0 47-AAA 1\n\n0 47-BBB 2\n");
        assert_eq!(entries.len(), 2);
        assert_eq!(entries[0].realm_guid, "47-AAA");
        assert_eq!(entries[1].realm_guid, "47-BBB");
    }

    #[test]
    fn save_round_trips_and_backs_up() {
        let tmp = std::env::temp_dir().join(format!(
            "warbandeer-desktop-charorder-test-save-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&tmp).unwrap();
        let order_path = tmp.join(ORDER_FILE);
        std::fs::write(&order_path, "Version: 2\r\n0 47-AAA 1\r\n0 47-BBB 2\r\n").unwrap();

        let ordered = vec![
            OrderLine {
                flag: "0".to_string(),
                realm_guid: "47-BBB".to_string(),
            },
            OrderLine {
                flag: "0".to_string(),
                realm_guid: "47-AAA".to_string(),
            },
        ];
        let backup_path = save(&tmp, &ordered).expect("save should succeed");

        // Backup preserves the original content exactly.
        let backup_text = std::fs::read_to_string(&backup_path).unwrap();
        assert_eq!(backup_text, "Version: 2\r\n0 47-AAA 1\r\n0 47-BBB 2\r\n");

        // The live file now reflects the new order, CRLF, positions renumbered from 1.
        let new_text = std::fs::read_to_string(&order_path).unwrap();
        assert_eq!(new_text, "Version: 2\r\n0 47-BBB 1\r\n0 47-AAA 2\r\n");

        std::fs::remove_dir_all(&tmp).ok();
    }

    #[test]
    fn save_refuses_to_clobber_an_existing_backup() {
        let tmp = std::env::temp_dir().join(format!(
            "warbandeer-desktop-charorder-test-clobber-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&tmp).unwrap();
        std::fs::write(tmp.join(ORDER_FILE), "Version: 2\r\n0 47-AAA 1\r\n").unwrap();

        let stamp = chrono::Local::now().format("%Y%m%d-%H%M%S");
        std::fs::write(
            tmp.join(format!("character-list-order.backup-{stamp}.txt")),
            "existing backup",
        )
        .unwrap();

        let ordered = vec![OrderLine {
            flag: "0".to_string(),
            realm_guid: "47-AAA".to_string(),
        }];
        let result = save(&tmp, &ordered);
        assert!(result.is_err());

        std::fs::remove_dir_all(&tmp).ok();
    }

    #[test]
    fn load_round_trips_through_a_real_saved_variables_file() {
        let tmp = std::env::temp_dir().join(format!(
            "warbandeer-desktop-charorder-test-load-{}",
            std::process::id()
        ));
        let sv_dir = tmp.join("SavedVariables");
        std::fs::create_dir_all(&sv_dir).unwrap();
        std::fs::write(tmp.join(ORDER_FILE), "Version: 2\r\n0 47-098A25AB 1\r\n").unwrap();
        std::fs::write(
            sv_dir.join("Warbandeer_Characters.lua"),
            r#"
WarbandeerCharDB = {
    ["version"] = 30,
    ["characters"] = {
        ["Arcanix"] = {
            ["realm"] = "Stormrage",
            ["guid"] = "Player-47-098A25AB",
            ["classId"] = 8,
            ["className"] = "Mage",
            ["basic"] = {
                ["level"] = 80,
                ["specialization"] = { ["role"] = "DAMAGER" },
                ["professions"] = { ["primary"] = { ["name"] = "Tailoring" } },
            },
        },
    },
}
"#,
        )
        .unwrap();

        let payload = load(&tmp, "TestAccount").expect("load should succeed");
        assert_eq!(payload.account, "TestAccount");
        assert_eq!(payload.db_version, Some(30));
        assert_eq!(payload.unresolved_count, 0);
        assert_eq!(payload.characters.len(), 1);
        assert_eq!(payload.characters[0].name, "Arcanix");
        assert_eq!(payload.characters[0].role, "DPS");

        std::fs::remove_dir_all(&tmp).ok();
    }
}
