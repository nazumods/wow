---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Icons = ns.icons
local insert = table.insert

local function formatBestVaultRewardOption(o)
  if not o or o.best == 0 then return nil end
  local t
  if o.bestN > 1 then
    t = o.best.." x"..o.bestN
  else
    t = o.best
  end
  local lines = {}
  for i,n in pairs(o.counts) do
    insert(lines, i.." x"..n)
  end
  return {
    text = t,
    onEnter = function(self)
      self.label:Color(1, 1, 1, 0.8)
      if #lines > 1 then
        ui.tip:AnchorTo(self, "ANCHOR_BOTTOMRIGHT", -10, 10)
        ui.tip:ClearLines()
        for _,l in ipairs(lines) do ui.tip:AddLine(l) end
        ui.tip:Show()
      end
    end,
    onLeave = function(self)
      self.label:Color(1, 1, 1, 1)
      if #lines > 1 then
        ui.tip:Hide()
      end
    end,
  }
end

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "vault", label = "Great Vault",
    name = "Vault",
    width = 50,
    getData = function(t)
      if not t.weeklies then return nil end
      local prefix = t.weeklies.hasUnclaimedVault and ("|A:"..Icons.Vault..":14:14|a ") or ""
      if t.weeklies.vault then
        local r = formatBestVaultRewardOption(t.weeklies.vault)
        if r and prefix ~= "" then r.text = prefix..r.text end
        return r
      end
      if prefix ~= "" then return {text = prefix} end
      return nil
    end,
  }
)
