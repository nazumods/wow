---@type Warbandeer_Collected
local ns = select(2, ...)
local ui, api = ns.ui, ns.api
local Class = ns.lua.Class
local CleanFrame, TableFrame, ScrollFrame = ui.CleanFrame, ui.TableFrame, ui.ScrollFrame

---Is this character locked to the group's instance at its difficulty? The three-deep walk this
---replaces was written out four times — twice inside one sort comparator (#770 step 17).
---@class Warbandeer_Collected
---@field LockedFor fun(toon: table, group: table): any  truthy when locked; the lock record itself
---@param toon table  a character from api.GetAllCharacters()
---@param group table  a set group, carrying `instance` + `difficulty`
---@return any
ns.LockedFor = function(toon, group)
  local locks = toon.instances.locks
  return locks and locks[group.instance] and locks[group.instance][group.difficulty]
end

---One tooltip line naming every character saved to this group's instance, or nil when there is nothing
---to say — the group isn't an instance, or nobody is locked to it.
---
---This is where the lock column went (#864). It used to be a padlock in a 15px column that only the
---`/collected` window had, drawn only for the logged-in character, and invisible to anyone without an
---active lockout — so it cost a leading gutter on every row to say nothing on almost all of them.
---A tooltip line can name WHO is saved, which the glyph never could, and costs nothing when silent.
---
---**Returns nil rather than "nobody saved"** for the same reason the glyph didn't draw: the useful
---signal is the lockout, and a line on all 34 instance groups saying nothing is wrong would be noise
---on the rows you look at most. Clicking the name still opens the full per-character panel.
---
---Only ~34 of the 473 armour groups carry `instance` at all, so this is nil for the rest without
---touching the roster.
---@param group table  a set group, carrying `instance` + `difficulty` when it is an instance
---@return string?
function ns.SavedCharacters(group)
  if not group.instance then return nil end
  local names = {}
  for _, toon in ipairs(api.GetAllCharacters()) do
    if ns.LockedFor(toon, group) then names[#names + 1] = toon.name end
  end
  if #names == 0 then return nil end
  return ("|cffff7f7fSaved:|r %s"):format(table.concat(names, ", "))
end

---The panel's rows, sorted and coloured. `group` is what the two callers differ by: the constructor
---has no group yet and wants the plain roster, while a show is always for one instance and sorts its
---locked characters to the top, colouring them red against green for the ones still free.
---@param group table?
---@return table[]
local function buildRows(group)
  local toons = api.GetAllCharacters()
  table.sort(toons, function(c1, c2)
    if group then
      local l1, l2 = ns.LockedFor(c1, group), ns.LockedFor(c2, group)
      if l1 and not l2 then return true end
      if not l1 and l2 then return false end
    end
    if c1.basic.level ~= c2.basic.level then return c1.basic.level > c2.basic.level end
    return c1.name < c2.name
  end)
  return ns.lua.lists.map(toons, function(t)
    local color = WHITE_FONT_COLOR
    if group then
      color = ns.LockedFor(t, group) and DIM_RED_FONT_COLOR or GREEN_FONT_COLOR
    end
    return { t.basic.level, { text = t.name, color = color } }
  end)
end

---Singleton side panel listing all characters and their lockout status for a set group's instance.
---@class LockoutView: CleanFrame
---@field data TableFrame level + character-name rows
---@field scroll ScrollFrame scroll container for the table's row area
local LockoutView = Class(CleanFrame, function(self)
  self.data = TableFrame:new{
    parent = self,
    headerHeight = 0,
    position = {
      TopLeft = {2, -2},
      BottomRight = {-2, 2},
    },
    colInfo = {
      { width =  20, backdrop = {color = ns.Colors.TransparentBlack} },
      { width = 150, backdrop = {color = ns.Colors.TransparentBlack} },
    },
    -- Sized from the roster, then thrown away: the first show replaces these rows with the
    -- group-aware ones. It still has to run, since the column widths come from it.
    GetData = function() return buildRows() end,
  }
  self:Width(self.data:Width() + 4)

  self.scroll = ScrollFrame:new{
    parent = self,
    position = {
      TopLeft = {2, -2},
      BottomRight = {-2, 2},
    },
  }
  self.scroll:Child(self.data.rowArea)
end, {
  background = {0, 0, 0, 0.7},
  inset = 3,
})
---@class Warbandeer_Collected
---@field LockoutView LockoutView
ns.LockoutView = LockoutView

local _view = nil
---Show the shared LockoutView for a set group, listing lock status per character.
---@class Warbandeer_Collected
---@field ShowLockoutView fun(grpIdx: integer, parent: Frame, position: table) grpIdx indexes ns.Sets; position is a LibNUI position spec
ns.ShowLockoutView = function(grpIdx, parent, position)
  if not _view then
    _view = LockoutView:new{}
  end
  local group = ns.Sets[grpIdx]
  if not group then
    _view:Hide()
    return
  end

  _view.data.data = buildRows(group)
  _view.data:update()

  _view:Parent(parent)
  _view:Position(position)
  _view:Show()
  _view:Level(parent:Level() + 1)
end

---Hide the shared LockoutView (no-op if never shown).
---@class Warbandeer_Collected
---@field HideLockoutView fun()
ns.HideLockoutView = function()
  if _view then
    _view:Hide()
  end
end
