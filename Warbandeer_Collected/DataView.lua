local _, ns = ...
local floor, max = math.floor, math.max
local ui, api, Colors = ns.ui, ns.api, ns.Colors
local lists, prepend = ns.lua.lists, ns.lua.lists.prepend
local Class = ns.lua.Class
local TableFrame, Texture = ui.TableFrame, ui.Texture

local GreenCheck = {
  atlas = ns.icons.CheckGreen,
  atlasSize = false,
  position = {
    TopLeft = {3, -2},
    BottomRight = {-3, 2},
  },
}

local _arrow = nil
local _selectedRow = nil

local shades = {
  {165/255,   0/255,  38/255, 1},
  {215/255,  48/255,  39/255, 1},
  {244/255, 109/255,  67/255},
  {253/255, 174/255,  97/255},
  {254/255, 224/255, 139/255},
  {217/255, 239/255, 139/255},
  {166/255, 217/255, 106/255},
  {102/255, 189/255,  99/255},
  { 26/255, 152/255,  80/255},
  {      0, 104/255,  55/255},
}

local DataView = Class(TableFrame, function(self)
  -- autoadjust name width
  local w = 0
  for _,r in ipairs(self.cells) do
    if #r > 2 then
      w = max(w, r[2].label:Width())
    end
  end
  self.cols[2]:Width(w)
  self.rowArea:Width(self.rowArea:Width() + w)
  self:Width(self:Width() + w)
end, {
  headerHeight = 28,
  colInfo = prepend(
    lists.map(ns.icons.classes, function(icon)
      return {
        atlas = icon,
        atlasSize = false,
        width = 28,
        padding = 2,
        justifyH = ui.justify.Center,
        backdrop = {color = ns.Colors.TransparentBlack},
      }
    end),
    { width = 15, backdrop = {color = ns.Colors.TransparentBlack} },
    { width =  0, backdrop = {color = ns.Colors.TransparentBlack} }
  ),
  GetData = function(self)
    local toon = api:GetCharacterData(api:GetCurrentCharacter())
    return lists.map(ns.Sets, function(grp, grpIdx)
      local lock = toon.instances.locks and toon.instances.locks[grp.instance] and toon.instances.locks[grp.instance][grp.difficulty]
      if not ns.db.sets[grp.id] then return {} end
      local r = lists.map(grp.sets, function(set)
        if not ns.db.sets[grp.id][set.id] then return nil end
        if ns.db.sets[grp.id] and ns.db.sets[grp.id][set.id] == true then return GreenCheck end
        return {
            text = ns.db.sets[grp.id][set.id].total - ns.db.sets[grp.id][set.id].collected,
            justifyH = ui.justify.Center,
            color = shades[max(1,floor(ns.db.sets[grp.id][set.id].collected / ns.db.sets[grp.id][set.id].total * 10))],
            onEnter = function(self)
              ui.ShowInfoTip(grp, set, self, {
                BottomRight = {self, ui.edge.Top, -2, 2},
              })
            end,
            onLeave = function(self) ui.HideInfoTip() end,
          }
      end)
      tinsert(r, 1, {
        text = lock and Colors.Strings.Icons.Lock or Colors.Strings.Icons.Empty,
      })
      tinsert(r, 2, {
        text = grp.name,
        onClick = function()
          ns.ShowLockoutView(grpIdx, ns.window, {
            TopRight = {ns.window, ui.edge.TopLeft, -25, 0},
            BottomRight = {ns.window, ui.edge.BottomLeft, -25, 0},
          })
          local row = self.rows[grpIdx]
          if _selectedRow ~= nil then
            self.cells[_selectedRow][2].label:Color(WHITE_FONT_COLOR)
          end
          _selectedRow = grpIdx
          self.cells[grpIdx][2].label:Color(NORMAL_FONT_COLOR:GetRGBA())
          if not _arrow then
            _arrow = Texture:new{
              parent = self,
              path = "interface/common/commonicons",
              coords = {
                0.02654,
                0.10273,
                0.2529296875,
                0.5029296875
              },
            }
          end
          _arrow._widget:SetSize(14, 16)
          _arrow:TopRight(row, ui.edge.TopLeft, -3, -2)
        end,
      })
      return r
    end)
  end,
})
ns.DataView = DataView
