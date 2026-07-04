# Warbandeer_Alias

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `Warbandeer_AliasDB` (v1) · **Reads:** `WarbandeerApi` · **UI:** LibNUI

Prepends an `(alias)` prefix to your outgoing **guild** chat when your real character name differs from a configured alias, so guildmates see a consistent name.

## Files

| File | Purpose |
|---|---|
| `addon.lua` | Whole addon: `MigrateDB`, `onLoad` (settings UI + chat hooks), and the prefix logic. Hooks every `ChatFrameNEditBox`'s `OnKeyDown` to rewrite text before send. |

## How it works

- `onLoad` builds a `SettingsFrame` with a text control (`alias`) and toggle (`startsWith`), nested as a subcategory under the shared **Warbandeer** parent via `settings:RegisterSubcategory(ns:GetSettingsParent("Warbandeer"))` (LibNAddOn's shared parent registry — Warbandeer's own settings carry that group; an empty parent is created on demand if Warbandeer isn't loaded). Exposed as `ns.api.AliasSettingsCategory`.
- `hookEditBox` hooks each edit box's **`OnKeyDown`**. On ENTER/NUMPADENTER, if the message is `GUILD` chat and `ShouldPrefix()` is true, it `SetText`s the prefixed message in place — unless prepending the prefix would push the message past WoW's 255-byte send cap, in which case it's left untouched (see Gotchas).
- `ShouldPrefix()`: false when alias is empty; with `startsWith` off → prefix when `ns.player ~= alias`; with it on → prefix when player name does **not** start with the alias.
- Messages starting with `/ ! # @ ?` (after leading whitespace) are skipped.

## Gotchas

- **Hook point is `OnKeyDown`, not the send path.** It fires before `OnEnterPressed`, so a plain `SetText` is picked up by the secure send without spreading taint (`HookScript` doesn't taint).
- **Hooks all current edit boxes at load**, then re-hooks via `hooksecurefunc("FCF_OpenTemporaryWindow")` so temporary chat windows are covered; `editBox._aliasHooked` guards against double-hooking.
- **255-byte send cap.** `SendChatMessage` enforces WoW's server-side 255-**byte** limit and silently drops the tail past it (the editbox template's `bytes=1280`/`visibleBytes=255` does not clamp a `SetText`). Prepending the prefix to a near-max message would corrupt it, so the hook skips the rewrite when `#text + #prefix > 255`, sending the user's message unprefixed rather than truncated. `#` is the byte length WoW counts (correct in Lua 5.1).

## SavedVariables (`Warbandeer_AliasDB`)

```lua
{ version = 1, settings = { alias = "", startsWith = false } }
```
`MigrateDB` seeds missing `settings`/`alias`/`startsWith`; non-destructive.
