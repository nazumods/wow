# LibNUI

OOP UI widget library. Global: `LibNUI` (also `ns.ui` in consuming addons).

## Files

| File | Purpose |
|---|---|
| `LibNUI/globals.lua` | Bootstrap, create `LibNUI` global, `/nui version`, `/nui test` |
| `LibNUI/constants.lua` | `ui.edge`, `ui.layer`, `ui.wrap`, `ui.justify`, `ui.fonts` |
| `LibNUI/Region.lua` | Abstract base — root of widget hierarchy |
| `LibNUI/Texture.lua` | Wraps WoW Texture objects |
| `LibNUI/Label.lua` | Wraps FontString objects |
| `LibNUI/Frame.lua` | Core frame wrapper (events, dragging, animation) |
| `LibNUI/BgFrame.lua` | Frame with auto-created backdrop Texture |
| `LibNUI/Dialog.lua` | WoW Dialog frame (DIALOG strata, title bar, Escape) |
| `LibNUI/StatusBar.lua` | Wraps WoW StatusBar with fill/backdrop |
| `LibNUI/Button.lua` | Interactive button with glow, keybinds, cooldown, tooltip |
| `LibNUI/SecureButton.lua` | SecureActionButtonTemplate (spells/toys in combat) |
| `LibNUI/CheckButton.lua` | Toggle checkbox |
| `LibNUI/AutoWidget.lua` | Factory: auto-selects Label, Texture, or Button |
| `LibNUI/EditBox.lua` | Text input field |
| `LibNUI/ScrollFrame.lua` | Scrollable container |
| `LibNUI/CleanFrame.lua` | Styled frame with dark background and border |
| `LibNUI/Cell.lua` | Table cell, auto-renders as Label or Texture |
| `LibNUI/TableCol.lua` | Column header strip; `header` is a Frame so it can carry mouse scripts (e.g. `tooltip`). The Label/Texture content is parented inside and surfaced as `header.label` / `header.texture` |
| `LibNUI/TableRow.lua` | Row header strip |
| `LibNUI/TableFrame.lua` | Full data grid with headers and cells |
| `LibNUI/TitleFrame.lua` | Windowed frame with title bar, icon, close button |
| `LibNUI/TabFrame.lua` | Tabbed container with button bar |
| `LibNUI/Tooltip.lua` | Custom tooltip with line pooling |
| `LibNUI/settings/SettingsFrame.lua` | WoW Settings panel container |
| `LibNUI/settings/TextSetting.lua` | Label + EditBox setting control |
| `LibNUI/settings/ToggleSetting.lua` | Label + CheckButton setting control |

## Class Hierarchy

```
Region
 +-- Texture
 +-- Label
 +-- Frame
      +-- BgFrame
      |    +-- TableCol
      |    +-- TableRow
      +-- Dialog
      +-- StatusBar
      +-- Button
      |    +-- SecureButton
      |    +-- CheckButton
      +-- EditBox
      +-- ScrollFrame
      +-- CleanFrame
      |    +-- TitleFrame
      |    +-- Tooltip
      +-- TabFrame
      +-- SettingsFrame
      +-- TextSetting
      +-- ToggleSetting
Cell (Frame subclass, standalone)
AutoWidget (standalone, no parent class)
```

## Constants

### `ui.edge`
`Top`, `Center`, `TopLeft`, `TopRight`, `Bottom`, `BottomLeft`, `BottomRight`, `Left`, `Right`

### `ui.layer`
`Background`, `Border`, `Artwork`, `Overlay`, `Highlight`

### `ui.justify`
`Left`, `Center`, `Right`, `Top`, `Middle`, `Bottom`

### `ui.wrap`
`Clamp`, `Repeat`, `Mirror`

### `ui.fonts`
`GameFontHighlight`, `GameFontHighlightSmall`, `SystemFont_Med2`

## Region (Base Class)

### Constructor
Calls `self:CreateWidget()` (subclass provides), then applies `position` and `alpha`.

### Methods
| Method | Description |
|---|---|
| `Parent(parent)` | Set parent (unwraps `_widget`) |
| `Position(position)` | Apply declarative position table |
| `SetPoint(point, target?, edge?, x?, y?)` | Anchor (auto-unwraps target) |
| `All()` | `SetAllPoints()` |
| `ClearAllPoints()` | `ClearAllPoints()` |
| `Center/Top/TopLeft/TopRight/Bottom/BottomLeft/BottomRight/Left/Right(...)` | Shorthand anchors |
| `Size(x?, y?)` | Getter/setter |
| `Width(w?)` / `Height(h?)` | Getter/setter |
| `Show()` / `Hide()` / `SetShown(bool)` / `Toggle()` | Visibility |
| `Alpha(a?)` | Getter/setter |

