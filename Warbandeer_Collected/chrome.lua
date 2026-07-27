---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Label, Button, Texture = ui.Frame, ui.Label, ui.Button, ui.Texture
local C_Timer = C_Timer

-- Shared control chrome: the framed, labelled button three separate surfaces build, and the framed
-- box it is drawn from. Not a grid concern (that's GridShared.lua) and deliberately NOT part of the
-- `DressingRoom` class — the library window and the transmogrifier row are peers of the room, not
-- children of it, and both were reaching `ns.DressingRoom._k.selBox` for the box alone (#770 step 6).
-- Loads before `controls/` so those files can alias these at file scope.

---@class Warbandeer_Collected
---@field SelBox fun(parent: table): table  the framed box; returns the outer border Texture
---@field RowButton fun(spec: table): table  `{ box, border, label, text, disabled }`
---@field EnableRowButton fun(btn: table, on: boolean)
---@field ArmConfirm fun(owner: table, btn: table, caption: string, lapsed: string, subject: string)
---@field Disarm fun(owner: table)
---@field ArmedSubject fun(owner: table, btn: table): string?
---@field ArmedFor fun(owner: table, btn: table, subject: any): boolean

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
  local press = Button:new{ parent = box, position = { All = true },
    OnClick = function() if not btn.disabled then spec.onClick() end end }
  -- **A disabled button must not LOOK live either.** LibNUI's Button shows its hover glow on
  -- OnEnter and flashes the border green on OnMouseDown; neither knows about our `disabled` flag,
  -- so a greyed button still lit on hover and flashed on click while swallowing it — which reads as
  -- active-but-broken, worse than the refusal message this replaces. `Frame:RegisterScript` bridges
  -- these to same-named methods resolved on the instance **at call time**, so shadowing them here
  -- is enough; the class methods stay untouched for every other Button in the suite.
  local enter, down = press.OnEnter, press.OnMouseDown
  press.OnEnter     = function(s) if not btn.disabled then enter(s) end end
  press.OnMouseDown = function(s) if not btn.disabled then down(s) end end
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
-- ─── Arm-then-confirm ────────────────────────────────────────────────────────
-- One controller for the destructive-confirm gesture both surfaces implemented separately (#770
-- step 7): same 4s budget, same ticker, same `"<caption> <n>"` repaint, same lapse line.
--
-- **State lives on the OWNER, not here.** With the workspace docked (#713) the dressing room and the
-- library window are on screen together and each can hold its own armed button — a module-level
-- `_armed` would let one surface disarm the other's.

local SELECTED   = {0.85, 0.65, 0.13, 1}
local CONFIRM_S  = 4

---Arm `btn` on `owner`: gold border, a caption counting the seconds down, and a revert after
---`CONFIRM_S` that says out loud what was NOT done.
---
---**Both halves of the lapse are load-bearing (#698).** A silent revert made a late second click
---pixel-identical to a first one, so "I clicked Delete twice and it's gone" and "…and nothing
---happened" were indistinguishable at the button. The countdown makes the lapse visible as it
---happens; the chat line is the half that survives walking away, and it **names its subject** (#729)
---because with both surfaces armable at once two anonymous notices would be identical.
---
---The caption stays short — a row button is ~62px and ellipsizes, so the name goes to chat where
---there is width for it.
---@param owner table  the window/room holding the armed state
---@param btn table  a `ns.RowButton` handle
---@param caption string  armed caption; the seconds left are appended
---@param lapsed string  past participle for the lapse notice ("deleted", "replaced")
---@param subject string  what the arm is ABOUT — remembered, not merely printed (see ArmedFor)
function ns.ArmConfirm(owner, btn, caption, lapsed, subject)
  ns.Disarm(owner)
  owner._armed, owner._armedFor = btn, subject
  btn.border:Color(SELECTED)
  local left = CONFIRM_S
  local function paint() btn.label:Text(("%s %d"):format(caption, left)) end
  paint()
  -- A ticker rather than a one-shot: the caption repaints every second and the final tick IS the
  -- revert. Only this path prints — disarming because another button was clicked is a deliberate
  -- abandonment and needs no notice.
  owner._armTimer = C_Timer.NewTicker(1, function()
    left = left - 1
    if left > 0 then return paint() end
    owner._armTimer = nil
    ns.Disarm(owner)
    ns.Print(("Confirmation expired — \"%s\" was not %s."):format(subject, lapsed))
  end, CONFIRM_S)
end

---Revert whatever `owner` has armed, stopping its countdown. Safe when nothing is.
---@param owner table
function ns.Disarm(owner)
  if owner._armTimer then owner._armTimer:Cancel(); owner._armTimer = nil end
  local btn = owner._armed
  owner._armed, owner._armedFor = nil, nil
  if not btn then return end
  btn.label:Text(btn.text)   -- the resting caption, kept on the handle by ns.RowButton
  btn.border:Color(IDLE)
end

---What `btn` is currently armed about on `owner`, or nil if it isn't armed.
---
---Separate from `ArmedFor` for the one caller that can't compare yet: the room's Save re-reads its
---target from the live name field *after* this point, and carries the answer across a retry chain,
---so it captures the subject rather than testing it (#759).
---@param owner table
---@param btn table
---@return string?
function ns.ArmedSubject(owner, btn)
  return owner._armed == btn and owner._armedFor or nil
end

---Is this click the confirming one **for this subject**?
---
---The single rule that makes an arm authorise acting on the thing it was asked about, and nothing
---else (#759). A bare "is it armed" answered a weaker question: with the subject free to change
---between the two clicks — retyping the name field, moving the selection — an arm taken for one look
---silently authorised destroying another. A changed subject simply isn't a confirmation, so the
---click re-arms for the new one instead.
---@param owner table
---@param btn table
---@param subject any  computed the SAME way it was at arm time, or this can never match
---@return boolean
function ns.ArmedFor(owner, btn, subject)
  return owner._armed == btn and owner._armedFor == subject
end

function ns.EnableRowButton(btn, on)
  btn.disabled = not on or nil
  -- **Not the `muted` token**, which the room's own greying used: that is `{0.8, 0.8, 0.8}` — a
  -- secondary-text grey meant for keybind labels, and against the `text` white it is far too close
  -- to read as disabled at all (measured in game: indistinguishable). Blizzard's own disabled-text
  -- colour is what the eye already knows, and it makes a greyed verb obviously inert rather than
  -- merely slightly dimmer.
  btn.label:Color(on and "text" or DISABLED_FONT_COLOR)
end
