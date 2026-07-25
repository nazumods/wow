---@class ShadowsOfUI_ProfCommissions: AddOn
local ns = LibNAddOn(...)

-- "Changelog" button in settings (ns.changelog from changelog.lua).
ns:RegisterChangelog("Shadows of UI")

-- Layout + threshold knobs shared by the feature files. They live on the namespace rather than as
-- per-file locals so /sprofcomm can retune them from here; there is no saved data, so every value is
-- back at its default next session.
---@type table<string, number>
ns.tuning = {
  iconSize = 18,
  iconGap = 3, -- px between adjacent reward icons
  moneyReserve = 80, -- px reserved for the money display, measured from its right edge; the reward
                     -- group's right edge pins here so the icons form a neat column regardless of
                     -- the amount's width
  glowQuality = Enum.ItemQuality.Epic, -- rewards at this quality or better get the gold rare glow
}

-- Blizzard_Professions is load-on-demand; its Templates dependency (which defines the commission
-- mixin) is already loaded by the time this fires. Hooking the shared mixin table before any cell
-- is created means every cell picks up the wrapped Populate. The orders page instance already
-- exists at this point, so hook it directly (hooking the mixin table would miss the live instance).
local hooked = false
EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", function()
  if hooked then return end
  hooked = true
  if ProfessionsCrafterTableCellCommissionMixin then
    hooksecurefunc(ProfessionsCrafterTableCellCommissionMixin, "Populate", ns.PopulateRewardIcons)
  end
  if ProfessionsFrame and ProfessionsFrame.OrdersPage then
    hooksecurefunc(ProfessionsFrame.OrdersPage, "SetupTable", ns.ReplaceReagentsColumn)
  end
end)

-- /sprofcomm             — status (whether the commission hook is installed + current icon size/reserve)
-- /sprofcomm size <n>    — retune the reward icon size live; takes effect on the next list refresh
--                          (re-sort a column or reopen the Crafting Orders window). A tuning aid,
--                          since exact pixel sizing is easier eyeballed in-game than guessed.
-- /sprofcomm reserve <n> — retune the reserved money-zone width (px) the reward column pins to.
-- /sprofcomm glow <n>    — retune the quality a reward must reach to earn the gold glow.
-- /sprofcomm rewards     — dump every reward drawn this session with its resolved quality, so the
--                          glow criteria can be checked against a live order.
SLASH_SUI_PROFCOMM1 = "/sprofcomm"
SlashCmdList["SUI_PROFCOMM"] = function(msg)
  msg = msg or ""
  if msg:match("^%s*rewards%s*$") then
    ns.DumpRewards()
    return
  end
  local g = tonumber(msg:match("^%s*glow%s+(%d+)"))
  if g then
    ns.tuning.glowQuality = g
    ns.Print(("Rare-reward glow threshold set to quality %d (refresh the order list to apply)."):format(g))
    return
  end
  local n = tonumber(msg:match("^%s*size%s+(%d+)"))
  if n then
    ns.tuning.iconSize = n
    ns.Print(("Reward icon size set to %d (refresh the order list to apply)."):format(n))
    return
  end
  local r = tonumber(msg:match("^%s*reserve%s+(%d+)"))
  if r then
    ns.tuning.moneyReserve = r
    ns.Print(("Money-zone reserve set to %d px (refresh the order list to apply)."):format(r))
    return
  end
  ns.Print(("Crafting-order hook %s; reward icon size %d, money reserve %d, glow at quality %d+."):format(
    hooked and "installed" or "not installed (open a profession window first)",
    ns.tuning.iconSize, ns.tuning.moneyReserve, ns.tuning.glowQuality))
end
