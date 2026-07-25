//! Operator-only Ops panel backend: drives the `warbandeer-discord` bot(s) on the box over SSH by
//! invoking the versioned `ops/bot-ops.sh` helper — the only privileged surface. This never runs
//! docker or edits the bot's `.env` itself; it shells `ssh` and lets the box script do the
//! whitelisted work, so bot secrets never traverse the wire. The helper lives in the `nazumods/wow`
//! repo (`apps/warbandeer-discord/ops/bot-ops.sh`) and is deployed on the box — this crate just
//! calls it, so nothing is duplicated here.
//!
//! Multi-target: `ops.json` lists one or more bots (debug/prod); the panel picks one and passes its
//! index to each command, which resolves the target's ssh/remoteDir and its compose project +
//! container (sent to the helper as `BOT_OPS_PROJECT` / `BOT_OPS_CONTAINER`).
//!
//! Gated: every command resolves an operator-supplied config file (`ops.json` in the app config
//! dir, or the path in an env var — see [`set_config_env_var`]). No config → [`ops_config`] returns
//! `None` and the frontend hides the Bot Ops tab, so shipped builds stay dormant for end users.
//!
//! # Installing into a Tauri app
//!
//! ```ignore
//! tauri::Builder::default()
//!     .setup(|_app| {
//!         bot_ops::set_config_env_var("MY_APP_OPS_CONFIG"); // optional, app-specific override
//!         Ok(())
//!     })
//!     .invoke_handler(tauri::generate_handler![
//!         bot_ops::commands::ops_config,
//!         bot_ops::commands::bot_status,
//!         bot_ops::commands::bot_logs,
//!         bot_ops::commands::bot_restart,
//!         bot_ops::commands::bot_env_get,
//!         bot_ops::commands::bot_env_set,
//!     ])
//! ```
//!
//! The commands live in [`commands`] rather than at the crate root on purpose: `#[tauri::command]`
//! emits a `#[macro_export]`ed `__cmd__<name>` *and* re-exports it from the defining module, and at
//! the crate root those two land on the same path (E0255, "defined multiple times").

use serde::{Deserialize, Serialize};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::OnceLock;
use tauri::{AppHandle, Manager};

const DEFAULT_PROJECT: &str = "warbandeer-discord-debug";
const DEFAULT_CONTAINER: &str = "warbandeer-discord";

/// Env var honoured by every host app, so an operator with several installed apps can point them
/// all at one `ops.json`. Checked after the host's own name (see [`set_config_env_var`]).
const SHARED_CONFIG_ENV_VAR: &str = "BOT_OPS_CONFIG";

/// The host app's own config-path env var, if it registered one. Kept in a `OnceLock` rather than
/// taken as a command argument because the frontend must not get to choose which file is read.
static APP_CONFIG_ENV_VAR: OnceLock<String> = OnceLock::new();

/// Name an app-specific env var that overrides the config path (e.g. `WOW_COMPANION_OPS_CONFIG`).
///
/// Call once during `setup`, before any command runs. Optional: without it only the shared
/// `BOT_OPS_CONFIG` and the app config dir are consulted. Later calls are ignored, so a host can't
/// be re-pointed at another file mid-run.
pub fn set_config_env_var(name: impl Into<String>) {
    let _ = APP_CONFIG_ENV_VAR.set(name.into());
}

fn default_project() -> String {
    DEFAULT_PROJECT.to_string()
}
fn default_container() -> String {
    DEFAULT_CONTAINER.to_string()
}

/// One managed bot. `project`/`container` are the compose project + container name on that host;
/// they default to the debug bot's and are passed to the helper per call.
#[derive(Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase")]
pub struct OpsTarget {
    pub name: String,
    pub ssh: String,
    pub remote_dir: String,
    #[serde(default = "default_project")]
    pub project: String,
    #[serde(default = "default_container")]
    pub container: String,
}

