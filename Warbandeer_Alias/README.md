# Warbandeer_Alias

Lets your guild always know who they're talking to. If you play many alts, set an
**alias** once and every guild chat message you send is prefixed with it — e.g.
`(Naz) hi all` — whenever your current character's name doesn't already give it away.

Only **guild chat** is touched. Whispers, party, raid, and public channels are never
modified, and messages starting with `/`, `!`, `#`, `@`, or `?` are left alone.

## Settings

Found in the Blizzard settings panel (as a Warbandeer subcategory when Warbandeer is
installed):

- **Alias** — the name your guildmates know you by.
- **Starts With** — when enabled, the prefix is skipped if your character's name
  already *starts with* the alias (e.g. alias `Naz` on `Nazuraki`); when disabled, the
  prefix applies on any name that isn't exactly the alias.

## Requirements

**LibNAddOn** and **LibNUI**.

## Saved data

`Warbandeer_AliasDB` (account-wide): your alias and the toggle.
