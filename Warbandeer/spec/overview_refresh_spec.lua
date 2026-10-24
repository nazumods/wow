local wb = require("Warbandeer.spec.warbandeer")

-- #1059 / #1099: the Overview built its stat cards and reputation bars once, so gold earned or a
-- claimed paragon chest showed only after /reload. The pieces below are what OnBeforeShow now
-- re-runs on every open. Real control/view files are loaded with the UI stubbed (see
-- spec/warbandeer.lua), so these prove the refill logic, not that a frame renders.

-- A label/texture stand-in that records what it was last told.
local function fake()
  local f = { shown = true }
  function f:Text(t) if t == nil then return self.text end self.text = t return self end
  function f:Color(c) self.color = c return self end
  function f:Texture(p) self.path = p end
  function f:SetVertexColor(...) self.tint = { ... } end
  function f:SetShown(s) self.shown = s end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:ClearAllPoints() end
  function f:Left() end
  function f:TopLeft() end
  return f
end

local COLORS = { text = { 1 }, muted = { 2 }, gold = { 3 }, track = { 4 }, green = { 5 } }

describe("Overview live refresh", function()
  after_each(function() wb.restoreGlobals() end)

  describe("LabeledBar:Update", function()
    it("resets text, colours, hover value and fill from the new row", function()
      local ns = wb.loadFlavored("retail", { "controls/LabeledBar.lua" }, { ns = { theme = { colors = COLORS } } })
      local bar = {
        nameLabel = fake(), valueLabel = fake(), width = 100,
        bar = { backdrop = fake(), fill = fake() },
        hoverValue = "old hover", trackColor = { 9 }, barColor = { 9 },
      }
      bar.Fill = function(self, pct) self.filled = pct return self end
      local out = ns.LabeledBar.Update(bar, {
        label = "Faction", value = "claim", pct = 1, valueColor = COLORS.gold, barColor = { 7 },
      })
      assert.equals(bar, out)
      assert.equals("Faction", bar.nameLabel.text)
      assert.equals("claim", bar.valueLabel.text)
      assert.equals("claim", bar.value)            -- the hover-leave swap restores the NEW value
      assert.same(COLORS.gold, bar.valueLabel.color)
      assert.is_nil(bar.hoverValue)                -- a stale hover value must not survive
      assert.same({ 4 }, bar.bar.backdrop.tint)    -- stale paragon track falls back to neutral
      assert.same({ 7 }, bar.bar.fill.tint)
      assert.equals(1, bar.filled)
    end)
  end)

  describe("StatCard:Sub", function()
    local function load()
      local ui = {
        Frame = {}, layer = { Artwork = 1 }, edge = { BottomLeft = "BL", Right = "R" },
        Label = { new = function() return fake() end },
        Texture = { new = function() return fake() end },
      }
      return wb.loadFlavored("retail", { "controls/StatCard.lua" }, { ns = { ui = ui, theme = { colors = COLORS, fonts = {} } } })
    end

    it("creates the sub-line on first use, updates it, then hides it when cleared", function()
      local card = { amountLabel = fake() }
      local StatCard = load().StatCard
      StatCard.Sub(card, "+5g this week", "up.tga", COLORS.green)
      assert.equals("+5g this week", card.subLabel.text)
      assert.is_true(card.subLabel.shown)
      assert.equals("up.tga", card.subIconTex.path)

      local label = card.subLabel
      StatCard.Sub(card, "+9g this week", "up.tga", COLORS.green)
      assert.equals(label, card.subLabel)          -- reused, not recreated
      assert.equals("+9g this week", label.text)

      StatCard.Sub(card, nil)
      assert.is_false(label.shown)
      assert.is_false(card.subIconTex.shown)
    end)

    it("drops the glyph but keeps the text when the icon goes away", function()
      local card = { amountLabel = fake() }
      local StatCard = load().StatCard
      StatCard.Sub(card, "text", "up.tga")
      StatCard.Sub(card, "text")
      assert.is_false(card.subIconTex.shown)
      assert.is_true(card.subLabel.shown)
    end)
  end)

  describe("FactionBars:Refresh", function()
    local state, made, bags

    local function load()
      state = { reward = true, ids = { 1, 2 } }
      made, bags = {}, {}
      local LabeledBar = {
        new = function(_, o)
          local b = { opts = o, shown = true, updates = 0 }
          function b:Update(row) self.updates = self.updates + 1 self.row = row end
          function b:Show() self.shown = true end
          function b:Hide() self.shown = false end
          function b:Height() return 10 end
          b.valueLabel = {}
          made[#made + 1] = b
          return b
        end,
      }
      local ns = wb.loadFlavored("retail", { "views/overview/FactionBars.lua" }, {
        ns = { LabeledBar = LabeledBar, theme = { colors = COLORS }, data = { factionColors = {}, minorFactions = {} } },
        globals = {
          C_MajorFactions = {
            GetMajorFactionIDs = function() return state.ids end,
            GetMajorFactionData = function(id)
              return { name = "Faction" .. id, renownLevel = 10, maxLevel = 10, renownLevelThreshold = 0 }
            end,
            GetRenownLevels = function() end,
          },
          C_Reputation = {
            GetFactionDataByID = function() end,
            IsFactionParagon = function() return true end,
            GetFactionParagonInfo = function(id)
              return 1500, 1000, 0, state.reward and id == 1
            end,
          },
          C_GossipInfo = { GetFriendshipReputation = function() end, GetFriendshipReputationRanks = function() end },
        },
      })
      ns.overview.ParagonBag = function()
        local bag = fake()
        function bag:Right() end
        bags[#bags + 1] = bag
        return bag
      end
      local FactionBars = ns.overview.FactionBars
      local view = { expansionLevel = 10, extraFactionIDs = {}, width = 230, _bars = {}, _bags = {} }
      function view:Width(w) if w then self.w = w end return self.w end
      function view:Height(h) if h then self.h = h end return self.h or 0 end
      return FactionBars, view
    end

    it("clears the reward bag and count when the chest is claimed, without rebuilding bars", function()
      local FactionBars, view = load()
      assert.is_true(FactionBars.Refresh(view))     -- first pass sizes the stack
      assert.equals(2, #made)
      assert.equals(1, view.rewardCount)
      assert.is_true(bags[1].shown)

      state.reward = false                          -- chest claimed in game
      assert.is_false(FactionBars.Refresh(view))    -- same rows: height unchanged
      assert.equals(0, view.rewardCount)
      assert.is_false(bags[1].shown)
      assert.equals(2, #made)                       -- pooled, no new frames
      assert.equals(1, made[1].updates)
      assert.equals("paragon", made[1].row.value)

      state.reward = true                           -- a new chest ready: the bag comes back
      FactionBars.Refresh(view)
      assert.equals(1, view.rewardCount)
      assert.is_true(bags[1].shown)
      assert.equals(1, #bags)                       -- the same bag, re-shown
    end)

    it("hides surplus pooled bars when factions disappear and grows when they return", function()
      local FactionBars, view = load()
      FactionBars.Refresh(view)
      state.ids = { 1 }
      assert.is_true(FactionBars.Refresh(view))     -- one row shorter
      assert.is_false(made[2].shown)
      assert.equals(10, view:Height())
      state.ids = { 1, 2 }
      FactionBars.Refresh(view)
      assert.is_true(made[2].shown)
      assert.equals(2, #made)
    end)
  end)
end)
