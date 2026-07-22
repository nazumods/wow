# Warbandeer: Collected

A **transmog set tracker** for your whole warband. It shows a grid of instance tier
sets versus your characters, with the number of appearances each character can still
collect. Use the title-bar buttons to flip the row order between oldest and newest
expansion first, hover a set to see its pieces (collected vs missing), and click a
row to see which of your characters are locked out of that instance — so you always
know who to run it on next. An **Armor / Weapons** toggle at the top of the window
switches the grid between your armor sets and your weapon collection (see **Weapons
view** below).

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
bulk version — it strips every piece off at once to show the bare race, weapons
and shirt and tabard included (click it again and everything you had on comes
back). There's also a **Background** toggle for a
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

## Weapons view

The **Armor / Weapons** toggle at the top of the window flips the whole grid between
your armor sets and your **weapons**. In Weapons mode the rows become weapon
**sources** — each raid, dungeon, and world boss, plus per-expansion buckets for
Quest, Vendor, World Drop, Crafted, Trading Post and Achievement weapons — and the
columns become the **weapon types** (one-handed swords, staves, bows, off-hands, and
so on). Each cell works just like the armor grid: the number of appearances you still
need, shaded red→green by how close you are (a green check when you've collected them
all). Hover a cell for the list of individual weapons in it, each with a collected
mark and its **difficulty** (LFR / Normal / Heroic / Mythic). Sort by expansion and
filter by expansion or source category, exactly like the armor grid.

**Click a cell** to open the dressing room holding those weapons on your own
character, with a chooser listing every look in that cell — the same-named difficulty
recolours told apart by their **difficulty** label. Use **↑/↓** to step through the
looks and **←/→** to jump to the neighbouring weapon type from the same source; the
grid draws a white box around the cell you're viewing so you never lose your place.
Mark a look with the **★** button to add it to your weapon wanted list.

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
breakdown — plus, while you're still missing pieces, a **How to obtain** line for where
to get them (which class each illusion is locked to, and the Broken Shore / Timewalking
source for the Legion arsenals) — and Shift-click to flag it wanted just like a set. Click a Weapons cell to
open the dressing room holding the piece on your own character — for an **arsenal** it
shows the weapon appearance; for an **illusion** it lays the enchant shimmer over your
equipped weapon. Use the **Up/Down** nav to cycle through the pieces (the 15 Ebon
weapons, the 5 Shaman brands); the title names the one you're viewing.

## Look builder

Finish a transmog right in the dressing room. The model has **main-hand and off-hand
weapon slots across the bottom** and **shirt and tabard slots down the left**, just like
the character sheet. Click any of them to open a **look builder** panel docked to the
right and add a piece to the armor set you're previewing — all on the model at once.

