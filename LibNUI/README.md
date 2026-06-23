# LibNUI

A library of OOP UI classes wrapping Blizzard's frames and adding convenience and quality of life features.

## Setup

List it in your `.toc`:

```
## Dependencies: LibNUI
```

All classes are available via the `LibNUI` global. You may want local aliases for brevity:

```lua
local TitleFrame = LibNUI.TitleFrame
local TableFrame = LibNUI.TableFrame
```

Inside a LibNAddOn-based addon, the same table is exposed as `ns.ui`. Annotate the alias
with the `LibNUI` class so the language server links the widget classes:

```lua
---@type LibNUI
local ui = ns.ui
```

## Core Concepts

### Construction

All widgets are constructed by calling `:new{}` with an options table:

```lua
local frame = LibNUI.Frame:new{
  name   = "MyAddonFrame",
  parent = UIParent,
  size   = {400, 300},
}
```

### `_widget`

Every object wraps a WoW UI object exposed as `._widget`. Use it for anything LibNUI doesn't expose directly.

### Getter/Setter methods

Most methods act as both getter and setter: called with no argument they return the current value; called with an argument they set it.

```lua
frame:Width()      -- returns width
frame:Width(200)   -- sets width to 200
```

### `position` table

Constructor option and standalone method. Keys map to anchor helpers on `Region`. Values are forwarded as arguments.

```lua
position = {
  TopLeft  = {parent, "TOPLEFT", 0, 0},  -- {target, edge, x, y}
  Width    = 100,
  Height   = 30,
  All      = true,  -- SetAllPoints
  Hide     = true,  -- hides after positioning
}
```

### Themes

Built-in widget styling lives in `ui.themes.dark` as named tokens (`colors`, `fonts`, `textures`). Widgets resolve styling against the **active theme**: the `theme` constructor option, inherited through the parent widget chain, falling back to `ui.themes.dark`. Pass a theme once on a top-level window and every child widget inherits it.

```lua
local myTheme = ui.Theme{   -- unlisted tokens fall back to the dark theme
  colors = { window = {0.05, 0.05, 0.06, 1}, header = {1, 0.6, 0.4, 1} },
  fonts  = { title = {path, 16}, header = {path, 11}, body = {path, 13} },
}
local win = ui.TitleFrame:new{ title = "Mine", theme = myTheme }
```

Any color option also accepts a token name string (e.g. `background = "window"`), resolved against the widget's active theme. Always build custom themes via `ui.Theme{}` — raw tables miss the dark-theme fallback.

---

## Constants

```lua
ui.edge    -- "TOP", "CENTER", "TOPLEFT", "TOPRIGHT", "BOTTOM", "BOTTOMLEFT",
           -- "BOTTOMRIGHT", "LEFT", "RIGHT"
ui.layer   -- "BACKGROUND", "BORDER", "ARTWORK", "OVERLAY", "HIGHLIGHT"
ui.justify -- "LEFT", "CENTER", "RIGHT", "TOP", "MIDDLE", "BOTTOM"
ui.wrap    -- "CLAMP", "REPEAT", "MIRROR"
ui.fonts   -- "GameFontHighlight", "GameFontHighlightSmall", "SystemFont_Med2"
```

---

## Class Hierarchy

```
Region
├── Texture
├── Label
└── Frame
    ├── BgFrame
    │   ├── TableCol
    │   └── TableRow
    ├── CleanFrame
    │   ├── TitleFrame
    │   └── Tooltip
    ├── Button
    │   ├── CheckButton
    │   └── SecureButton
    ├── MinimapButton
    ├── Cell
    ├── Dialog
    ├── EditBox
    ├── ScrollFrame
    ├── StatusBar
    ├── TabFrame
    ├── TableFrame
    └── SettingsFrame / TextSetting / ToggleSetting

AutoWidget  (standalone — creates Label/Texture/Button based on options)
```

---

## Region

Base class for all positioned widgets.

### Constructor options

| Option     | Type    | Description                                  |
|------------|---------|----------------------------------------------|
| `position` | table   | Anchor table (see *position* above)          |
| `alpha`    | number  | Initial alpha (0–1)                          |

### Methods

