---@type Warbandeer_Collected
local ns = select(2, ...)
local ui, api = ns.ui, ns.api
local Class = ns.lua.Class
local CleanFrame, TableFrame, ScrollFrame = ui.CleanFrame, ui.TableFrame, ui.ScrollFrame

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
    GetData = function()
      local toons = api.GetAllCharacters()
      table.sort(toons, function(c1, c2)
        if c1.basic.level ~= c2.basic.level then return c1.basic.level > c2.basic.level end
        return c1.name < c2.name
      end)
      return ns.lua.lists.map(toons, function(t)
        return {
          t.basic.level,
          { text = t.name, color = WHITE_FONT_COLOR },
        }
      end)
    end,
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

  local toons = api.GetAllCharacters()
  table.sort(toons, function(c1, c2)
    local l1 = c1.instances.locks and c1.instances.locks[group.instance] and c1.instances.locks[group.instance][group.difficulty]
    local l2 = c2.instances.locks and c2.instances.locks[group.instance] and c2.instances.locks[group.instance][group.difficulty]
    if l1 and not l2 then return true
    elseif not l1 and l2 then return false
    elseif c1.basic.level ~= c2.basic.level then return c1.basic.level > c2.basic.level end
    return c1.name < c2.name
  end)
  local rows = {}
  for _, toon in ipairs(toons) do
    local locked = toon.instances.locks and toon.instances.locks[group.instance]
      and toon.instances.locks[group.instance][group.difficulty]
    rows[#rows + 1] = {
      toon.basic.level,
      { text = toon.name, color = locked and DULL_RED_FONT_COLOR or GREEN_FONT_COLOR },
    }
  end
  _view.data.data = rows
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