/// What the frontend needs to render the target switch (no compose internals).
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub struct OpsTargetInfo {
    pub name: String,
    pub ssh: String,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RawMulti {
    targets: Vec<OpsTarget>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct RawFlat {
    ssh: String,
    remote_dir: String,
}

fn project_container_ok(s: &str) -> bool {
    !s.is_empty()
        && s.chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '-' | '_' | '.'))
}

/// Parse + validate the config JSON into one-or-more targets. Accepts the multi-target
/// `{ "targets": [...] }` shape, or the legacy flat `{ ssh, remoteDir }` (read as a single `debug`
/// target). `source` names the origin for error messages.
fn parse_config(text: &str, source: &str) -> Result<Vec<OpsTarget>, String> {
    let value: serde_json::Value =
        serde_json::from_str(text).map_err(|e| format!("parse {source}: {e}"))?;
    let targets: Vec<OpsTarget> = if value.get("targets").is_some() {
        serde_json::from_value::<RawMulti>(value)
            .map_err(|e| format!("parse {source}: {e}"))?
            .targets
    } else {
        let flat: RawFlat =
            serde_json::from_value(value).map_err(|e| format!("parse {source}: {e}"))?;
        vec![OpsTarget {
            name: "debug".to_string(),
            ssh: flat.ssh,
            remote_dir: flat.remote_dir,
            project: default_project(),
            container: default_container(),
        }]
    };

    if targets.is_empty() {
        return Err(format!("{source}: no ops targets configured"));
    }
    for t in &targets {
        if t.name.trim().is_empty() || t.ssh.trim().is_empty() || t.remote_dir.trim().is_empty() {
            return Err(format!(
                "{source}: every target needs a non-empty `name`, `ssh`, and `remoteDir`"
            ));
        }
        // project/container are interpolated into the remote docker command — restrict them.
        if !project_container_ok(&t.project) || !project_container_ok(&t.container) {
            return Err(format!(
                "{source}: target `{}` has an invalid `project`/`container`",
                t.name
            ));
        }
    }
    Ok(targets)
}

/// `Ok(None)` when the file is simply absent (the normal "ops mode off" state); `Err` only when
/// a config that *does* exist is unreadable or malformed, so a typo is visible rather than silent.
fn read_config_at(path: &Path) -> Result<Option<Vec<OpsTarget>>, String> {
    if !path.is_file() {
        return Ok(None);
    }
    let text = std::fs::read_to_string(path).map_err(|e| format!("read {path:?}: {e}"))?;
    Ok(Some(parse_config(&text, &path.display().to_string())?))
}

/// First non-empty of: the host's registered env var, then the shared `BOT_OPS_CONFIG`.
fn config_path_override() -> Option<PathBuf> {
    APP_CONFIG_ENV_VAR
        .get()
        .map(String::as_str)
        .into_iter()
        .chain(std::iter::once(SHARED_CONFIG_ENV_VAR))
        .find_map(|name| match std::env::var(name) {
            Ok(p) if !p.is_empty() => Some(PathBuf::from(p)),
            _ => None,
        })
}

fn config_path(app: &AppHandle) -> Option<PathBuf> {
    config_path_override()
        .or_else(|| app.path().app_config_dir().ok().map(|d| d.join("ops.json")))
}

fn read_targets(app: &AppHandle) -> Result<Option<Vec<OpsTarget>>, String> {
    match config_path(app) {
        Some(p) => read_config_at(&p),
        None => Ok(None),
    }
}

fn require_target(app: &AppHandle, target: usize) -> Result<OpsTarget, String> {
    let targets =
        read_targets(app)?.ok_or_else(|| "Ops mode isn't configured (no ops.json).".to_string())?;
    targets
        .into_iter()
        .nth(target)
        .ok_or_else(|| format!("no ops target at index {target}"))
}

fn script_path(t: &OpsTarget) -> String {
    format!("{}/ops/bot-ops.sh", t.remote_dir.trim_end_matches('/'))
}