| Method                        | Description                                      |
|-------------------------------|--------------------------------------------------|
| `Parent(parent)`              | Set parent widget                                |
| `Position(position)`          | Apply a position table                           |
| `GetName()`                   | Returns widget name                              |
| `SetPoint(point, ...)`        | Raw anchor — unwraps `._widget` automatically    |
| `All()`                       | `SetAllPoints()`                                 |
| `Center/Top/TopLeft/...(...)`  | Anchor helpers for each edge                    |
| `Size(x, y)`                  | Get/set size                                     |
| `Width(w)` / `Height(h)`      | Get/set individual dimensions                    |
| `Show()` / `Hide()`           | Visibility; `Show` fires `OnBeforeShow` if set   |
| `Toggle()`                    | Toggle visibility                                |
| `SetShown(bool)`              | Conditional show/hide                            |
| `Alpha(a)`                    | Get/set alpha                                    |

### Callbacks

| Callback       | Description              |
|----------------|--------------------------|
| `OnBeforeShow` | Called before `Show()`   |

---

## Texture

Inherits `Region`. Wraps a Blizzard `Texture` widget.

### Constructor options

| Option        | Type          | Description                                  |
|---------------|---------------|----------------------------------------------|
| `parent`      | Region/widget | Required — the owning frame                  |
| `name`        | string        | Optional name                                |
| `layer`       | string        | Draw layer (`ui.layer.*`)                    |
| `template`    | string        | Template                                     |
| `path`        | string        | Texture file path                            |
| `atlas`       | string        | Atlas name                                   |
| `atlasSize`   | bool/number   | True for native atlas size                   |
| `color`       | table/color   | Solid color `{r, g, b, a}`                   |
| `vertexColor` | table         | Vertex tint `{r, g, b, a}`                   |
| `blendMode`   | string        | e.g. `"ADD"`                                 |
| `gradient`    | table         | Args forwarded to `SetGradient`              |
| `coords`      | table         | TexCoord `{l, r, t, b}`                      |
| `rotation`    | number        | Rotation in radians                          |

### Methods

| Method                   | Description                           |
|--------------------------|---------------------------------------|
| `Atlas(...)`             | `SetAtlas`                            |
| `Texture(path)`          | `SetTexture`                          |
| `Color(r,g,b,a)`         | `SetColorTexture` — accepts table     |
| `SetVertexColor(r,g,b,a)`| Vertex tint — accepts table           |
| `Coords(l,r,t,b)`        | `SetTexCoord`                         |
| `Gradient(orient,min,max)`| `SetGradient` — re-apply a vertex gradient (ColorMixin min/max, alpha interpolated) over the base texture |

---

## Label

Inherits `Region`. Wraps a `FontString`.

### Constructor options

| Option      | Type   | Description                                           |
|-------------|--------|-------------------------------------------------------|
| `parent`    |        | Required                                              |
| `layer`     | string | Draw layer (default `ARTWORK`)                        |
| `font`      | string | Font template name (default `GameFontHighlight`)      |
| `fontObj`   | object | Font object — overrides `font`                        |
| `fontInfo`  | table  | `{path, size, flags}` passed to `SetFont`             |
| `text`      | string | Initial text                                          |
| `color`     | table  | Text color `{r, g, b, a}`                             |
| `justifyH`  | string | `ui.justify.Left/Center/Right`                        |
| `justifyV`  | string | `ui.justify.Top/Middle/Bottom`                        |

### Methods

| Method         | Description                             |
|----------------|-----------------------------------------|
| `Text(text)`   | Get/set text                            |
| `Color(r,g,b,a)` | Set text color — accepts table        |

---

## Frame

Inherits `Region`. The general-purpose container frame.

### Constructor options

Includes all `Region` options, plus:

| Option       | Type    | Description                                               |
|--------------|---------|-----------------------------------------------------------|
| `name`       | string  | Global widget name                                        |
| `parent`     |         | Parent frame                                              |
| `type`       | string  | Blizzard frame type (default `"Frame"`)                   |
| `template`   | string  | Blizzard template string                                  |
| `strata`     | string  | Frame strata                                              |
| `level`      | number  | Frame level                                               |
| `scale`      | number  | Frame scale                                               |
| `clamped`    | bool    | Clamp to screen                                           |
| `special`    | bool    | Register as `UISpecialFrame` (Escape closes it)           |
| `background` | table   | Solid color background `{r, g, b, a}`                     |
| `drag`       | bool    | Make draggable                                            |
| `dragTarget` | frame   | Use another frame as the drag handle                      |
| `scripts`    | table   | List of script events to auto-register                    |
| `events`     | table   | WoW events to register (dispatched to same-named methods) |
| `unitEvents` | table   | `{event = {unit, ...}}` for unit events                   |

