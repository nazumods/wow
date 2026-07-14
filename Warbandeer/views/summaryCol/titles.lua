---@type Warbandeer
local ns = select(2, ...)
---@type LibNUI
local ui = ns.ui
local Right = ui.justify.Right

-- Titles: how many player titles each character has earned (data from the Warbandeer_Characters
-- `titles` broker; last-seen, logged-in char only). The count is the cell; hovering lists the
-- character's titles, marking the featured (active) one. The footer is the DISTINCT count across
-- the warband (a title held by several alts counts once), so it reads as the account's collection
-- size rather than a meaningless sum.
local GOLD = "|cffffd100" -- featured-title highlight

table.insert(
  ns.SummaryColumns,
  ns.SummaryColumn:new{
    key = "titles", label = "Titles",
    name = "Titles",
    width = 44,
    justifyH = Right,
    tooltip = {
      "Titles",
      "Player titles this character has earned. Hover for the list (the featured title is"
        .. " highlighted). Titles are only readable while a character is logged in, so an alt"
        .. " shows its last-seen set.",
    },
    getData = function(toon)
      local t = toon.titles
      local known = t and t.known
      if not known then return "" end
      return {
        text = #known,
        justifyH = Right,
        fontInfo = ns.theme.fonts.number,
        onEnter = function(self)
          ns.AnchorTip(self)
          ui.tip:ClearLines()
          ui.tip:AddLine(("%s — %d title(s)"):format(toon.name, #known))
          if #known == 0 then ui.tip:AddLine("|cff808080No titles earned|r") end
          for _, e in ipairs(known) do
            if e.id == t.current then
              ui.tip:AddLine(GOLD .. e.name .. "  (featured)|r")
            else
              ui.tip:AddLine(e.name)
            end
          end
          ui.tip:Show()
        end,
        onLeave = function() ui.tip:Hide() end,
      }
    end,
    -- Footer: titles collected across the whole warband, counted once each (union by id).
    getFooter = function(toons)
      local seen, n = {}, 0
      for _, toon in ipairs(toons) do
        local known = toon.titles and toon.titles.known
        if known then
          for _, e in ipairs(known) do
            if not seen[e.id] then seen[e.id] = true; n = n + 1 end
          end
        end
      end
      if n == 0 then return "" end
      return { text = n, justifyH = Right, color = {1, 1, 1, 0.6} }
    end,
  }
)
