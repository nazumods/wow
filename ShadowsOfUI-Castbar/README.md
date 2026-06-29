# Cast Bars

Two minimal, movable cast bars for your **target** and **focus target**, in the clean
"Shadows of UI" style. They show what your target (and focus) is casting — spell icon,
name, and remaining time — and stay out of the way the rest of the time.

## Features

- **Target & focus cast bars.** Two independent bars, one for each unit, each placed
  wherever you like.
- **Works in combat.** The bars are purely cosmetic, so they update and can be repositioned
  without any combat restrictions.
- **Non-interruptible casts stand out.** Interruptible casts fill gold, non-interruptible
  casts grey, channels green.
- **Adjustable text size.** Set the spell-name / cast-time font anywhere from 8 to 22px.
- **Placed with Edit Mode.** Open Blizzard's Edit Mode and each bar becomes a labelled,
  draggable handle with a selection outline — drag to position it, or **click it for a small
  config popup** (show/hide that bar, text size, reset position) right next to the bar.

## Placing the bars

1. Open **Edit Mode** (game menu → Edit Mode).
2. Each bar appears as a labelled sample ("Target Cast Bar" / "Focus Cast Bar") with a
   cyan selection outline.
3. **Drag** a bar to position it, or **click** it to open a config popup beside the bar
   (enable that bar, change the text size, or reset its position).
4. Close Edit Mode. The position is saved per account.

## Commands

| Command | Action |
|---|---|
| `/scast` | Open the settings panel |
| `/scast dump` | Print the current text size and each bar's state + position (debug) |

## Settings

Found under **Options → AddOns → Shadows of UI → Cast Bars**:

- **Show target cast bar** — on by default.
- **Show focus cast bar** — on by default.
- **Bar text size** — 8–22px (default 12).

## Dependencies

- LibNAddOn
- LibNUI

## Saved Data

`ShadowsOfUI_CastbarDB` (account-wide): the text size, the two per-bar enable toggles, and
each bar's saved position.
