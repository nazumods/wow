# Warbandeer_Bars

A **headless data layer** for action bar layouts. It automatically tracks each character's
action bars, keybinds, macros, pet bar, and equipment-set outfits — one profile per
character **and** spec — so any UI can preview another character/spec's setup and import it
onto the one you're playing.

There is **no window**. `Warbandeer_Bars` only collects and stores data, and exposes
`WarbandeerBarsApi` for a consuming addon (a Warbandeer view, or a standalone window) to
build on. It is the sibling of `Warbandeer_Characters` and `Warbandeer_Collected`: a backbone,
not a viewer.

This solves the "oh, I forgot to save the layout on *X*" problem — every character's current
setup is captured on its own, in the background, with nothing to remember.

## How it tracks

Profiles are captured at session boundaries — never on a churning per-click basis:

| Trigger | When |
|---|---|
| `onLogin` | 2 s after entering the world (lets the bars finish loading) |
| `ACTIVE_TALENT_GROUP_CHANGED` | 500 ms after a spec change (lets the new spec settle) |
| `PLAYER_LOGOUT` | on logout **and** on `/reload` |

A capture is skipped during combat (the macro temp-index resolution touches protected APIs)
and while a cursor drag is in progress (it would clobber the held action). None of the triggers
above fire in combat, so in practice this is just insurance.

Captures are always **full fidelity** (bars + binds + macros + pet bar + outfits). What a
*restore* applies is filtered separately — see the include settings below.

## Stored data

`WarbandeerBarsDB` (account-wide), keyed by character name then spec ID:

```lua
WarbandeerBarsDB = {
  version  = 2,
  profiles = {
    ["Nazuraki"] = {
      [62] = {            -- specID (e.g. 62 = Arcane Mage)
        version  = 2,
        captured = 1717000000,        -- server time
        char     = "Nazuraki",
        realm    = "Area 52",
        class    = "MAGE",            -- class file token
        classID  = 8,
        specID   = 62,
        spec     = "Arcane",          -- spec name
        specIcon = 135932,
        level    = 80,
        slots    = { { id = 1, type = "spell", index = 30451 }, ... },
        binds    = { { command = "ACTIONBUTTON1", key1 = "1" }, ... },
        bindingSet = 2,               -- GetCurrentBindingSet() at capture (1 = account, 2 = per-character)
        macros   = { { id = 1, name = "Burst", icon = "...", body = "#showtooltip\n..." }, ... },
        petslots = { { id = 1, type = "spell", index = 2649 }, ... },
        outfits  = { "Raid", "Mythic+" },
        layoutName = "My Layout",     -- active Edit Mode layout name at capture (nil if none)
        barLayout  = { [1] = { orientation = 0, numIcons = 12, numRows = 1, enabled = true }, ... }, -- v2: real on-screen bar geometry
      },
    },
  },
  layouts = {            -- Edit Mode layout snapshots (v2), shared across characters
    ["My Layout"] = { [1] = { numIcons = 12, numRows = 1, orientation = 0 }, ... },
  },
}
```

`WarbandeerBarsSettings` (per character) is the **restore filter** only — capture always stores
everything:

```lua
{ include = { bars = true, macros = true, petbar = true, bindings = false, outfits = false },
  accountMacros = true, charMacros = true }
```

Bindings and outfits default **off** so importing buttons doesn't silently rewrite your keybinds.

## API — `WarbandeerBarsApi`

```lua
-- Query
:GetCurrentCharacter()                       --> string
:GetCurrentSpecID()                          --> number
:GetProfile(char?, specID?)                  --> profile?   (defaults to current char/spec)
:GetProfiles(char?)                          --> { [specID] = profile }?
:ListCharacters()                            --> string[]   (sorted)
:GetAllProfiles()                            --> profile[]  (flat, for list views)

-- Capture / store
:Snapshot()                                  --> profile?   (capture current char now, and store)
:DeleteProfile(char, specID)
:DeleteCharacter(char)                       --> boolean    (forget all of a char's profiles; false if none)

-- Apply to the current character
:Restore(profile, include?, silent?, barFilter?)
:RestoreProfile(char, specID, include?, silent?, barFilter?)  --> boolean (false if no such profile)
--   barFilter? = map of internal bar numbers (1-15) to bool; false = leave that bar untouched

-- Engine passthrough
:Capture(include?, accountMacros?, charMacros?)   --> profile (does NOT store)

-- Settings
:GetIncludeSettings()                        --> include table (live; mutate to change)

-- Edit Mode layouts
:GetLayouts()                                --> { [layoutName] = barSettings }
:GetLayout(name)                             --> barSettings?  ({ [barIndex] = {numIcons, numRows, orientation} })
```

A previewing UI reads `profile.slots` (each `{ id, type, index?/strindex? }`) and resolves
icons/names itself (`C_Spell.GetSpellTexture`, etc.). `:RestoreProfile` is the one call needed
to import another character's layout onto the current one.

### Restore behaviour

Restoring is out-of-combat only. By type:

- **spell / item / mount / pet / flyout / equipment set** — picked up and placed; spell overrides
  and base-spell fallbacks are resolved automatically. Anything you don't know is skipped with a warning.
- **macros** — matched by name + body, or **recreated** on the target character if missing
  (account or per-character slot as appropriate), then placed. This is what makes a cross-character
  import actually work.
- Slots not present in the profile are cleared.

## Slash commands

Inspection/testing only (the data layer has no window):

```
/wbb                          status
/wbb snapshot                 capture the current character now
/wbb list                     list stored profiles
/wbb restore <char> [specID]  restore a stored profile onto the current character
/wbb forget <char> [specID]   delete profile(s)   (omit specID to forget the whole character)
```

`/wbbars` is an alias for `/wbb`.

## Dependencies

`LibNAddOn` only — no LibNUI, no `Warbandeer_Characters`. Truly headless.
