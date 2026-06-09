# LibNUI

**Deps:** LibNAddOn · **Commands:** `/nui version`, `/nui test [key]` · **Global:** `LibNUI` (= `ns.ui` in consuming addons)

OOP UI widget library. Every widget wraps a backing WoW object (`self._widget`) and is built via `Widget:new{ ...options }`. Widgets register themselves on `ui` (e.g. `ui.Frame`, `LibNUI.Frame`). Files live at the addon root; `settings/` holds the WoW Settings-panel controls.

## Files

| File | Purpose |
|---|---|
| `globals.lua` | Creates `LibNUI`/`ns.ui`; registers `/nui version` and `/nui test` (loads on-demand `LibNUI_Test`) |
| `constants.lua` | Enum tables: `ui.edge`, `ui.layer`, `ui.justify`, `ui.wrap`, `ui.fonts` |
| `Region.lua` | `Region` — abstract base; anchoring/size/visibility/alpha + declarative `position` system |
| `Texture.lua` | `Texture` — wraps WoW Texture (atlas, color, coords, nine-slice) |
| `Label.lua` | `Label` — wraps FontString; `Text`, `Color`, `JustifyH`, `StringWidth` |
| `Frame.lua` | `Frame` — core frame wrapper: events, dragging, per-frame `onUpdate`, `delay` |
| `BgFrame.lua` | `BgFrame` — Frame with auto-created backdrop Texture; `backdropColor`/`backdropTexture` |
| `Dialog.lua` | `Dialog` — DIALOG-strata frame with Blizzard title bar, Escape-to-close; `makeTitlebarDraggable` |
| `StatusBar.lua` | `StatusBar` — fill bar with backdrop/texture/orientation; `Color`, `Texture`, `SetValue` |
| `Button.lua` | `Button` — interactive button: glow, keybind label, item/spell/toy tooltip, `onClick` |
| `SecureButton.lua` | `SecureButton` — `SecureActionButtonTemplate` for casting spells/toys in combat |
| `CheckButton.lua` | `CheckButton` — toggle checkbox; `Checked`, `OnToggle` |
| `AutoWidget.lua` | `AutoWidget` — standalone factory that builds a Button, Texture, or Label from options |
| `EditBox.lua` | `EditBox` — text input; `Text` |
| `ScrollFrame.lua` | `ScrollFrame` — scrollable container; `Child` |
| `CleanFrame.lua` | `CleanFrame` — styled dark frame with tooltip border (base for windows) |
| `Cell.lua` | `Cell` — table cell (Frame); renders as Label or Texture, reused across re-sorts via `update`. Label cell-data keys: `text`, `color`, `justifyH`, `font` (font-object name), `fontInfo` (`{path,size}` tuple, re-applied on reuse) |
| `TableCol.lua` | `TableCol` — column header (BgFrame); content surfaced as `header.label`/`header.texture` |
| `TableRow.lua` | `TableRow` — row header strip (BgFrame) |
| `TableFrame.lua` | `TableFrame` — full data grid (headers + cells); `set`, `addCol`/`addRow`, `update`, `setFooter` |
| `TitleFrame.lua` | `TitleFrame` — windowed CleanFrame with title bar, icon, close button; `Title` |
| `TabFrame.lua` | `TabFrame` — tabbed container; `Select`, `Tab`, `Selected` |
| `Tooltip.lua` | `Tooltip` — custom tooltip with line pooling + scrolling menus; singleton `ui.tip` |
| `settings/SettingsFrame.lua` | `SettingsFrame` — WoW Settings panel container; `AddControl`, `Register(Sub)category` |
| `settings/TextSetting.lua` | `TextSetting` — label + EditBox bound to `table[field]` |
| `settings/ToggleSetting.lua` | `ToggleSetting` — label + CheckButton bound to `table[field]` |

## Class Hierarchy

```
Region
 ├─ Texture
 ├─ Label
 └─ Frame
     ├─ BgFrame
     │   ├─ TableCol
     │   └─ TableRow
     ├─ Dialog
     ├─ StatusBar
     ├─ Button
     │   ├─ SecureButton
     │   └─ CheckButton
     ├─ EditBox
     ├─ ScrollFrame
     ├─ Cell
     ├─ TabFrame
     ├─ SettingsFrame
     ├─ TextSetting
     ├─ ToggleSetting
     └─ CleanFrame
         ├─ TitleFrame
         └─ Tooltip
AutoWidget — standalone factory (no parent class)
```

