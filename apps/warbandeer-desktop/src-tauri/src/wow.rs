//! Locating the WoW install + its data files.
//!
//! Resolution order for the `_retail_` directory (the one that holds `WTF/` and
//! `Logs/`):
//!   1. an explicit override passed from the UI / `WOW_DIR` env var,
//!   2. an ancestor of the running exe or the cwd that contains `WTF/Account`
//!      (true in dev: this crate lives under `…/_retail_/Interface/AddOns/apps/…`),
//!   3. the default Windows install path.

use std::path::{Path, PathBuf};

const DEFAULT_INSTALL: &str = r"C:\Program Files (x86)\World of Warcraft\_retail_";

fn has_account(dir: &Path) -> bool {
    dir.join("WTF").join("Account").is_dir()
}

/// Resolve the `_retail_` directory, or `None` if nothing plausible is found.
pub fn find_retail_dir(override_dir: Option<&str>) -> Option<PathBuf> {
    let mut candidates: Vec<PathBuf> = Vec::new();

    if let Some(d) = override_dir.filter(|s| !s.is_empty()) {
        candidates.push(PathBuf::from(d));
    }
    if let Ok(d) = std::env::var("WOW_DIR") {
        if !d.is_empty() {
            candidates.push(PathBuf::from(d));
        }
    }
    for start in [std::env::current_exe().ok(), std::env::current_dir().ok()]
        .into_iter()
        .flatten()
    {
        for anc in start.ancestors() {
            if has_account(anc) {
                candidates.push(anc.to_path_buf());
                break;
            }
        }
    }
    candidates.push(PathBuf::from(DEFAULT_INSTALL));

    candidates.into_iter().find(|c| has_account(c))
}

/// Find the SavedVariables file `<file>` for an account that actually has it.
/// Returns `(account_name, path)`.
pub fn find_saved_var(retail: &Path, file: &str) -> Option<(String, PathBuf)> {
    let accounts = retail.join("WTF").join("Account");
    let mut found: Option<(String, PathBuf)> = None;
    for entry in std::fs::read_dir(&accounts).ok()?.flatten() {
        if !entry.path().is_dir() {
            continue;
        }
        let path = entry.path().join("SavedVariables").join(file);
        if path.is_file() {
            let acct = entry.file_name().to_string_lossy().into_owned();
            // Prefer the most recently written account if several have the file.
            let mtime = std::fs::metadata(&path)
                .and_then(|m| m.modified())
                .ok();
            let better = match &found {
                None => true,
                Some((_, prev)) => std::fs::metadata(prev)
                    .and_then(|m| m.modified())
                    .ok()
                    .zip(mtime)
                    .map(|(p, c)| c > p)
                    .unwrap_or(false),
            };
            if better {
                found = Some((acct, path));
            }
        }
    }
    found
}

/// The `Logs/` directory of the install (may not exist).
pub fn logs_dir(retail: &Path) -> PathBuf {
    retail.join("Logs")
}

/// The account's folder under `WTF/Account/<name>/`.
pub fn account_dir(retail: &Path, account: &str) -> PathBuf {
    retail.join("WTF").join("Account").join(account)
}

/// Every account folder that has a `character-list-order.txt` (i.e. has been used at the
/// character-select screen at least once), sorted by name.
pub fn list_order_accounts(retail: &Path) -> Vec<String> {
    let accounts = retail.join("WTF").join("Account");
    let mut out: Vec<String> = std::fs::read_dir(&accounts)
        .into_iter()
        .flatten()
        .flatten()
        .filter(|entry| entry.path().join("character-list-order.txt").is_file())
        .map(|entry| entry.file_name().to_string_lossy().into_owned())
        .collect();
    out.sort();
    out
}
