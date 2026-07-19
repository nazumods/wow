# LibNUI ModelViewer

A `ModelScene`-backed 3D model viewer widget for [LibNUI](../LibNUI/README.md). Extracted
from core LibNUI because it is a useful but uncommon component — only addons that actually
present a 3D character / transmog viewer need to depend on it.

It registers itself as `ui.Model` (a.k.a. the `LibNUI.Model` global) on the shared LibNUI
widget table, so consumers use it exactly like any other LibNUI widget.

## Dependencies

- **LibNAddOn**
- **LibNUI**

## Setup

List it in your `.toc` so it loads before your addon — its widget must exist on `ui` by the
time your files run:

```
## Dependencies: LibNAddOn, LibNUI, LibNUI-ModelViewer
```

The widget is then available on the shared LibNUI table — as the `LibNUI.Model` global, or as
`ns.ui.Model` inside a LibNAddOn-based addon:

```lua
---@type LibNUI
local ui = ns.ui
local Model = ui.Model
```

## Model

Inherits `Frame` (backed by a `ModelScene`). A 3D viewer that borrows Blizzard's
dressup scene (id 596) for camera + lighting + a skinnable player actor: set a
body via a unit, an arbitrary race+gender (creature display ID), or a unit
re-rendered as another race, then `TryOn` transmog appearance sources.
**Left-drag** spins the model (actor yaw), **right-drag** pans the camera, and the
**mouse wheel** zooms — pan and zoom glide smoothly (the camera eases them itself),
and a left-drag **flick** keeps the model spinning and coasts to a stop. The dragged
angle is preserved when you re-skin the actor (`DisplayInfo`/`Unit`), so swapping the
body doesn't snap it back to front-facing; pan/zoom live on the camera and likewise
persist across re-skins. Note a creature
display only textures if it's a **baked** display (carries its own textures) — a
bare base/`ChrModel` display renders white, since the engine can only composite
textures for the active player's own race. All models render through one
player-sized actor, so races at their natural size come out wildly inconsistent; use
`Aggressiveness` to normalize every model toward a common (~human-male) size, with
`Scale` as a user multiplier on top.

### Constructor options

| Option        | Type   | Description                                           |
|---------------|--------|-------------------------------------------------------|
| `rotateSpeed` | number | Radians of yaw per screen pixel dragged (default 0.01) |
| `facing`      | number | Initial yaw (radians) applied on load so the model faces the camera; re-skinned models pose side-on by default (default `-math.rad(88)`) |
| `minZoom`     | number | Closest the wheel may zoom in, in scene units (default 2). The borrowed scene pins zoom to 6–10, so this widens the usable range |
| `maxZoom`     | number | Farthest the wheel may zoom out, in scene units (default 16) |
| `spinFriction`| number | How fast a left-drag flick decays to a stop (DeltaLerp amount per ideal frame; default 0.05 ≈ a 1s glide). Lower = longer coast |
| `spinTracking`| number | How closely the tracked throw speed follows the cursor while dragging (default 0.5). Smooths out spikes so carefully placing the model doesn't fling it on release |

### Methods

| Method                | Description                                                      |
|-----------------------|------------------------------------------------------------------|
| `DisplayInfo(id, useCustomizations?)` | Skin the actor with a creature display ID. `useCustomizations` defaults **false** — a baked display carries its own race+gender textures; passing true overlays the active player's customizations (only textures the player's own race) |
| `Unit(token, customRaceID?, useNativeForm?)` | Skin from a unit (e.g. `"player"`), optionally rendered as another race (`customRaceID` = chrRaceID, keeps the unit's gender). `useNativeForm` (default true) is the unit's native vs altered form (Worgen human, Dracthyr visage) — only effective when the *unit* has an alternate form. `autoDress` is off |
| `TryOn(source)`       | Put on an item link or `itemModifiedAppearanceID` (sourceID)     |
| `Undress()` / `Dress()` | Strip / re-equip the actor's gear                              |
| `UndressSlot(slot)`   | Strip one equipment slot (inventory slot id) off the model, leaving the rest — the removal half of a paper-doll per-slot toggle (`TryOn` re-adds). Doesn't touch the remembered `Outfit`; re-set that so an async re-skin honors the change |
| `Outfit(sources)`     | Remember a transmog outfit (list of sourceIDs; empty = undressed) and re-apply it after every async model (re)load. Use this instead of one-shot `TryOn`/`Undress` when re-skinning, since the load otherwise resets the actor to its baked default. Call before `DisplayInfo`/`Unit` |
| `SlotTransmog(slot, appearanceID, opts?)` | Precisely set **one** slot's transmog, including the extras a bare `TryOn` can't express — an enchant **illusion** (`opts.illusionID`, weapon slots), a **secondary appearance** (`opts.secondaryAppearanceID` — split shoulders, or a Legion artifact's paired off-hand), and `opts.ignoreChildItems` (default true). Routes through `SetItemTransmogInfo` (the primitive Blizzard's dressing room uses), composes with `Outfit`/`TryOn` (re-applied last for its slot after each async re-skin), and remembers the override across re-skins. `appearanceID` 0 renders the slot bare. Illusion preview: `SlotTransmog(INVSLOT_MAINHAND, hostWeaponSourceID, { illusionID = sid })` |
| `ClearSlotTransmog(slot)` | Forget a slot's `SlotTransmog` override so later re-skins no longer re-apply it (the base `Outfit`/`TryOn` look governs that slot again). Doesn't restrip in place — follow with a fresh `Outfit`/`Dress` |
| `Aggressiveness(n)`   | Set the bounding-box normalization strength (0 = the model's natural size, **default**; 1 = forced to ~human-male size). A mid value (e.g. 0.5) keeps races consistent while preserving some racial size character. Remembered and re-applied after each async re-skin |
| `Scale(n)`            | Set the user scale multiplier on top of the normalized size (1 = the normalized size). Remembered and re-asserted every frame, so it survives an async re-skin's scale reset regardless of load timing |
| `Spin(v)`             | Get/set the model's rotation speed in radians/sec. A non-zero value spins it with the same inertia as a mouse flick (handy for a showcase spin); `Spin(0)` halts. No-arg reads the live speed |
| `ResetView()`         | Restore the view to its load defaults: the facing yaw (cancelling any spin), the scene's natural zoom, and no pan. Undoes the user's drag-rotate / right-drag pan / wheel-zoom. The user scale multiplier (`Scale`) is a separate control and is left untouched |
