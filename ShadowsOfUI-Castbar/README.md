# Cast Bars

Minimal, movable cast bars for your **target**, **focus target**, and **yourself**, in the
clean "Shadows of UI" style. They show what's being cast — spell icon, name, and remaining
time — and stay out of the way the rest of the time.

## Features

- **Target, focus & player cast bars.** Three independent bars, one for each unit, each
  placed wherever you like. The **player** bar is off by default (see below).
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
2. Each bar appears as a labelled sample ("Target Cast Bar" / "Focus Cast Bar" /
   "Player Cast Bar") with a cyan selection outline.
3. **Drag** a bar to position it, or **click** it to open a config popup beside the bar
   (enable that bar, change the text size, or reset its position).
4. Close Edit Mode. The position is saved per account.

A bar you've **hidden** still appears in Edit Mode — dimmed — so you can always reposition it
or switch it back on from the popup, rather than having to dig into the settings panel.

## The player cast bar

The **player** bar (your own casts) is **off by default**, because WoW already shows a player
cast bar of its own — turning this on without hiding Blizzard's would give you two. To use it:

1. Enable **Show player cast bar** in the settings (or its Edit Mode config popup).
2. Optionally hide Blizzard's own cast bar via **Edit Mode → Cast Bar**.

## Commands

| Command | Action |
|---|---|
| `/scast` | Open the settings panel |
| `/scast dump` | Print the current text size and each bar's state + position (debug) |

## Settings

Found under **Options → AddOns → Shadows of UI → Cast Bars**:

- **Show target cast bar** — on by default.
- **Show focus cast bar** — on by default.
- **Show player cast bar** — off by default (your own casts).
- **Bar text size** — 8–22px (default 12).

## Dependencies

- LibNAddOn
- LibNUI

## Saved Data

`ShadowsOfUI_CastbarDB` (account-wide): the text size, the three per-bar enable toggles, and
each bar's saved position.
