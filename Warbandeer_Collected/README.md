# Warbandeer_Collected

A **transmog set tracker** for your whole warband. It shows a grid of instance tier
sets versus your characters, with the number of appearances each character can still
collect. Use the title-bar button to flip the row order between oldest and newest
expansion first, hover a set to see its pieces (collected vs missing), and click a
row to see which of your characters are locked out of that instance — so you always
know who to run it on next.

Hover a set and click **Preview model** in the tooltip to open a 3D dressing room
showing the set worn by any playable **race and gender** you pick — handy for
deciding what a transmog will actually look like. Like the character sheet, each
piece sits in its equipment slot down the sides (green border = collected, red =
still missing); hover a slot for the in-game item tooltip. There's an **Undress**
toggle to strip the set off and see the bare race. The window stays open until you
close it (Escape or the X); drag to spin the model.

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
