# LibNUI

A library of OOP UI classes wrapping Blizzard's frames and adding convenience and quality of life features.

## Dependencies

- **LibNAddOn**

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

> **`Position` adds anchors — it does not replace them.** Each key is forwarded straight to
> `SetPoint`, and nothing clears what was there before. Calling `Position` a second time therefore
> *accumulates*: re-anchoring a widget with a **different** point than it already has leaves the old
> anchor in force too, and the widget lands somewhere neither call asked for. Re-anchoring with the
> **same** point replaces that one anchor, which is why this often appears to work until the day you
> switch from `TopLeft` to `Left`.
>
> To move a widget, clear first:
>
> ```lua
> row:ClearAllPoints()
> row:Position{ TopLeft = {list, "TOPLEFT", 0, -y} }
> ```
>
> This only affects **re-**positioning; the constructor's `position` runs once on a fresh widget.
> `FilterDropdown` re-lays its pooled rows this way.

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

**Runtime theme swaps.** `theme:Apply{ colors = {...}, fonts = {...}, textures = {...} }` merges the given tokens into the theme **in place** and repaints registered widgets — so a settings control can switch an accent colour live:

```lua
-- register the parts of a widget that should follow the theme (once, at construction)
myHeader:Themed(function(self) self.title:Color("header") end)

-- later, from a settings control:
myTheme:Apply{ colors = { header = {0.7, 0.5, 1, 1} } }   -- purple accent
```