### Position System
```lua
position = {
    TopLeft  = { parent, "BOTTOMLEFT", x, y },  -- table → unpack as args
    Width    = 200,                               -- scalar → single arg
    All      = true,                              -- true → no args
    Hide     = false,                             -- false → skip
}
```
Any key matching a method name on the instance is valid.

## Texture

**Parent:** Region | **Registered:** `ui.Texture`

### Constructor Options
`parent`, `name`, `layer`, `template`, `atlas`, `atlasSize`, `rotation`, `color`, `vertexColor`, `blendMode`, `gradient`, `path`, `coords`

### Methods
`Atlas(...)`, `Texture(texture)`, `Color(r,g,b,a | table | ColorMixin)`, `SetVertexColor(...)`, `Coords(...)`

## Label

**Parent:** Region | **Registered:** `ui.Label`

### Constructor Options
`parent`, `name`, `layer` (default `Artwork`), `font` (default `GameFontHighlight`), `fontObj`, `fontInfo`, `text`, `color`, `justifyH`, `justifyV`

### Methods
`Text(text?)` — getter/setter, returns self when setting
`Color(r,g,b,a | table | ColorMixin)` — returns self

## Frame

**Parent:** Region | **Registered:** `ui.Frame`

### Constructor Options
`type` (default `"Frame"`), `name`, `parent`, `template`, `strata`, `clamped`, `scale`, `level`, `special`, `background`, `drag`, `dragTarget`, `scripts`, `events`, `unitEvents`

### Methods
| Category | Methods |
|---|---|
| Events | `OnEvent`, `RegisterScript(...)`, `SetScript(event, handler)`, `RemoveScript(event)`, `listenForEvents()`, `registerEvent(event)`, `unregisterEvent(event)` |
| Dragging | `makeDraggable()`, `makeContainerDraggable()`, `setDragTarget(target)` |
| Animation | `startUpdates()` (calls `onUpdate(elapsed_ms)` each frame, ms not seconds), `stopUpdates()`, `delay(ms, fn)` |
| Properties | `Attribute(name, value?)`, `Level(level?)` |

**`special = true`**: Registers in `_G` and `UISpecialFrames` (Escape closes it).

**`events`**: List of event names. Frame's `OnEvent` dispatches to `self[eventName](self, ...)`.

## BgFrame

**Parent:** Frame | **Registered:** `ui.BgFrame`

Default backdrop: `{color = {0,0,0,0.8}}`. Creates Texture in OVERLAY layer.

Methods: `backdropColor(...)`, `backdropTexture(...)`

## StatusBar

**Parent:** Frame | **Registered:** `ui.StatusBar` | **Type:** `"StatusBar"`

### Constructor Options
`backdrop`, `fill` (`{color, gradient, blend}`), `color`, `texture` (string or table with `coords`), `orientation`, `min`, `max`

### Methods
`Color(c)`, `Texture(t)`, `SetValue(v)` — custom TexCoord clipping if table-based texture

## Button

**Parent:** Frame | **Registered:** `ui.Button` | **Type:** `"Button"`

### Constructor Options
`normal` (`{texture, coords}`), `onClick`, `bindLeftClick`, `kbLabel`, `glow` (default true), `itemID`, `tooltip`, `OnChange`, `OnClick`

Default scripts: `OnEnter`, `OnLeave`, `OnMouseDown`, `OnMouseUp`, `OnReceiveDrag`

### Tooltip Config
```lua
tooltip = { _widget, owner, point, itemId, toyId, spellId, mountSpellId }
```

## SecureButton

**Parent:** Button | **Registered:** `ui.SecureButton` | **Template:** `"SecureActionButtonTemplate"`

Options: `actions` — list of `{type, target, spell, toy}`

**Warning:** Never `SetAttribute` during combat.

## CheckButton

**Parent:** Button | **Registered:** `ui.CheckButton` | **Type:** `"CheckButton"` | **Template:** `"ChatConfigCheckButtonTemplate"`

Options: `text`, `OnToggle`
Methods: `OnClick()`, `Checked(isChecked?)`

## AutoWidget

**Registered:** `ui.AutoWidget` | Standalone factory.

| Condition | Creates |
|---|---|
| `onClick` set | Button |
| `path` or `atlas` set | Texture |
| Otherwise | Label |

Options: `parent`, `onClick`, `path`, `atlas`, `atlasSize`, `coords`, `vertexColor`, `position`, `label`, `font`, `color`, `justifyH`

## EditBox

**Parent:** Frame | **Registered:** `ui.EditBox` | **Type:** `"EditBox"` | **Template:** `"InputBoxTemplate"`

Options: `fontObj`, `autoFocus`, `text`, `cursorPosition`
Methods: `Text(text?)`

## ScrollFrame

