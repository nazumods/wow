//! Load a WoW SavedVariables file into a typed model by executing it in a
//! sandboxed Lua 5.1 VM (the same dialect WoW uses) and deserializing the global.

use crate::model::CharDb;
use mlua::{Lua, LuaSerdeExt, Value};
use std::path::Path;

/// Run `<file>` (which assigns `WarbandeerCharDB = {...}`) and deserialize it.
pub fn load_char_db(path: &Path) -> Result<CharDb, String> {
    let src = std::fs::read_to_string(path).map_err(|e| format!("read {path:?}: {e}"))?;

    let lua = Lua::new();
    lua.load(&src)
        .set_name("WarbandeerCharDB")
        .exec()
        .map_err(|e| format!("lua exec: {e}"))?;

    let global: Value = lua
        .globals()
        .get("WarbandeerCharDB")
        .map_err(|e| format!("read global: {e}"))?;

    if matches!(global, Value::Nil) {
        return Err("WarbandeerCharDB is not defined in the file".into());
    }

    lua.from_value(global).map_err(|e| format!("deserialize: {e}"))
}
