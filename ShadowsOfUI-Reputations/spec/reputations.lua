-- Loads ShadowsOfUI-Reputations/panel.lua against a fake client so the row-tooltip hooks
-- can be driven out of game. Path is relative to the AddOns root.
--
-- The fake ReputationEntryMixin has OnEnter / OnLeave stubs that do what Blizzard's do for
-- tooltips: on `retail` the row's OnEnter takes GameTooltip ownership first; on `forever`
-- (Camelot) it opens none. hooksecurefunc wraps the mixin method like the real one.
local M = {}

---@param opts { forever: boolean?, standings: boolean?, selected: boolean?, blizzardOpens: boolean? }
---@return table w  { ns, row, tooltip, enter, leave, fid, hidden() }
function M.load(opts)
  opts = opts or {}
  local forever = opts.forever and true or false
  local standings = opts.standings ~= false
  -- Does Blizzard's own OnEnter open (and own) the tooltip? Retail's does for a standard row,
  -- Camelot's never does; `blizzardOpens = false` models a Retail row that opens none (Paragon).
  local opens = opts.blizzardOpens
  if opens == nil then opens = not forever end

  local tip = { owner = nil, lines = {}, shown = false, hides = 0 }
  function tip:SetOwner(frame) self.owner, self.lines, self.shown = frame, {}, false end
  function tip:GetOwner() return self.owner end
  function tip:SetText(text) self.lines[#self.lines + 1] = text end
  function tip:Show() self.shown = true end
  function tip:IsShown() return self.shown end
  function tip:Hide() self.shown, self.hides = false, self.hides + 1 end

  local Mixin = {}
  local row = { elementData = { factionID = 2640, name = "Row Name" } }
  function row:IsSelected() return opts.selected and true or false end
  -- Blizzard's OnEnter: Retail opens (and owns) the tooltip for a standard row; Camelot does not.
  function Mixin.OnEnter(self)
    if opens and not self:IsSelected() then
      tip:SetOwner(self)
      tip.lines[1] = "Blizzard tooltip"
      tip:Show()
    end
  end
  function Mixin.OnLeave() end

  local env = {
    GameTooltip = tip,
    ReputationEntryMixin = Mixin,
    HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 },
    C_Reputation = { GetFactionDataByID = function(id) return { name = "Faction " .. id } end },
    hooksecurefunc = function(tbl, name, fn)
      local orig = tbl[name]
      tbl[name] = function(...) orig(...); fn(...) end
    end,
  }
  setmetatable(env, { __index = _G })

  local ns = {
    flavor = { isForever = forever, isRetail = not forever },
    AppendStandings = function(tooltip, factionID)
      if not standings then return false end
      tooltip.lines[#tooltip.lines + 1] = "Standing across your warband: " .. factionID
      return true
    end,
  }
  local chunk = assert(loadfile("ShadowsOfUI-Reputations/panel.lua"))
  setfenv(chunk, env)
  chunk("ShadowsOfUI-Reputations", ns)

  return {
    ns = ns, row = row, tooltip = tip, fid = 2640,
    enter = function() Mixin.OnEnter(row) end,
    leave = function() Mixin.OnLeave(row) end,
  }
end

return M