**Parent:** Frame | **Registered:** `ui.ScrollFrame` | **Type:** `"ScrollFrame"` | **Template:** `"UIPanelScrollFrameTemplate"`

Methods: `Child(child?)`

## CleanFrame

**Parent:** Frame | **Registered:** `ui.CleanFrame`

Defaults: `parent=UIParent`, `clamped=true`, `strata="MEDIUM"`, `background={0.114, 0.141, 0.165, 1}`
Creates border Frame child using `BackdropTemplate` with tooltip border.

## TitleFrame

**Parent:** CleanFrame | **Registered:** `ui.TitleFrame`

Defaults: `drag=true` (inherits CleanFrame defaults)
Options: `title`

### Sub-fields
`self.titlebar` (Frame), `self.titlebar.title` (Label), `self.titlebar.icon` (Frame with `.icon` Texture), `self.closeButton` (Frame with `.icon` Texture)

Methods: `Title(text)`

## TabFrame

**Parent:** Frame | **Registered:** `ui.TabFrame`

### Constructor Options
`tabs` (string[]), `tabHeight` (24), `tabWidth` (80), `activeColor`, `inactiveColor`, `onSelect`

### Sub-fields
`self.tabBar`, `self.content`, `self._tabs` (Frame[]), `self._panels` (Frame[]), `self._selected`

### Methods
`Select(index)`, `Tab(index)` → content panel Frame, `Selected()` → index

## TableFrame

**Parent:** Frame | **Registered:** `ui.TableFrame`

### Constructor Options
`colNames`, `rowNames`, `colInfo`, `rowInfo`, `numCols`, `numRows`, `cellWidth` (100), `cellHeight` (20), `headerWidth`, `headerHeight`, `headerFont`, `colHeaderFont`, `rowHeaderFont`, `padding` (2), `autosize`, `backdrop`, `colBackdrop`, `data`, `GetData`

### Critical: offsetX / offsetY
Computed **once at construction**: `offsetX = rowNames ~= nil ? headerWidth : 0`. For dynamic tables, pass `rowNames = {}` / `colNames = {}`.

### Sub-fields
`self.cols` (TableCol[]), `self.rows` (TableRow[]), `self.cells` (Cell[][]), `self.rowArea` (Frame)

### Methods
`onLoad()`, `row(n)`, `col(n)`, `set(row, col, element)`, `addCol(info)`, `addRow(info)`, `update()`, `setFooter(data)`

### Footer row (`setFooter(data)`)
Lazily builds a footer TableRow pinned below `rowArea`; `data` is per-column cell data (same shape as a row's cell data) keyed by column index — columns absent from `data` render no footer cell. Re-callable to refresh (reuses footer cells like `update()`). Optional construction fields: `footerHeight` (defaults to `cellHeight`), `footerBackdrop`. Footer cells live in `self.footerCells` / row in `self.footerRow`.

### `colInfo` Fields
`name`, `width`, `atlas`, `atlasSize`, `padding`, `padLeft`, `justifyH`, `color`, `backdrop`, `autosize`, `tooltip` (string or string[] — shown on header hover via `ui.tip`)

### `rowInfo` Fields
`name`, `height`, `atlas`, `atlasSize`, `justifyH`, `color`, `backdrop`

## Tooltip

**Parent:** CleanFrame | **Registered:** `ui.Tooltip`

Defaults: `strata="DIALOG"`, `background={0,0,0,0.7}`, `inset=3`

### Methods
`ClearLines()`, `AddLine(text, r?, g?, b?, a?)`, `AnchorTo(frame, anchor, dx?, dy?)`, `ShowForCharacter(toon, position)`, `MaxWidth(w)` (cap content width; pass nil to clear — deviates from getter pattern since nil is a meaningful set value)

### `maxHeight` (scrolling menus)
Optional constructor field. When the stacked constructor `lines` exceed `maxHeight`, they're
clipped into an inner mouse-wheel-scrollable viewport (the CleanFrame border is anchored outside
`self`, so an inner `_port` frame is clipped, not the tooltip). Only the constructor `lines` path
is scroll-aware (not `AddLine`). Used by the Detail view's character picker.

Singleton: `ui.tip`
Helpers: `ui.ShowCharacterTooltip(toon, frame, position)`, `ui.HideCharacterTooltip()`

## Settings Widgets

### SettingsFrame
**Parent:** Frame | Methods: `AddControl(control)`, `RegisterCategory(name?)`, `RegisterSubcategory(parentCategory, name?)`, `AddTextControl(label, table, field)`, `AddToggleControl(label, table, field)`

### TextSetting
**Parent:** Frame | Options: `label`, `table`, `field`, `editor`, `SettingChanged`

### ToggleSetting
**Parent:** Frame | Options: `label`, `table`, `field`, `SettingChanged`
