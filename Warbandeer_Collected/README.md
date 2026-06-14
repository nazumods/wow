# Warbandeer_Collected

A **transmog set tracker** for your whole warband. It shows a grid of instance tier
sets versus your characters, with the number of appearances each character can still
collect. Use the title-bar button to flip the row order between oldest and newest
expansion first, hover a set to see its pieces (collected vs missing), and click a
row to see which of your characters are locked out of that instance — so you always
know who to run it on next.

Click a set's cell to open a 3D dressing
room showing the set worn by any playable **race** you pick — handy for
deciding what a transmog will actually look like. Like the character sheet, each
piece sits in its equipment slot down the sides (green border = collected, red =
still missing); hover a slot for the in-game item tooltip. There's an **Undress**
toggle to strip the set off and see the bare race, a **Background** toggle for a
class-themed backdrop (greyed out for the few classes without one), and a scale
slider to resize the model. The model always
uses your own character's **gender** (a model that can actually wear the set is
locked to your gender by the game), and the race icons match your gender. Races with two forms
(Worgen, Dracthyr) show a form toggle at the top of the model so you can preview
either one. A directional pad in the model's upper-right corner — `<`/`>` (or the
**Left/Right arrow keys**) flips through the other classes' sets from the same
instance, and `^`/`v` (or the **Up/Down arrow keys**) switches between that raid's
difficulty tiers (Normal/Heroic/Mythic, etc.) for the same class — all without
reopening. The window stays open until you close it (Escape or the X); drag to spin
the model.

## Usage

| Command | What it does |
|---|---|
| `/collected` or `/collect` | Open/close the window |
| `/collected scan` | Rebuild collection data from the game's transmog APIs |

The addon compartment button (next to the minimap) also works: click to open,
right-click to scan.

## Requirements

- **LibNAddOn** and **LibNUI** (libraries)
- **Warbandeer_Characters** — provides character and lockout data.

## Saved data

`WarbandeerCollectedDB` (account-wide): scanned set/appearance counts.
