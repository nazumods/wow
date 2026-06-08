# Warbandeer_Alias

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `Warbandeer_AliasDB` (v1) · **Reads:** `WarbandeerApi` · **UI:** LibNUI

Prepends an `(alias)` prefix to your outgoing **guild** chat when your real character name differs from a configured alias, so guildmates see a consistent name.

## Files

| File | Purpose |
|---|---|
| `addon.lua` | Whole addon: `MigrateDB`, `onLoad` (settings UI + chat hooks), and the prefix logic. Hooks every `ChatFrameNEditBox`'s `OnKeyDown` to rewrite text before send. |

## How it works

- `onLoad` builds a `SettingsFrame` with a text control (`alias`) and toggle (`startsWith`), registered as a subcategory under `ns.api.SettingsCategory` (or standalone if absent) and exposed as `ns.api.AliasSettingsCategory`.
- `hookEditBox` hooks each edit box's **`OnKeyDown`**. On ENTER/NUMPADENTER, if the message is `GUILD` chat and `ShouldPrefix()` is true, it `SetText`s the prefixed message in place.
- `ShouldPrefix()`: false when alias is empty; with `startsWith` off → prefix when `ns.player ~= alias`; with it on → prefix when player name does **not** start with the alias.
- Messages starting with `/ ! # @ ?` (after leading whitespace) are skipped.

## Gotchas

- **Hook point is `OnKeyDown`, not the send path.** It fires before `OnEnterPressed`, so a plain `SetText` is picked up by the secure send without spreading taint (`HookScript` doesn't taint).
- **Hooks all current edit boxes at load**, then re-hooks via `hooksecurefunc("FCF_OpenTemporaryWindow")` so temporary chat windows are covered; `editBox._aliasHooked` guards against double-hooking.

## SavedVariables (`Warbandeer_AliasDB`)

```lua
{ version = 1, settings = { alias = "", startsWith = false } }
```
`MigrateDB` seeds missing `settings`/`alias`/`startsWith`; non-destructive.
