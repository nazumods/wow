---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, Button, Texture = ui.Frame, ui.Label, ui.Button, ui.Texture

-- Shared control chrome: the framed, labelled button three separate surfaces build, and the framed
-- box it is drawn from. Not a grid concern (that's GridShared.lua) and deliberately NOT part of the
-- `DressingRoom` class — the library window and the transmogrifier row are peers of the room, not
-- children of it, and both were reaching `ns.DressingRoom._k.selBox` for the box alone (#770 step 6).
-- Loads before `controls/` so those files can alias these at file scope.

---@class Warbandeer_Collected
---@field SelBox fun(parent: table): table  the framed box; returns the outer border Texture
---@field RowButton fun(spec: table): table  `{ box, border, label, text, disabled }`
---@field EnableRowButton fun(btn: table, on: boolean)

-- Same values the dressing room's own `selBox` used, so nothing repaints differently. They stay
-- exported from `DressingRoom._k` as well (SELECTED/IDLE are read all over its companion files).
local IDLE  = {0.20, 0.20, 0.24, 1}
local PANEL = {0.05, 0.05, 0.06, 1}

---A framed box: a 1px border with the panel fill inset inside it. Returns the **border** texture,
---which is what callers recolour to signal selection or an armed confirm.
---@param parent table
---@return table border
function ns.SelBox(parent)
  local border = Texture:new{
    parent = parent, layer = ui.layer.Background,
    position = { All = true }, color = IDLE,
  }
  Texture:new{
    parent = parent, layer = ui.layer.Border, color = PANEL,
    position = { TopLeft = {1, -1}, BottomRight = {-1, 1} },
  }
  return border
end

---One framed, labelled button. Three surfaces built this: the dressing room's control rows, the
---outfit library's verb row, and the buttons added to Blizzard's transmogrifier — two of which
---carried comments admitting they were copies of a third they couldn't reach.
---
---Returns the **room's** handle shape, the superset of the three: `box`, `border` (recolour to arm
---or select), `label` (the Label), `text` (the resting caption, so an armed button can restore it)
---and `disabled`.
---
---**`wordWrap = false` on the caption is structural, not cosmetic.** The box is a fixed height, so
---a caption that wraps grows out of it and over whatever is below (an armed "Replace <name>?" did
---exactly that across three lines). What it does instead is ellipsize, which is why an armed caption
---is `Sure?` rather than the verb: `Sure? 4` measures 46.5px in the theme's Geist-13 body font where
---`Confirm 4` measures 60.0 and loses the countdown DIGIT — the visible half of #698 — to the
---ellipsis. Measured, not guessed.
---
---**Disabled swallows the click** rather than firing and printing a refusal afterwards; the caption
---greys to match. Same "don't offer what won't work" as Blizzard's own name prompt.
---@param spec table  `{ parent, x, w, label, onClick, height?, opaque? }`
---@return table btn
function ns.RowButton(spec)
  local box = Frame:new{
    parent = spec.parent,
    -- An explicit opaque fill only where asked for: the transmogrifier's buttons sit on BLIZZARD's
    -- frame, where a bare border and a caption read as text floating over the scene rather than as
    -- buttons. The two on our own opaque windows need nothing behind them.
    background = spec.opaque and {0.11372549019, 0.14117647058, 0.16470588235, 0.95} or nil,
    position = { TopLeft = {spec.x, 0}, Width = spec.w, Height = spec.height or 20 },
  }
  local btn = { box = box, border = ns.SelBox(box), text = spec.label }
  btn.label = Label:new{ parent = box, justifyH = ui.justify.Center, wordWrap = false,
    position = { Left = {2, 0}, Right = {-2, 0} }, text = spec.label }
  -- `glow` left on so these carry LibNUI's hover border, as every button in the addon does: among
  -- controls that all light up on mouseover, one that doesn't reads as disabled.
  Button:new{ parent = box, position = { All = true },
    OnClick = function() if not btn.disabled then spec.onClick() end end }
  return btn
end

---Enable/disable a row button, greying its caption to match.
---
---Callers that own an arm-then-confirm state must disarm BEFORE calling this — the click is
---swallowed once `disabled` is set, so an armed button left greyed goes on asking once a second for
---a confirmation it can no longer accept, then prints a lapse notice for a question that stopped
---being answerable (#716).
---@param btn table
---@param on boolean
function ns.EnableRowButton(btn, on)
  btn.disabled = not on or nil
  btn.label:Color(on and "text" or "muted")   -- theme tokens, as the room's own greying used
end