/// Run `bash <script> <sub-args>` on the target's host, selecting the bot via `BOT_OPS_*`.
///
/// `sub_args` are fixed subcommand names and validated numbers only — never user text. The target's
/// `project`/`container` are validated to a safe charset at parse time, so interpolating them is
/// safe. The script path is left unquoted so a leading `~` in `remoteDir` is expanded remotely.
fn ssh_run(t: &OpsTarget, sub_args: &[&str], stdin: Option<&str>) -> Result<String, String> {
    let remote = format!(
        "BOT_OPS_PROJECT={} BOT_OPS_CONTAINER={} bash {} {}",
        t.project,
        t.container,
        script_path(t),
        sub_args.join(" ")
    );
    let mut cmd = Command::new("ssh");
    cmd.args([
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=8",
        "-o",
        "StrictHostKeyChecking=accept-new",
    ])
    .arg(&t.ssh)
    .arg(&remote)
    .stdin(if stdin.is_some() {
        Stdio::piped()
    } else {
        Stdio::null()
    })
    .stdout(Stdio::piped())
    .stderr(Stdio::piped());

    let mut child = cmd
        .spawn()
        .map_err(|e| format!("failed to launch ssh: {e}"))?;
    if let Some(data) = stdin {
        child
            .stdin
            .take()
            .ok_or("no ssh stdin handle")?
            .write_all(data.as_bytes())
            .map_err(|e| format!("write ssh stdin: {e}"))?;
    }
    let out = child
        .wait_with_output()
        .map_err(|e| format!("ssh wait: {e}"))?;
    let stdout = String::from_utf8_lossy(&out.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&out.stderr).into_owned();
    if !out.status.success() {
        return Err(format!("{}\n{}", stdout.trim(), stderr.trim())
            .trim()
            .to_string());
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

/// The six `#[tauri::command]`s a host app registers. See the crate docs for why they are nested
/// here instead of sitting at the crate root.
pub mod commands {
    use super::*;

    /// The gate + the target switch's options: `Some(list)` → show the Bot Ops tab with a selector,
    /// `None` → keep it hidden.
    #[tauri::command]
    pub fn ops_config(app: AppHandle) -> Result<Option<Vec<OpsTargetInfo>>, String> {
        Ok(read_targets(&app)?.map(|ts| {
            ts.into_iter()
                .map(|t| OpsTargetInfo {
                    name: t.name,
                    ssh: t.ssh,
                })
                .collect()
        }))
    }

    #[tauri::command]
    pub fn bot_status(app: AppHandle, target: usize) -> Result<BotStatus, String> {
        let out = ssh_run(&require_target(&app, target)?, &["status"], None)?;
        serde_json::from_str(&out).map_err(|e| format!("parse status: {e}: {out}"))
    }

    #[tauri::command]
    pub fn bot_logs(app: AppHandle, target: usize, lines: Option<u32>) -> Result<String, String> {
        let n = lines.unwrap_or(200).min(5000).to_string();
        ssh_run(&require_target(&app, target)?, &["logs", &n], None)
    }

    #[tauri::command]
    pub fn bot_restart(app: AppHandle, target: usize) -> Result<String, String> {
        ssh_run(&require_target(&app, target)?, &["restart"], None)
    }

    #[tauri::command]
    pub fn bot_env_get(
        app: AppHandle,
        target: usize,
    ) -> Result<std::collections::HashMap<String, String>, String> {
        let out = ssh_run(&require_target(&app, target)?, &["env-get"], None)?;
        serde_json::from_str(&out).map_err(|e| format!("parse env-get: {e}: {out}"))
    }

    #[tauri::command]
    pub fn bot_env_set(
        app: AppHandle,
        target: usize,
        changes: Vec<EnvChange>,
    ) -> Result<EnvSetResult, String> {
        let t = require_target(&app, target)?;
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
        let out = ssh_run(&t, &["env-set"], Some(&stdin))?;
        serde_json::from_str(&out).map_err(|e| format!("parse env-set: {e}: {out}"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_the_flat_legacy_form_as_one_debug_target() {
        let ts = parse_config(r#"{"ssh":"me@host","remoteDir":"~/bot"}"#, "test").unwrap();
        assert_eq!(ts.len(), 1);
        assert_eq!(ts[0].name, "debug");
        assert_eq!(ts[0].ssh, "me@host");
        assert_eq!(ts[0].project, DEFAULT_PROJECT);
        assert_eq!(ts[0].container, DEFAULT_CONTAINER);
    }

    #[test]
    fn parses_multi_targets_with_defaults_and_overrides() {
        let ts = parse_config(
            r#"{"targets":[
                {"name":"debug","ssh":"a@h","remoteDir":"~/d"},
                {"name":"prod","ssh":"b@h","remoteDir":"~/p","project":"warbandeer-discord","container":"warbandeer-discord"}
            ]}"#,
            "test",
        )
        .unwrap();
        assert_eq!(ts.len(), 2);
        assert_eq!(ts[0].project, DEFAULT_PROJECT); // defaulted
        assert_eq!(ts[1].name, "prod");
        assert_eq!(ts[1].project, "warbandeer-discord"); // overridden
    }

    #[test]
    fn rejects_bad_configs() {
        assert!(parse_config(r#"{"targets":[]}"#, "test").is_err()); // no targets
        assert!(parse_config(r#"{"ssh":"","remoteDir":"~/b"}"#, "test").is_err()); // empty ssh
        assert!(parse_config("not json", "test").is_err());
        // project with a shell metacharacter is rejected
        assert!(parse_config(
            r#"{"targets":[{"name":"x","ssh":"a@h","remoteDir":"~/d","project":"bad;rm"}]}"#,
            "test",
        )
        .is_err());
    }

    #[test]
    fn absent_config_file_is_none_not_error() {
        let missing = std::env::temp_dir().join("bot-ops-does-not-exist.json");
        assert!(read_config_at(&missing).unwrap().is_none());
    }

    #[test]
    fn script_path_trims_trailing_slash() {
        let t = OpsTarget {
            name: "debug".into(),
            ssh: "x".into(),
            remote_dir: "~/bot/".into(),
            project: DEFAULT_PROJECT.into(),
            container: DEFAULT_CONTAINER.into(),
        };
        assert_eq!(script_path(&t), "~/bot/ops/bot-ops.sh");
    }

    #[test]
    fn deserializes_status_and_env_set_payloads() {
        let s: BotStatus = serde_json::from_str(
            r#"{"running":true,"status":"Up 3 days","image":"img","realmStatus":"DOWN"}"#,
        )
        .unwrap();
        assert!(s.running);
        assert_eq!(s.realm_status, "DOWN");

        let noop: EnvSetResult = serde_json::from_str(
            r#"{"ok":true,"changed":[],"recreated":false,"note":"no changes"}"#,
        )
        .unwrap();
        assert!(noop.ok);
        assert!(!noop.recreated);
        assert!(noop.changed.is_empty());
    }

    // `set_config_env_var` writes a process-global `OnceLock`, so the two env-var cases share one
    // test — separate `#[test]`s would race for the single set.
    #[test]
    fn config_override_prefers_the_apps_var_then_the_shared_one() {
        assert!(config_path_override().is_none(), "no vars set yet");

        std::env::set_var(SHARED_CONFIG_ENV_VAR, "/shared/ops.json");
        assert_eq!(
            config_path_override(),
            Some(PathBuf::from("/shared/ops.json"))
        );

        set_config_env_var("BOT_OPS_TEST_APP_CONFIG");
        // Registered but unset — the shared var still wins over the app config dir.
        assert_eq!(
            config_path_override(),
            Some(PathBuf::from("/shared/ops.json"))
        );

        std::env::set_var("BOT_OPS_TEST_APP_CONFIG", "/app/ops.json");
        assert_eq!(config_path_override(), Some(PathBuf::from("/app/ops.json")));

        std::env::remove_var("BOT_OPS_TEST_APP_CONFIG");
        std::env::remove_var(SHARED_CONFIG_ENV_VAR);
    }
}
