//! Operator-only Ops panel backend: drives a `warbandeer-discord`/`rackbops-discord-bot` bot on
//! the box over SSH by invoking a versioned `bot-ops.sh` helper — the only privileged surface.
//! This never runs docker or edits the bot's `.env` itself; it shells `ssh` and lets the box
//! script do the whitelisted work, so bot secrets never traverse the wire. This crate just calls
//! that script, so nothing is duplicated here — but **two differently-shaped copies of it exist
//! now** (`apps/warbandeer-discord/ops/bot-ops.sh` in this repo, and
//! [`roshne/rackbops-discord-bot`'s fork](https://github.com/roshne/rackbops-discord-bot/blob/main/ops/bot-ops.sh)),
//! and this crate has to stay compatible with both — see [`OpsTarget`] and
//! `apps/bot-ops/README.md`'s "Two `bot-ops.sh` copies exist" section for the full divergence.
//!
//! Multi-target: `ops.json` lists one or more bots (debug/prod); the panel picks one and passes its
//! index to each command, which resolves the target's ssh/remoteDir and its compose project +
//! container (sent to the helper as `BOT_OPS_PROJECT` / `BOT_OPS_CONTAINER`). A target on the
//! newer `bot-ops.sh` contract also sets `configDir`/`composeFile`/`scriptPath` — see
//! [`OpsTarget`].
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
///
/// `config_dir`/`compose_file`/`script_path` are for a target whose `bot-ops.sh` requires
/// `BOT_OPS_CONFIG_DIR`/`BOT_OPS_COMPOSE_FILE` (no fallback) and is deployed at a fixed path
/// independent of `remote_dir` — a newer helper contract some deployments have moved to. All
/// three are optional, and must be set together or not at all (enforced in [`parse_config`]): a
/// target that omits them behaves exactly as before, deriving the script path from `remote_dir`
/// and passing neither env var.
#[derive(Serialize, Deserialize, Clone, Default, Debug)]
#[serde(rename_all = "camelCase")]
pub struct OpsTarget {
    pub name: String,
    pub ssh: String,
    pub remote_dir: String,
    #[serde(default = "default_project")]
    pub project: String,
    #[serde(default = "default_container")]
    pub container: String,
    #[serde(default)]
    pub config_dir: Option<String>,
    #[serde(default)]
    pub compose_file: Option<String>,
    #[serde(default)]
    pub script_path: Option<String>,
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

/// `configDir`/`composeFile`/`scriptPath` are single-quoted verbatim into the remote command
/// (see `remote_command`), which is why they need no charset restriction as tight as
/// `project_container_ok`'s — but a `'` would break out of that quoting, and an embedded newline
/// would make the value span more of the remote command than intended. Reject both.
fn path_field_ok(s: &str) -> bool {
    !s.contains('\'') && !s.contains(['\n', '\r'])
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
            ..Default::default()
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
        // configDir/composeFile/scriptPath are for the newer bot-ops.sh contract (no fallback on
        // the box either) — a target must set all three or none, never a partial set that would
        // otherwise surface as a confusing remote `die` instead of a named local error.
        let migrated = [&t.config_dir, &t.compose_file, &t.script_path];
        let set_count = migrated.iter().filter(|f| f.is_some()).count();
        if set_count != 0 && set_count != migrated.len() {
            return Err(format!(
                "{source}: target `{}` must set `configDir`, `composeFile`, and `scriptPath` together, or none of them",
                t.name
            ));
        }
        for (field, value) in [
            ("configDir", &t.config_dir),
            ("composeFile", &t.compose_file),
            ("scriptPath", &t.script_path),
        ] {
            if let Some(v) = value {
                if v.trim().is_empty() {
                    return Err(format!(
                        "{source}: target `{}` has an empty `{field}`",
                        t.name
                    ));
                }
                // These three are single-quoted verbatim into the remote command (see
                // `remote_command`) — a `'` would break out of that quoting, and a newline would
                // make the value span more of the command than intended. Neither is a legitimate
                // character in a path, so reject both outright rather than trying to escape them.
                if !path_field_ok(v) {
                    return Err(format!(
                        "{source}: target `{}` has an invalid `{field}` (no `'` or newlines)",
                        t.name
                    ));
                }
            }
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
    config_path_override().or_else(|| app.path().app_config_dir().ok().map(|d| d.join("ops.json")))
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

/// The remote `bot-ops.sh` path: `script_path` verbatim when the target set it (the newer,
/// fixed-shared-path contract), else derived from `remote_dir` as before.
fn script_path(t: &OpsTarget) -> String {
    match &t.script_path {
        Some(p) => p.clone(),
        None => format!("{}/ops/bot-ops.sh", t.remote_dir.trim_end_matches('/')),
    }
}

/// Builds the remote command string `ssh_run` sends: `BOT_OPS_PROJECT`/`BOT_OPS_CONTAINER` always,
/// `BOT_OPS_CONFIG_DIR`/`BOT_OPS_COMPOSE_FILE` only when the target set them ([`parse_config`]
/// enforces they're set together with `script_path`) — a target that didn't opt into the newer
/// contract sends neither, unchanged from before these fields existed. Split out from `ssh_run`
/// so the command shape is directly testable without spawning a real `ssh` process.
///
/// `config_dir`/`compose_file`/an explicit `script_path` are single-quoted: unlike `remote_dir`,
/// they're meant to be plain absolute paths with no `~` to expand, and — as env-var-assignment
/// *prefixes* on the command line, ahead of the `bash <script>` word — an unquoted space in one of
/// them would be far worse than in `remote_dir`: the remote shell would treat everything after the
/// space as the command to run instead of an argument, silently skipping `bash <script>` entirely.
/// `path_field_ok` (checked in [`parse_config`]) rules out the one character that could break out
/// of single-quoting (`'`) plus embedded newlines, so quoting here is always safe.
fn remote_command(t: &OpsTarget, sub_args: &[&str]) -> String {
    let mut remote = format!(
        "BOT_OPS_PROJECT={} BOT_OPS_CONTAINER={}",
        t.project, t.container
    );
    if let Some(dir) = &t.config_dir {
        remote.push_str(&format!(" BOT_OPS_CONFIG_DIR='{dir}'"));
    }
    if let Some(file) = &t.compose_file {
        remote.push_str(&format!(" BOT_OPS_COMPOSE_FILE='{file}'"));
    }
    let script = script_path(t);
    let script_arg = if t.script_path.is_some() {
        format!("'{script}'")
    } else {
        // Legacy-derived from remote_dir — left unquoted so a leading `~` expands remotely.
        script
    };
    remote.push_str(&format!(" bash {script_arg} {}", sub_args.join(" ")));
    remote
}

/// Run `bash <script> <sub-args>` on the target's host, selecting the bot via `BOT_OPS_*`.
///
/// `sub_args` are fixed subcommand names and validated numbers only — never user text. The
/// target's `project`/`container` are validated to a safe charset at parse time; `configDir`/
/// `composeFile`/an explicit `scriptPath` are single-quoted (see [`remote_command`]). The
/// legacy-derived script path is left unquoted so a leading `~` in `remoteDir` is expanded
/// remotely.
fn ssh_run(t: &OpsTarget, sub_args: &[&str], stdin: Option<&str>) -> Result<String, String> {
    let remote = remote_command(t, sub_args);
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
            ..Default::default()
        };
        assert_eq!(script_path(&t), "~/bot/ops/bot-ops.sh");
    }

    #[test]
    fn script_path_prefers_the_explicit_field_when_set() {
        let t = OpsTarget {
            name: "debug".into(),
            ssh: "x".into(),
            remote_dir: "~/bot/".into(),
            project: DEFAULT_PROJECT.into(),
            container: DEFAULT_CONTAINER.into(),
            script_path: Some("/opt/rackbops-discord-bot/bin/bot-ops.sh".into()),
            ..Default::default()
        };
        // Not `~/bot/ops/bot-ops.sh` — the explicit path wins outright, no `ops/` nesting assumed.
        assert_eq!(script_path(&t), "/opt/rackbops-discord-bot/bin/bot-ops.sh");
    }

    #[test]
    fn parses_a_migrated_target_and_passes_config_dir_and_compose_file() {
        let ts = parse_config(
            r#"{"targets":[{
                "name":"debug","ssh":"a@h","remoteDir":"/opt/rackbops-discord-bot/bin",
                "project":"rackbops-discord-bot-debug","container":"rackbops-discord-bot-debug",
                "configDir":"/opt/rackbops-discord-bot/debug",
                "composeFile":"/opt/stacks/rackbops-discord-bot-debug/docker-compose.yml",
                "scriptPath":"/opt/rackbops-discord-bot/bin/bot-ops.sh"
            }]}"#,
            "test",
        )
        .unwrap();
        let t = &ts[0];
        assert_eq!(
            t.config_dir.as_deref(),
            Some("/opt/rackbops-discord-bot/debug")
        );
        assert_eq!(
            t.compose_file.as_deref(),
            Some("/opt/stacks/rackbops-discord-bot-debug/docker-compose.yml")
        );

        let remote = remote_command(t, &["status"]);
        assert!(remote.contains("BOT_OPS_CONFIG_DIR='/opt/rackbops-discord-bot/debug'"));
        assert!(remote.contains(
            "BOT_OPS_COMPOSE_FILE='/opt/stacks/rackbops-discord-bot-debug/docker-compose.yml'"
        ));
        assert!(remote.ends_with("bash '/opt/rackbops-discord-bot/bin/bot-ops.sh' status"));
    }

    #[test]
    fn legacy_target_sends_neither_new_env_var() {
        let ts = parse_config(r#"{"ssh":"me@host","remoteDir":"~/bot"}"#, "test").unwrap();
        let remote = remote_command(&ts[0], &["status"]);
        assert!(!remote.contains("BOT_OPS_CONFIG_DIR"));
        assert!(!remote.contains("BOT_OPS_COMPOSE_FILE"));
        assert!(remote.ends_with("bash ~/bot/ops/bot-ops.sh status"));
    }

    #[test]
    fn rejects_a_partial_migrated_field_set_one_of_three() {
        // configDir alone, without composeFile/scriptPath, must be rejected at parse time rather
        // than surfacing as a remote `die` the first time a command actually runs.
        let err = parse_config(
            r#"{"targets":[{"name":"debug","ssh":"a@h","remoteDir":"~/d","configDir":"/opt/x"}]}"#,
            "test",
        )
        .unwrap_err();
        assert!(
            err.contains("configDir"),
            "error should name the field: {err}"
        );
    }

    #[test]
    fn rejects_a_partial_migrated_field_set_two_of_three() {
        // configDir + composeFile set, scriptPath missing — a narrower guard than "at least one"
        // (e.g. one that only checked `set_count == 1`) would let this slip through.
        let err = parse_config(
            r#"{"targets":[{
                "name":"debug","ssh":"a@h","remoteDir":"~/d",
                "configDir":"/opt/x","composeFile":"/opt/x/docker-compose.yml"
            }]}"#,
            "test",
        )
        .unwrap_err();
        assert!(
            err.contains("together"),
            "error should call out the all-or-nothing rule: {err}"
        );
    }

    #[test]
    fn rejects_an_empty_migrated_field() {
        let err = parse_config(
            r#"{"targets":[{
                "name":"debug","ssh":"a@h","remoteDir":"~/d",
                "configDir":"","composeFile":"/opt/x/docker-compose.yml","scriptPath":"/opt/x/bot-ops.sh"
            }]}"#,
            "test",
        )
        .unwrap_err();
        assert!(
            err.contains("empty"),
            "error should call out the empty field: {err}"
        );
    }

    #[test]
    fn rejects_a_single_quote_in_a_migrated_field() {
        // A `'` would break out of remote_command's single-quoting of these fields — reject it at
        // parse time instead of producing a malformed remote command.
        let err = parse_config(
            r#"{"targets":[{
                "name":"debug","ssh":"a@h","remoteDir":"~/d",
                "configDir":"/opt/x'; rm -rf /","composeFile":"/opt/x/docker-compose.yml","scriptPath":"/opt/x/bot-ops.sh"
            }]}"#,
            "test",
        )
        .unwrap_err();
        assert!(
            err.contains("configDir"),
            "error should name the field: {err}"
        );
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