### Methods

| Method                        | Description                                             |
|-------------------------------|---------------------------------------------------------|
| `SetScript(event, handler)`   | Set a script handler                                    |
| `RemoveScript(event)`         | Remove a script handler                                 |
| `RegisterScript(...)`         | Auto-forward listed script events to same-named methods |
| `registerEvent(event)`        | Register a WoW event                                    |
| `unregisterEvent(event)`      | Unregister a WoW event                                  |
| `OnEvent(event, ...)`         | Default dispatcher — calls `self[event](self, ...)`     |
| `makeDraggable()`             | Enable mouse drag                                       |
| `makeContainerDraggable()`    | Wire up `OnDragStart`/`OnDragStop`                      |
| `setDragTarget(target)`       | Another widget acts as move handle                      |
| `startUpdates()`              | Start `OnUpdate` loop calling `self:onUpdate(elapsed)`  |
| `stopUpdates()`               | Stop `OnUpdate` loop                                    |
| `delay(ms, fn)`               | Run `fn` (or method name) after `ms` milliseconds       |
| `Attribute(name, value)`      | Get/set frame attribute                                 |
| `EnableMouse(enabled)`        | Toggle mouse interactivity (defaults to true)           |
| `Level(level)`                | Get/set frame level                                     |

### Callbacks

| Callback    | Description                                               |
|-------------|-----------------------------------------------------------|
| `OnLogin`   | Called on `PLAYER_ENTERING_WORLD` when `login or reload`  |
| `onUpdate`  | Called each frame when `startUpdates()` is active; arg is elapsed ms |
| `[event]`   | Any registered WoW event name — called by `OnEvent`       |

---

## BgFrame

Inherits `Frame`. Adds a full-size backdrop `Texture` in the `Overlay` layer.

### Constructor options

| Option     | Type  | Description                                               |
|------------|-------|-----------------------------------------------------------|
| `backdrop` | table | `{color = {r,g,b,a}}` — defaults to `{0, 0, 0, 0.8}`     |

### Methods

| Method                    | Description               |
|---------------------------|---------------------------|
| `backdropColor(r,g,b,a)`  | Change backdrop color     |
| `backdropTexture(texture)` | Change backdrop texture  |

---

## CleanFrame

Inherits `Frame`. A ready-to-use clean frame with a tooltip-style blurred border and dark background. Defaults: `UIParent`, clamped, strata `MEDIUM`, dark blue-grey background.

```lua
local f = LibNUI.CleanFrame:new{
  name = "MyFrame",
}
f:Center()
f:Size(400, 300)
```

---

## TitleFrame

Inherits `CleanFrame`. Adds a title bar with icon, title text, and a close button. Draggable by the title bar.

### Constructor options

| Option  | Type   | Description             |
|---------|--------|-------------------------|
| `title` | string | Title bar text          |

### Methods

