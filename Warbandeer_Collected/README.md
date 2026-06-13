# Warbandeer_Collected

A **transmog set tracker** for your whole warband. It shows a grid of instance tier
sets versus your characters, with the number of appearances each character can still
collect. Use the title-bar button to flip the row order between oldest and newest
expansion first, hover a set to see its pieces (collected vs missing), and click a
row to see which of your characters are locked out of that instance — so you always
know who to run it on next.

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
