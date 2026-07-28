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
/// A user-captured snapshot of a specific order, independent of the live order file —
/// stays as-is until the user explicitly remembers a new one. Same on-disk format as
/// `ORDER_FILE` so `parse_order_file` and the write logic both apply unchanged.
const MEMORY_FILE: &str = "character-list-order - Memory.txt";

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
    /// Current spec's display name (e.g. `"Frost"`); empty when unknown.
    pub spec: String,
    /// Average equipped item level; 0 when unknown (frontend shows blank instead of a bare 0).
    pub item_level: i64,
    /// Primary-slot profession name; empty when untrained or unknown.
    pub profession1: String,
    /// Second-slot profession name; empty when untrained or unknown.
    pub profession2: String,
    /// The slot number as actually stored in the order file. Not guaranteed contiguous —
    /// deleting a character removes its line but leaves surviving rows' numbers as-is, so
    /// gaps (e.g. 1, 3, 4 with no 2) reflect real vacant slots. Only meaningful as "the real
    /// file's slot layout" in the freshly-loaded, unsorted view; once previewing a sort or a
    /// manual reorder it's just "this row's slot before that change" — see `Slot #` handling
    /// in `CharacterSort.svelte`, which only renders gap placeholders while positions are
    /// still strictly increasing (i.e. still file order).
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

/// What the frontend sends back to write a new order (and what a remembered order reads
/// back as): the exact fields the file format stores per row. `position` is written
/// verbatim, not recomputed from array order — the frontend is responsible for numbering
/// (including deliberately skipping a number to preserve a locked-empty-slot reservation).
#[derive(Deserialize, Serialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct OrderLine {
    pub flag: String,
    pub realm_guid: String,
    pub position: i64,
}

struct OrderEntry {
    flag: String,
    realm_guid: String,
    /// The raw third column, verbatim — see `ResolvedCharacter::position`.
    position: i64,
}

