local wb = require("Warbandeer.spec.warbandeer")

-- #958: Warbandeer on Forever. Real view/column/init files are loaded under both client flavors
-- (LibNAddOn's real flavor.lua decides what ns:Supports says) with the UI stubbed -- see
-- spec/warbandeer.lua. The specs prove WHAT REGISTERS and which reads survive absent data, not that
-- a frame renders (that is the in-game run).
describe("Warbandeer on Forever", function()
  after_each(function() wb.restoreGlobals() end)

  -- ------------------------------------------------------------------ D1: class-id gaps
  describe("init.lua class list", function()
    local function load(getClassInfo, flavor)
      local colorCalls = {}
      local ns = wb.loadFlavored(flavor or "forever", { "init.lua" }, {
        globals = {
          GetNumClasses = function() return 4 end,
          GetClassInfo = getClassInfo,
          C_ClassColor = { GetClassColor = function(id)
            assert(id ~= nil, "GetClassColor called with a nil class id")
            colorCalls[#colorCalls + 1] = id
            return { r = 1 }
          end },
        },
      })
      return ns, colorCalls
    end

    it("init: a class-id gap is skipped, not an error", function()
      -- Forever's beta has class ids with gaps: GetClassInfo(2) returns nothing at all
      local ns, colorCalls = load(function(i)
        if i == 2 then return nil end
        return "Class" .. i, "FILE" .. i, i
      end)
      assert.equals(3, #ns.CLASSES)
      assert.same({ "Class1", "Class3", "Class4" }, ns.CLASS_NAMES)
      assert.same({ "FILE1", "FILE3", "FILE4" }, colorCalls)  -- never called with nil
    end)

    it("init: a gap at either end and a fully populated range both stay packed", function()
      local ns = load(function(i)
        if i == 1 or i == 4 then return nil end
        return "Class" .. i, "FILE" .. i, i
      end)
      assert.same({ "Class2", "Class3" }, ns.CLASS_NAMES)
      local full = load(function(i) return "Class" .. i, "FILE" .. i, i end, "retail")
      assert.equals(4, #full.CLASSES)
    end)

    it("the Great Vault is offered as a default view on Retail only", function()
      local retail = load(function(i) return "Class" .. i, "FILE" .. i, i end, "retail")
      assert.equals("vault", retail.viewKeys[#retail.viewKeys])
      assert.equals(8, #retail.viewKeys)
      local forever = load(function(i) return "Class" .. i, "FILE" .. i, i end, "forever")
      assert.equals(7, #forever.viewKeys)
      for _, name in ipairs(forever.viewKeys) do assert.is_not.equals("vault", name) end
    end)
  end)

  -- ------------------------------------------------------------------ D2: views never register
  describe("views of systems Forever lacks", function()
    local CASES = {
      { file = "views/VaultView.lua", key = "VaultView", feature = "Great Vault" },
      { file = "views/Legion.lua", key = "Legion", feature = "Legion" },
      { file = "views/MidnightProfs.lua", key = "MidnightProfs", feature = "Midnight Professions" },
      { file = "views/HousingDecorView.lua", key = "HousingDecorView", feature = "Housing Decor",
        globals = { WarbandeerHousingDecorApi = { List = {} } } },
    }
    for _, c in ipairs(CASES) do
      it("Forever: " .. c.key .. " is not registered", function()
        local ns = wb.loadFlavored("forever", { c.file }, { globals = c.globals })
        assert.is_nil(ns.views[c.key])
      end)
      it("Retail: " .. c.key .. " is registered", function()
        local ns = wb.loadFlavored("retail", { c.file }, { globals = c.globals })
        assert.is_not_nil(ns.views[c.key])
      end)
    end

    -- ns answers any unknown name with a stub, so "was it assigned?" is read off its own keys.
    local function assigned(ns, name)
      for key in pairs(ns) do if key == name then return true end end
      return false
    end

    it("the vault's helper files build nothing on Forever and their column registry on Retail", function()
      local files = { "views/VaultColumns.lua", "views/VaultRoster.lua" }
      local forever = wb.loadFlavored("forever", files)
      assert.is_false(assigned(forever, "VaultColumns"))
      assert.is_false(assigned(forever, "VaultRoster"))
      local retail = wb.loadFlavored("retail", files)
      assert.is_true(assigned(retail, "VaultColumns"))
      assert.is_true(assigned(retail, "VaultRoster"))
    end)

    it("the Great Vault column toggles are registered on Retail only", function()
      local function settings(flavor)
        local registered = {}
        wb.loadFlavored(flavor, { "views/VaultColumns.lua", "views/vaultColumnsSettings.lua" }, {
          -- VaultColumns = false: where VaultColumns.lua does not run, the name is simply absent
          -- in the game (a bare ipairs over it would raise); the stub would otherwise invent one.
          ns = { VaultColumns = false, RegisterSettings = function(_, spec) registered[#registered + 1] = spec end },
        })
        return registered
      end
      assert.equals(0, #settings("forever"))
      assert.equals(1, #settings("retail"))
    end)
  end)

  -- ------------------------------------------------------------------ the rail / minimap list
  describe("NavViews", function()
    -- Every view init.lua orders, registered by a stand-in except the four that gate themselves:
    -- those are registered (or not) by loading the REAL files, so the list is the gates' output.
    local function navNames(flavor)
      local ns = wb.loadFlavored(flavor, {
        "init.lua", "views/VaultView.lua", "views/Legion.lua", "views/MidnightProfs.lua", "views/HousingDecorView.lua",
        "window.lua",
      }, { globals = {
        GetNumClasses = function() return 0 end,
        GetClassInfo = function() return nil end,
        WarbandeerHousingDecorApi = { List = {} },
      } })
      local gated = { vault = true, legion = true, midnightprofs = true, decor = true }
      for _, name in ipairs(ns.viewOrder) do
        if not gated[name] then ns.views["Stand" .. name] = { name = name, _title = name } end
      end
      local names = {}
      for _, v in ipairs(ns.NavViews()) do names[#names + 1] = v.name end
      return names, ns
    end

    it("NavViews on Forever has no vault/legion/midnightprofs/decor entries; Retail's list is unchanged", function()
      local forever, fns = navNames("forever")
      local retail = navNames("retail")
      local expectedForever = {}
      for _, name in ipairs(fns.viewOrder) do
        if name ~= "vault" and name ~= "legion" and name ~= "midnightprofs" and name ~= "decor" then
          expectedForever[#expectedForever + 1] = name
        end
      end
      assert.same(expectedForever, forever)
      assert.same(fns.viewOrder, retail)  -- every ordered view, in order, on Retail
    end)

    it("a saved default view naming an unregistered view is ignored (no nil view class)", function()
      local _, ns = navNames("forever")
      ns.db = { settings = { defaultView = 3 } }       -- "summary": registered
      assert.equals("summary", ns.DefaultViewName())
      ns.views.Standsummary = nil                      -- ... and now it is not
      assert.is_nil(ns.DefaultViewName())
      ns.db.settings.defaultView = 8                   -- a Retail-saved "Great Vault" index
      assert.is_nil(ns.DefaultViewName())
      ns.db.settings.defaultView = nil
      assert.is_nil(ns.DefaultViewName())
    end)

    it("InitialViewName falls back to the first nav view when the saved default is unregistered", function()
      local _, ns = navNames("forever")
      ns.db = { settings = { defaultView = 8 } }       -- a Retail-saved "Great Vault" index
      assert.is_nil(ns.DefaultViewName())
      assert.equals(ns.NavViews()[1].name, ns.InitialViewName())
      ns.db.settings.defaultView = 3                   -- "summary": registered, so it wins
      assert.equals("summary", ns.InitialViewName())
    end)

    it("Retail keeps a saved Great Vault default", function()
      local _, ns = navNames("retail")
      ns.db = { settings = { defaultView = 8 } }
      assert.equals("vault", ns.DefaultViewName())
    end)
  end)

  -- ------------------------------------------------------------------ D3: summary columns
  describe("Summary columns of systems Forever lacks", function()
    -- `caches` counts Midnight weekly cache quests: gated by the `midnight` feature (#987), the rest by the system they need.
    local GATED = { "vault", "keystone", "delversBounty", "delves", "cofferKey", "endeavors", "lumber", "caches",
                    "catalyst", "heroCrest", "mythCrest", "voidcore", "fieldAccolade", "unalloyedAbundance",
                    "manaCrystal", "shardOfDundun" }
    -- a column key whose file name differs from it (crests.lua holds two columns)
    local FILES_OF = { heroCrest = "crests", mythCrest = "crests", fieldAccolade = "fieldaccolade",
                       unalloyedAbundance = "unalloyedabundance", manaCrystal = "manacrystal", shardOfDundun = "dundun" }
    -- catalyst.lua formats these into an atlas string at load; the harness's `anything()` stub cannot be a %s argument
    local ICONS = { ns = { icons = { CheckGreen = "check", RedX = "x" } } }
    local FILES = { "views/SummaryColumns.lua", "views/summaryCol/level.lua" }  -- level: an ungated column (no setting key)
    local seen = {}
    for _, f in ipairs(GATED) do
      local file = FILES_OF[f] or f
      if not seen[file] then seen[file] = true; FILES[#FILES + 1] = "views/summaryCol/" .. file .. ".lua" end
    end

    local function keys(ns)
      local out = {}
      for _, c in ipairs(ns.SummaryColumns) do out[c.key or "?"] = true end
      return out
    end

    it("D3: gated columns are absent on Forever, present on Retail", function()
      local forever = keys(wb.loadFlavored("forever", FILES, ICONS))
      local retail = keys(wb.loadFlavored("retail", FILES, ICONS))
      for _, k in ipairs(GATED) do
        assert.is_nil(forever[k], k .. " must not register on Forever")
        assert.is_true(retail[k], k .. " must register on Retail")
      end
    end)

    it("D3: an ungated column is untouched on both clients", function()
      assert.equals(1, #wb.loadFlavored("forever", FILES, ICONS).SummaryColumns)   -- level only
      assert.equals(1 + #GATED, #wb.loadFlavored("retail", FILES, ICONS).SummaryColumns)
    end)

    it("D3: a saved setting naming a gated column is skipped, never an error", function()
      local ns = wb.loadFlavored("forever", FILES, ICONS)
      ns.db = { settings = { summaryColumns = { vault = false, keystone = false, caches = false, delves = true } } }
      local visible
      assert.has_no.errors(function() visible = ns.VisibleSummaryColumns() end)
      assert.equals(1, #visible)                        -- only the ungated level column: every named one is gated
      ns.db.settings.summaryColumns.caches = nil
      assert.equals(1, #ns.VisibleSummaryColumns())     -- caches is not registered on Forever, setting or no setting
    end)

    it("D3: the Summary Columns settings panel lists no gated column on Forever", function()
      local function labels(flavor)
        local spec
        wb.loadFlavored(flavor, (function()
          local f = {}
          for _, x in ipairs(FILES) do f[#f + 1] = x end
          f[#f + 1] = "views/summaryColumnsSettings.lua"
          return f
        end)(), { ns = { icons = ICONS.ns.icons, RegisterSettings = function(_, s) spec = s end } })
        local out = {}
        -- with every named column gated there is nothing to list: the panel then registers nothing at all
        for _, field in ipairs(spec and spec[1].fields or {}) do out[field.key] = true end
        return out
      end
      local forever, retail = labels("forever"), labels("retail")
      for _, k in ipairs(GATED) do
        assert.is_nil(forever[k])
        assert.is_true(retail[k])
      end
    end)
  end)

  -- ------------------------------------------------------------------ D4: the Encounter Journal
  describe("Overview's Traveler's Log click", function()
    local function load(flavor, globals)
      return wb.loadFlavored(flavor, { "views/Overview.lua" }, { globals = globals })
    end

    it("D4: on Forever the click never touches the Encounter Journal", function()
      local function boom() error("the Encounter Journal was referenced on Forever") end
      local ns = load("forever", {
        EncounterJournal_LoadUI = boom,
        EncounterJournal_OpenJournal = boom,
        MonthlyActivitiesFrame_OpenFrame = boom,
        C_PlayerInfo = { IsTravelersLogAvailable = function() return true end },
      })
      assert.has_no.errors(function() ns.OpenTravelersLog() end)
    end)

    it("D4: on Retail the click loads and opens the journal in Blizzard's order", function()
      local calls = {}
      local ns = load("retail", {
        EncounterJournal = nil,
        EncounterJournal_LoadUI = function()
          calls[#calls + 1] = "load"
          _G.EncounterJournal = { IsShown = function() return false end }
        end,
        EncounterJournal_OpenJournal = function() calls[#calls + 1] = "open" end,
        MonthlyActivitiesFrame_OpenFrame = function() calls[#calls + 1] = "frame" end,
        C_PlayerInfo = { IsTravelersLogAvailable = function() return true end },
      })
      ns.OpenTravelersLog()
      _G.EncounterJournal = nil
      assert.same({ "load", "open", "frame" }, calls)
    end)

    it("D4: on Retail an unavailable Traveler's Log still does nothing", function()
      local ns = load("retail", {
        EncounterJournal_LoadUI = function() error("not available") end,
        C_PlayerInfo = { IsTravelersLogAvailable = function() return false end },
      })
      assert.has_no.errors(function() ns.OpenTravelersLog() end)
    end)
  end)

  -- ------------------------------------------------------------------ D5: nil-safe reads
  describe("GlyphBox", function()
    it("D5: with no applied-glyph map and no spec query it renders without error", function()
      -- Forever: no specializations (no GetNumSpecializationsForClassID), the data layer writes no
      -- glyphs.applied and an empty basic.specialization. Every API the box reads returns nothing.
      local ns = wb.loadFlavored("forever", { "controls/GlyphBox.lua" }, {
        globals = { C_SpecializationInfo = false, GetNumSpecializationsForClassID = false,
          GetSpecializationInfoForClassID = false },
        ns = { api = {
          GetAppliedGlyphs = function() return nil, false end,
          GetLearnedUnlocks = function() return nil end,
          GetAppearanceUnlocks = function() return nil end,
          GetClassMounts = function() return nil end,
        } },
      })
      local GlyphBox = ns.GlyphBox
      local box = setmetatable({}, { __index = function(_, k)
        return GlyphBox[k] or function() return wb.anything() end
      end })
      GlyphBox.__ctor(box)
      local char = { name = "Zed", classId = 1, basic = { specialization = {} } }
      local height
      assert.has_no.errors(function() height = box:Populate(char) end)
      assert.equals(0, height)  -- nothing to show: the box hides and reserves no space
    end)
  end)
end)
