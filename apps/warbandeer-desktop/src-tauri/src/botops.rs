//! Ops-panel backend: drives the Warbandeer debug bot on the box over SSH by invoking the
//! versioned `ops/bot-ops.sh` helper — the only privileged surface. This never runs docker or
//! edits the bot's `.env` itself; it shells `ssh` and lets the box script do the whitelisted
//! work, so bot secrets never traverse the wire.
//!
//! Gated: every command resolves an operator-supplied config file (`ops.json` in the app config
//! dir, or the path in `WARBANDEER_OPS_CONFIG`). No config → `ops_config` returns `None` and the
//! frontend hides the Ops tab, so shipped builds stay dormant for end users.

use serde::{Deserialize, Serialize};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use tauri::{AppHandle, Manager};

#[derive(Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct OpsConfig {
    /// SSH destination, e.g. `"roshne@192.168.7.48"`.
    pub ssh: String,
    /// Remote bot dir holding `.env` + `ops/bot-ops.sh`,
    /// e.g. `"~/repos/wow-debug/apps/warbandeer-discord"`.
    pub remote_dir: String,
}

/// Parse + validate the config JSON. `source` names the origin for error messages.
fn parse_config(text: &str, source: &str) -> Result<OpsConfig, String> {
    let cfg: OpsConfig =
        serde_json::from_str(text).map_err(|e| format!("parse {source}: {e}"))?;
    if cfg.ssh.trim().is_empty() || cfg.remote_dir.trim().is_empty() {
        return Err(format!("{source}: both `ssh` and `remoteDir` are required"));
    }
    Ok(cfg)
}

/// `Ok(None)` when the file is simply absent (the normal "ops mode off" state); `Err` only when
/// a config that *does* exist is unreadable or malformed, so a typo is visible rather than silent.
fn read_config_at(path: &Path) -> Result<Option<OpsConfig>, String> {
    if !path.is_file() {
        return Ok(None);
    }
    let text = std::fs::read_to_string(path).map_err(|e| format!("read {path:?}: {e}"))?;
    Ok(Some(parse_config(&text, &path.display().to_string())?))
}

fn config_path(app: &AppHandle) -> Option<PathBuf> {
    match std::env::var("WARBANDEER_OPS_CONFIG") {
        Ok(p) if !p.is_empty() => Some(PathBuf::from(p)),
        _ => app.path().app_config_dir().ok().map(|d| d.join("ops.json")),
    }
}

fn read_config(app: &AppHandle) -> Result<Option<OpsConfig>, String> {
    match config_path(app) {
        Some(p) => read_config_at(&p),
        None => Ok(None),
    }
}

fn require_config(app: &AppHandle) -> Result<OpsConfig, String> {
    read_config(app)?.ok_or_else(|| "Ops mode isn't configured (no ops.json).".to_string())
}

fn script_path(cfg: &OpsConfig) -> String {
    format!("{}/ops/bot-ops.sh", cfg.remote_dir.trim_end_matches('/'))
}