| Method                   | Description                                                                                                                                                                                |
|--------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Title(text)`            | Update title text                                                                                                                                                                         |
| `RememberPosition(store)`| Persist the window's dragged position into `store` (typically a saved-variables table). Restores the saved point on the spot and writes it back on every drag-stop, so the window doesn't re-center after a `/reload`. `store` is mutated in place: `{ point, relPoint, x, y }`. |

### Sub-frames

| Field              | Description                |
|--------------------|----------------------------|
| `titlebar`         | The title bar `Frame`       |
| `titlebar.title`   | Title `Label`               |
| `titlebar.icon`    | Icon container `Frame`      |
| `closeButton`      | Close `Button`              |

---

## CopyWindow

Inherits `TitleFrame`. A ready-made window for console-style text the user can copy: a scrolling, pre-highlighted multi-line `EditBox` with a titlebar font-size picker. The window auto-sizes to the widest line and shows a fresh title each time you call `Display`. The picked font size persists account-wide (in LibNUI's own saved variables).

Most callers don't construct one — use the shared singleton:

```lua
LibNUI.ShowCopyWindow("My Report", table.concat(lines, "\n"))
```

`ShowCopyWindow` lazily builds a single `CopyWindow` on first use and reuses it for every later call.

`ToggleCopyWindow(title, text)` is the open/close variant: if the shared window is already open showing that same `title` it closes it, otherwise it shows `text` — so a slash command that re-runs toggles the window (and still switches content when a *different* title is requested).

### Constructor options

`CopyWindow` needs no options — it ships sensible defaults (centered, draggable, Escape-to-close, height 380). Pass `title`/`position` overrides as for any `TitleFrame` if you build your own instance.

### Methods

| Method                 | Description                                                              |
|------------------------|--------------------------------------------------------------------------|
| `Display(title, text)` | Re-title, size to the content, select-all the text, and show the window  |

### Commands

`/wdebug <lua>` — a dev console that evaluates an expression or statement and shows the result (tables are dumped recursively, `print(...)` is captured) in a `CopyWindow`.

---

## TabFrame

Inherits `Frame`. A tabbed container: a tab button bar across the top and one content panel per tab. Anchor your widgets inside `frame:Tab(i)`.

### Constructor options

| Option          | Type     | Description                                          |
|-----------------|----------|------------------------------------------------------|
| `tabs`          | table    | List of tab label strings                            |
| `tabHeight`     | number   | Height of the tab bar (default `24`)                 |
| `tabWidth`      | number   | Width of each tab button (default `80`)              |
| `activeColor`   | table/str| Background color (or theme token) of the active tab  |
| `inactiveColor` | table/str| Background color (or theme token) of inactive tabs   |
| `onSelect`      | func     | `fun(self, index)` called when the selection changes |

### Methods

| Method          | Description                                |
|-----------------|--------------------------------------------|
| `Select(index)` | Switch to a tab                            |
| `Tab(index)`    | Returns the content panel `Frame` for a tab|
| `Selected()`    | Returns the selected tab index             |

### Sub-frames

| Field     | Description                       |
|-----------|-----------------------------------|
| `tabBar`  | The tab button bar `Frame`        |
| `content` | The content area below the bar    |

---

## Tooltip

Inherits `CleanFrame`. A text tooltip rendered as a list of lines. Auto-sizes to content.

### Constructor options

| Option  | Type  | Description                                     |
|---------|-------|-------------------------------------------------|
| `lines` | table | List of line defs: `{text, background, onClick, onEnter, onLeave}` |
| `inset` | number | Inner padding (default `3`)                    |

---

## Button

Inherits `Frame`. Interactive button with optional keybind label, glow border, tooltip, and cooldown.

### Constructor options

Includes all `Frame` options, plus:

| Option          | Type    | Description                                                  |
|-----------------|---------|--------------------------------------------------------------|
| `onClick`       | func    | Click handler                                                |
| `normal`        | table   | `{texture, coords}` for normal state texture                 |
| `glow`          | bool    | Show border glow on hover (default `true`)                   |
| `bindLeftClick` | string  | Keybind string — wires `SetOverrideBindingClick`             |
| `kbLabel`       | bool    | Show keybind label (default `true` when `bindLeftClick` set) |
| `tooltip`       | table   | Tooltip content: `{itemId, spellId, toyId, mountSpellId, owner, point}` |
| `itemID`        | number  | Enables cooldown tracking                                    |

### Methods

| Method     | Description           |
|------------|-----------------------|
| `Text(t)`  | Get/set button text   |

### Callbacks

| Callback     | Description                                               |
|--------------|-----------------------------------------------------------|
| `OnClick`    | Called on mouse up                                        |
| `OnChange`   | Called on drag-receive for matching item/spell/mount type |

---

## MinimapButton

Inherits `Frame` (`type = "Button"`). A draggable button anchored to the minimap edge. The widget owns the positioning, drag, and highlight boilerplate; the consumer supplies the icon, the click behaviour, the tooltip, and a persistence table. (An addon-compartment entry is a separate concern — register it declaratively via the `.toc` `AddonCompartmentFunc` / LibNAddOn `X-NUI-COMPARTMENT`, not through this widget.)

Positioning is **shape-aware** via `GetMinimapShape()` (round, square, and partial minimaps), the saved angle persists across sessions, and the hover highlight uses ADD blend so it brightens — never hides — the icon. Defaults to `parent = Minimap`; **create it at or after `PLAYER_LOGIN`** so any `GetMinimapShape` provider has loaded.

```lua
ui.MinimapButton:new{
  name            = "MyAddonMinimapButton",
  icon            = "Interface\\AddOns\\MyAddon\\icon.png",
  iconFillsButton = true,                 -- icon art carries its own border
  db              = MyAddonDB.minimap,    -- { angle, hide } persisted here
  defaultAngle    = 198,
  tooltip         = { "My Addon", "Left-click to open", "Drag to move" },
  onClick         = function(self, mouseButton) ... end,
}
```

### Constructor options

Includes all `Frame` options, plus:

| Option            | Type            | Description                                                                                  |
|-------------------|-----------------|----------------------------------------------------------------------------------------------|
| `icon`            | string\|number  | Icon texture path or fileID                                                                   |
| `iconFillsButton` | bool            | Icon fills the button (its art carries the border); else a Blizzard ring + background is drawn around an inset icon |
| `db`              | table           | Persistence store; the widget reads/writes `{ angle, hide }`                                  |
| `defaultAngle`    | number          | Ring angle (degrees) used when `db.angle` is unset (default `225`)                            |
| `radius`          | number          | Pixels past the minimap edge (default `8`)                                                    |
| `tooltip`         | string[]\|func  | Tooltip lines (first is the header), or `fun(self): string[]`                                 |
| `onClick`         | func            | `fun(self, mouseButton)` — decides left/right behaviour                                       |

### Methods

| Method        | Description                                            |
|---------------|--------------------------------------------------------|
| `Shown(bool)` | Get/set visibility, persisting into `db.hide`          |
| `Angle(deg)`  | Get/set the ring angle in degrees (normalized 0–360)   |
| `Icon(path)`  | Get/set the icon texture                               |
| `ShowContextMenu(generator)` | Open a `MenuUtil` context menu anchored to the button (call from `onClick` on right-click) |

### Callbacks

| Callback              | Description                                  |
|-----------------------|----------------------------------------------|
| `onClick(mouseButton)` | Supplied via the `onClick` option; fired on click |

---

## CheckButton

Inherits `Button`. Uses `ChatConfigCheckButtonTemplate`. Default size 32×32.

### Constructor options

| Option   | Type   | Description |
|----------|--------|-------------|
| `text`   | string | Label text  |

### Methods

| Method              | Description                         |
|---------------------|-------------------------------------|
| `Checked(bool)`     | Get/set checked state               |

### Callbacks

| Callback           | Description                            |
|--------------------|----------------------------------------|
| `OnToggle(checked)` | Called on click with the *new* state  |

---

## SecureButton

Inherits `Button`. Uses `SecureActionButtonTemplate` for protected actions (spells, toys).

### Constructor options

| Option    | Type  | Description                                                  |
|-----------|-------|--------------------------------------------------------------|
| `actions` | table | List of `{type, target, spell, toy}` action definitions      |

---

## EditBox

Inherits `Frame`. Uses `InputBoxTemplate`. Auto-focus is off by default.

### Constructor options

| Option           | Type   | Description                         |
|------------------|--------|-------------------------------------|
| `text`           | string | Initial text                        |
| `fontObj`        | object | Font object                         |
| `autoFocus`      | bool   | Focus on creation (default `false`) |
| `cursorPosition` | number | Initial cursor position             |
| `scripts`        | table  | Additional scripts                  |

Pre-registered scripts: `OnEditFocusLost`, `OnEnterPressed`, `OnEscapePressed`

### Methods

| Method               | Description                                       |
|----------------------|---------------------------------------------------|
| `Text(text)`         | Get/set text                                      |
| `CursorPosition(pos)`| Get/set cursor position                           |
| `HighlightText(s, e)`| Highlight a range (whole text if no args)         |
| `Font(fontInfo)`     | Get/set the font as a `{path, size[, flags]}` tuple |

---

## ScrollFrame

Inherits `Frame`. Uses `UIPanelScrollFrameTemplate`.

### Methods

| Method                  | Description                                                      |
|-------------------------|------------------------------------------------------------------|
| `Child(child)`          | Get/set scroll child                                             |
| `VerticalScroll(offset)`| Get/set vertical offset (pixels); clamped to range when setting  |

---

## StatusBar

Inherits `Frame`.

### Constructor options

| Option        | Type    | Description                                               |
|---------------|---------|-----------------------------------------------------------|
| `backdrop`    | table   | Mixin with backdrop texture config                        |
| `fill`        | table   | `{color, gradient, blend}` for a fill overlay texture     |
| `color`       | table   | Color fill `{r,g,b,a}`                                    |
| `texture`     | table/str | Bar texture — table for advanced coords-based texture   |
| `orientation` | string  | `"HORIZONTAL"` or `"VERTICAL"`                            |
| `min`/`max`   | number  | Min/max range                                             |

### Methods

| Method           | Description                        |
|------------------|------------------------------------|
| `Color(c)`       | Set color fill                     |
| `Texture(t)`     | Set bar texture                    |
| `SetValue(v)`    | Set current value (handles custom texture coords) |

---

## Slider

Inherits `Frame` (backed by a WoW `Slider`). A themed track with a draggable gold
thumb; drag or click to change the value. `OnChange` fires with the new value and
whether it came from user input. Set `step` to snap to increments.

### Constructor options

| Option        | Type   | Description                                                  |
|---------------|--------|--------------------------------------------------------------|
| `min`         | number | Minimum value (default 0)                                    |
| `max`         | number | Maximum value (default 1)                                    |
| `step`        | number | Value step; also snaps while dragging                        |
| `value`       | number | Initial value                                                |
| `orientation` | string | `"HORIZONTAL"` (default) or `"VERTICAL"`                     |
| `thickness`   | number | Track thickness in px (default 4)                            |
| `OnChange`    | func   | `function(self, value, userInput)` on value change           |

### Methods

| Method            | Description                                            |
|-------------------|--------------------------------------------------------|
| `Value(v)`        | Get (no arg) or set the value; setting fires `OnChange` |
| `MinMax(min,max)` | Set the value range                                     |

---

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
| `Outfit(sources)`     | Remember a transmog outfit (list of sourceIDs; empty = undressed) and re-apply it after every async model (re)load. Use this instead of one-shot `TryOn`/`Undress` when re-skinning, since the load otherwise resets the actor to its baked default. Call before `DisplayInfo`/`Unit` |
| `Aggressiveness(n)`   | Set the bounding-box normalization strength (0 = the model's natural size, **default**; 1 = forced to ~human-male size). A mid value (e.g. 0.5) keeps races consistent while preserving some racial size character. Remembered and re-applied after each async re-skin |
| `Scale(n)`            | Set the user scale multiplier on top of the normalized size (1 = the normalized size). Remembered and re-asserted every frame, so it survives an async re-skin's scale reset regardless of load timing |
| `Spin(v)`             | Get/set the model's rotation speed in radians/sec. A non-zero value spins it with the same inertia as a mouse flick (handy for a showcase spin); `Spin(0)` halts. No-arg reads the live speed |
| `ResetView()`         | Restore the view to its load defaults: the facing yaw (cancelling any spin), the scene's natural zoom, and no pan. Undoes the user's drag-rotate / right-drag pan / wheel-zoom. The user scale multiplier (`Scale`) is a separate control and is left untouched |

---

## Dialog

Inherits `Frame`. Uses Blizzard's `DialogButtonFrame` with title bar. DIALOG strata, Escape closes it.

### Constructor options

| Option       | Type  | Description          |
|--------------|-------|----------------------|
| `title`      | string | Title bar text      |
| `titleColor` | table  | `{r,g,b}` for title |

### Methods

| Method                    | Description               |
|---------------------------|---------------------------|
| `makeTitlebarDraggable()` | Wire title bar drag       |

---

## TableFrame

Inherits `Frame`. Renders a 2D grid with optional column and row headers, alternating backdrop colors, and auto-sizing.

### Constructor options

| Option          | Type    | Description                                                               |
|-----------------|---------|---------------------------------------------------------------------------|
| `colNames`      | table   | List of column header strings                                             |
| `rowNames`      | table   | List of row header strings                                                |
| `colInfo`       | table   | Per-column config: `{name, width, justifyH, atlas, atlasSize, padding, padLeft, color, backdrop, autosize}` |
| `rowInfo`       | table   | Per-row config: `{name, height, justifyH, atlas, atlasSize, color, backdrop}` |
| `numCols`       | number  | Column count (derived from `colNames` if omitted)                         |
| `numRows`       | number  | Row count (derived from `rowNames` if omitted)                            |
| `cellWidth`     | number  | Default cell width (default `100`)                                        |
| `cellHeight`    | number  | Default cell height (default `20`)                                        |
| `headerWidth`   | number  | Row header width (defaults to `cellWidth`)                                |
| `headerHeight`  | number  | Column header height (defaults to `cellHeight`)                           |
| `autosize`      | bool    | Auto-size all columns to content width                                    |
| `padding`       | number  | Padding added during auto-size                                            |
| `backdrop`      | table   | Default backdrop for all cells                                            |
| `colBackdrop`   | table   | Default backdrop for column headers                                       |
| `GetData`       | func    | Called by `onLoad` to fetch data table                                    |
| `data`          | table   | 2D data table `{{cell, ...}, ...}` — can be loaded later via `update()`   |
| `headerFont`    | string  | Font for all headers                                                      |
| `colHeaderFont` | string  | Font override for column headers                                          |
| `rowHeaderFont` | string  | Font override for row headers                                             |

### Methods

| Method              | Description                                            |
|---------------------|--------------------------------------------------------|
| `onLoad()`          | Call after construction to load data and apply autosize |
| `update()`          | Refresh cells from `self.data`                         |
| `row(n)`            | Get row `n`                                            |
| `col(n)`            | Get col `n`                                            |
| `set(row, col, el)` | Assign a `Cell` or widget to a position                |
| `addRow(info)`      | Append a row with info table                           |
| `addCol(info)`      | Append a column with info table                        |

### Dynamic table gotcha

`offsetX` (space reserved for row header labels) and `offsetY` (space reserved for column header labels) are both computed **once at construction time** from whether `rowNames`/`colNames` are non-nil. If you intend to add rows or columns dynamically via `addRow`/`addCol`, pass empty tables for the axes you'll be populating so the offsets are computed correctly:

```lua
local t = TableFrame:new{
  rowNames     = {},   -- non-nil → offsetX = headerWidth (room for row labels)
  colNames     = {},   -- non-nil → offsetY = headerHeight (room for col labels)
  headerWidth  = 70,
  headerHeight = 22,
  cellHeight   = 20,
}
t:addCol{name = "Item",  width = 140}
t:addRow{name = "Weapons"}
```

Omitting either empty table when you plan to use the corresponding `add*` method will cause the row data and headers to overlap.

### Cell data format

Each element in the `data` 2D table can be a string or a table:

```lua
-- plain text
data = {{"value1", "value2"}}

