---@type Warbandeer_Collected
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Frame, Button, Label = ui.Frame, ui.Button, ui.Label
local FilterDropdown, EditBox = ui.FilterDropdown, ui.EditBox
local C_Timer = C_Timer
local DressingRoom = ns.DressingRoom
local k = DressingRoom._k
local selBox, IDLE, SELECTED = k.selBox, k.IDLE, k.SELECTED
local GRIDW, ROWH, ROW3 = k.GRIDW, k.ROWH, k.ROW3

-- The outfit row (#642): the third bottom control row, wiring the dressing room to the game's own
-- **custom sets** store — save the composed look into it, load one back out. Reopens the
-- DressingRoom class; the store wrappers and validation are outfit.lua, the compose/apply and
-- outfit mode are controls/DressingRoomOutfit.lua.
--
--   [ Outfit ▾ ] [ name ] [ Save ] [ Rename ] [ Delete ]
--
-- Deliberately no `ui.Dialog` name prompt: rename needs a name field regardless, so one inline
-- field serves both and stays visible instead of appearing modally. Nothing else in the suite
-- uses Dialog, so this also avoids being its first caller for one string.
--
-- Both destructive/lossy actions ARM before they fire — the button relabels and a second click
-- inside CONFIRM_S commits. That covers "delete this set" and "save a look with slots this
-- character can't collect" (the game drops those silently) without a modal.

local DROPW, NAMEW, BTNW, GAP = 180, 170, 66, 6
local CONFIRM_S = 4   -- seconds an armed button stays armed before reverting

-- One labelled button in the row: a framed box with a click target and a centered caption, whose
-- text can be swapped when armed. Returns a small handle the actions drive.
---@param room DressingRoom
---@param x number
---@param label string
---@param onClick fun()
---@return table  { box, border, label, text }
local function rowButton(room, x, label, onClick)
  local box = Frame:new{
    parent = room._outfitRow, position = { TopLeft = {x, 0}, Width = BTNW, Height = ROWH },
  }
  local btn = { box = box, border = selBox(box), text = label }
  btn.label = Label:new{ parent = box, justifyH = ui.justify.Center,
    position = { Left = {2, 0}, Right = {-2, 0} }, text = label }
  Button:new{ parent = box, position = { All = true }, glow = false, OnClick = onClick }
  return btn
end

-- Put a button into its armed state (gold border + a warning caption), reverting after CONFIRM_S
-- so an armed Delete can't sit waiting indefinitely. Only one button is ever armed at a time.
---@param room DressingRoom
---@param btn table
---@param caption string
local function arm(room, btn, caption)
  room:_disarmOutfit()
  room._armed = btn
  btn.label:Text(caption)
  btn.border:Color(SELECTED)
  room._armTimer = C_Timer.NewTimer(CONFIRM_S, function()
    room._armTimer = nil
    room:_disarmOutfit()
  end)
end

---Revert whichever button is armed back to its resting caption.
function DressingRoom:_disarmOutfit()
  if self._armTimer then self._armTimer:Cancel(); self._armTimer = nil end
  local btn = self._armed
  if not btn then return end
  self._armed = nil
  btn.label:Text(btn.text)
  btn.border:Color(IDLE)
end

-- Build the outfit row. Called by the constructor after _buildControls, so it sits below the
-- ratings row and above the race panels.
---@param controls Frame  the bottom controls strip built by the constructor
function DressingRoom:_buildOutfits(controls)
  self._outfitRow = Frame:new{
    parent = controls, position = { TopLeft = {0, -ROW3}, Width = GRIDW, Height = ROWH },
  }

  -- Saved-set dropdown. Options keep `GetCustomSets()`'s own order — custom set ids are REUSED
  -- after a delete (a new set came back as id 5 with six sets already saved), so id order says
  -- nothing about creation order and must not be sorted on.
  self._outfitDrop = FilterDropdown:new{
    parent = self._outfitRow, bordered = true, width = DROPW, options = {},
    onSelect = function(_, id) self:LoadOutfit(id) end,
    position = { TopLeft = {0, 0} },
  }

  local nameBox = Frame:new{
    parent = self._outfitRow,
    position = { TopLeft = {DROPW + GAP, 0}, Width = NAMEW, Height = ROWH },
  }
  selBox(nameBox)
  self._outfitName = EditBox:new{
    parent = nameBox, position = { TopLeft = {6, -1}, BottomRight = {-4, 1} },
  }
  self._outfitName._widget:SetScript("OnEscapePressed", function(f) f:ClearFocus() end)
  self._outfitName._widget:SetScript("OnEnterPressed", function(f) f:ClearFocus(); self:SaveOutfit() end)

  local bx = DROPW + GAP + NAMEW + GAP
  self._outfitSave   = rowButton(self, bx,                     "Save",   function() self:SaveOutfit() end)
  self._outfitRename = rowButton(self, bx + BTNW + GAP,        "Rename", function() self:RenameOutfit() end)
  self._outfitDelete = rowButton(self, bx + 2 * (BTNW + GAP),  "Delete", function() self:DeleteOutfit() end)

  -- Reopen on the set last loaded (db.lastOutfit), if it still exists. The name field is seeded
  -- too, but the look is NOT applied — the room opens on whatever set was clicked, and loading is
  -- an explicit act.
  local last = ns.db and ns.db.lastOutfit
  if last then
    for _, s in ipairs(ns.CustomSets()) do
      if s.id == last then self._outfitID = last; self._outfitName:Text(s.name) end
    end
  end
  self:RefreshOutfits()
  -- Another addon (or Blizzard's own UI) can add, rename or delete a set behind our back.
  ns:registerEvent("TRANSMOG_CUSTOM_SETS_CHANGED", function() self:RefreshOutfits() end)
end

---Repopulate the dropdown from the store, keeping the current selection if it still exists.
function DressingRoom:RefreshOutfits()
  if not self._outfitDrop then return end
  local opts, stillThere = {}, false
  for _, s in ipairs(ns.CustomSets()) do
    opts[#opts + 1] = { key = s.id, label = s.name }
    if s.id == self._outfitID then stillThere = true end
  end
  if not stillThere then self._outfitID = nil end
  self._outfitDrop:SetOptions(opts, self._outfitID)
end

---Load a saved custom set into the room, switching it into outfit mode.
---@param customSetID number
function DressingRoom:LoadOutfit(customSetID)
  local list = ns.CustomSetOutfit(customSetID)
  if not list then
    ns.Print("That saved set couldn't be read.")
    return
  end
  local name
  for _, s in ipairs(ns.CustomSets()) do if s.id == customSetID then name = s.name end end
  self._outfitID = customSetID
  self._outfitName:Text(name or "")
  if ns.db then ns.db.lastOutfit = customSetID end
  self:EnterOutfitMode(name or "Outfit", list)
end

-- The name in the field, trimmed. "" when empty.
---@param room DressingRoom
---@return string
local function typedName(room)
  return (room._outfitName:Text() or ""):match("^%s*(.-)%s*$")
end

---Save the composed look: overwrite the selected set when the name still matches it, else create
---a new one. Warns (and arms) when the look carries slots this character can't collect, because
---the game drops those silently on write.
function DressingRoom:SaveOutfit()
  local armed = self._armed == self._outfitSave
  self:_disarmOutfit()

  local list = self:ComposeOutfit()
  local issues = ns.OutfitIssues(list)
  if issues.filled == 0 then
    ns.Print("Nothing to save — the preview is empty.")
    return
  end
  if issues.pending then
    ns.Print("Item data is still loading — try again in a moment.")
    return
  end
  -- `unusable` is armour-type/class/faction validity, NOT ownership: an appearance you simply
  -- haven't collected saves fine. This fires when the look was composed from another class's set.
  if #issues.unusable > 0 and not armed then
    local names = {}
    for i, slotID in ipairs(issues.unusable) do names[i] = ns.SlotLabel(slotID) end
    ns.Print(("%d of %d slots can't be collected by this character and will be dropped: %s")
      :format(#issues.unusable, issues.filled, table.concat(names, ", ")))
    arm(self, self._outfitSave, "Save anyway?")
    return
  end

  local name = typedName(self)
  -- Overwrite only when the field still names the selected set; a changed name means "save a new
  -- one", which is what makes this single button cover both.
  local overwrite
  for _, s in ipairs(ns.CustomSets()) do
    if s.id == self._outfitID and s.name == name then overwrite = s.id end
  end

  local id, err = ns.SaveCustomSet(name, list, overwrite)
  if not id then
    ns.Print("Couldn't save: " .. err)
    return
  end
  self._outfitID = id
  self:RefreshOutfits()
  ns.Print(overwrite and ("Overwrote \"%s\"."):format(name) or ("Saved \"%s\"."):format(name))
end

---Rename the selected set to whatever is in the name field.
function DressingRoom:RenameOutfit()
  self:_disarmOutfit()
  if not self._outfitID then
    ns.Print("Pick a saved set to rename.")
    return
  end
  local ok, err = ns.RenameCustomSet(self._outfitID, typedName(self))
  if not ok then
    ns.Print("Couldn't rename: " .. err)
    return
  end
  self:RefreshOutfits()
  ns.Print(("Renamed to \"%s\"."):format(typedName(self)))
end

---Delete the selected set. Arms first — the second click inside CONFIRM_S commits.
function DressingRoom:DeleteOutfit()
  local armed = self._armed == self._outfitDelete
  self:_disarmOutfit()
  if not self._outfitID then
    ns.Print("Pick a saved set to delete.")
    return
  end
  if not armed then
    arm(self, self._outfitDelete, "Confirm?")
    return
  end
  ns.DeleteCustomSet(self._outfitID)
  self._outfitID = nil
  self._outfitName:Text("")
  self:RefreshOutfits()
  ns.Print("Deleted.")
end
