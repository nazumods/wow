# Warbandeer: Collected

A **transmog set tracker** for your whole warband. It shows a grid of instance tier
sets versus your characters, with the number of appearances each character can still
collect. Use the title-bar buttons to flip the row order between oldest and newest
expansion first, hover a set to see its pieces (collected vs missing), and click a
row to see which of your characters are locked out of that instance — so you always
know who to run it on next.

## PTR preview

The **PTR PREVIEW** title-bar button switches the grid to show just the **upcoming**
sets — the transmog sets that are on the current Public Test Realm but **not yet on
live**. Each upcoming set shows a muted blue dot (there's no collection data for
content that isn't out yet), and the counter switches to a "+N sets upcoming" tally
with the PTR build the preview was generated from. You can still **Shift-click to flag** an upcoming set as
wanted (the flag carries over once it ships to live). The 3D preview of an upcoming
set only works when you're **actually logged into the PTR** — there the appearances
exist and clicking opens the dressing room like any other set. On a live realm the
client doesn't have those appearances yet, so clicking instead prints a short note
pointing you to the PTR rather than opening an empty model. The list is a snapshot,
refreshed by the addon author when a new PTR patch arrives.

## Wanted & ranking

Mark the sets you're chasing and rate how they look:

- **Wanted** — **Shift-click** any of a set's appearances in the grid (or use the
  **Wanted** button in the dressing room) to flag the set. Wanted sets show a gold star in the grid, the header
  keeps a running `★` count, and the **Wanted only** title-bar button filters the
  grid down to just your target list. `/collected wanted` lists them all in chat.
- **Tier rank** — give a set an **S / A / B / C / F** rating in the dressing room.
  Set a single baseline rank, or turn on **This race** to rank it for the specific
  race you're previewing (some sets look better on some races). The grid shows the
  tier letter, in its tier color, in the corner of the appearance — for your current
  character's race. Both are saved account-wide and are independent of whether
  you've collected the set.

Click an appearance to open a 3D dressing
room showing the set worn by any playable **race** you pick — handy for
deciding what a transmog will actually look like. Like the character sheet, each
piece sits in its equipment slot down the sides (green border = collected, red =
still missing); hover a slot for the in-game item tooltip, and **click a slot to
toggle that piece on or off the model** (its icon greys out while it's off) to see
how the set looks without a helm, cloak, and so on. The **Undress** toggle is the
bulk version — it strips every piece off at once to show the bare race (click it
again to redress). There's also a **Background** toggle for a
class-themed backdrop, a scale slider to resize the model, and a **Reset View**
button to snap the camera back to its starting rotation, zoom, pan, and scale. The model always
uses your own character's **gender** (a model that can actually wear the set is
locked to your gender by the game), and the race icons match your gender. Races with two forms
(Worgen, Dracthyr) show a form toggle at the top of the model so you can preview
either one. A directional pad in the model's upper-right corner — `<`/`>` (or the
**Left/Right arrow keys**) flips through the other classes' sets from the same
instance, and `^`/`v` (or the **Up/Down arrow keys**) switches between that raid's
difficulty tiers (Normal/Heroic/Mythic, etc.) for the same class — all without
reopening. While the dressing room is open, the grid draws a **white box around the
cell of the set you're viewing** and moves it as you arrow-navigate — left/right across
the classes, up/down through the tiers (scrolling it into view if needed) — so you never
lose your place in the list. The slot columns down each side are tinted by the raid's difficulty,
reusing the familiar item-quality colors (LFR green, Normal blue, Heroic purple,
Mythic gold), so you can tell at a glance which tier you're previewing. A badge in
the model's lower-right corner shows which **expansion** the set is from (hover it
for the expansion name). The window stays open until you close it (Escape or the X); drag to spin
the model.

## Class weapon cosmetics

The **Weapons** category (in the Category filter) tracks the class-specific weapon
cosmetics that are easy to miss:

- **Illusions** — the class weapon-enchant illusions: the Death Knight's Rune of
  Razorice, the Rogue's Poisoned, and the Shaman's five weapon imbues (Flametongue,
  Frostbrand, Earthliving, Windfury, Rockbiter).
- **Arsenals** — the Legion class weapon-appearance bundles: the Death Knight's
  Armaments of the Ebon Blade, the Paladin's Armaments of the Silver Hand, and the
  Demon Hunter's Warglaives of Azzinoth.

Each cell counts how many pieces you still need (read **account-wide**, so it's right
no matter which character you're on), hover it for the per-piece owned/missing
breakdown, and Shift-click to flag it wanted just like a set. Click a Weapons cell to
open the dressing room holding the piece on your own character — for an **arsenal** it
shows the weapon appearance; for an **illusion** it lays the enchant shimmer over your
equipped weapon. Use the **Up/Down** nav to cycle through the pieces (the 15 Ebon
weapons, the 5 Shaman brands); the title names the one you're viewing.

## Usage

| Command | What it does |
|---|---|
| `/collected` or `/collect` | Open/close the window |
| `/collected scan` | Rebuild collection data from the game's transmog APIs |
| `/collected wanted` | List the sets you've flagged as wanted |

The addon compartment button (next to the minimap) also works: click to open,
right-click to scan.

## Dependencies

- **LibNAddOn**
- **LibNUI**
- **Warbandeer_Characters** — provides character and lockout data.

## Saved data

`WarbandeerCollectedDB` (account-wide): scanned set/appearance counts, plus your
wanted flags and tier ranks (baseline + per-race). Ratings are kept separately from
the scan data, so re-scanning never clears them. The collection window and the set
preview window also remember where you last dragged them, so they reopen in place
instead of re-centering.