-- table with options
data = {
  {
    {text = "value", color = {1,0,0,1}, justifyH = "LEFT", font = "...",
     onClick = function(cell) end,
     onEnter = function(cell) end,
     onLeave = function(cell) end},
    {atlas = "...", atlasSize = true, path = "...", coords = {...}, vertexColor = {...}},
  }
}
```

---

## AutoWidget

Standalone (does not inherit `Region`). Chooses its widget type from the options:

- `onClick` present → creates a `Button`
- `path` or `atlas` present → creates a `Texture`
- otherwise → creates a `Label`

Used internally by `TableRow` and `TableCol` headers.

---

## FrameColor integration

LibNUI automatically registers modules for supported frames in FrameColor, letting users configure frame colors from FrameColor's settings panel.

---

## Settings

Three settings widgets live under `LibNUI` and are loaded from `settings/`:

- `SettingsFrame` — container for a settings UI
- `TextSetting` — a labeled text input
- `ToggleSetting` — a labeled checkbox toggle

---

## Example: TitleFrame

```lua
local TitleFrame = LibNUI.TitleFrame

local f = TitleFrame:new{
  name  = "MyAddonWindow",
  title = "My Addon",
}
f:Center()
f:Size(500, 400)
```

## Example: TableFrame

```lua
local TableFrame = LibNUI.TableFrame

local t = TableFrame:new{
  parent      = myFrame,
  colInfo     = {
    {name = "Name",   width = 150},
    {name = "Value",  width = 80, justifyH = "RIGHT"},
  },
  cellHeight  = 22,
  headerHeight = 24,
  autosize    = false,
  GetData     = function(self)
    return {
      {"Iron Ore",   "12"},
      {"Gold Ore",   "3"},
    }
  end,
}
t:TopLeft(myFrame, "TOPLEFT", 10, -10)
t:onLoad()
```

## Example: Button with tooltip

```lua
local Button = LibNUI.Button

local btn = Button:new{
  parent  = myFrame,
  normal  = {texture = "Interface/Icons/inv_misc_gem_pearl_06"},
  tooltip = {itemId = 123456},
  onClick = function(self) print("clicked") end,
}
btn:Size(36, 36)
btn:Center()
```

## References

- [UIOBJECT_Font](https://warcraft.wiki.gg/wiki/UIOBJECT_Font) has some good preview images of the various font globals.
