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

The **Weapons** grid has the same **PTR PREVIEW** toggle (on its filter strip): it shows
the upcoming *weapon* appearances that aren't on live yet, with a "+N appearances upcoming"
tally — refreshed the same way, per PTR patch. On the PTR itself (where those appearances are
live) both grids show real counts; on a live realm each upcoming cell is a muted blue dot,
since the content has no data there yet.

## Wanted & ranking

Mark what you're chasing and rate how it looks. Both grids have both — armor sets and
individual weapon looks — and both are saved account-wide, independent of whether
you've collected the thing.

- **Wanted** — **Shift-click** any of a set's appearances in the grid (or use the
  **Wanted** button in the dressing room) to flag the set. Wanted sets show a gold star in the grid, the header
  keeps a running `★` count, and the **Wanted only** title-bar button filters the
  grid down to just your target list. `/collected wanted` lists them all in chat.
- **Tier rank** — give a set an **S / A / B / C / F** rating in the dressing room.
  Set a single baseline rank, or turn on **This race** to rank it for the specific
  race you're previewing (some sets look better on some races). The grid shows the
  tier letter, in its tier color, in the corner of the appearance — for your current
  character's race.
- **Weapons** get the same two, one look at a time rather than one set at a time —
  see **Weapons view** below. There's no **This race** for a weapon: it looks the
  same on everybody. Flagging is the one part that doesn't work from the grid: a
  weapon cell stands for every look of that type from that source at once, so you
  flag a weapon in the chooser beside the dressing room instead.

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

**One workspace.** The dressing room docks to the right of the collection window and the Outfit
Library docks beneath it, so the three lock into a single movable cluster — grab any of them by its
title bar and all three move together, always keeping their relative positions and staying on screen.

## Weapons view

The **Armor / Weapons** toggle at the top of the window flips the whole grid between
your armor sets and your **weapons**. In Weapons mode the rows become weapon
**sources** — each raid, dungeon, and world boss, plus per-expansion buckets for
Quest, Vendor, World Drop, Crafted, Trading Post and Achievement weapons — and the
columns become the **weapon types**, each a small icon (hover a header for its name —
one-handed swords, staves, bows, off-hands, and so on) — the types your class can wield show in
gold, the ones it can't are dimmed (a hint, not a filter, so every column stays put). Each cell
works just like the armor grid: the number of appearances you still
need, shaded red→green by how close you are (a green check when you've collected them
all). Hover a cell for the list of individual weapons in it, each with a collected
mark and its **difficulty** (LFR / Normal / Heroic / Mythic). Sort by expansion and
filter by expansion or source category, exactly like the armor grid — including the
**★ Wanted only** button, which cuts the grid down to just the sources and weapon
types holding something you've flagged. The header's `★` count switches with the
grid: wanted sets in Armor, wanted weapon looks in Weapons.

**Click a cell** and the weapon goes straight into the look you're building — same
window, same character, same paper doll you dress armor on. The armor set stays on,
the slot columns stay up, and the weapon slot at the bottom lights up with the piece
you're looking at. A chooser lists every look in the cell, with the same-named
difficulty recolours told apart by their **difficulty** label. Use **↑/↓** to step
through the looks and **←/→** to jump to the neighbouring weapon type from the same
source — the character re-renders in place each time, wearing your outfit. The grid
draws a white box around the cell you're viewing so you never lose your place.

