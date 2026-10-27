//! Load a WoW SavedVariables file into a typed model by executing it in a
//! sandboxed Lua 5.1 VM (the same dialect WoW uses) and deserializing the global.

use crate::model::CharDb;
use mlua::{Lua, LuaOptions, LuaSerdeExt, StdLib, Value};
use std::path::Path;

/// Run `<file>` (which assigns `WarbandeerCharDB = {...}`) and deserialize it.
pub fn load_char_db(path: &Path) -> Result<CharDb, String> {
    let src = std::fs::read_to_string(path).map_err(|e| format!("read {path:?}: {e}"))?;

    // No stdlib (no io/os/package), and the file loaders are nil'd: the file is plain data.
    let lua =
        Lua::new_with(StdLib::NONE, LuaOptions::default()).map_err(|e| format!("lua init: {e}"))?;
    for name in ["dofile", "loadfile", "load", "loadstring", "require"] {
        lua.globals().set(name, Value::Nil).map_err(|e| format!("lua init: {e}"))?;
    }
    lua.load(&src).set_name("WarbandeerCharDB").exec().map_err(|e| format!("lua exec: {e}"))?;

    let global: Value =
        lua.globals().get("WarbandeerCharDB").map_err(|e| format!("read global: {e}"))?;

    if matches!(global, Value::Nil) {
        return Err("WarbandeerCharDB is not defined in the file".into());
    }

    lua.from_value(global).map_err(|e| format!("deserialize: {e}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};

    static NEXT: AtomicUsize = AtomicUsize::new(0);

    fn load(src: &str) -> Result<CharDb, String> {
        let dir = std::env::temp_dir()
            .join(format!("wbd-sv-{}-{}", std::process::id(), NEXT.fetch_add(1, Ordering::Relaxed)));
        std::fs::create_dir_all(&dir).unwrap();
        let p = dir.join("Warbandeer_Characters.lua");
        std::fs::write(&p, src).unwrap();
        let r = load_char_db(&p);
        let _ = std::fs::remove_dir_all(&dir);
        r
    }

    #[test]
    fn os_and_io_are_unavailable() {
        assert!(load("os.execute('echo hi')\nWarbandeerCharDB = {}").is_err());
        assert!(load("io.open('x')\nWarbandeerCharDB = {}").is_err());
    }

    #[test]
    fn loaders_are_removed() {
        // Assert on the global being nil, not on a call failing: a call to a missing file fails anyway.
        for g in ["dofile", "loadfile", "load", "loadstring", "require"] {
            let src = format!("assert({g} == nil, '{g} still defined')\nWarbandeerCharDB = {{}}");
            assert!(load(&src).is_ok(), "{g} should be nil");
        }
    }

    #[test]
    fn plain_data_still_loads() {
        assert!(load("WarbandeerCharDB = {}").is_ok());
    }

    #[test]
    fn base_library_and_populated_table_load() {
        let src = "local t = setmetatable({}, nil)\nfor k, v in pairs({version = 3}) do t[k] = v end\nWarbandeerCharDB = t";
        let db = load(src).expect("base lib available");
        assert_eq!(db.version, Some(3.0));
    }
}