## Constants

| Enum | Values |
|---|---|
| `ui.edge` | `Top`, `Center`, `TopLeft`, `TopRight`, `Bottom`, `BottomLeft`, `BottomRight`, `Left`, `Right` |
| `ui.layer` | `Background`, `Border`, `Artwork`, `Overlay`, `Highlight` |
| `ui.justify` | `Left`, `Center`, `Right`, `Top`, `Middle`, `Bottom` |
| `ui.wrap` | `Clamp`, `Repeat`, `Mirror` |
| `ui.fonts` | `GameFontHighlight`, `GameFontHighlightSmall`, `SystemFont_Med2` |

## Region (base class)

Constructor calls subclass `CreateWidget()`, then applies `position` and `alpha`.

| Method | Description |
|---|---|
| `Parent(p)` | Set parent (auto-unwraps `_widget`) |
| `Position(tbl)` | Apply declarative position table |
| `SetPoint(point, target?, edge?, x?, y?)` | Anchor (auto-unwraps target) |
| `All()` / `ClearAllPoints()` | `SetAllPoints` / clear |
| `Center/Top/TopLeft/TopRight/Bottom/BottomLeft/BottomRight/Left/Right(...)` | Shorthand anchors |
| `Size(x?, y?)` · `Width(w?)` · `Height(h?)` | Getter/setter |
| `Show()` · `Hide()` · `SetShown(b)` · `Toggle()` | Visibility |
| `Alpha(a?)` | Getter/setter |

### `position` table

```lua
position = {
    TopLeft = { parent, "BOTTOMLEFT", x, y },  -- table → unpacked as method args
    Width   = 200,                              -- scalar → single arg
    All     = true,                             -- true → no args
    Hide    = false,                            -- false → key skipped
}
```
Any key matching a method on the instance is valid; tables are unpacked, scalars passed directly, `false` skipped.

## Constructor options (per widget)

| Widget | Key options |
|---|---|
| `Texture` | `parent`, `name`, `layer`, `template`, `atlas`, `atlasSize`, `rotation`, `color`, `vertexColor`, `blendMode`, `gradient`, `path`, `coords` |
| `Label` | `parent`, `name`, `layer` (`Artwork`), `font` (`GameFontHighlight`), `fontObj`, `fontInfo`, `text`, `color`, `justifyH`, `justifyV`, `wordWrap` |
| `Frame` | `type` (`"Frame"`), `name`, `parent`, `template`, `strata`, `clamped`, `scale`, `level`, `special`, `background`, `drag`, `dragTarget`, `scripts`, `events`, `unitEvents` |
| `BgFrame` | inherits Frame; default backdrop `{color={0,0,0,0.8}}` |
| `Dialog` | inherits Frame; `title`, `titleColor` |
| `StatusBar` | `backdrop`, `fill` (`{color,gradient,blend}`), `color`, `texture` (string or `{...,coords}`), `orientation`, `min`, `max` |
| `Button` | `normal` (`{texture,coords}`), `onClick`, `bindLeftClick`, `kbLabel`, `glow` (true), `itemID`, `tooltip`, `OnChange`, `OnClick` |
| `SecureButton` | `actions` — list of `{type, target, spell, toy}` |
| `CheckButton` | `text`, `OnToggle` |
| `AutoWidget` | `parent`, `onClick`, `path`, `atlas`, `atlasSize`, `coords`, `vertexColor`, `position`, `label`, `font`, `color`, `justifyH` |
| `EditBox` | `fontObj`, `autoFocus`, `text`, `cursorPosition` |
| `CleanFrame` | `parent` (`UIParent`), `clamped` (true), `strata` (`MEDIUM`), `background` (`{0.114,0.141,0.165,1}`) |
| `TitleFrame` | inherits CleanFrame; `title`, `drag` (true) |
| `TabFrame` | `tabs` (string[]), `tabHeight` (24), `tabWidth` (80), `activeColor`, `inactiveColor`, `onSelect` |
| `Tooltip` | inherits CleanFrame; `lines`, `maxHeight` (clips into scrollable viewport); `strata` (`DIALOG`), `background` (`{0,0,0,0.7}`), `inset` (3) |
| `SettingsFrame` | `heading` (`{text,fontObj,color}`), `headingText` |
| `TextSetting` / `ToggleSetting` | `label`, `table`, `field`, (`editor`), `SettingChanged` |

