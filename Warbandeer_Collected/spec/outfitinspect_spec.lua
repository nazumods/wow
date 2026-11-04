local collected = require("Warbandeer_Collected.spec.collected")

-- The inspect handshake (#1112). `GetInspectItemTransmogInfoList` answers for whoever the client
-- inspected LAST, so the look may only be read once INSPECT_READY has matched the GUID we asked
-- about. These pin that gate; the real handshake still needs the game.
describe("GrabTargetOutfit", function()
  local ns, onReady, cached, shown, retries, imported, savedGlobals

  local GLOBALS = {
    "C_TransmogCollection", "UnitExists", "UnitIsPlayer", "CanInspect", "UnitGUID",
    "GetUnitName", "NotifyInspect", "ClearInspectPlayer",
  }

  before_each(function()
    savedGlobals = {}
    for _, k in ipairs(GLOBALS) do savedGlobals[k] = _G[k] end
    cached, shown, retries, imported = nil, {}, 0, 0

    _G.C_TransmogCollection = { GetInspectItemTransmogInfoList = function() return cached end }
    _G.UnitExists = function() return true end
    _G.UnitIsPlayer = function() return true end
    _G.CanInspect = function() return true end
    _G.UnitGUID = function() return "Player-B" end
    _G.GetUnitName = function() return "Bee" end
    _G.NotifyInspect = function() end
    _G.ClearInspectPlayer = function() end

    ns = {
      Print = function() end,
      Retry = function() retries = retries + 1; return true end,   -- always "scheduled another try"
      ResetRetry = function() end,
      CancelRetry = function() end,
      ShareableOutfit = function(list) return list end,
      EncodeOutfit = function() return "encoded" end,
      OutfitSummary = function() return "" end,
      OutfitIssues = function() return {} end,
      OpenDressingRoom = function() return { ImportOutfit = function() imported = imported + 1 end } end,
      ui = { ShowCopyWindow = function(title) shown[#shown + 1] = title end },
    }
    onReady = collected.loadInspect(ns)
  end)

  after_each(function()
    for _, k in ipairs(GLOBALS) do _G[k] = savedGlobals[k] end
  end)

  it("does not finish on another player's cached list before INSPECT_READY", function()
    cached = { [1] = { appearanceID = 1 } }   -- the previous inspectee's look, already in the client
    ns.GrabTargetOutfit()
    assert.equal(0, #shown)
    assert.equal(0, imported)
    assert.is_true(retries >= 1)   -- still waiting, the retry clock is running
  end)

  it("ignores an INSPECT_READY for a different GUID", function()
    cached = { [1] = { appearanceID = 1 } }
    ns.GrabTargetOutfit()
    onReady(nil, "Player-A")
    assert.equal(0, #shown)
  end)

  it("finishes with the target's name once INSPECT_READY matches its GUID", function()
    ns.GrabTargetOutfit()
    cached = { [1] = { appearanceID = 2 } }
    onReady(nil, "Player-B")
    assert.same({ "Bee's look" }, shown)
    assert.equal(1, imported)
  end)

  it("keeps waiting after a matching INSPECT_READY while the list is still empty", function()
    ns.GrabTargetOutfit()
    cached = {}
    onReady(nil, "Player-B")
    assert.equal(0, #shown)
    assert.is_true(retries >= 1)
  end)
end)