- Click the **main-hand** or **off-hand** slot to open the picker for that hand. The
  weapon-type dropdown lists only the types that go in that hand and that the set's own
  class can transmog (so a Warrior set offers plate weapons even while you're on a Mage).
  Click any weapon you've collected to hold it on the model; it then shows in the slot,
  with a green border. Names are colored by item quality and show where the weapon comes
  from — hover for the full item tooltip.
- The **Illusions** tab (on the main-hand picker) lists the enchant illusions the set's
  class can use, green when you've collected them — including that class's own weapon
  shimmers (a Shaman set's imbues, a Death Knight set's runeforge) even on another class.
  Click one and its shimmer lays over the weapon you're holding (or your character's
  currently-equipped weapon if you haven't picked one). This list shows every illusion that
  class can use, collected or not, each marked with a **green check** or a **red X** —
  **shift-click** one to flag it wanted.
- Click the **shirt** or **tabard** slot to browse **every** one in the game. No set comes
  with either, so this list is the only place they turn up — and unlike the weapon lists it
  shows the ones you haven't collected too, each row marked with a **green check** if you own
  it and a **red X** if you don't. You can still try an unowned one on the model and share it
  in an exported look. **Hidden Shirt** and **Hidden Tabard** are pinned to the top of their
  lists, since they're what you reach for to leave the slot deliberately empty. **Shift-click a
  row** to flag it wanted (a gold star), the same way you flag a set in the grid.

Step to another class's set (the arrow keys, or the nav pad) and the picker re-scopes to
that class's weapons and illusions.

A two-handed main-hand (a staff, a 2H sword) fills both hands, so picking one greys out the
off-hand slot — switch back to a one-hander and your off-hand pick comes back.

**Right-click a slot to clear it** (or click the piece again in the picker). Drag the
panel's header to move the whole window.

## Saving a look

The preview window has an **outfit row** under the ratings — a dropdown of your saved looks,
a name field, and **Save**, **Rename**, **Delete** and **Push**.

**Your library follows you.** Looks saved here are kept for the whole account, so one you put
together on your main is waiting on every alt. The game's own saved transmog sets are
per-character — a set saved on one character simply isn't there on another — which is exactly
what this works around.

- Pick a look from the dropdown to **load** it: the model, the equipment slots, the weapons
  and the shirt and tabard all change to it.
- **Save** writes what's on screen into whichever look the dropdown has selected. To keep a new
  one instead, pick **+ New Look** at the bottom of the dropdown, type a name, and Save.
- **Rename** changes the selected look's name to whatever's in the name field.
- **Delete** asks once (the button changes to *Confirm?*) before removing anything. Saving a new
  look under a name you already use asks the same way — it offers to **replace** that one rather
  than making you pick another name.
- **Push** copies the selected look into *this* character's transmog sets, so you can wear it at
  a transmogrifier. That's the only step that's per-character, and the only one the game's
  25-set limit applies to.
- Buttons that can't do anything are greyed: Save until you've named a new look, and Rename,
  Delete and Push until you've picked one.

**Any look saves whole**, whatever your character can wear. A plate set saved from a Druid
comes back complete, and pieces you simply haven't collected yet save normally too — so you
can build and keep a look for an alt. Actually *wearing* it is a separate matter: a
transmogrifier still only lets a character wear what its class can equip.

While a saved look is loaded the window shows its name, and the rating buttons are hidden —
a look isn't one of the tracked sets, so there's nothing to rate. Click any set in the
grid to go back to normal previewing.

## Sharing a look

Any look you've put together in the preview window can be turned into the same
`/customset` string the game itself uses, so you can paste it to a friend, keep it in a
note, or drop it back in later.

- `/collected outfit export` copies the look on screen into a window you can select and
  copy from. It also lists every slot it captured, so you can check the string against
  what you're looking at.
- `/collected outfit import <string>` dresses the open preview from a string — either one
  of yours or one someone sends you.
- `/collected outfit list` shows the transmog sets you've saved in game, and how many of
  your slots are used.

The string works both ways with the game's own `/customset` command, so the person you
send it to doesn't need this addon.

**Pieces you haven't collected are fine to share.** A string carries appearances you
don't own yet, which makes it a good way to pass a wishlist look around. The export marks
those slots `(not owned)` so you can see at a glance which ones you're still chasing.

**Another class's set is fine too.** A plate set exported from a Druid shares, re-imports and
saves complete — nothing is dropped for being the wrong armour type.

## Usage

| Command | What it does |
|---|---|
| `/collected` or `/collect` | Open/close the window |
| `/collected scan` | Rebuild collection data from the game's transmog APIs |
| `/collected wanted` | List the sets you've flagged as wanted |
| `/collected outfit export` | Copy the previewed look as a shareable `/customset` string |
| `/collected outfit import <string>` | Dress the preview from a `/customset` string |
| `/collected outfit list` | Your account-wide library, plus this character's transmog sets |
| `/collected outfit save <name>` | Save the previewed look to your library |
| `/collected outfit load <name>` | Dress the preview from your library |
| `/collected outfit delete <name>` | Remove a look from your library |
| `/collected outfit push <name>` | Copy a look into this character's transmog sets |

The addon compartment button (next to the minimap) also works: click to open,
right-click to scan.

## Dependencies

- **LibNAddOn**
- **LibNUI**
- **LibNUI-ModelViewer** — the 3D `ui.Model` viewer used by the dressing room.
- **Warbandeer_Characters** — provides character and lockout data.

## Saved data

`WarbandeerCollectedDB` (account-wide): scanned set/appearance counts, plus your
wanted flags and tier ranks (baseline + per-race) and your wanted weapon looks,
shirt/tabard appearances and illusions, plus **your outfit library** — the looks you've saved,
kept for the whole account so they're available on every character. (The game's own transmog
sets stay in its store, per character; **Push** copies a look across.) Ratings are kept separately from
the scan data, so re-scanning never clears them. The collection window and the set
preview window also remember where you last dragged them, so they reopen in place
instead of re-centering.
