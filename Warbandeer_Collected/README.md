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
cycle it** through three states — worn, **hidden**, and **no transmog** — to see
how the set looks without a helm, cloak, and so on.

The difference between the two off states only matters once you save or share the
look, but then it matters a lot. **Hidden** puts the game's own *Hidden Helm* (or
Hidden Cloak, Hidden Tabard, …) in the slot, so it stays empty wherever the look is
applied — that's what you were looking at in the preview. **No transmog** leaves the
slot alone instead, so at a transmogrifier whatever you have equipped shows through.
On the paper doll a hidden slot shows the game's Hidden icon, a no-transmog slot
greys the set's piece out, and the tooltip always names the state you're in and what
the next click does. The **Undress** toggle is the bulk version — it hides every
piece at once to show the bare race, weapons and shirt and tabard included (click it
again and everything you had on comes back). There's also a **Background** toggle for a
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

**Take a weapon with you.** The chooser has **Main hand** and **Off hand** buttons at
the top — click one and the weapon you're looking at joins the look you're building,
without going through the weapon picker under the model. Only the hands that weapon
can actually go in are offered (the other is greyed out): a one-hander can take either,
a two-hander or a bow only the main hand, a shield or an off-hand frill only the off
hand. Click the same button again to take it back off. You won't see it here — this
preview shows a bare character holding the weapon on its own — but it's there the
moment you switch back to an armor set.

**The preview follows the toggle.** Flipping between Armor and Weapons brings back
whatever you were last previewing in the view you're switching to, so you can go and
find a weapon and come back to the set you were building without hunting for it again.
If you haven't previewed anything in that view yet, the window simply leaves the
preview as it is rather than closing it — and a saved look you've loaded is never
disturbed by the toggle, since it doesn't belong to either grid.

**The toggle is in the dressing room too**, at the left of its first button row, so you
can switch between armor and weapons without digging the collection window out from
behind the preview. It does the same thing as the one in the window — both stay in step —
and the lit half tells you which view the thing on the model came from. With a saved look
loaded, neither half is lit: that look isn't from either grid.

## Legion class arsenals

The three Legion class weapon-appearance bundles have rows of their own in the Weapons
view: the Paladin's **Armaments of the Silver Hand**, the Death Knight's **Armaments of
the Ebon Blade**, and the Demon Hunter's **Warglaives of Azzinoth**. They work exactly
like any other weapon source — a cell per weapon type with the count you still need,
hover for the individual pieces and where they come from, click to preview and to take
one into your look.

They used to sit in the *armor* grid under a "Weapons" category, which is gone. Almost
all of those appearances were already in the Weapons view anyway, just filed anonymously
under Legion's Vendor row; now they're grouped and named. The class **weapon-enchant
illusions** moved too — they were never really a set, and they live in the look builder's
**Illusions** tab, which is where you'd reach for one anyway (see below).

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
- Each look remembers **who saved it, what class they were, which class's set it was built from,
  and its armour type** — so months later you still know that leather look came from your rogue.
  Names in the dropdown are tinted the class colour of **whoever saved them**, and
  `/collected outfit list` spells the rest out.
- **Save** writes what's on screen under **whatever name is in the box**. Leave it as the selected
  look's name to update that one; type a different name and you get a new look, with the original
  untouched. **+ New Look** at the bottom of the dropdown just clears the box to start fresh.
- **Rename** changes the selected look's name to whatever's in the name field. It's the only thing
  that renames — pressing Enter in the box always saves, never renames.
- **Delete** asks once (the button changes to *Confirm?*) before removing anything. Saving under a
  name that belongs to a *different* look asks the same way, so you can't overwrite one by accident.
- **Push** copies the selected look into *this* character's transmog sets, so you can wear it at
  a transmogrifier. That's the only step that's per-character, and the only one the game's
  25-set limit applies to.
- Buttons that can't do anything are greyed: Save until you've named a new look, and Rename,
  Delete and Push until you've picked one.

**Any look saves whole**, whatever your character can wear. A plate set saved from a Druid
comes back complete, and pieces you simply haven't collected yet save normally too — so you
can build and keep a look for an alt. Actually *wearing* it is a separate matter: a
transmogrifier still only lets a character wear what its class can equip.

**Slots you hid stay hidden.** A slot you clicked to *hidden* saves, loads and shares as the
game's Hidden piece for that slot, so the look you get back is the one you were looking at —
not one that quietly falls back to your equipped gear. A slot you clicked all the way round to
*no transmog* saves as exactly that.

While a saved look is loaded the window shows its name, and the rating buttons are hidden —
a look isn't one of the tracked sets, so there's nothing to rate. Click any set in the
grid to go back to normal previewing.

## Sharing a look

Under the outfit row is a **share row** — a paste field and **Export**, **Post to Chat**
and **Import**. All three act on the look **currently on screen**, so you can share
something you haven't saved yet.

The game has two ways of passing a transmog around, and this uses both:

- **Export** gives you the same `/customset` string the game itself uses — a line of text
  you can send in any chat, drop in a note, or keep for later. It opens in a window you can
  select and copy from, and lists every slot it captured so you can check the string against
  what you're looking at. **The person you send it to doesn't need this addon**: it pastes
  straight into the game's own `/customset` command.
- **Post to Chat** puts the look in your chat box as a **clickable link**. Pick a channel and
  send it, and whoever clicks it sees the outfit in their dress-up window. Nothing is sent
  until *you* press Enter.
- **Import** dresses the preview from either format. Paste a `/customset` string into the
  field and press Enter or click Import.

To import a **link** someone posted, use `/collected outfit import` and shift-click their
link onto the end of the command — chat links can't be dropped into the addon's own field.

Both formats carry exactly the same look, including your shirt, tabard, both weapons and a
weapon illusion.

**Pieces you haven't collected are fine to share.** Both formats carry appearances you
don't own yet, which makes either a good way to pass a wishlist look around. The export marks
those slots `(not owned)` so you can see at a glance which ones you're still chasing.

**Another class's set is fine too.** A plate set exported from a Druid shares, re-imports and
saves complete — nothing is dropped for being the wrong armour type.

If a look has only just appeared on the model, posting it to chat may say the item data is
still loading — give it a moment and click again.

`/collected outfit list` shows your library alongside the transmog sets you've saved in game,
and how many of the game's set slots are used.

## Usage

| Command | What it does |
|---|---|
| `/collected` or `/collect` | Open/close the window |
| `/collected scan` | Rebuild collection data from the game's transmog APIs |
| `/collected wanted` | List the sets you've flagged as wanted |
| `/collected outfit export` | Copy the previewed look as a shareable `/customset` string |
| `/collected outfit post` | Put the previewed look in your chat box as a clickable link |
| `/collected outfit import <string>` | Dress the preview from a `/customset` string or a shift-clicked link |
| `/collected outfit list` | Your account-wide library, plus this character's transmog sets |
| `/collected outfit save <name>` | Save the previewed look to your library |
| `/collected outfit load <name>` | Dress the preview from your library |
| `/collected outfit delete <name>` | Remove a look from your library |
| `/collected outfit push <name>` | Copy a look into this character's transmog sets |
| `/collected cleanup` | Remove saved data for collection rows this version no longer shows |

`cleanup` is safe to ignore. Upgrades never delete anything, so when a row moves — as the
Illusions and Arsenals rows did — its old scan results and any ratings you gave it stay in
your saved variables, harmlessly. Run this once you're happy with the new version to clear
them out.

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