/// Run `bash <script> <sub-args>` on the box. `stdin` is piped through when `Some`.
///
/// `sub_args` are fixed subcommand names and validated numbers only — never user text — so the
/// single remote command line carries no injection risk. The script path is left unquoted so a
/// leading `~` in `remoteDir` is expanded by the remote login shell.
fn ssh_run(cfg: &OpsConfig, sub_args: &[&str], stdin: Option<&str>) -> Result<String, String> {
    let remote = format!("bash {} {}", script_path(cfg), sub_args.join(" "));
    let mut cmd = Command::new("ssh");
    cmd.args([
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=8",
        "-o",
        "StrictHostKeyChecking=accept-new",
    ])
    .arg(&cfg.ssh)
    .arg(&remote)
    .stdin(if stdin.is_some() { Stdio::piped() } else { Stdio::null() })
    .stdout(Stdio::piped())
    .stderr(Stdio::piped());

    let mut child = cmd.spawn().map_err(|e| format!("failed to launch ssh: {e}"))?;
    if let Some(data) = stdin {
        child
            .stdin
            .take()
            .ok_or("no ssh stdin handle")?
            .write_all(data.as_bytes())
            .map_err(|e| format!("write ssh stdin: {e}"))?;
    }
    let out = child.wait_with_output().map_err(|e| format!("ssh wait: {e}"))?;
    let stdout = String::from_utf8_lossy(&out.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&out.stderr).into_owned();
    if !out.status.success() {
        return Err(format!("{}\n{}", stdout.trim(), stderr.trim()).trim().to_string());
    }
    Ok(stdout)
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BotStatus {
    pub running: bool,
    pub status: String,
    pub image: String,
    pub realm_status: String,
}

#[derive(Deserialize)]
pub struct EnvChange {
    pub key: String,
    pub value: String,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EnvSetResult {
    pub ok: bool,
    pub changed: Vec<String>,
    pub recreated: bool,
    #[serde(default)]
    pub backup: Option<String>,
    #[serde(default)]
    pub note: Option<String>,
    #[serde(default)]
    pub log: Option<String>,
}

/// The gate: `Some` config → the frontend shows the Ops tab, `None` → it stays hidden.
#[tauri::command]
pub fn ops_config(app: AppHandle) -> Result<Option<OpsConfig>, String> {
    read_config(&app)
}

#[tauri::command]
pub fn bot_status(app: AppHandle) -> Result<BotStatus, String> {
    let out = ssh_run(&require_config(&app)?, &["status"], None)?;
    serde_json::from_str(&out).map_err(|e| format!("parse status: {e}: {out}"))
}

#[tauri::command]
pub fn bot_logs(app: AppHandle, lines: Option<u32>) -> Result<String, String> {
    let n = lines.unwrap_or(200).min(5000).to_string();
    ssh_run(&require_config(&app)?, &["logs", &n], None)
}

#[tauri::command]
pub fn bot_restart(app: AppHandle) -> Result<String, String> {
    ssh_run(&require_config(&app)?, &["restart"], None)
}

#[tauri::command]
pub fn bot_env_get(app: AppHandle) -> Result<std::collections::HashMap<String, String>, String> {
    let out = ssh_run(&require_config(&app)?, &["env-get"], None)?;
    serde_json::from_str(&out).map_err(|e| format!("parse env-get: {e}: {out}"))
}

#[tauri::command]
pub fn bot_env_set(app: AppHandle, changes: Vec<EnvChange>) -> Result<EnvSetResult, String> {
    let cfg = require_config(&app)?;
    // KEY=VALUE lines for the helper's stdin. Reject embedded newlines: the helper is
    // line-oriented and a real value never contains one — this also defends the line protocol.
    let mut stdin = String::new();
    for c in &changes {
        if c.key.contains(['\n', '\r']) || c.value.contains(['\n', '\r']) {
            return Err(format!("value for '{}' contains a newline", c.key));
        }
        stdin.push_str(&c.key);
        stdin.push('=');
        stdin.push_str(&c.value);
        stdin.push('\n');
    }
    let out = ssh_run(&cfg, &["env-set"], Some(&stdin))?;
    serde_json::from_str(&out).map_err(|e| format!("parse env-set: {e}: {out}"))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_a_valid_config() {
        let cfg = parse_config(r#"{"ssh":"me@host","remoteDir":"~/bot"}"#, "test").unwrap();
        assert_eq!(cfg.ssh, "me@host");
        assert_eq!(cfg.remote_dir, "~/bot");
    }

    #[test]
    fn rejects_config_missing_fields() {
        assert!(parse_config(r#"{"ssh":"","remoteDir":"~/bot"}"#, "test").is_err());
        assert!(parse_config(r#"{"ssh":"me@host","remoteDir":""}"#, "test").is_err());
        assert!(parse_config("not json", "test").is_err());
    }

    #[test]
    fn absent_config_file_is_none_not_error() {
        let missing = std::env::temp_dir().join("warbandeer-ops-does-not-exist.json");
        assert!(read_config_at(&missing).unwrap().is_none());
    }

    #[test]
    fn script_path_trims_trailing_slash() {
        let cfg = OpsConfig { ssh: "x".into(), remote_dir: "~/bot/".into() };
        assert_eq!(script_path(&cfg), "~/bot/ops/bot-ops.sh");
    }

    #[test]
    fn deserializes_status_and_env_set_payloads() {
        let s: BotStatus = serde_json::from_str(
            r#"{"running":true,"status":"Up 3 days","image":"img","realmStatus":"DOWN"}"#,
        )
        .unwrap();
        assert!(s.running);
        assert_eq!(s.realm_status, "DOWN");

        let noop: EnvSetResult =
            serde_json::from_str(r#"{"ok":true,"changed":[],"recreated":false,"note":"no changes"}"#)
                .unwrap();
        assert!(noop.ok);
        assert!(!noop.recreated);
        assert!(noop.changed.is_empty());
    }
}
