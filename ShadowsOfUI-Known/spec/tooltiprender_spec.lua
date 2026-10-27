local known = require("ShadowsOfUI-Known.spec.known")

-- The shared name-list renderer behind "Learnable by:", "Known by:" and "Guild crafters:" (tooltip.lua):
-- one entry inline; several as a header plus up to 5 names; past 5, the first 4 then "and N more.".
describe("ShadowsOfUI-Known tooltip name lists", function()
  after_each(function() known.restore() end)

  -- A Tailoring alt; `learned` captured recipes make it a "knower" of recipe id 1.
  local function toon(name, learned)
    local t = {
      name = name, classKey = "Mage",
      basic = { level = 80, professions = { primary = { skillID = 197, skillLevel = 100 } } },
    }
    if learned then
      t.professions = { details = { [197] = { recipes = { midnight = { learned = learned, total = #learned } } } } }
    end
    return t
  end
  local KNOWS = { { id = 1, name = "Bolt of Linen" } }

  local function toons(n, learned)
    local out = {}
    for i = 1, n do out[i] = toon(("Alt%d"):format(i), learned) end
    return out
  end

  local function guild(n, online)
    local out = {}
    for i = 1, n do out[i] = { name = ("Guildie%d"):format(i), classKey = "Mage", online = online ~= false } end
    return out
  end

  -- The three surfaces, each driven to produce `n` entries.
  local surfaces = {
    {
      label = "Known by:",
      lines = function(n)
        local d = known.loadTooltips({ toons = toons(n, KNOWS) })
        return d.hoverCraftingOrderRow(1, 77)
      end,
      prefix = "Alt",
    },
    {
      label = "Learnable by:",
      lines = function(n)
        local d = known.loadTooltips({ toons = toons(n) })
        return d.hoverRecipeItem("Pattern: Bolt of Linen")
      end,
      prefix = "Alt",
    },
    {
      label = "Guild crafters:",
      lines = function(n)
        local d = known.loadTooltips({ toons = toons(1, KNOWS), guild = { guild(n), "ready" } })
        local lines = d.hoverCraftingOrderRow(1, 77)
        -- drop the unrelated Known by block above the guild section
        local from
        for i, l in ipairs(lines) do if l:find("Guild crafters:", 1, true) then from = i; break end end
        return { unpack(lines, from) }
      end,
      prefix = "Guildie",
    },
  }

  for _, s in ipairs(surfaces) do
    describe(s.label, function()
      it("one entry is a single inline line", function()
        local lines = s.lines(1)
        assert.equals(1, #lines)
        assert.equals(s.label .. " " .. s.prefix .. "1", lines[1])
      end)

      it("two to five entries are a header plus one indented line each", function()
        for _, n in ipairs({ 2, 5 }) do
          known.restore()
          local lines = s.lines(n)
          assert.equals(s.label, lines[1])
          assert.equals(n + 1, #lines)
          assert.equals("  " .. s.prefix .. n, lines[n + 1])
          assert.is_nil(lines[#lines]:find("more", 1, true))
        end
      end)

      it("six or more are the first four names then 'and N more.'", function()
        local lines = s.lines(7)
        assert.equals(s.label, lines[1])
        assert.equals(6, #lines)                       -- header + 4 names + the tail
        assert.equals("  " .. s.prefix .. "4", lines[5])
        assert.equals("  and 3 more.", lines[6])
      end)

      it("exactly six hides two behind the tail (never a lone 'and 1 more.')", function()
        local lines = s.lines(6)
        assert.equals("  and 2 more.", lines[#lines])
      end)
    end)
  end
end)