/// Parses `character-list-order.txt`: a `Version: 2` header line, then one
/// `{flag} {realmID}-{lowGUID} {position}` line per character. Position values aren't
/// necessarily contiguous (a sort key, not an index) — file order is what we read by, but
/// the raw value is kept too so a vacant slot from a deleted character is still visible.
fn parse_order_file(text: &str) -> Vec<OrderEntry> {
    text.lines()
        .skip(1) // "Version: 2" header
        .filter(|line| !line.trim().is_empty())
        .filter_map(|line| {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() != 3 {
                return None;
            }
            let position: i64 = parts[2].parse().ok()?;
            Some(OrderEntry {
                flag: parts[0].to_string(),
                realm_guid: parts[1].to_string(),
                position,
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
        .map(|e| {
            let position = e.position;
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
                        spec: c
                            .basic
                            .specialization
                            .as_ref()
                            .and_then(|s| s.active.clone().or_else(|| s.key.clone()))
                            .unwrap_or_default(),
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
                    spec: String::new(),
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

fn format_order_text(ordered: &[OrderLine]) -> String {
    let mut out_lines = vec!["Version: 2".to_string()];
    for line in ordered {
        out_lines.push(format!("{} {} {}", line.flag, line.realm_guid, line.position));
    }
    out_lines.join("\r\n") + "\r\n"
}

/// Where order-file backups are parked. Deliberately OUTSIDE the WTF account folder: WoW
/// never reads them, and leaving them beside `character-list-order.txt` clutters the user's
/// account dir (and got swept as noise). Staged under `C:\Temp` per the suite convention;
/// on non-Windows (CI, tests) it falls back to the platform temp dir.
pub fn default_backup_dir() -> std::path::PathBuf {
    #[cfg(windows)]
    {
        std::path::PathBuf::from(r"C:\Temp\WarbandeerCharacterSort")
    }
    #[cfg(not(windows))]
    {
        std::env::temp_dir().join("WarbandeerCharacterSort")
    }
}

/// Backs up the existing file (timestamped, local time) into `backup_dir` — namespaced by
/// account name since all accounts' backups now share one folder outside the WTF tree — then
/// writes the new order. Refuses to overwrite an existing backup of the same name (e.g. two
/// saves of the same account within one second) rather than silently discarding one.
pub fn save(account_dir: &Path, backup_dir: &Path, ordered: &[OrderLine]) -> Result<String, String> {
    let order_path = account_dir.join(ORDER_FILE);

    let account = account_dir
        .file_name()
        .map(|s| s.to_string_lossy().into_owned())
        .filter(|s| !s.is_empty());
    let stamp = chrono::Local::now().format("%Y%m%d-%H%M%S");
    let backup_name = match &account {
        Some(a) => format!("character-list-order.{a}.backup-{stamp}.txt"),
        None => format!("character-list-order.backup-{stamp}.txt"),
    };

    std::fs::create_dir_all(backup_dir)
        .map_err(|e| format!("create backup dir {backup_dir:?}: {e}"))?;
    let backup_path = backup_dir.join(backup_name);
    if backup_path.exists() {
        return Err(format!(
            "Backup {backup_path:?} already exists — wait a second and try again."
        ));
    }
    std::fs::copy(&order_path, &backup_path)
        .map_err(|e| format!("backup to {backup_path:?}: {e}"))?;

    std::fs::write(&order_path, format_order_text(ordered))
        .map_err(|e| format!("write {order_path:?}: {e}"))?;

    Ok(backup_path.to_string_lossy().into_owned())
}

/// Reads the remembered-order file, if one has been saved for this account. `Ok(None)`
/// means nothing's been remembered yet — the normal starting state, not an error.
pub fn load_memory(account_dir: &Path) -> Result<Option<Vec<OrderLine>>, String> {
    let memory_path = account_dir.join(MEMORY_FILE);
    if !memory_path.is_file() {
        return Ok(None);
    }
    let text = std::fs::read_to_string(&memory_path)
        .map_err(|e| format!("read {memory_path:?}: {e}"))?;
    Ok(Some(
        parse_order_file(&text)
            .into_iter()
            .map(|e| OrderLine {
                flag: e.flag,
                realm_guid: e.realm_guid,
                position: e.position,
            })
            .collect(),
    ))
}

/// Overwrites the remembered order in place. Unlike `save`, no backup is made — this is a
/// saved preference the user asked to persist "until a new one is remembered", so plainly
/// replacing it on the next remember is the intended behavior, not a data-loss risk.
pub fn save_memory(account_dir: &Path, ordered: &[OrderLine]) -> Result<(), String> {
    let memory_path = account_dir.join(MEMORY_FILE);
    std::fs::write(&memory_path, format_order_text(ordered))
        .map_err(|e| format!("write {memory_path:?}: {e}"))
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
    save(
        &crate::wow::account_dir(&retail, &account),
        &default_backup_dir(),
        &ordered,
    )
}

#[tauri::command]
pub fn get_remembered_order(
    account: String,
    wow_dir: Option<String>,
) -> Result<Option<Vec<OrderLine>>, String> {
    let retail = crate::wow::find_retail_dir(wow_dir.as_deref())
        .ok_or("Couldn't find a WoW _retail_ folder. Set WOW_DIR.")?;
    load_memory(&crate::wow::account_dir(&retail, &account))
}

#[tauri::command]
pub fn remember_character_order(
    account: String,
    ordered: Vec<OrderLine>,
    wow_dir: Option<String>,
) -> Result<(), String> {
    let retail = crate::wow::find_retail_dir(wow_dir.as_deref())
        .ok_or("Couldn't find a WoW _retail_ folder. Set WOW_DIR.")?;
    save_memory(&crate::wow::account_dir(&retail, &account), &ordered)
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
                        active: Some("Frost".to_string()),
                        key: Some("Frost".to_string()),
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
            achievements: Default::default(),
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
        assert_eq!(resolved[0].spec, "Frost");
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
    fn preserves_a_gap_from_a_deleted_character() {
        // Slot 2 is missing (a character deleted from that slot), so the raw stored
        // numbers themselves have a gap even though these are the only two lines in the
        // file — that gap must survive into the resolved position, not get silently
        // renumbered to 1, 2.
        let db = CharDb::default();
        let entries = parse_order_file("Version: 2\n0 47-AAA 1\n0 47-BBB 3\n");
        let resolved = resolve(&db, &entries);

        assert_eq!(resolved[0].position, 1);
        assert_eq!(resolved[1].position, 3);
    }

    #[test]
    fn save_round_trips_and_backs_up_outside_the_account_folder() {
        let tmp = std::env::temp_dir().join(format!(
            "warbandeer-desktop-charorder-test-save-{}",
            std::process::id()
        ));
        // Account dir and backup dir are deliberately separate — the backup must NOT land
        // in the account folder.
        let account_dir = tmp.join("ROSHNE");
        let backup_dir = tmp.join("backups");
        std::fs::create_dir_all(&account_dir).unwrap();
        let order_path = account_dir.join(ORDER_FILE);
        std::fs::write(&order_path, "Version: 2\r\n0 47-AAA 1\r\n0 47-BBB 2\r\n").unwrap();

        let ordered = vec![
            OrderLine {
                flag: "0".to_string(),
                realm_guid: "47-BBB".to_string(),
                position: 1,
            },
            OrderLine {
                flag: "0".to_string(),
                realm_guid: "47-AAA".to_string(),
                position: 2,
            },
        ];
        let backup_path = save(&account_dir, &backup_dir, &ordered).expect("save should succeed");

        // Backup lands in backup_dir (not the account folder) and carries the account name.
        assert!(Path::new(&backup_path).starts_with(&backup_dir));
        let backup_name = Path::new(&backup_path).file_name().unwrap().to_string_lossy();
        assert!(backup_name.starts_with("character-list-order.ROSHNE.backup-"));
        assert!(!account_dir.join(&*backup_name).exists());

        // Backup preserves the original content exactly.
        let backup_text = std::fs::read_to_string(&backup_path).unwrap();
        assert_eq!(backup_text, "Version: 2\r\n0 47-AAA 1\r\n0 47-BBB 2\r\n");

        // The live file now reflects the new order and positions, verbatim, CRLF.
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
        let account_dir = tmp.join("ROSHNE");
        let backup_dir = tmp.join("backups");
        std::fs::create_dir_all(&account_dir).unwrap();
        std::fs::create_dir_all(&backup_dir).unwrap();
        std::fs::write(account_dir.join(ORDER_FILE), "Version: 2\r\n0 47-AAA 1\r\n").unwrap();

        let stamp = chrono::Local::now().format("%Y%m%d-%H%M%S");
        std::fs::write(
            backup_dir.join(format!("character-list-order.ROSHNE.backup-{stamp}.txt")),
            "existing backup",
        )
        .unwrap();

        let ordered = vec![OrderLine {
            flag: "0".to_string(),
            realm_guid: "47-AAA".to_string(),
            position: 1,
        }];
        let result = save(&account_dir, &backup_dir, &ordered);
        assert!(result.is_err());

        std::fs::remove_dir_all(&tmp).ok();
    }

    #[test]
    fn save_writes_position_verbatim_preserving_a_deliberate_gap() {
        // A locked-empty-slot reservation shows up here as a plain skipped number — the
        // frontend computes gap-aware positions, and `save` just writes whatever it's given.
        let tmp = std::env::temp_dir().join(format!(
            "warbandeer-desktop-charorder-test-gap-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&tmp).unwrap();
        std::fs::write(tmp.join(ORDER_FILE), "Version: 2\r\n0 47-AAA 1\r\n").unwrap();

        let ordered = vec![
            OrderLine {
                flag: "0".to_string(),
                realm_guid: "47-AAA".to_string(),
                position: 1,
            },
            OrderLine {
                flag: "0".to_string(),
                realm_guid: "47-BBB".to_string(),
                position: 3, // slot 2 is a deliberately preserved gap
            },
        ];
        save(&tmp, &tmp.join("backups"), &ordered).expect("save should succeed");

        let new_text = std::fs::read_to_string(tmp.join(ORDER_FILE)).unwrap();
        assert_eq!(new_text, "Version: 2\r\n0 47-AAA 1\r\n0 47-BBB 3\r\n");

        std::fs::remove_dir_all(&tmp).ok();
    }

    #[test]
    fn load_memory_returns_none_when_nothing_remembered() {
        let tmp = std::env::temp_dir().join(format!(
            "warbandeer-desktop-charorder-test-nomemory-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&tmp).unwrap();

        assert!(load_memory(&tmp).unwrap().is_none());

        std::fs::remove_dir_all(&tmp).ok();
    }

    #[test]
    fn save_memory_round_trips_without_touching_the_live_order_file() {
        let tmp = std::env::temp_dir().join(format!(
            "warbandeer-desktop-charorder-test-memory-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&tmp).unwrap();
        std::fs::write(tmp.join(ORDER_FILE), "Version: 2\r\n0 47-AAA 1\r\n").unwrap();

        let ordered = vec![
            OrderLine {
                flag: "0".to_string(),
                realm_guid: "47-BBB".to_string(),
                position: 1,
            },
            OrderLine {
                flag: "0".to_string(),
                realm_guid: "47-AAA".to_string(),
                position: 2,
            },
        ];
        save_memory(&tmp, &ordered).expect("save_memory should succeed");

        let remembered = load_memory(&tmp).unwrap().expect("memory file should exist");
        assert_eq!(remembered.len(), 2);
        assert_eq!(remembered[0].realm_guid, "47-BBB");
        assert_eq!(remembered[1].realm_guid, "47-AAA");

        // The live order file is untouched by remembering.
        let live_text = std::fs::read_to_string(tmp.join(ORDER_FILE)).unwrap();
        assert_eq!(live_text, "Version: 2\r\n0 47-AAA 1\r\n");

        std::fs::remove_dir_all(&tmp).ok();
    }

    #[test]
    fn save_memory_overwrites_a_previous_memory() {
        let tmp = std::env::temp_dir().join(format!(
            "warbandeer-desktop-charorder-test-memory-overwrite-{}",
            std::process::id()
        ));
        std::fs::create_dir_all(&tmp).unwrap();

        save_memory(
            &tmp,
            &[OrderLine {
                flag: "0".to_string(),
                realm_guid: "47-AAA".to_string(),
                position: 1,
            }],
        )
        .unwrap();
        save_memory(
            &tmp,
            &[OrderLine {
                flag: "0".to_string(),
                realm_guid: "47-BBB".to_string(),
                position: 1,
            }],
        )
        .unwrap();

        let remembered = load_memory(&tmp).unwrap().unwrap();
        assert_eq!(remembered.len(), 1);
        assert_eq!(remembered[0].realm_guid, "47-BBB");

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
                ["specialization"] = { ["role"] = "DAMAGER", ["active"] = "Frost" },
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
        assert_eq!(payload.characters[0].spec, "Frost");

        std::fs::remove_dir_all(&tmp).ok();
    }
}