### `Button` tooltip / `AutoWidget` dispatch

```lua
tooltip = { _widget, owner, point, itemId, toyId, spellId, mountSpellId }
```
`AutoWidget`: `onClick` set → Button; `path`/`atlas` set → Texture; otherwise → Label.

## TableFrame

Constructor options: `colNames`, `rowNames`, `colInfo`, `rowInfo`, `numCols`, `numRows`, `cellWidth` (100), `cellHeight` (20), `headerWidth`, `headerHeight`, `headerFont`, `colHeaderFont`, `rowHeaderFont`, `padding` (2), `autosize`, `backdrop`, `colBackdrop`, `data`, `GetData`, `footerHeight`, `footerBackdrop`.

Sub-fields: `self.cols` (TableCol[]), `self.rows` (TableRow[]), `self.cells` (Cell[][]), `self.rowArea` (Frame), `self.footerRow` / `self.footerCells` (lazy).

Methods: `onLoad()`, `row(n)`, `col(n)`, `set(row, col, element)`, `addCol(info)`, `addRow(info)`, `update()`, `setFooter(data)`.

- `colInfo` fields: `name`, `width`, `atlas`, `atlasSize`, `padding`, `padLeft`, `justifyH`, `color`, `backdrop`, `autosize`, `tooltip` (string or string[], shown on header hover via `ui.tip`).
- `rowInfo` fields: `name`, `height`, `atlas`, `atlasSize`, `justifyH`, `color`, `backdrop`.
- `setFooter(data)`: lazily builds a footer TableRow pinned below `rowArea`; `data` keyed by column index (columns absent render no footer cell). Re-callable to refresh.

## TitleFrame / TabFrame sub-fields

- **TitleFrame**: `self.titlebar` (Frame) → `.title` (Label), `.icon` (Frame with `.icon` Texture); `self.closeButton` (Frame with `.icon` Texture). `Title(text)` setter.
- **TabFrame**: `self.tabBar`, `self.content`, `self._tabs` (button Frame[]), `self._panels` (Frame[]), `self._selected`.

## Tooltip

Methods: `ClearLines()`, `AddLine(text, r?, g?, b?, a?)`, `AnchorTo(frame, anchor, dx?, dy?)`, `ShowForCharacter(toon, position)`, `MaxWidth(w)` (pass `nil` to clear — deviates from the getter pattern since `nil` is a meaningful set value).

Singleton `ui.tip`. Helpers: `ui.ShowCharacterTooltip(toon, frame, position)`, `ui.HideCharacterTooltip()`.

## Gotchas

- **TableFrame `offsetX`/`offsetY` are baked in at construction** from whether `rowNames`/`colNames` are non-nil (`offsetX = rowNames ~= nil and headerWidth or 0`). For dynamic tables built with `addRow`/`addCol`, pass `rowNames = {}` / `colNames = {}` or row data overlaps the headers.
- **`Frame:onUpdate(elapsed)` receives milliseconds**, not seconds (Frame multiplies WoW's seconds by 1000). `Frame:delay(ms, fn)` likewise takes ms.
- **`special = true`** registers the frame in `_G` and `UISpecialFrames` (Escape closes it) — only for top-level windows. `Dialog` does this unconditionally.
- **`SecureButton`**: never call `SetAttribute` during combat (taint).
- **`Cell` is reused across re-sorts** — `Cell:Label()`/`update` re-applies `justifyH` every time, because a cell that previously held left-aligned data must reset when new data is right-aligned. When a `getData` returns a *shared* table, decorate a shallow copy before adding hover/click handlers, or wrappers chain across every row sharing the object.
- **`events` option** is a list of event names; the Frame's `OnEvent` dispatches to `self[eventName](self, ...)`.
- **Addon-local controls register on the addon's `ns`, never on `ui`/`LibNUI`** — only LibNUI's own widgets belong on the shared global; polluting it can clobber LibNUI symbols for every other addon.