**Wanted & tiers, per look.** Weapons are flagged and rated one appearance at a time.
While you're browsing a weapon the dressing room's own **Wanted** star and
**S / A / B / C / F** row act on the look you're currently viewing — the window title
tells you which one that is — so it's the same strip of buttons you use for armor sets,
pointed at whatever you're actually looking at. Click the tier it already has, or the
**–**, to clear it. (**This race** greys out here: a weapon looks the same on every
race, so there's nothing to override.) Click any armor set in the grid and the row goes
back to rating that set. You can also **shift-click** any chooser row to flag that look
wanted without stepping to it — it gets a gold star. Every row
carries its own tier letter, so you can see the whole cell ranked at a glance while you
step through it. Back in the grid, a cell is starred when **any** look in it is wanted
and shows the **best** tier among its looks, so a bucket of four daggers advertises the
one you actually want out of it. That star is a readout of the whole bucket, which is why
the cell itself doesn't take a shift-click the way an armor set's does — flagging happens
in the chooser, where you can see which of the four you're picking.

**Which hand.** The chooser's **Main hand** and **Off hand** buttons say where the
weapon you're browsing is being held, and clicking the other one moves it there. Only
the hands that weapon can actually go in are offered (the other is greyed out): a
one-hander can take either, a staff or a bow only the main hand, a shield or an
off-hand frill only the off hand. Two-handed axes, maces and swords take either hand
too, so you can build a Titan's Grip look straight from the grid. A weapon starts in
whichever hand suits its type, so browsing a sword and then a shield leaves you
holding both. Right-click the weapon slot under the model to put one down.

Nothing else changes when you flip the **Armor / Weapons** toggle — it swaps which
grid you're looking at and leaves the preview window exactly as it is, so you can go
and find a weapon and come straight back to the set you were building.

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
  The off hand takes a second one-hander, a shield or off-hand frill, or a two-handed axe,
  mace or sword for a Titan's Grip look.
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

A main-hand with no room beside it — a staff, a polearm, a bow or a gun — greys out the
off-hand slot. Switch back to something that leaves room and your off-hand pick comes back.

**Titan's Grip looks work.** Two-handed axes, maces and swords are offered for the off hand
as well, so a Fury Warrior can hold two of them and both show on the model. They're offered
for any class whose set is on screen, not just Warriors — this is a preview, and it renders
looks the way the rest of the builder does, leaving what you can actually equip to the
transmogrifier.

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
- **Names ignore capitals.** Typing `boylane 3` when you already have a *Boylane 3* means that
  look — so it asks before replacing it, rather than quietly leaving you two entries you can't tell
  apart. The look keeps the spelling you gave it; **Rename** is what changes that.
- **Rename** changes the selected look's name to whatever's in the name field. It's the only thing
  that renames — pressing Enter in the box always saves, never renames.
- **Delete** asks once before removing anything: the button goes gold, changes to *Sure?* and counts
  down the few seconds you have to click it again. If the countdown runs out it names the look and
  tells you it wasn't deleted, so a click that arrived too late can never look like one that worked.
  Saving under a name that belongs to a *different* look asks the same way, so you can't overwrite
  one by accident. A pending question only ever applies to the look it was asked about — pick a
  different look, or lose the one you'd picked, and the button drops back to normal rather than
  quietly retargeting. Retype the name and Save asks again about the new one, rather than taking
  the answer you gave about the old one as covering it.
- **Push** copies the selected look into *this* character's transmog sets, so you can wear it at
  a transmogrifier. That's the only step that's per-character, and the only one the game's
  25-set limit applies to. If this character already has a set under that name, Push asks first and
  tells you which one it would replace.
- Buttons that can't do anything are greyed: Save until you've named a new look, and Rename,
  Delete and Push until you've picked one.

**Saving from the game's transmogrifier.** You don't have to build a look in this addon to keep it.
At any transmogrifier you'll find two extra buttons under your character:

- **Save Look** takes whatever is on the model right then — including pieces you've staged but not
  yet applied — asks you to name it, and saves it to **both** your account-wide library *and* this
  character's own transmog sets, in one click.
- If the game won't take the set — you're at its 25-set limit, or it doesn't like the name — the
  look is **still saved to your library**, and you're told why the game set was skipped. The half
  that follows you everywhere is never lost to a per-character limit.
- A name that's already in your library asks before replacing it. The look it saves is the one you
  named — if you go back to staging pieces while that question is still on screen, answering **Yes**
  still stores what was on the model when you typed the name, not what's on it now.
- **Outfit Library** opens the library window right there, so you can find an old look and
  **Push** it onto this character without leaving the transmogrifier.

**Finding a look once you have a lot of them.** The **Outfit Library…** button at the bottom of the
preview window opens the library — the same list, with room to search it and a model to see them on:

- **Filter by armour type.** The one that groups a look across characters: a leather look shows up
  whether you're after it for your rogue, your druid or your demon hunter, none of whom share a
  class. Looks that aren't tied to one armour type — cosmetic, mixed, or weapons only — show under
  every type, because they genuinely go on anyone.
- **Filter by class**, meaning the class the look was **built for**, not whoever saved it. A Warrior
  look your Druid put together is a Warrior look. Only classes you actually have looks for are
  offered.
- **Search** by the look's name or by the character who saved it.
- The filters combine, **Clear** drops all of them at once, and the title bar counts what you're
  seeing out of what you have.
- **Click a look to see it.** It appears on the window's own model, dressed exactly as it was
  saved, with who saved it written underneath. The window stays open, so you can click down the
  list comparing them.
- **Rename**, **Delete** and **Push** act on the look you've selected, right beside the model.
  Delete always asks first, and Push asks whenever it would replace a same-named set on this
  character — the same way the outfit row asks. Saving stays where the look you're *building*
  lives — the outfit row, or the transmogrifier.
- **This window and the outfit row stay in step.** They're normally on screen together, and either
  one can change the library — so a look renamed or deleted in one updates in the other straight
  away, instead of one of them sitting there offering something that's already gone.

**Bring your old transmog sets in.** Sets you saved in the game's own dressing room live on
**one character only** — that's a WoW limitation, and it's the whole reason this library exists.
**Import this character's sets** at the bottom of the window copies every one of them into the
library, where every character can reach them. Do it once per alt.

Nothing you already have is ever overwritten. A set whose name is already in your library is
saved as *"name (2)"* instead, and one that's already been imported is simply left alone — so you
can press the button again on a character you've already done, and nothing will pile up. You'll
get a short summary of what happened either way.

Imported looks record the character you imported them from and their armour type, but not which
class's set they were built from — the game doesn't keep that once a set is saved, so it's simply
unknown rather than guessed, and those looks show up under **every** class filter.

Looks saved before the library started recording where looks came from show as *no provenance
recorded* — and they're **never** hidden by a filter, so nothing you've saved can go missing behind
one.

**Any look saves whole**, whatever your character can wear. A plate set saved from a Druid
comes back complete, and pieces you simply haven't collected yet save normally too — so you
can build and keep a look for an alt. Actually *wearing* it is a separate matter: a
transmogrifier still only lets a character wear what its class can equip.

**Slots you hid stay hidden.** A slot you clicked to *hidden* saves, loads and shares as the
game's Hidden piece for that slot, so the look you get back is the one you were looking at —
not one that quietly falls back to your equipped gear. A slot you clicked all the way round to
*no transmog* saves as exactly that.

While a saved look is loaded the window shows its name, and the rating buttons are hidden —
a look isn't one of the tracked sets, so there's nothing to rate. (Click a weapon in the
Weapons grid and they come back, pointed at that weapon; switch the grid back to Armor
without picking anything and they go away again.) Click any set in the grid to go back to
normal previewing.

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

## Taking a look off someone you can see

Target a player whose transmog you like and run `/collected outfit inspect`. It reads what
they're wearing and hands it back as the same `/customset` string Export produces — copy it,
send it to a friend, or paste it into `/collected outfit import` to wear it yourself. If the
preview window is already open it dresses itself from their look straight away, **with the
name field already filled in with their name** — so keeping it is a single click on **Save**.

This is the game's ordinary inspect, so the usual rules apply: it has to be a player, they
have to be close enough to inspect, and their gear takes a moment to arrive. If it doesn't,
you'll be told to get closer and try again. **Faction and realm are no obstacle** — someone
from the opposite faction, or from another realm standing beside you in a city, reads just
the same as a guildmate.

Everything you can see on them comes across, down to the **enchant glow** on their weapons.
The one thing that can't travel is a **weapon they aren't holding** — the format has no way
to say "empty hand", so an off-hand they've left bare shows yours instead. The listing in the
copy window says so explicitly, rather than leaving the slot out.

**Pieces you haven't collected are fine to share.** Both formats carry appearances you
don't own yet, which makes either a good way to pass a wishlist look around. The export marks
those slots `(not owned)` so you can see at a glance which ones you're still chasing.

**Another class's set is fine too.** A plate set exported from a Druid shares, re-imports and
saves complete — nothing is dropped for being the wrong armour type.

**Empty slots stay empty for whoever you send it to.** A look with no cloak used to arrive
wearing the recipient's *own* cloak — the format says "no transmog here", and the game's
dress-up window reads that as "leave what you're already wearing". Anything the preview shows
bare is now shared as genuinely bare, so what they see is what you saw. Two caveats worth
knowing:

- **Weapons are the exception.** The game has a "hidden" appearance for every armor and
  cosmetic slot but none for the two weapon slots, so a look with no main-hand will still show
  the recipient's own weapon. Nothing in the format can express otherwise.
- If you deliberately cycled a slot to **no transmog** (the third click), that's left alone —
  you asked for the wearer's own gear to show, and sharing respects it. That choice lives in
  the preview though: save a look and reload it later and it comes back as simply bare, since
  the saved format has nowhere to record the difference.

If a look has only just appeared on the model, posting it to chat may say the item data is
still loading — give it a moment and click again.

`/collected outfit list` shows your library alongside the transmog sets you've saved in game,
and how many of the game's set slots are used.

## Usage

| Command | What it does |
|---|---|
| `/collected` or `/collect` | Open/close the window |
| `/collected scan` | Rebuild collection data from the game's transmog APIs |
| `/collected refresh` | Redraw the open window's grids without rescanning — use it if the grid ever appears with its text missing |
| `/collected wanted` | List the sets you've flagged as wanted |
| `/collected outfit export` | Copy the previewed look as a shareable `/customset` string |
| `/collected outfit post` | Put the previewed look in your chat box as a clickable link |
| `/collected outfit import <string>` | Dress the preview from a `/customset` string or a shift-clicked link |
| `/collected outfit inspect` | Read your target's transmog as a `/customset` string, and dress the preview with it |
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
wanted flags and tier ranks (baseline + per-race) for sets, the same two for individual
weapon looks, your wanted shirt/tabard appearances and illusions, plus **your outfit library** — the looks you've saved,
kept for the whole account so they're available on every character. (The game's own transmog
sets stay in its store, per character; **Push** copies a look across.) Ratings are kept separately from
the scan data, so re-scanning never clears them. The collection window and the set
preview window also remember where you last dragged them, so they reopen in place
instead of re-centering.
