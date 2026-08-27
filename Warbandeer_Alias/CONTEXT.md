# Warbandeer_Alias

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `Warbandeer_AliasDB` (v1) · **Reads:** `WarbandeerApi` · **UI:** LibNUI

Prepends an `(alias)` prefix to your outgoing **guild** chat when your real character name differs from a configured alias, so guildmates see a consistent name.

## Files

| File | Purpose |
|---|---|
| `addon.lua` | Whole addon: `MigrateDB`, `onLoad` (settings UI + chat hook), and the prefix logic. Registers the `ChatFrame.OnEditBoxPreSendText` EventRegistry callback to rewrite text before send. |

## How it works

- `onLoad` builds a `SettingsFrame` with a text control (`alias`) and toggle (`startsWith`), nested as a subcategory under the shared **Warbandeer** parent via `settings:RegisterSubcategory(ns:GetSettingsParent("Warbandeer"))` (LibNAddOn's shared parent registry — Warbandeer's own settings carry that group; an empty parent is created on demand if Warbandeer isn't loaded). Exposed as `ns.api.AliasSettingsCategory`, and recorded as `ns.settingsCategory` so a future changelog reuses this panel rather than adding a duplicate "Alias" subcategory.
- `OnPreSendText` is registered on the **`ChatFrame.OnEditBoxPreSendText`** EventRegistry callback (Blizzard's designated addon hook, added with the 12.0 chat-send rearchitecture). If the message is `GUILD` chat and `ShouldPrefix()` is true, it `SetText`s the prefixed message in place — unless prepending the prefix would push the message past WoW's 255-byte send cap, or the player is in combat lockdown, in which case it's left untouched (see Gotchas).
- `ShouldPrefix()`: false when alias is empty; with `startsWith` off → prefix when the player name `~= alias`; with it on → prefix when player name does **not** start with the alias. The name is read **live** via `ns.wow.Player.GetName()` each call (not captured once at load), so a mid-session rename/transfer can't leave a stale comparison.
- Messages starting with `/ ! # @ ?` (after leading whitespace) are skipped.

## Gotchas

- **Hook point is `ChatFrame.OnEditBoxPreSendText`** — `SendText` fires it after `ParseText(1)` (so `editBox:GetChatType()` already resolves `/g` → `"GUILD"`) and before `GetText()` is read for the send, so `SetText` lands in the outgoing message. One registration covers every edit box, temporary chat windows included (the editBox arrives as the callback arg). The pre-12.0 `OnKeyDown` hook broke when Blizzard rearchitected the chat send path.
- **Combat lockdown skip.** A `SetText` from insecure code inside the send path taints the protected `SendChatMessage` that follows and drops the message — the callback bails on `InCombatLockdown()`, sending in-combat messages unprefixed.
- **255-byte send cap.** `SendChatMessage` enforces WoW's server-side 255-**byte** limit and silently drops the tail past it (the editbox template's `bytes=1280`/`visibleBytes=255` does not clamp a `SetText`). Prepending the prefix to a near-max message would corrupt it, so the hook skips the rewrite when `#text + #prefix > 255`, sending the user's message unprefixed rather than truncated. `#` is the byte length WoW counts (correct in Lua 5.1).

## SavedVariables (`Warbandeer_AliasDB`)

```lua
{ version = 1, settings = { alias = "", startsWith = false } }
```
`MigrateDB` seeds missing `settings`/`alias`/`startsWith`; non-destructive.
