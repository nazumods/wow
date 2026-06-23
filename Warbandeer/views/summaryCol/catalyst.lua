---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui

-- Catalyst column. Shows two things per max-level character: a left-pinned ✓/✗ for
-- "Midnight Season 1: Catalyst Unbound" (achievement 61519 — class set bonuses
-- unlocked, captured per-character via quests.CatalystUnbound) and the Dawnlight
-- Manaflux charge count pushed to the right. Charges recharge 1 every two weeks up
-- to 8, so a full bank (red) means further recharge is wasted. The ✓/✗ is an inline
-- atlas (so the cell stays a single label). A leading inline element of a FIXED
-- width (ICON_W) sits on EVERY row — the real ✓/✗ at max level, a same-width
-- transparent spacer for leveling alts — so that, right-justified, every count
-- lines up on the same edge (a leading inline of a different width shifts the
-- right-justified text, so the widths must match). GAP is the icon→count spacing;
-- the `:0:-N` markup offset lowers the icon onto the text baseline.
local ICON_W = 14
local CHECK  = ("|A:%s:%d:%d:0:-3|a"):format(ns.icons.CheckGreen, ICON_W, ICON_W)
local CROSS  = ("|A:%s:%d:%d:0:-3|a"):format(ns.icons.RedX, ICON_W, ICON_W)
local SPACER = ("|T%s:%d:%d|t"):format("Interface\\AddOns\\Warbandeer\\icons\\spacer.tga", ICON_W, ICON_W)
local GAP = " "
table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "catalyst", label = "Catalyst",
    iconPath = "Interface\\AddOns\\Warbandeer\\icons\\catalyst.tga",
    iconColor = ns.theme.colors.muted,
    width = 48,
    justifyH = ui.justify.Center,
    tooltip = {
      "Catalyst",
      "Green check = this character has earned Catalyst Unbound (class set bonuses unlocked). "
        .. "Number = Dawnlight Manaflux charges held (red when full — recharge is being wasted).",
    },
    getData = function(t)
      local c = t.currency and t.currency.Catalyst
      local q = c and c.quantity or 0
      -- the number's colour encodes the charge state regardless of level
      local color = q == 0 and ns.theme.colors.muted
        or (c.capped and ns.CappedColor or ns.UncappedColor)

      -- Catalyst Unbound is an endgame achievement, so only show the ✓/✗ for
      -- max-level characters; leveling alts get the same-width transparent spacer
      -- so their charge count still lines up with the max-level counts.
      if (t.basic.level or 0) < ns.wow.maxLevel then
        return { text = SPACER .. GAP .. q, justifyH = ui.justify.Right, color = color,
                 fontInfo = ns.theme.fonts.number }
      end

      local unbound = t.quests and t.quests.CatalystUnbound or false
      local mark = unbound and CHECK or CROSS
      return {
        -- inline atlas keeps its own green/red; the number takes `color`
        text     = mark .. GAP .. q,
        justifyH = ui.justify.Right,
        color    = color,
        fontInfo = ns.theme.fonts.number,
        onEnter  = function(self)
          ns.AnchorTip(self)
          ui.tip:ClearLines()
          local sc = unbound and ns.theme.colors.green or ns.theme.colors.red
          ui.tip:AddLine(unbound and "Catalyst Unbound — earned"
            or "Catalyst Unbound — not earned", sc[1], sc[2], sc[3])
          ui.tip:AddLine("Manaflux charges: " .. q .. (c and c.capped and " (full)" or ""), 1, 1, 1)
          ui.tip:Show()
        end,
        onLeave  = function() ui.tip:Hide() end,
      }
    end,
  }
)