`Region:Themed(fn)` runs `fn(self, theme)` immediately and again after every `Apply`. Widgets constructed *after* an `Apply` need no registration to get the new values — construction resolves tokens from the same (now-mutated) tables; register only what must restyle while already on screen. Registration is permanent: call it once per widget at construction, never per refresh. Note that widgets without a custom theme register on the shared dark theme, so `ui.themes.dark:Apply` affects every LibNUI-based addon — scope user-facing accent pickers to a custom theme.

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
    │   │   ├── CopyWindow
    │   │   └── Notification
    │   └── Tooltip
    ├── Button
    │   ├── CheckButton
    │   └── SecureButton
    ├── RadioGroup
    ├── SectionHeader
    ├── Timer
    ├── VirtualList
    ├── Accordion
    ├── StatTile
    ├── LabeledValue
    ├── IconListItem
    ├── Badge
    ├── TextLink
    ├── SortableHeaderRow
    ├── BarsPreview
    ├── BorderBox
    ├── MinimapButton
    ├── Cell
    ├── Dialog
    ├── EditBox
    ├── FilterDropdown
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
| `IsMouseOver()`               | Whether the cursor is within the region's hit rect |
| `Themed(fn)`                  | Register `fn(self, theme)` to run now + after every `theme:Apply` (see *Themes*) |

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
| `Rotation(r)`            | Get/set render rotation (radians)     |
| `Gradient(orient,min,max)`| `SetGradient` — re-apply a vertex gradient (ColorMixin min/max, alpha interpolated) over the base texture |
| `DrawLayer(layer, sublevel?)` | Set the draw layer + optional sublevel (higher sublevel draws on top within a layer) |

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
| `wordWrap`  | bool   | Pass `false` to truncate with an ellipsis instead of wrapping |
| `tooltip`   | string/table | Hover tooltip line(s) — an invisible hit-rect overlays the text (FontStrings can't take mouse events) |

### Methods

| Method         | Description                             |
|----------------|-----------------------------------------|
| `Text(text)`   | Get/set text                            |
| `Color(r,g,b,a)` | Set text color — accepts table        |
| `StringWidth()` | Natural (unwrapped) width of the current text |
| `UnboundedWidth()` | Single-line width ignoring wrapping and width constraints |
| `DrawLayer(layer, sublevel?)` | Set the draw layer + optional sublevel |

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
| `EnableKeyboard(enabled)`     | Receive keyboard input (so an `OnKeyDown` handler fires) |
| `SetPropagateKeyboardInput(p)`| Pass handled keys on (`true`) or consume them (`false`) — e.g. trap Esc. No-ops in combat lockdown (the call is taint-restricted since 10.1.5) |
| `Level(level)`                | Get/set frame level                                     |
| `Raise()`                     | Raise the frame above its siblings within its strata    |

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

## BorderBox

Inherits `Frame`. A thin rectangular outline — four edge textures hugging the frame's own rect, with a transparent interior (it draws only the border). Each edge is two-point-anchored to a pair of the frame's corners, so it stretches with the frame and a resize needs no re-layout. Overlay it on content, or anchor it to a sub-region to frame just that part (e.g. a border around an icon + its number inside a composite [`Cell`](#cell-data-format)).

### Constructor options

| Option      | Type              | Description                                      |
|-------------|-------------------|--------------------------------------------------|
| `thickness` | number            | Edge width in px (default `1`)                   |
| `color`     | string \| number[] | Edge colour: theme token or rgba (default `"border"`) |

### Methods

| Method          | Description                          |
|-----------------|--------------------------------------|
| `Color(c)`      | Recolour all four edges (chainable)  |
| `Thickness(t)`  | Set edge thickness in px (chainable) |

```lua
-- a 1px gold outline hugging an icon
local box = LibNUI.BorderBox:new{ parent = cell, color = {1, 0.82, 0, 1} }
box:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
box:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
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
| `SavePosition()`         | Write the window's current point into the store `RememberPosition` was given (a no-op before then). Only needed when something moves the window by a path this class can't see — e.g. another frame's titlebar retargeted at it via `setDragTarget`, which triggers neither hook `RememberPosition` installs. Call it when that drag ends. |

### Sub-frames

| Field              | Description                |
|--------------------|----------------------------|
| `titlebar`         | The title bar `Frame`       |
| `titlebar.title`   | Title `Label`               |
| `titlebar.icon`    | Icon container `Frame`      |
| `closeButton`      | Close `Button`              |

---

## CopyWindow

Inherits `TitleFrame`. A ready-made window for console-style text the user can copy: a scrolling, pre-highlighted multi-line `EditBox` with a titlebar font-size picker. The window auto-sizes to the wider of its widest body line and its title — so a long title always clears the size picker and close button — and shows a fresh title each time you call `Display`. Growth stops at a fixed maximum width, past which the title truncates with an ellipsis rather than overlapping the titlebar controls. The picked font size persists account-wide (in LibNUI's own saved variables).

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

## Notification

Inherits `TitleFrame`. A movable, Escape-closable notification card: an accent title
strip + close X, an optional icon, a wrapped body, an optional "don't show again"
checkbox, and a dismiss button. Call `Notify()` to show it — that resets the checkbox and
arms the optional auto-hide. The close X, the dismiss button, and Escape all take it down
through the same path (firing `onDismiss`).

Because it registers as a UISpecialFrame (so Escape closes it), **pass a unique `name`**
whenever `special` is left at its default `true`.

```lua
local note = LibNUI.Notification:new{
  name          = "MyAddonReminder",
  title         = "Reminder",
  body          = "Don't forget your weekly bounty!",
  icon          = 1064187,
  dontShowAgain = true,
  onDontShowAgain = function(_, checked) MyDB.showReminder = not checked end,
}
note:Notify()
```

### Constructor options

| Option          | Type          | Description                                                     |
|-----------------|---------------|-----------------------------------------------------------------|
| `name`          | string        | **Required** while `special` (registers the UISpecialFrame)     |
| `title`         | string        | Title-bar text (rendered in the accent colour)                  |
| `body`          | string        | Wrapped body text                                               |
| `icon`          | string/number | Icon texture path or fileID, shown left of the body             |
| `dismiss`       | string/bool   | Dismiss button label; `false` to omit (default `"Dismiss"`)     |
| `dontShowAgain` | bool          | Show the "don't show again" checkbox (default `false`)          |
| `dontShowText`  | string        | Checkbox label (default `"Don't show this again"`)              |
| `duration`      | number        | Auto-hide after N seconds (default `nil` = manual dismiss)      |
| `width`/`height`| number        | Intrinsic card size (default 360×170); survives any `position`  |

### Methods

| Method        | Description                                                                    |
|---------------|-------------------------------------------------------------------------------|
| `Notify()`    | Show the card: reset the checkbox, (re)arm the auto-hide, and show             |
| `Body(text)`  | Get/set the body text                                                         |

### Callbacks

| Callback                    | Description                                                    |
|-----------------------------|----------------------------------------------------------------|
| `onDismiss()`               | Fired on dismiss — button, close X, or Escape                  |
| `onDontShowAgain(checked)`  | Fired when the "don't show again" checkbox toggles            |

---

## TabFrame

Inherits `Frame`. A tabbed container: a tab button bar across the top and one content panel per tab. Anchor your widgets inside `frame:Tab(i)`.

### Constructor options

| Option          | Type     | Description                                          |
|-----------------|----------|------------------------------------------------------|
| `tabs`          | table    | List of tab label strings                            |
| `tabHeight`     | number   | Height of the tab bar (default `24`)                 |
| `tabWidth`      | number   | Width of each tab button (default `80`)              |
| `autosize`      | bool     | Size each tab to its label text instead of `tabWidth` (default `false`) |
| `tabPadding`    | number   | Horizontal padding inside an autosized tab (default `24`) |
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

### Methods (singleton `ui.tip`)

| Method                        | Description                                                            |
|-------------------------------|-------------------------------------------------------------------------|
| `ClearLines()` / `AddLine(text, color?)` | Line-by-line fill                                           |
| `Lines(title, ...)`           | One-call fill: clear + accent title + body lines; chainable            |
| `AnchorTo(frame, anchor, dx?, dy?)` | GameTooltip-style anchor constants                               |
| `AnchorBeside(frame, dx?, dy?)` | Side-flip anchor: prefers the frame's right, flips left at the screen edge. Call after content is set |
| `MaxWidth(w)`                 | Cap the width (lines wrap); pass `nil` to clear                        |

---

## FilterDropdown

A compact select control: a labelled button that drops an attached panel of options. The panel hangs flush under the button's left edge, is never narrower than the button (widening to fit a long option), and its option text shares the button label's inset — button and menu read as one control. On open, the current selection renders gold and the chevron flips; picking an option updates the button label and fires `onSelect`.

The menu closes on Esc (consumed, so it stays out of a parent window's Escape handling), on any click outside the control, and when the dropdown itself hides; only one `FilterDropdown` menu is open at a time. A long option list (taller than `maxMenuHeight`) caps its height and scrolls (with the themed scrollbar); shorter menus keep the flat, un-scrolled layout unchanged.

### Constructor options

| Option      | Description                                                                 |
|-------------|-----------------------------------------------------------------------------|
| `options`   | List of `{ key, label, enabled? }` specs (`enabled` defaults true; disabled renders greyed and inert) |
| `selected`  | Key of the initially selected option (sets the button label)                |
| `onSelect`  | `fun(self, key)` fired when the selection changes                           |
| `width`     | Button width (default 96)                                                   |
| `menuWidth` | Minimum menu width (default 0 — the menu is at least as wide as the button and grows to fit its longest option) |
| `maxMenuHeight` | Height (px) beyond which the option panel scrolls instead of growing off-screen (default 400) |
| `bordered`  | Draw a framed background + 1px border, matching toggle buttons (default false)|

### Methods

| Method          | Description                                                  |
|-----------------|--------------------------------------------------------------|
| `Select(key)`   | Re-point at `key` (updates the label) **without** firing `onSelect` |
| `SetOptions(options, selected?)` | Replace the option list and re-lay-out the menu (the panel is built once at construction; its rows are pooled and reused, so a swap leaks no frames). Selects `selected` when it's a valid key of the new list, else the current key if it survives, else the first option; refreshes the label. **Without** firing `onSelect` |
| `labelFor(key)` | The display label for a key (empty string if not found)      |

```lua
ui.FilterDropdown:new{
  parent = titlebar,
  bordered = true, selected = "all",
  options = {
    { key = "all",  label = "Expansion" },
    { key = 11,     label = "The War Within" },
    { key = 12,     label = "Midnight" },
  },
  onSelect = function(_, key) view:SetExpansion(key) end,
}
```

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
| `glowAlpha`     | number  | Glow opacity 0–1 (default `1`). Softens the hover glow without removing it — `glow = false` is the only other lever, and a button with no glow at all reads as disabled |
| `bindLeftClick` | string  | Keybind string — wires `SetOverrideBindingClick`             |
| `kbLabel`       | bool    | Show keybind label (default `true` when `bindLeftClick` set) |
| `tooltip`       | table   | Tooltip content: `{itemId, spellId, toyId, mountSpellId, owner, point}` |
| `itemID`        | number  | Enables cooldown tracking                                    |

### Methods

| Method     | Description           |
|------------|-----------------------|
| `Text(t)`  | Get/set button text   |
| `ConfirmFlash(text?, ms?)` | Flash a confirmation string (default `"Done!"`), restore the original after `ms` (default 1500) |

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

## RadioGroup

Inherits `Frame`. A vertical stack of mutually-exclusive options — the single-select
companion to `CheckButton`. Each option renders as one `CheckButton` row; picking one
checks it and clears the rest (re-clicking the selected row keeps it selected). Mirrors
`FilterDropdown`'s `{ key, label }` + `Select`/`onSelect` contract.

### Constructor options

| Option     | Type   | Description                                                       |
|------------|--------|-------------------------------------------------------------------|
| `options`  | table  | List of `{ key, label }`, laid out top to bottom                  |
| `selected` | any    | Initial selected key                                              |
| `header`   | string | Optional heading label above the rows                            |
| `spacing`  | number | Vertical pitch between rows in px (default `32`, = CheckButton height) |
| `width`    | number | Group width in px (default `180`)                                |

### Methods

| Method        | Description                                                      |
|---------------|------------------------------------------------------------------|
| `Select(key)` | Get the selected key, or set it programmatically (no `onSelect`) |

### Callbacks

| Callback         | Description                                        |
|------------------|----------------------------------------------------|
| `onSelect(key)`  | Fired when the user picks a *different* option     |

---

## Timer

Inherits `Frame` (wraps a `Label`, since FontStrings can't self-tick). A live-updating time
display: counts up from `0:00`, or down from `duration` to `0:00` (firing `onFinish`). Ticks
on the frame's `OnUpdate` and re-renders only when the formatted string changes. Auto-sizes
to its text, so anchor it by an edge; style via `color` or `:Color`.

```lua
local t = LibNUI.Timer:new{ parent = card, color = "header", position = { TopRight = {...} } }
t:Value(25):Start()   -- seed 0:25 (a run in progress) and tick up
```

### Constructor options

| Option      | Type          | Description                                                        |
|-------------|---------------|--------------------------------------------------------------------|
| `format`    | string/fun    | A `ns.lua.strings.duration` style (`"m:ss"` default, `"h:mm:ss"`, `"auto"`) or `fun(seconds) -> string` |
| `countdown` | bool          | Count down from `duration` to 0 instead of up (default `false`)   |
| `duration`  | number        | Countdown start / total seconds (default `0`)                     |
| `autoStart` | bool          | Start ticking on construction (default `false`)                   |
| `overtime`  | bool          | A countdown keeps running past 0 into negative time (`-m:ss`), recoloured red (default `false`) |
| `overtimeColor` | string/table | Colour applied while negative (default red)                    |
| `color`     | string/table  | Text colour (forwarded to the label)                              |

### Methods

| Method        | Description                                                          |
|---------------|---------------------------------------------------------------------|
| `Start()`     | Start (or resume) ticking                                           |
| `Stop()`      | Pause; the elapsed count is kept                                    |
| `Reset()`     | Zero the count and re-render                                        |
| `Value(sec)`  | Get the displayed seconds, or set them (seed a run already going)   |
| `Color(...)`  | Set the text colour                                                 |

### Callbacks

| Callback       | Description                                    |
|----------------|------------------------------------------------|
| `onFinish()`   | Fired once when a countdown reaches 0          |

---

## SectionHeader

Inherits `Frame`. A titled section separator — an accent-coloured heading with a 1px
divider rule underneath, plus an optional right-aligned muted `summary` slot on the
heading row. The most-repeated construct when laying out stacked panels. It sizes its own
height from the heading; **anchor it with a fixed width** (Left+Right to the parent, or a
`Width`) so the rule and right-aligned summary have an edge to reach.

### Constructor options

| Option         | Type         | Description                                            |
|----------------|--------------|--------------------------------------------------------|
| `text`         | string       | Heading text                                           |
| `summary`      | string       | Optional right-aligned secondary text (muted)          |
| `titleColor`   | string/table | Heading colour token or rgba (default `"header"`)      |
| `dividerColor` | string/table | Rule colour token or rgba (default `"header"` — the accent) |
| `fontInfo`     | table        | `{path, size[, flags]}` heading font override          |
| `underline`    | bool         | Draw the 1px rule (default `true`)                     |
| `gap`          | number       | Px between heading and rule (default `5`)              |

### Methods

| Method         | Description                                                          |
|----------------|---------------------------------------------------------------------|
| `Text(v)`      | Get/set the heading text                                            |
| `Summary(v)`   | Get/set the summary text (no-op if no `summary` was configured)     |

---

## VirtualList

Inherits `Frame`. A pooled, variable-height, mixed-row-type list — the complement to
`TableFrame`'s fixed grid. It owns a scrolling viewport (with the themed auto-hiding
scrollbar) and a pool of row frames per *type*; `SetItems(items)` stacks one row per item
top to bottom, reusing rows across rebuilds and hiding the surplus. Rows anchor left+right
to the content child, so they reflow width on resize.

It is **not windowed** — it builds a frame per item (fine for the dozens-to-hundreds a
panel shows), not only the on-screen ones. Row builders parent their row to
`list:Content()`; `update` populates the reused row for an item and returns its height.

```lua
local list = LibNUI.VirtualList:new{
  parent = panel, position = { All = true },
  createRow = function(l)
    local row = LibNUI.Frame:new{ parent = l:Content() }
    row.label = LibNUI.Label:new{ parent = row, position = { Left = {row, 8, 0} } }
    return row
  end,
  updateRow = function(_, row, item) row.label:Text(item.text); return item.height end,
}
list:SetItems(myItems)
```

For mixed row types, pass a `rowTypes` map and a `typeOf` selector instead of
`createRow`/`updateRow` (this is how `Accordion` interleaves header and child rows).

### Constructor options

| Option      | Type    | Description                                                          |
|-------------|---------|----------------------------------------------------------------------|
| `createRow` | fun     | Single-type: `fun(list) -> row` — build one blank pooled row          |
| `updateRow` | fun     | Single-type: `fun(list, row, item, index) -> height?` — populate      |
| `rowTypes`  | table   | Multi-type: `{ name = { create, update } }` (instead of the above)   |
| `typeOf`    | fun     | Multi-type: `fun(item, index) -> name` (default reads `item.type`)   |
| `items`     | table   | Initial items                                                        |
| `spacing`   | number  | Vertical gap between rows (default `2`)                              |
| `padding`   | number  | Inset around the stacked rows (default `4`)                          |
| `rowHeight` | number  | Fallback row height when an `update` returns nil (default `20`)     |
| `scrollbar` | bool    | Themed scrollbar on the viewport (default `true`)                    |
| `emptyText` | string  | Muted centred placeholder shown when the item list is empty          |

### Methods

| Method               | Description                                                             |
|----------------------|-------------------------------------------------------------------------|
| `SetItems(items)`    | (Re)render: acquire/reuse a row per item, stack, hide surplus, resize   |
| `Content()`          | The content child that row builders parent into                         |
| `Refresh()`          | Re-run the layout with the current items                                |
| `EmptyText(text?)`   | Get/set the empty-state placeholder text, updating the live label — for a list reused across contexts that need a different hint per subject |
| `Row(index)`         | The live pooled row currently showing item `index` (`nil` if out of range) — decorate it for a selectable list |
| `ScrollToItem(index)`| Minimally scroll item `index` into view (only when it's above/below the viewport) |

---

## Accordion

Inherits `Frame`. Collapsible sections built on `VirtualList`: each section is a clickable
header row (accent caret + title) whose child rows appear only while expanded. Toggling a
header rebuilds the underlying list, so headers and child rows share one pooled, scrolling
viewport. You supply the child-row builders (`createRow`/`updateRow`, parenting into
`acc:Content()`); the header rows are built in. Expansion state is keyed by `section.key`,
so it survives `SetSections`.

```lua
local acc = LibNUI.Accordion:new{
  parent = panel, position = { All = true },
  createRow = function(a)
    local row = LibNUI.Frame:new{ parent = a:Content() }
    row.label = LibNUI.Label:new{ parent = row, position = { Left = {row, 24, 0} } }
    return row
  end,
  updateRow = function(_, row, rowData) row.label:Text(rowData); return 20 end,
}
acc:SetSections({
  { key = "a", title = "Section A", expanded = true, rows = {"one", "two"} },
  { key = "b", title = "Section B", rows = {"three", "four"} },
})
```

### Constructor options

| Option         | Type    | Description                                                       |
|----------------|---------|-------------------------------------------------------------------|
| `sections`     | table   | `{ key, title, rows?, expanded? }` list                          |
| `createRow`    | fun     | `fun(acc) -> row` — build one blank pooled child row              |
| `updateRow`    | fun     | `fun(acc, row, rowData, section) -> height?` — populate a child   |
| `headerHeight` | number  | Header row height (default `24`)                                 |
| `rowHeight`    | number  | Fallback child-row height (default `20`)                         |
| `headerColor`  | string  | Caret + title colour token (default `"header"`)                  |
| `spacing`      | number  | Row gap (default `2`)                                            |
| `padding`      | number  | Inset (default `4`)                                             |
| `scrollbar`    | bool    | Themed scrollbar (default `true`)                               |

### Methods

| Method              | Description                                                    |
|---------------------|----------------------------------------------------------------|
| `SetSections(list)` | Replace the sections and re-render (expansion preserved by key) |
| `Toggle(key)`       | Flip a section's expansion, re-render, fire `onToggle`         |
| `Expand(key)` / `Collapse(key)` | Force a section open/closed                        |
| `IsExpanded(key)`   | Whether a section is currently expanded                        |
| `Content()`         | The content child that child-row builders parent into          |

### Callbacks

| Callback                      | Description                                     |
|-------------------------------|--------------------------------------------------|
| `onToggle(key, expanded)`     | Fired when a header toggles                      |

---

## Content primitives: StatTile, LabeledValue, IconListItem, Badge

Four small building blocks for dashboards and summary panels. They pair naturally with
`VirtualList` (build them in `createRow`, re-point with their setters in `updateRow`).

### StatTile

Inherits `Frame`. A bordered "KPI" box: a big centred value on top, a small muted
subtitle at the bottom, and a 1px border whose colour can express state
(locked / unlocked / current). Lay several in a row for vault-slot-style strips.

| Option          | Type          | Description                                            |
|-----------------|---------------|--------------------------------------------------------|
| `value`         | string/number | Big top text                                           |
| `subtitle`      | string        | Small bottom text                                      |
| `valueColor`    | string/table  | Value colour (default `"text"`)                        |
| `subtitleColor` | string/table  | Subtitle colour (default `"muted"`)                    |
| `borderColor`   | string/table  | 1px border colour (default `"divider"`)                |
| `fill`          | string/table  | Inner fill colour (default `"backdrop"`)               |
| `valueFont`     | string        | Font object for the value (default `GameFontHighlightLarge`) |
| `tooltip`       | string/table  | Hover tooltip line(s)                                  |
| `width`/`height`| number        | Intrinsic tile size (default 64×40); survives any `position` |

Methods: `Value(v)`, `Subtitle(v)`, `Colors{value?, subtitle?, border?, fill?}` (one-call
restyle; nil fields unchanged).

### LabeledValue

Inherits `Frame`. One "label: value" stat field — an optional small icon, a muted
caption, and an accent value to its right. Stack several for a summary block.

| Option       | Type          | Description                              |
|--------------|---------------|------------------------------------------|
| `label`      | string        | The field caption                        |
| `value`      | string/number | Initial value text                       |
| `icon`       | string/number | Optional icon left of the caption        |
| `labelColor` | string/table  | Caption colour (default `"muted"`)       |
| `valueColor` | string/table  | Value colour (default `"header"`)        |
| `iconSize`   | number        | Icon size (default `16`)                |
| `gap`        | number        | Px between icon/label/value (default `4`)|
| `height`     | number        | Intrinsic row height (default `16`)      |

Methods: `Value(v)` for live updates.

### IconListItem

Inherits `Frame`. A media list row: an icon (or a `•` bullet when there's no icon), a
title line with an optional muted `kind` suffix, and a wrapped subtitle — the whole row
hoverable for a tooltip (`itemID` shows the real item tooltip; otherwise `tooltip` lines).
Anchor with a width (Left+Right) so the subtitle has room to wrap.

| Option          | Type          | Description                                       |
|-----------------|---------------|---------------------------------------------------|
| `icon`          | string/number | Icon path/fileID; nil renders a bullet            |
| `title`         | string        | First-line text                                   |
| `kind`          | string        | Muted suffix (`"Name  •  Kind"`)                  |
| `subtitle`      | string        | Wrapped second line                               |
| `itemID`        | number        | Hover shows this item's real tooltip              |
| `tooltip`       | string/table  | Hover lines when there's no `itemID`              |
| `tooltipAnchor` | string        | Which way the `tooltip` opens (default `"LL/UR"`) |
| `iconSize`      | number        | Icon size (default `20`)                          |
| `height`        | number        | Intrinsic row height (default `32`)               |

`tooltipAnchor` keys pin the tip's corner onto the row's corner as `"<tipCorner>/<rowCorner>"`,
using the corner shorthand `LL` / `LR` / `UL` / `UR` (Lower|Upper × Left|Right). The tip opens
toward its own opposite corner, so pick by which way it should extend — a right-docked list wants
it to open leftward (`"LR/LL"`) or stay within its own width (`"LR/LR"`) rather than fly off to the
right (`"LL/UR"`, the default): `LL/UR` up-right, `LR/UL` up-left, `UL/LR` down-right, `UR/LL`
down-left, `LR/LL` beside-left, `LL/LR` beside-right, `LR/LR` above right-aligned, `LL/LL` above
left-aligned.

Methods: `Set(data)` — re-point the whole row at new content (the pooled-reuse /
`VirtualList.updateRow` path); absent keys clear that part.

### Badge

Inherits `Frame`. An inline status pill: short coloured text on a subtle fill, auto-sized
to the text — for `[B]`-style markers and status tags beside a name. Anchor its Left next
to the text it decorates.

| Option    | Type         | Description                                  |
|-----------|--------------|----------------------------------------------|
| `text`    | string       | Badge text (keep it short)                   |
| `color`   | string/table | Text colour (default `"header"`)             |
| `fill`    | string/table | Pill fill (default `"backdrop"`)             |
| `tooltip` | string/table | Hover legend line(s)                         |

Methods: `Text(v)` — set and re-fit the pill.

### TextLink

Inherits `Frame` (Button-backed). A text-only hyperlink: an accent-coloured clickable
label that brightens on hover and fires `onClick`. Auto-sizes to its text.

| Option       | Type         | Description                              |
|--------------|--------------|------------------------------------------|
| `text`       | string       | Link text                                |
| `color`      | string/table | Resting colour (default `"header"`)      |
| `hoverColor` | string/table | Hover colour (default `"text"`)          |
| `onClick`    | fun          | Click handler                            |

Methods: `Text(v)` — set and re-fit.

### SortableHeaderRow

Inherits `Frame`. A standalone clickable column-header strip for lists that aren't built
on `TableFrame` — e.g. a header row above a `VirtualList`. (`TableFrame` has its own
opt-in sortable columns; this is its counterpart for grid-less lists, sharing the same
click/flip/arrow contract.) Clicking a column selects it (ascending, or `descFirst`),
clicking again flips the direction; the active column renders in the accent colour with
an arrow. Sort your own data in `onSort` and re-render.

| Option      | Type   | Description                                                        |
|-------------|--------|--------------------------------------------------------------------|
| `columns`   | table  | `{ key, label, width, justifyH?, descFirst? }` list                |
| `sortKey` / `sortDesc` | any/bool | Initial sort state                                     |
| `height`    | number | Strip height (default `20`)                                       |
| `gap`       | number | Px between columns (default `2`)                                  |

Methods: `Sort(key?, desc?)` — get the current `(key, descending)`, or set it
programmatically (no `onSort`). Callback: `onSort(key, descending)` on user clicks.

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
| `placeholder`    | string | Muted prompt shown while the box is empty |
| `placeholderColor` | string / rgba | Its colour (default `"muted"`) |
| `placeholderInset` | table | `{left, right}` px insets (default `{6, -4}`) |

Pre-registered scripts: `OnEditFocusLost`, `OnEnterPressed`, `OnEscapePressed`, `OnTextChanged`

### Methods

| Method               | Description                                       |
|----------------------|---------------------------------------------------|
| `Text(text)`         | Get/set text                                      |
| `CursorPosition(pos)`| Get/set cursor position                           |
| `HighlightText(s, e)`| Highlight a range (whole text if no args)         |
| `Font(fontInfo)`     | Get/set the font as a `{path, size[, flags]}` tuple |
| `Placeholder(text)`  | Get/set the prompt; builds it on first use        |

The placeholder is parented to the EditBox itself rather than any framing box, so it sits on
exactly the edge the typed text will land on, and it shows whenever the box is empty — focused or
not. It stays in step **without taking `OnTextChanged` from you**: an `OnTextChanged` you supply is
wrapped, not replaced. `Text()` syncs it too, so setting text in code hides the prompt just as
typing does.

---

## ScrollFrame

Inherits `Frame`. Uses `UIPanelScrollFrameTemplate`.

By default the frame keeps the stock Blizzard scrollbar. Set `scrollbar = true` for a
themed, **auto-hiding** scrollbar instead: it hides the Blizzard bar and overlays a
`Slider` (theme-aware gold thumb) on the inner right edge, driving the offset from the
thumb and the mousewheel and hiding itself when the content fits. The themed bar overlays
the rightmost `scrollbarWidth` pixels, so inset your scroll child by that much to avoid
overlap. Only the opt-in path touches the frame's wheel/range scripts — default consumers
are unaffected.

### Constructor options

| Option           | Type   | Description                                             |
|------------------|--------|---------------------------------------------------------|
| `scrollbar`      | bool   | Build the themed auto-hiding scrollbar (default `false`) |
| `scrollbarWidth` | number | Themed scrollbar width in px (default `16`)             |
| `wheelStep`      | number | Pixels scrolled per mousewheel notch (default `30`)    |

### Methods

| Method                  | Description                                                      |
|-------------------------|------------------------------------------------------------------|
| `Child(child)`          | Get/set scroll child                                             |
| `VerticalScroll(offset)`| Get/set vertical offset (pixels); clamped to range when setting. Syncs the themed scrollbar thumb when one is built |
| `Refresh()`             | Recompute the scroll range (via `UpdateScrollChildRect`) after the child's content extent changed, then re-clamp the offset so it can't stay scrolled into empty space, and re-fit the themed scrollbar. The range tracks the child's **content extent** (its shown sub-frames), not its set height — a caller that shrinks the child must also hide the frames below (see `TableFrame:ResizeRows`) or the range stays full |
| `Scrolls()`             | Whether the content currently overflows the viewport (the view can scroll / the themed scrollbar is showing). The single truth behind both scroll affordances — the same range `_syncScrollbar` reads — so a consumer reserving a scrollbar gutter can gate it on this and stay in lockstep with the bar's own show/hide |
| `EnsureVisible(top, height)` | Scroll the **minimum** distance that brings a band of content into view — a band already visible doesn't move the view at all. `top` is measured from the top of the scroll **child**, which is the space a list already has for its rows (element *i* starts at `(i - 1) * rowHeight`). Minimum-distance rather than centring, so arrowing through a list nudges the view one row instead of jumping the target to mid-viewport each press. Clamping is `VerticalScroll`'s, so a band past the end of the content settles at the bottom |

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
| `label`       | string | Optional muted caption above the track's left end            |
| `valueFormat` | func   | Optional `fun(value) -> string`; enables a live accent readout above the right end |
| `OnChange`    | func   | `function(self, value, userInput)` on value change           |

### Methods

| Method            | Description                                            |
|-------------------|--------------------------------------------------------|
| `Value(v)`        | Get (no arg) or set the value; setting fires `OnChange` |
| `MinMax(min,max)` | Set the value range                                     |

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
| `colInfo`       | table   | Per-column config: `{name, width, justifyH, atlas, atlasSize, padding, padLeft, color, backdrop, autosize, sortable, sortKey, descFirst}` |
| `rowInfo`       | table   | Per-row config: `{name, height, justifyH, atlas, atlasSize, color, backdrop}` |
| `numCols`       | number  | Column count (derived from `colNames` if omitted)                         |
| `numRows`       | number  | Row count (derived from `rowNames` if omitted)                            |
| `cellWidth`     | number  | Default cell width (default `100`)                                        |
| `cellHeight`    | number  | Default cell height (default `20`)                                        |
| `headerWidth`   | number  | Row header width (defaults to `cellWidth`)                                |
| `headerHeight`  | number  | Column header height (defaults to `cellHeight`)                           |
| `autosize`      | bool    | Auto-size all columns to text-content width (icon-only columns keep their set width) |
| `padding`       | number  | Padding added during auto-size                                            |
| `backdrop`      | table   | Default backdrop for all cells                                            |
| `colBackdrop`   | table   | Default backdrop for column headers                                       |
| `GetData`       | func    | Called by `onLoad` to fetch data table                                    |
| `data`          | table   | 2D data table `{{cell, ...}, ...}` — can be loaded later via `update()`   |
| `headerFont`    | string  | Font for all headers                                                      |
| `colHeaderFont` | string  | Font override for column headers                                          |
| `rowHeaderFont` | string  | Font override for row headers                                             |
| `onSort`        | func    | `function(self, key, descending)` fired when a `sortable` header is clicked (see **Sortable columns**) |
| `footerHeight`  | number  | Height of the footer row (defaults to `cellHeight`)                       |
| `footerBackdrop`| table   | Backdrop for the footer row (defaults to the `footer` color token)        |
| `detachedFooter`| bool    | Opt in to content-sized footer cells decoupled from column widths (see **Footer row**) |

### Methods

| Method              | Description                                            |
|---------------------|--------------------------------------------------------|
| `onLoad()`          | Call after construction to load data and apply autosize |
| `update()`          | Refresh cells from `self.data`                         |
| `row(n)`            | Get row `n` — a `TableRow`; `row:Highlighted(b)` marks it as the active row (translucent accent overlay; striping untouched) |
| `col(n)`            | Get col `n`                                            |
| `set(row, col, el)` | Assign a `Cell` or widget to a position                |
| `addRow(info)`      | Append a row with info table                           |
| `addCol(info)`      | Append a column with info table                        |
| `setFooter(data)`   | Build (or refresh) a totals footer pinned below the rows; `data` is a per-column-index map of cell data (columns absent render no footer cell) — see **Footer row** |
| `Sort(key?, desc?)` | Read the active sort as `(key, descending)`, or set it programmatically (restyles headers, does **not** fire `onSort`) |

### Sortable columns

Opt in per column via `colInfo`, mirroring `SortableHeaderRow`'s contract so the two feel like one system:

- `sortable = true` — makes the column's header clickable and reserves room for an up/down arrow.
- `sortKey` — stable identity passed to `onSort` (defaults to the column index).
- `descFirst = true` — first click sorts descending (numeric "biggest first" columns).

The active column renders in the accent colour with an arrow; other sortable headers rest muted. Clicking the active column flips direction; a new column starts at its natural direction. `TableFrame` owns the header UI + sort state; **the consumer owns the comparator and repaint** — it sorts its own data in `onSort` and calls `update()`. `TableFrame` never permutes `self.data` itself, so a consumer holding index-parallel state (row → object maps, per-row closures) stays aligned by re-sorting *before* rebuilding those rows.

```lua
local t = TableFrame:new{
  colInfo = {
    { name = "NAME", width = 90, sortable = true, sortKey = "name" },
    { name = "SKILL", width = 44, sortable = true, sortKey = "skill", descFirst = true },
  },
  onSort = function(self, key, desc)
    sortMyEntries(entries, key, desc)   -- consumer owns the comparator (missing = -inf, stable tiebreak)
    self.data = rebuildRows(entries)
    self:update()
  end,
}
```

### Footer row

`setFooter(data)` builds (or refreshes) a totals row pinned below the data rows, with its own backdrop (`footerBackdrop`) and a divider above it. `data` is keyed by **column index** — a column absent from the map renders no footer cell — and the call is re-runnable to refresh (reused cells are updated in place), so it can be paired with `update()`.

```lua
t:setFooter{
  [1] = {text = "5 max, 2 lvl", justifyH = "LEFT"},
  [4] = {text = "1,234,567g 45s 12c", justifyH = "RIGHT", color = {1, 0.82, 0, 1}},
}
```

By default each footer cell **spans its column** (anchored left→right, like a data cell), so its width is clamped to the column. That couples the two: a column can't shrink below its footer's aggregate total (typically far wider than any single cell). Opt into **`detachedFooter = true`** to break the coupling — each footer cell is instead sized to its own content and anchored to its column by the single edge matching its `justifyH` (right/left/center). The total then renders in full, overflowing into the empty footer space beside it, while the column is free to `autosize` down to its per-row values. For fixed-width columns the two modes render identically; the difference only shows once a column shrinks below its total.

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

#### Composite cells

A cell whose data has a `parts` array renders **multiple positioned elements** (icons + labels) instead of a single texture or label, with an optional 1–2px **border box** ([`BorderBox`](#borderbox)) around a sub-region — e.g. a crest icon and its number framed together:

```lua
{
  parts = {
    -- each part is a texture (path/atlas) or label (text) spec plus a `position` table
    { path = "...crest", position = { Left = {"cell", "LEFT", 4, 0}, Size = {14, 14} } },  -- part 1
    { text = "1,240", color = "muted", position = { Left = {1, "RIGHT", 3, 0} } },          -- part 2
  },
  border = {                                                   -- optional
    color = {1, 0.82, 0, 1}, thickness = 1,
    position = { TopLeft = {1, "TOPLEFT", -2, 2}, BottomRight = {2, "BOTTOMRIGHT", 2, -2} },
  },
  onEnter = function(cell) end, onLeave = function(cell) end,   -- handlers work as usual
}
```

- **Symbolic anchor targets** — in a part's or the border's `position`, an anchor arg's target may be the string `"cell"` (the cell itself) or an integer `N` (part `N`'s widget). A part may only anchor to an *earlier* part. Only anchor keys (`Left`, `TopLeft`, `Center`, …) are resolved; scalar keys like `Size` pass through. `Center = {}` (no target) still anchors to the cell.
- **Recycling** — composite cells survive re-sorts: parts are reused when the kind matches and rebuilt otherwise, and a cell transitions cleanly between composite and plain (single texture/label / empty string) data.
- **Autosize** — a composite cell has no single `.label`, so `TableFrame:Autosize` skips it; give composite columns a fixed `width` (via `colInfo`).

---

## RingSelector

Inherits `Frame`. An OPie-style radial selector: it lays the given `items` out as
glyphs evenly around a center (clockwise from the top) and highlights the slice the
cursor **aims toward** — you point a direction, you don't have to hover the icon.
Inside the center dead-zone nothing is aimed. Pure insecure UI (taint-free); the
caller drives the lifecycle — show it, then call `Commit()` on key-release to fire
`onSelect` (the visual test also commits on click).

### Constructor options

| Option      | Type     | Description                                                       |
|-------------|----------|------------------------------------------------------------------|
| `items`     | table[]  | Slices: `{ name, path \| atlas, rotation?, title? }`             |
| `radius`    | number   | Center-to-glyph distance (default 72)                            |
| `iconSize`  | number   | Glyph size (default 30)                                          |
| `deadZone`  | number   | Center radius in px that selects nothing (default 26)           |
| `restColor` | number[] | Glyph tint at rest (rgba)                                         |
| `hiColor`   | number[] | Glyph tint when aimed at (rgba)                                  |
| `onSelect`  | func     | `function(name)` fired by `Commit()` with the aimed slice        |

### Methods

| Method       | Description                                                       |
|--------------|------------------------------------------------------------------|
| `Selected()` | Name of the slice the cursor aims at, or `nil` in the dead zone  |
| `Commit()`   | Fire `onSelect` for the aimed slice (if any) and return its name |

```lua
local ring = ui.RingSelector:new{
  parent   = parent,
  items    = { { name = "summary", atlas = "...", title = "Summary" }, ... },
  position = { Center = {} },
  onSelect = function(name) ns:view(name) end,
}
-- on the keybind's key-up:  ring:Commit(); ring:Hide()
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
