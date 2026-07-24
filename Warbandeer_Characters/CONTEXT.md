# Warbandeer_Characters (Data Layer)

**Deps:** LibNAddOn, LibNUI · **SavedVars:** `WarbandeerCharDB` (v41) · **Commands:** `/characters`, `/wbc` · **API:** `WarbandeerApi`

Data-collection backbone for the suite. Scans the active character each login/refresh and stores everything in `WarbandeerCharDB`, exposing it to the rest of the suite through the `WarbandeerApi` global. Per-field scanning is driven by the **broker** system (`broker.lua`).

## Files

| File | Purpose |
|---|---|
| `init.lua` | Addon bootstrap (assignment form) |
| `types.lua` | LuaLS aliases: `Specialization`, `SpecializationKey` |
| `broker.lua` | `Broker` class + `ns:RegisterBroker`/`InitBrokers`; reset constants `RESET_SUNDAY/DAILY/WEEKLY`; reset-boundary timestamps `ns.LAST_DAILY_RESET`/`LAST_RESET`/`LAST_SUNDAY_RESET`. `Broker:Reset`/`Update` skip an alt with no data table for a broker yet — `InitBrokers` Init's only the current character, so an alt predating a broker's addition (e.g. `professionKnowledge`) reaches the reset loops un-Init'd (#624); unit-tested in `spec/broker_spec.lua`. Also the self-registering **missing-data** surface: `ns:RegisterMissing{order,maxLevel?,check}` (non-broker completeness registry → `ns.missingProviders`) + the per-`BrokerField` `missing` declaration — a `MissingDescriptor` `{label?,maxLevel?,order?,check?}`, `false` (explicit opt-out), a bare `fn`, or nil (undeclared → auto-flagged). Both consumed by `missing.lua`'s walker |
| `database.lua` | `ns:MigrateDB`, `ns:initialize` (creates the per-char struct, then `InitBrokers`/`InitWarband`); `/characters list`, `/characters delete <name>` (also prunes the character's cached bank gear), `/characters cleanup` (recount numCharacters + drop bank gear for untracked characters) |
| `main.lua` | `ns:refresh` + `ns:refreshQueue` (one **field** scanned per 100ms); `/characters refresh`, `/characters dump`. Also `ns:registerDump(subcmd, title, description, body, toWindow?)` — the shared dump-buffer helper: each `body(self, out, args)` writes lines via `out:line(...)` (space-joined varargs) instead of printing, and the helper wires up **both** `dump <subcmd>` (→ chat) and `wdump <subcmd>` (→ `ui.ToggleCopyWindow(title, …)`, re-run toggles). `toWindow = true` routes the `dump <subcmd>` variant to the copy window too, for a dump whose output is inherently too large for chat (e.g. `pets` — a full stable can be hundreds of pets). Bare `/wbc wdump` (or `wdump *`) renders every registered dump under `== <title> ==` section headers into one copy window (chat truncates + can't be copied). `args` passes straight through, so a subcommand can take an arg (e.g. `dump wq self`) and the `wdump` variant gets it for free |
| `login.lua` | `ns.onLogin` → `initialize()` once, then `refresh()` |
| `logging.lua` | Settings panel **Warbandeer → Logging** subcategory: opt-in `combatLogging` checkbox (default off, `db.settings.combatLogging`). `LoggingCombat(true)` writes COMBAT_LOG events to `Logs/WoWCombatLog.txt` for offline parsing; the client never persists the toggle, so it's re-applied each `PLAYER_LOGIN`. Enables `advancedCombatLogging` via `SetTemporaryCVar` (restored at logout) only while active; only ever enables (never force-disables a manual `/combatlog`) |
| `api.lua` | `WarbandeerApi` public methods (see below) |
| `data/basic.lua` | Broker `basic`: `level`, `specialization`, `professions` (name summary), `xp` |
| `data/currency.lua` | Broker `currency`: `RestoredCofferKey`, `gold` (`GetMoney`), `CofferKeyShard`, `Catalyst`, `HeroDawncrest`, `MythDawncrest`, `NebulousVoidcore`, `UntaintedManaCrystal`, `ShardOfDundun`, `FieldAccolade`, `UnalloyedAbundance` |
| `data/warband.lua` | Account-wide (not a broker): `db.warband` bank gold + weekly wealth. `ns:GetWarbandWealth`, `RolloverWarbandWeek`, `InitWarband`; `/wbc dump warband` |
| `data/bank.lua` | Account-wide (not a broker): `db.bank` profession-gear cache for the warband bank, each character's bank, and guild banks. Also records each store's equippable gear (`equip` = `GearCandidate[]`) for the warband + personal banks (not guild). Scanned on bank/guild-bank open (warband+character via `C_Bank`/`C_Container`, guild via the classic API). Each store also records `items` (v19) — a full `{[itemID]=count}` map of *everything* in that bank (not just prof gear), accumulated in the same slot loop via `addCount`; drives `WarbandeerApi:GetItemCounts` (warband-stock tooltip). The warband bank's map is account-wide (stored once). **Load-then-rescan** for the `equip` ilvls: a fresh bank-open scan reads many slots cold, so `addEquip` falls back to the link's ilvl (never nil — a nil ilvl makes the upgrade finder drop the item, recommending a worse already-loaded piece first) and flags the slot; `scanPersonalBanks` requests a load and `scheduleBankRescan` re-scans (gen-guarded, `MAX_BANK_RESCANS`×`BANK_RESCAN_DELAY`, gated on the bank still open) until every slot reports its real scaled ilvl — mirrors `data/equipment.lua`. `WarbandeerApi:GetBankProfGear(skillID)`; `/wbc dump bankgear`. A character with no `db.bank.characters[name]` entry is flagged "bank contents" by its `missing` provider |
| `data/items.lua` | Broker `items`: `bags`, `reagentBag`; `/wbc refresh items` |
| `data/inventory.lua` | Broker `inventory`: `counts` — `{[itemID]=qty}` summed across the active character's bags + reagent bag (container IDs 0..NUM_BAG_SLOTS+1 via `C_Container`). Rescanned on `BAG_UPDATE_DELAYED` (500ms). Last-seen per character (only refreshable while logged in). Consumed by `WarbandeerApi:GetItemCounts` → ShadowsOfUI-WarbandInventory's stock tooltip. A character with no `inventory.counts` (not seen since v19) is flagged "bag contents" by its `missing` descriptor |
| `data/reputations.lua` | Broker `reputations`: `factions` — `{[factionID] = {name, label, rank, done, paragon?, accountWide?, categoryId?, current?, threshold?, paragonCurrent?, paragonThreshold?}}` for **every** faction the character has a standing with. `resolve()` picks the model per faction: major (`IsMajorFaction` → `RENOWN_LEVEL_LABEL`+renown, `HasMaximumRenown`), friendship (`GetFriendshipReputation`/`Ranks`), or standard reaction (`_G["FACTION_STANDING_LABEL"..reaction]`); `IsFactionParagon` sets `paragon`. v42 adds absolute bar-fill progress alongside each model — `current`/`threshold` from `renownReputationEarned`/`renownLevelThreshold` (major), `standing - reactionThreshold`/`nextThreshold - reactionThreshold` (friendship), or `currentStanding - currentReactionThreshold`/`nextReactionThreshold - currentReactionThreshold` (standard); `paragonCurrent`/`paragonThreshold` from `GetFactionParagonInfo` when paragon. Enumerated via `C_Reputation.ExpandAllFactionHeaders` + `GetNumFactions`/`GetFactionDataByIndex` (skip pure headers); the walk is in panel (tree) order, so the last top-level header (`isHeader and not isChild`) seen is stamped as each faction's `categoryId` (the expansion header's factionID — locale-proof grouping key for Warbandeer's Reputations view; sub-headers like Dragonscale Expedition don't reset it, so children inherit their expansion). Event `UPDATE_FACTION`, but the handler is heavily rate-limited (the full faction walk pegged the CPU when run per-event): (1) **self-trigger suppression** — the scan's own `ExpandAllFactionHeaders` fires more `UPDATE_FACTION` *asynchronously* (after `get` returns), so a synchronous flag can't catch it; instead the scan-completion time is stamped and events within `SELF_WINDOW` (1s) are ignored; (2) **throttle** — a scan never lands sooner than `MIN_INTERVAL` (6s) after the previous one; (3) **debounce** via LibNAddOn's `ns:debounce` (`SCAN_DEBOUNCE` 2s, like worldquests) — only the last event in a burst runs. Drives `WarbandeerApi:GetReputations`/`GetFactionStandings` → ShadowsOfUI-Reputations + Warbandeer's Reputations view. A character with no `reputations` is flagged "reputations" by its `missing` descriptor |
| `data/questlog.lua` | Broker `questlog`: `active` (`{[questID]=true}` set from the quest log) + `completed` (completed-quest **bitmap** — `pack(GetAllCompletedQuestIDs())`, `{[slot]=bits}` with **32-bit** slots: `slot=floor(qid/32)`, `bit=qid%32`). **32, not 64** — WoW Lua doubles + 32-bit `bit.*` silently drop high bits past ~53 (AR H5); membership via `band` only, so bit 31 → 0x80000000 round-trips. `ns.IsQuestCompleted(map, qid)` is the read helper (used by `api.lua`). `active` on `QUEST_ACCEPTED/REMOVED/TURNED_IN` (1s); `completed` re-packs on `QUEST_TURNED_IN` (3s debounce). Drives `WarbandeerApi:GetQuestStatus` → ShadowsOfUI-Quests. The completed bitmap is the **largest** per-character field. A character with no `questlog` is flagged "quest history" by its `missing` descriptor |
| `data/auctions.lua` | Event-driven owned-auction scanner (not a broker): on `AUCTION_HOUSE_SHOW` kicks `QueryOwnedAuctions`, then on `OWNED_AUCTIONS_UPDATED` reads `GetNumOwnedAuctions`/`GetOwnedAuctionInfo` into `db.characters[name].auctions` = `{ scannedAt, count, expiries[] (active only, absolute server-time stamps via `timeLeftSeconds`), value (copper tied up), bids }`. Active status only (`Enum.AuctionStatus.Active`). Last-seen (only readable at the AH). Drives `WarbandeerApi:GetAuctions` + Warbandeer's Summary `auctions` column — which derives a **live** count from expiries still in the future, so a stale cache (auctions run ≤48h) reads as zero rather than a phantom count. No `missing` provider (many characters never use the AH) |
| `data/mail.lua` | Event-driven mail scanner (not a broker): on `MAIL_INBOX_UPDATE`, scans the open inbox into `db.characters[name].mail` = `{ scannedAt, count, expiries[] (absolute server-time stamps, asc), items {[itemID]=qty}, money, hasMail }` — `daysLeft` is stored as an absolute expiry so it stays correct as the cache ages. Inbox contents are last-seen (only readable at a mailbox); `hasMail` (the `HasNewMail()` minimap-envelope state) is tracked separately on `UPDATE_PENDING_MAIL`, so new mail is flagged even before the mailbox is opened — a `mail` record may exist with only `hasMail` set and no `count`. `UPDATE_PENDING_MAIL` + `HasNewMail()` are the **exact event/API Blizzard's `MiniMapMailFrameMixin` uses to raise/lower the minimap envelope**, so the flag flips in lockstep with that icon. Caveat: Blizzard skips registering the event when the `IngameMailNotificationDisabled` game rule is active (no minimap icon on such realms/modes), so `hasMail` never sets there and the column falls back to the count. Also `ns:WarnExpiringMail` (login chat warning for mail within `ns.MAIL_WARN_DAYS` = 3 days, called from `login.lua` after a 6s delay). Feeds the `Mail` source of `GetItemCounts` + Warbandeer's Summary `mail` column. A character whose inbox was never scanned (`mail` nil or its `count` nil) is flagged "mail" by its `missing` provider |
| `data/gearbag.lua` | Broker `gearbag`: `items` — the active character's equippable bag gear (`GearCandidate[]`) for the upgrade finder (ShadowsOfUI-Upgrade). Filtered via `WarbandeerApi:ClassifyGearItem`; rescanned on `BAG_UPDATE_DELAYED` (a cold slot falls back to the link's ilvl rather than a nil that would drop the candidate; the scaled value refreshes on the next bag update) |
| `data/professioninfo.lua` | The static per-profession id table `ns.api.professionInfo` (keyed `sl<skillLineID>`: name, skill-line + Midnight variant ids, profession spell). Loaded before `data/professions.lua` |
| `data/professions.lua` | Broker `professions` + its `details` field (per-exp skill levels, spec points, learned recipes); scans pre-resolve current-exp recipes into the recipe-gear cache and capture each prof-gear recipe's reachable crafting `quality`/`qualityConc` (via `GetCraftingOperationInfo`). Owns `RECIPE_EXP_KEYS` + `ns.CURRENT_RECIPE_EXP`. The `gear` field is in `data/professions_gear.lua` |
| `data/professions_gear.lua` | The broker's `gear` field (profession tool/accessory slots, keyed by parent skillLineID) + its equip-load fallback (`anyUnloaded`/`scheduleFallback`, generation-guarded) + the `ITEM_DATA_LOAD_RESULT` drain that refreshes once profession-slot item data loads. Adds `ns.Professions.fields.gear` to the broker in `data/professions.lua` |
| `data/recipegear.lua` | Account-wide `db.recipeGear` cache (recipe → prof-gear output: itemID/rarity/equipLoc/target skillID), build-stamped; `WarbandeerApi:ResolveRecipeOutput`, `WarbandeerApi:ClassifyProfGearItem` (item → prof skillID/equipLoc, shared with the bank scanner), `WarbandeerApi:ClassifyGearItem` (item → equippable equipLoc/classID/subClassID, shared by `gearbag`/`bank`) |
| `data/concentration.lua` | Broker `concentration`: `data` — Midnight concentration currency per crafting prof, keyed by parent skillLineID |
| `data/artisancurrency.lua` | Broker `artisanCurrency`: `data` — current-expansion artisan crafting currency (Midnight's per-profession "Artisan's … Moxie", every prof incl. gathering), keyed by parent skillLineID. Consumed by ShadowsOfUI-Artisan |
| `data/professionknowledge.lua` | Broker `professionKnowledge`: `data` — per-Midnight-profession WEEKLY knowledge-point progress (treatise / weekly-quest / treasure / gathering), keyed by parent skillLineID; each source a `{done,total}` plus an aggregate `{done,total}`. Read from hidden quest flags (`C_QuestLog.IsQuestFlaggedCompleted`) against the static `ns.ProfessionKnowledge` table (Midnight quest IDs, cross-checked vs the WeeklyKnowledge addon), captured on login + `QUEST_TURNED_IN`, sticky vs transient reads, `resetOn = RESET_WEEKLY`. Pure `ns.SummarizeProfessionKnowledge` / `ns.MergeProfessionKnowledge` (+ `ns.ProfessionKnowledgeSources`) unit-tested in `spec/professionknowledge_spec.lua`. `WarbandeerApi:GetProfessionKnowledge`; `/wbc dump knowledge` (+ `wdump knowledge`). Consumed by Warbandeer's Midnight Profs view; retires the WeeklyKnowledge addon |
| `data/glyphinfo.lua` | The static appearance-glyph catalog (loaded before the broker): `ns.AppearanceGlyphs` (per-character APPLIED cosmetic glyphs, keyed by classId → `{itemID, glyph, label, specs?}`; `glyph` is the id embedded in an applied spell's hyperlink, `specs` the usable spec set) + `ns.AppearanceUnlocks` (ACCOUNT-WIDE Druid Marks/travel glyphs + Warlock demon Grimoires + the Warlock green fire unlock, keyed by classId → `{itemID, quest, spell, label, startItem?, startQuest?}`; the optional `startItem`/`startQuest` mark a PROGRESSIVE row (green fire) whose displayed item advances with questline progress, resolved in `api.lua`). Ids ported from the community GlyphList addon and verified in-game via `/wbc dump glyphs`. Also the pure `ns.MergeGlyphStatus(list, specID, applied)` helper (unit-tested in `spec/glyphs_spec.lua`). The per-character LEARNED class-unlock catalog (`ns.LearnedUnlocks`) split out into `data/learnedunlocks.lua` |
| `data/classmounts.lua` | The static class-mount catalog (loaded after `glyphinfo.lua`): `ns.ClassMounts`, keyed by classId → `{spellID?/itemID?, label, source?}` — the class's Legion order-hall mounts + spec-gated colour tints as ACCOUNT-WIDE collectibles (all classes but Evoker). `api.lua`'s `GetClassMounts` resolves each id to a mountID (`C_MountJournal.GetMountFromSpell/Item`) then reads name/icon/`isCollected` live. Tints with distinct item ids are separate entries; DK is ONE entry whose colour follows the active spec (not three). `source` is an inline "how to obtain" hint (not `collectiblesources.lua`, since tint mounts lack a teaching itemID). Registers `/wbc dump mounts` (+ `wdump mounts`), the in-game id/label verification probe. `ns.ClassMounts` integrity is unit-tested in `spec/glyphs_spec.lua` |
| `data/learnedunlocks.lua` | The static `ns.LearnedUnlocks` catalog (split out of `glyphinfo.lua`; loaded right after it) — per-character LEARNED class unlocks keyed by classId → `{itemID, spell, label, races?}`, where `spell` is the granted spell checked via `C_SpellBook.IsSpellKnown` and `races` marks an innate grant (Goblin/Gnome Mechanical taming). Populated for 8 classes: the Legion class-order-hall cosmetic/utility tomes (Paladin `[2]` Divine Tome, Rogue `[4]` Dirty Tricks, DK `[6]` Necrophile Tome, Shaman `[7]` Tomes of Hex, Mage `[8]` Mystical Tomes incl. the Polymorph variants, Monk `[10]` Meditation Manual, Hunter `[3]` Fireworks/Play Dead), plus the two predating sets — Druid `[11]` "Tome of the Wilds" and Hunter `[3]` "Tomes & Tames" (Skill Tames + utility tomes). Abilities with no collectible item are excluded (Eyes of the Beast, Ottuk Taming, Polymorph: Pig). Also `ns.LearnedUnlockTitle` (per-class card-section name) and the pure `ns.MergeLearnedStatus(list, known)` helper (unit-tested in `spec/glyphs_spec.lua`). Ids from Wowhead, verified in-game via `/wbc dump glyphs` |
| `data/challengetames.lua` | The static Challenge-Tames catalog (loaded after `glyphinfo.lua`, before the pets scanner): `ns.ChallengeTames` — a flat `ChallengeTame[]` of curated rare/"secret" Hunter tames (spirit beasts, Molten Front challenges, …), each `{ label, creatureID, displayID?, category, note?, howTo? }` (`note` = the short inline zone; `howTo` = the full obtain detail — spawn spot, taming mechanic, prerequisites — shown in the row's hover tooltip); a single-appearance tame keys on `creatureID` alone, a recolor pins a `displayID` under a shared `creatureID`. Plus the pure `ns.MergeChallengeTames(list, ownedCreatures, ownedDisplays)` helper (unit-tested in `spec/challengetames_spec.lua`) that merges the catalog with a Hunter's owned-id sets into an owned/missing status list, preserving order. Seed ids from the Wowhead Secret Hunter Pets guide, confirmed in-game via `/wbc dump tames` (a wrong seed id just reads "missing" until corrected). `howTo` obtain detail + zone/category corrections (2026-07-14, Petopia/Wiki): Lightning Paw moved to Spirit Beasts (exotic Duskwood fox); the untameable Iron Juggernaut boss (npc 71466) dropped (its tameable form is the Grey Juggernaut craft); coloured Juggernauts corrected to a Siege of Orgrimmar craft-and-tame (were mislabelled Tanaan); Sabertron to Stormsong Valley (was Ashran). Consumed by `WarbandeerApi:GetChallengeTames`. Aspirational → never feeds `/wbc missing` |
| `data/collectiblesources.lua` | The static `ns.CollectibleSources` map — itemID → a one-line "how to obtain" hint for every Detail appearance-card collectible (the `AppearanceGlyphs` glyphs, the `AppearanceUnlocks` Grimoires + green fire + Marks, and the `LearnedUnlocks` Tomes & Tames + Tome of the Wilds). Sourced from Wowhead + Warcraft Wiki, in-game name-verified. The three appearance getters attach it as each returned entry's `source`, and the Detail card appends it to the item tooltip's "How to obtain" line for an **unowned/unapplied** entry (owned entries suppress it). Repeated sources use shared string locals. Loaded after `glyphinfo.lua` |
| `data/glyphs.lua` | Broker `glyphs`: `applied` — cosmetic glyph ids the character has applied, keyed by **spec id** (`{[specID]={[glyph]=true}}`). Walks **every** spec tab (`scanAllSpecs`, grouped by the tab's `offSpecID`) and pulls each known spell's applied glyph id from its hyperlink (`link:match("%b::(%d+)")`, mirroring the GlyphList addon), so one scan can capture multiple specs — but WoW only reliably surfaces the ACTIVE spec's glyphs, so the active spec always gets a (possibly empty) entry ("scanned, none" ≠ "not discovered") while an inactive spec is stored only once a glyph is found there (else it fills in when that spec is next played). Merge-preserving (untouched specs keep their cached set); last-seen (only the logged-in char is readable). Event `SPELLS_CHANGED`/`PLAYER_SPECIALIZATION_CHANGED` (1s debounce). Also owns the `/wbc dump glyphs` (+ `wdump glyphs`) probe — prints each catalog entry's stored label beside its live-resolved item name (a wrong id shows a mismatch), a live **per-spec** scan (so all-spec capture is verifiable), plus applied/unlocked state. Account-wide unlocks are NOT stored here (read live by the API). Also field `unlocks` — a per-character set (`{[spell]=true}`) of the class-unlock spell ids the character has (`ns.LearnedUnlocks` — Druid Tome of the Wilds, Hunter Tomes & Tames), via `C_SpellBook.IsSpellKnown` OR an innate racial grant (Goblin/Gnome Mechanical taming); nil for a class with no unlocks. Drives `WarbandeerApi:GetAppliedGlyphs`/`GetAppearanceUnlocks`/`GetLearnedUnlocks` → Warbandeer's Detail appearance card. Its `applied` field **opts out** of the missing report (`missing = false`) — applied glyphs are per-character × per-spec *loadout* state and WoW surfaces only the active spec per login, so a "missing appearance glyphs" line would sit unresolved across most of the warband forever. The `unlocks` field's `missing` descriptor still flags a class with unlocks but no captured `glyphs.unlocks` with its section title (e.g. "tome of the wilds", "skill tames") |
| `data/pets.lua` | Event-driven scanner (not a broker), **Hunter-only**: the character's pet roster — `pets` = `{ scannedAt, active, stable }`, each list a `PetRecord[]` (name, family, level, spec, family icon, + stable `creatureID`/`displayID`). Both lists (active Call-Pet slots via `C_StableInfo.GetActivePetList`, stabled pets via `GetStabledPetList`) are only reliably readable **at a stable master** — the Blizzard stable UI drives everything off `PET_STABLE_SHOW` and calls `C_StableInfo.ClosePetStables()` on close, tearing the lists down — so this is a **last-seen** cache captured on `PET_STABLE_SHOW`/`PET_STABLE_UPDATE`, mirroring the bank/mail/auction scanners. The **active** list is additionally refreshed on `PET_INFO_UPDATE` (a Hunter's Call-Pet pets keep leveling / can be renamed in the field) — self-guarded: only for a Hunter that already has a stable-captured roster, and only when the API returns pets (away from a stable it may read empty, which must not clobber the last-seen list); `scannedAt` stays the last full-scan time. The stable `creatureID`/`displayID` are locale-independent (a pet's name is user-renameable, so it can't be matched on) — the matching key the **Challenge-Tames** checklist keys off (`data/challengetames.lua`: `creatureID` = base creature; `displayID` = recolor granularity for Sabertron colours / Deth'tilac recolors). Drives `WarbandeerApi:GetPets` → Warbandeer's Detail "Pets" button + docked roster panel. `/wbc dump pets` (+ `wdump pets`) — registered with `toWindow = true`, so even the plain `dump pets` opens the copy window (a full stable is too large for chat). Also owns `/wbc dump tames` (+ `wdump tames`, `toWindow = true`) — the Challenge-Tames verification probe: prints each catalog entry's label + creatureID (+displayID), grouped by category, and OWNED (naming the matched pet) / missing, to confirm a seed id actually matches a stored pet. Its `missing` provider flags a Hunter with no `pets` as "stable pets" (needs a stable visit) |
| `data/demons.lua` | Event-driven scanner (not a broker), **Warlock-only**: the character's summoned-demon roster — `demons` = `{ scannedAt, list }`, each a `DemonRecord` (`species` from `UnitCreatureFamily("pet")`, persistent `name`, `npcID` parsed from the pet GUID's 6th dash-field, `seenAt`). Unlike a Hunter's stable there is **no enumeration API** — a Warlock summons demons by spell, so only the currently-active demon is readable; this is therefore a **last-seen, per-summon** cache captured on `UNIT_PET` (filtered to `"player"`), filling in as the Warlock summons Imp / Voidwalker / Felhunter / Sayaad / Felguard. Deduped by `npcID` (locale-proof; falls back to `species` when a GUID has no parseable id) so a re-summon updates the record in place (last-seen name wins). Drives `WarbandeerApi:GetDemons` → the same Detail button + docked panel (a Warlock "Demons" branch, with per-species icons keyed on `npcID`). `/wbc dump demons` (+ `wdump demons`) — chat is fine (one row per demon family). Its `missing` provider flags a Warlock with no `demons` as "demons" (needs a summon); a partial roster isn't flagged (the full set is spec-dependent — only Demonology gets the Felguard) |
| `data/titles.lua` | Broker `titles`, per-character earned player titles (**last-seen**; only the logged-in character's titles are readable, like `glyphs`). `known` — a `TitleRecord[]` (`{ id = titleMaskID, name = trimmed display name }`, sorted by name) built by walking `1..GetNumTitles()` and keeping ids the character `IsTitleKnown` **and** whose `GetTitleName` reports a real player title (its 2nd return — Blizzard's own `GetKnownTitles` guard, which skips non-displayable mask ids). `current` — the featured/active `titleMaskID` (validated in-range + known; nil when none); `currentName` — its trimmed display name (captured beside `current` so the Summary column renders an alt's title with no live lookup). Events `KNOWN_TITLES_UPDATE` (+ `UNIT_NAME_UPDATE` for a featured-title change), 1s debounce; the login `refresh()` queue captures every field even if no title event fires that session. Drives `WarbandeerApi:GetTitles` → Warbandeer's Summary **Titles** column (the current/featured title). `/wbc dump titles` (+ `wdump titles`) prints the live scan count + featured title + the stored per-character state |
| `data/travelerslog.lua` | Account-wide **Traveler's Log** (Trading Post monthly activity) snapshot — the activity bar + Trader's Tender are warband-shared, so it lives once at `db.travelersLog` (the `data/warband.lua` account-wide pattern), not per character. `ns:InitTravelersLog()` (from `initialize()`, after `InitWarband`) seeds the store, requests pending chest rewards (async), takes an initial read, and hooks `PERKS_ACTIVITIES_UPDATED` / `PERKS_ACTIVITY_COMPLETED` / `CHEST_REWARDS_UPDATED_FROM_SERVER` / `PERKS_PROGRAM_CURRENCY_REFRESH`; a shared `refresh()` re-derives a compact snapshot via `derive(info, pending, currency)` (Blizzard's `Blizzard_MonthlyActivities.lua` formula — earned = sum of completed activities' contribution capped at the largest threshold; pct = earned/max; rewards joined from pending chest rewards by `thresholdOrderIndex`, filtered to the active month; `count` is every pending chest so a prior month's uncollected reward still flags). Guards: bails keeping the last snapshot when `C_PerksActivities` is absent or `thresholds` empty (Trading Post disabled / pre-data). Drives `WarbandeerApi:GetTravelersLog` → Warbandeer's Overview **Traveler's Log** strip. `/wbc dump travelerslog` (+ `wdump travelerslog`) prints the snapshot |
| `data/races.lua` | `API.ALLIANCE_RACES`, `API.HORDE_RACES`, `ns.NormalizeRaceId(raceId)` → `(raceIdx, isAlliance)` |
| `data/quests.lua` | Broker `quests`: `UndermineStoryMode`, `WWIRep`, `LumberAxe`, `delves`, `CatalystUnbound` (achievement 61519 per-character via `wasEarnedByMe` — `completed` is account-wide, but the 13th `GetAchievementInfo` return is per-character; sticky on `ACHIEVEMENT_EARNED`) |
| `data/delvetimes.lua` | Event tracker (not a broker): personal delve completion-time cache. Times each run start→finish — `PLAYER_ENTERING_WORLD`/`SCENARIO_UPDATE` capture the active delve (name via `GetInstanceInfo` — `GetScenarioInfo().name` is the generic "Delves" — falling back to the map name; in-delve test via `C_DelvesUI.HasActiveDelve`/`C_PartyInfo.IsDelveInProgress`; tier via the scenario delves-header widget) and `SCENARIO_COMPLETED` records `GetServerTime()` elapsed (gated on an in-progress timer, so non-delve scenarios are ignored). Stores a rolling window (`KEEP` = 10) of seconds per delve+tier in `db.characters[name].delveTimes`, keyed by `ns.NormalizeDelveKey` (tier 0 = unknown bucket). The server-time start is persisted (`delveTimes.active`) so a mid-run `/reload` still records. `SCENARIO_UPDATE` refreshes the active tier but never clobbers a known tier with the unknown bucket (the header widget reads 0 before it's populated and again as it tears down at completion); completion does a last-ditch `readTier()` if none stuck. Exposes `ns.NormalizeDelveKey` (shared with `api.lua` + `data/dungeontimes.lua`); drives `WarbandeerApi:GetDelveStats` → ShadowsOfUI-Delves. **Also captures per-run XP** (v31): a run-start `{xp, maxXP, level}` snapshot is stored on `delveTimes.active.xp` (nil at max level) and, on completion, `ns.FinishRunXP` computes the gain (single level-up aware; a run spanning ≥2 level-ups is dropped) into a parallel rolling window `runs.*.xps[tier]`. The `ns.StartRunXP`/`ns.FinishRunXP` helpers live here and are shared with `data/dungeontimes.lua`. `/wbc dump delves` (now also prints avg XP), `/wbc clear delves` (reset the current character's run-times) |
| `data/dungeontimes.lua` | Event tracker (not a broker): personal dungeon completion-time cache, structurally mirroring `data/delvetimes.lua`, covering **two run types** into one per-character `dungeonTimes` store (`active` carries a `kind` discriminator: `"mplus"` / `"dungeon"`). **Keyed Mythic+** — the clean `CHALLENGE_MODE_START` → `CHALLENGE_MODE_COMPLETED` pair, bucketed by keystone level (`runs.*.tiers`/`.xps`); `CHALLENGE_MODE_START` (re)stamps the authoritative start (after the countdown; does not re-fire on `/reload`; a run whose start was never seen is not begun mid-run, so partials don't skew the average). **Non-keyed dungeons** (normal/heroic/etc.) — no start/completion event pair exists, so the run is timed from instance entry (`PLAYER_ENTERING_WORLD` into a `party` instance that isn't an active keystone) and recorded on **`LFG_COMPLETION_REWARD`**, bucketed by `difficultyID` (`runs.*.diffs`/`.diffXps`); this only fires for **Dungeon-Finder (queued)** runs — walk-in / manually-formed premade runs have no reward event and are intentionally not recorded (deferred; issue #378 covers a future walk-in signal). Shared `PLAYER_ENTERING_WORLD` handler resumes either kind across a `/reload` (persisted start) and discards on leaving without a completion. Name via `GetInstanceInfo` (map-name fallback), keystone level via `C_ChallengeMode.GetActiveKeystoneInfo`, difficulty label via `ns.DungeonDifficultyLabel` (locale-independent: 1→Normal, 2→Heroic, 23→Mythic, 24→Timewalking). Rolling window (`KEEP` = 10) per bucket, plus the same per-run XP window as delves (via shared `ns.StartRunXP`/`FinishRunXP`; leveling runs only). Drives `WarbandeerApi:GetDungeonStats`. `/wbc dump dungeons`, `/wbc clear dungeons` |
| `data/worldquests.lua` | Broker `worldquests`: `rewards` — the logged-in character's active world-quest **gear** rewards that could upgrade an equipped slot, cached per-character (last-seen; reward data is only readable for the active char). Not max-level-gated — some WQs are available before the cap. Each entry is a `GearCandidate` + `{questID, title, zone, endTime}`. Scans the current expansion's WQ continent zones (`WQ_CONTINENTS` → `GetMapChildrenInfo`), keeps only equippable gear (`API:ClassifyGearItem`), gated by an ilvl ceiling (no scan when every slot ≥ `WQ_ILVL_CEILING` 220). Debounced on `QUEST_LOG_UPDATE`/`ZONE_CHANGED_NEW_AREA`; since reward data loads async, a scan that finds quests before their rewards are ready preloads them and schedules a bounded retry (`RefreshCurrentCharacterField`), keeping the last-seen list instead of caching empty. `WarbandeerApi:GetWorldQuestRewards`; `/wbc dump wq` (arg `self` restricts to `ns.currentData` — the fresh-scan case; no arg dumps every character). The upgrade *evaluation* lives in ShadowsOfUI-Upgrade (consumes the raw cache) |
| `data/daily.lua` | Broker `dailies`: empty (template for future daily tracking) |
| `data/playtime.lua` | Broker `playtime`: `total` seconds + `byPatch` baseline (async via `TIME_PLAYED_MSG`), plus `byDay` — per-character logged-in seconds per **local** calendar day (`"YYYY-MM-DD"` → seconds). `byDay` is **wall-clock session accounting**, independent of the async `/played` query: an `anchor` server-time is stamped at `Init` (login) and a `flush` folds `[anchor, now]` into the day buckets via `accrue` (splitting the span at local midnight), driven by a 60s `C_Timer.NewTicker` + `PLAYER_LOGOUT`. Offline time is never counted — the anchor resets at each login, so the gap since the previous session's last flush is dropped. The ticker bounds crash-loss (a hard exit skips `PLAYER_LOGOUT`) and keeps today's bucket fresh for a live view. Local-day keys (date() with no `!`) so an evening session lands on one human day instead of splitting at UTC midnight |
| `data/weekly.lua` | Broker `weeklies`: `DMF`, `preMidnight`, `delversBounty` (weekly Delver's Bounty treasure claimed — quest 86371; sticky on `QUEST_TURNED_IN` until the weekly reset, max-level only), `caches`, `vault`, `vaultSlots` (per-slot Great Vault detail — reward ilvl per track slot, built via `ns.SummarizeVaultSlots`; `WEEKLY_REWARDS_UPDATE` 1000ms; **feeds `/wbc missing` as "vault"** at max level when the character has no vault data this reset — neither `vaultSlots` nor the aggregate `vault` fallback, i.e. a blank pip row), `hasUnclaimedVault`, `keystone`, `keystoneMap` (challenge-map id of the owned keystone's dungeon, paired with the level), `dungeons`; `/wbc dump m+`, `/wbc dump vault` |
| `data/vaultslots.lua` | Pure (WoW-API-free, unit-tested) vault helpers: `ns.SummarizeVaultSlots` (activities → per-track `Raid`/`Dungeons`/`World` slots ordered by threshold, each with reward ilvl), `ns.RaidLocks` (instance-lock store → raid-only, sorted by difficulty rank then progress), `ns.RaidDifficultyLabel`. Feeds `data/weekly.lua`'s `vaultSlots` field, `WarbandeerApi:GetRaidLocks`, and Warbandeer's Great Vault view |
| `data/housing.lua` | Broker `housing` (field `active`: the neighborhoodGUID this character is feeding; **feeds `/wbc missing` as "endeavor"** when `active` is nil (any level) — sticky/never-reset, so nil = the character has never fed a neighborhood endeavor) + account-wide capture: caches per-neighborhood faction + endeavor (title/progress/required/resetAt/`xp` = `GetAvailableHouseXP`) and per-house level/favor into `db.housing` from `PLAYER_HOUSE_LIST_UPDATED` / `HOUSE_LEVEL_FAVOR_UPDATED` + the field's get. Never mutates the active/viewing neighborhood (taint). `/wbc dump housing`. (issue #550) |
| `data/housinginfo.lua` | Pure (WoW-API-free, unit-tested) housing shapes + shapers: `ns.ShapeHousing` (a character's `active` neighborhood → `{ active = "alliance"\|"horde", title }`), `ns.ShapeHouses` (join `houses` + `neighborhoods` → per-faction `HouseView` for the Overview). Feeds `WarbandeerApi:GetHousing`/`GetHouses` |
| `data/instances.lua` | Broker `instances`: `locks`; `/wbc refresh locks`, `/wbc dump locks` |
| `data/equipment.lua` | Broker `equipment`: `slots`, `ilvl`, `trackScanned`, `socketScanned` (marker set once gear is scanned with the GetItemGemID socket count — its `missing` descriptor flags "gem socket data" for alts last scanned before that fix); loads item data before reading. Each slot also records `emptySockets` (v15) — `emptySocketCount(link)` = `C_Item.GetItemNumSockets` minus the sockets that hold a gem (`C_Item.GetItemGemID` per socket, mirroring Blizzard's paperdoll socket display). **Not** the `GetItemStats` `EMPTY_SOCKET_*` keys: the Midnight Gem Manager applies gems outside the stat block, so a gemmed item still reports those keys and would falsely read as needing a gem. Captured here while the item is loaded so it persists + reads warband-wide. Each slot also records `enchant` — the applied permanent-enchant **name** read from the live tooltip (`C_TooltipInfo.GetInventoryItem` → the `ENCHANTED_TOOLTIP_LINE` "Enchanted: %s" line, trailing quality-tier atlas markup stripped), e.g. "Enchant Helm - Rune of Avoidance"; nil when unenchanted. Same "Enchant <Slot> - <X>" form as the recommendations, so ShadowsOfUI-Upgrade can flag a WRONG enchant warband-wide |
| `data/stats.lua` | Broker `stats`: `secondary` (v16) — `{ crit, haste, mastery, versatility }`, each `{ pct, rating }` (effective % + gear combat rating) from the live `GetCritChance`/`GetHaste`/`GetMasteryEffect`/`GetCombatRatingBonus` + `GetCombatRating` APIs (logged-in char only), so it's a last-seen snapshot read warband-wide. `mastery` also carries its active-spec passive `spell` id (`GetSpecializationMasterySpells`), letting Detail name the mastery + show its spec-specific effect. Refreshes on `COMBAT_RATING_UPDATE`. Drives Warbandeer's Detail stat grid. **Secret values:** these APIs can return WoW "secret" numbers (tainted addon code can't do arithmetic on them); each is passed through `safe()` (`canaccessvalue` guard, retail-only) and stored as **nil** when secret, so the snapshot is always safe to read + serialize (Detail's delta/radar math would otherwise taint) |
| `data/artifacts.lua` | Broker `artifacts`: `hidden`, `hiddenColors`, `classHall`; `/wbc dump artifact` |
| `dump.lua` | `/wbc stat` — warband-wide playtime/class statistics |
| `missing.lua` | `/wbc missing`, `/wbc missing me`, `/wbc missing audit` — a generic **walker** over every broker field's `missing` descriptor + every `ns:RegisterMissing` provider (self-registering: a field is *tracked* by a descriptor, opted out by `missing = false`, or auto-flagged when undeclared, so a new field participates for free). Emits labels ordered by each entry's explicit `order`; `ns:getMissingReport` pins the current character atop the alpha-sorted rest. `ns:AuditMissing` / `missing audit` list broker fields lacking a stance (also a silent load-time dev nudge). Hosts only the external `bars` provider (optional `WarbandeerBarsApi`, no data-file home) |
| `wmissing.lua` | `/wbc wmissing` — same report rendered in a copyable scroll window via the shared `ui.ToggleCopyWindow` (LibNUI's `CopyWindow`), so re-running the command closes the window; window/picker logic no longer lives here |

## WarbandeerApi Methods

```lua
WarbandeerApi:GetCurrentCharacter()       → string
WarbandeerApi:GetCharacterData(char?)     → Character   -- live ref, NOT a copy (mutable)
WarbandeerApi:HasProfessionDetail(char?, skillLineID) → boolean  -- per-expansion detail captured? (primary profs only; false = never opened)
WarbandeerApi:GetNumCharacters()          → integer
WarbandeerApi:GetNumMaxLevel()            → integer
WarbandeerApi:GetAllCharacters()          → Character[]
WarbandeerApi:GetAllianceCharacters()     → Character[]
WarbandeerApi:GetHordeCharacters()        → Character[]
WarbandeerApi:GetWarbandBankGold()        → integer (copper)
WarbandeerApi:GetWarbandWealth()          → integer (copper, bank + all char gold)
WarbandeerApi:GetWeeklyGoldMade()         → integer (copper, current wealth − week baseline; may be negative)
WarbandeerApi:GetWealthHistory()          → WarbandWeekRecord[]  (closed weeks, oldest first)
WarbandeerApi:GetTravelersLog()           → TravelersLogData?  (account-wide monthly Traveler's Log: pct, earned/max, rewards waiting, Tender, resetAt)
WarbandeerApi:RefreshCurrentCharacterField(broker, field)  -- synchronous single-field re-scan
WarbandeerApi:GetRaidLocks(char?)          → RaidLock[]  -- this week's raid lockouts, most-prestigious/most-progressed first (ns.RaidLocks)
WarbandeerApi:ResolveRecipeOutput(recipeID) → RecipeGearInfo|false|nil
    -- what prof gear a recipe crafts ({itemID, rarity, equipLoc, skillID}),
    -- from the account-wide cache; false = not prof gear, nil = item not in
    -- the client cache yet (load requested — retry later)
WarbandeerApi:ClassifyProfGearItem(itemID)  → skillID?, equipLoc?
    -- static class/subclass test: parent prof skillLineID + INVTYPE the item is
    -- gear for, or nil if not profession gear (synchronous, no item load)
WarbandeerApi:GetBankProfGear(skillID)     → BankGearEntry[]
    -- prof gear for a profession cached across every opened bank — warband,
    -- character, and guild ({itemID, equipLoc, rarity, count, source,
    -- sourceType}); source is a display label, sourceType ∈ warband/character/
    -- guild; empty until a bank is opened
WarbandeerApi:ClassifyGearItem(itemID)     → equipLoc?, classID?, subClassID?
    -- static test: equippable armour/weapon filling a real slot (nil for
    -- cosmetics/non-gear); synchronous, shared by the gearbag + bank scanners
WarbandeerApi:GetCharacterGearCandidates(char?) → { bags: GearCandidate[], bank: GearCandidate[] }
    -- a character's loose equippable gear: its bags (gearbag broker) + its
    -- personal bank (last bank scan).  The "held for them" pool; last-seen
WarbandeerApi:GetWarbandBankGear()         → GearCandidate[]
    -- equippable gear in the warband (account) bank; the shared "better
    -- elsewhere" pool; empty until the warband bank has been opened
WarbandeerApi:GetMail(char?)               → MailData?
    -- a character's last-seen mail cache { scannedAt, count, expiries[], items, money, hasMail };
    -- nil until it has visited a mailbox OR has new mail waiting. `hasMail` is the
    -- HasNewMail() minimap-envelope state (true while unread mail is waiting), tracked on
    -- UPDATE_PENDING_MAIL so it persists without opening the mailbox; the inbox-content
    -- fields stay nil until a mailbox is actually scanned
WarbandeerApi:GetAuctions(char?)           → AuctionData?
    -- a character's last-seen owned-auction cache { scannedAt, count, expiries[],
    -- value, bids }; nil until it has visited the auction house
WarbandeerApi:GetQuestStatus(questID)      → { active: {name,classKey}[], completed: {name,classKey}[] }?
    -- which tracked characters are on / have completed a quest (each list sorted
    -- by name); nil when none.  Drives ShadowsOfUI-Quests
WarbandeerApi:GetReputations(char?)        → table<factionID, FactionStanding>?
    -- a character's cached faction standings; nil until seen since v21
WarbandeerApi:GetProfessionKnowledge(char?) → table<skillLineID, ProfessionKnowledgeEntry>?
    -- a character's weekly profession knowledge (per-source {done,total} + aggregate);
    -- nil until seen since v39.  Drives Warbandeer's Midnight Profs "Know" column
WarbandeerApi:GetFactionStandings(factionID) → { name, classKey, label, rank, done, paragon? }[]?
    -- every tracked character's standing with one faction, highest rank first;
    -- nil when no character has any standing.  Drives ShadowsOfUI-Reputations
WarbandeerApi:GetItemCounts(itemID)        → ItemCountReport?
    -- account-wide counts of an item: { total, warband, characters =
    -- {{name, classKey, realm?, bags, bank, mail, total}} (sorted total desc), guilds =
    -- {{name, count}} }.  realm is set only when it differs from the current
    -- character's realm (cross-realm note).  Per-char = bags (inventory broker) + personal bank + mail
    -- (db.bank.characters[name].items); warband = db.bank.warband.items (once);
    -- guilds = db.bank.guilds[*].items.  All last-seen; nil when nothing is held
WarbandeerApi:GetWorldQuestRewards(char?)  → WorldQuestReward[]
    -- a character's cached active world-quest gear rewards (GearCandidate +
    -- {questID, title, zone, mapID, endTime}); captured while that char was logged in,
    -- last-seen.  Expired quests (endTime passed) are dropped on read.  Consumed
    -- by ShadowsOfUI-Upgrade's WorldQuestUpgrades; empty until the char has scanned
WarbandeerApi:GetDelveStats(delveName, tier?) → { name, classKey, avg, count, scope, avgXp?, xpCount? }[]?
    -- per-character average completion time for one delve, current char first then
    -- by name.  avg = rounded mean seconds of recent runs; scope = "T<tier>" when
    -- that tier has samples, else "all" (the all-tiers aggregate fallback).  avgXp/
    -- xpCount = mean XP gained per run where recorded (leveling runs only; nil at max).
    -- nil when no character has timed it.  delveName is normalized via ns.NormalizeDelveKey.
    -- Data from the per-char delveTimes cache (data/delvetimes.lua); drives ShadowsOfUI-Delves
WarbandeerApi:GetDungeonStats(dungeonName, level?, difficultyID?) → { name, classKey, avg, count, scope, avgXp?, xpCount? }[]?
    -- sibling of GetDelveStats over two axes.  Pass difficultyID for a non-keyed (normal/heroic/
    -- finder) run → reads the diffs store, scope = the difficulty label; else reads the keyed M+
    -- axis for `level`, scope = "+<level>".  Either axis falls back to its all-buckets aggregate
    -- (scope "all").  avgXp/xpCount as above (leveling runs only).  Non-keyed runs are recorded
    -- only for Dungeon-Finder (queued) completions (walk-ins deferred, #378).  Data from the
    -- per-char dungeonTimes cache (data/dungeontimes.lua).
WarbandeerApi:GetAppliedGlyphs(char?, specID?) → { itemID, label, glyph, applied, source? }[]?, scanned
    -- applied cosmetic appearance glyphs for one of the character's specs (specID defaults to
    -- the active spec): the class catalog (ns.AppearanceGlyphs) merged with the char's last-seen
    -- applied-glyph set for that spec.  per-character + per-spec (last-seen).  nil for a class
    -- with no glyphs (Evoker); second return `scanned` is false when that spec has never been
    -- scanned (applied state unknown, not none).  Drives Warbandeer's Detail appearance card + spec picker
WarbandeerApi:GetAppearanceUnlocks(char?)  → { itemID, label, spell, unlocked, source? }[]?
    -- account-wide appearance unlocks for the char's CLASS (Druid Marks / travel-form
    -- glyphs, Warlock demon Grimoires + green fire).  `unlocked` read live via
    -- C_QuestLog.IsQuestFlaggedCompletedOnAccount, so it's identical for every character of
    -- the class (no per-character storage).  A progressive row (green fire) carries
    -- startItem/startQuest and resolves its itemID to the next step — starter item until the
    -- chain begins, then the reward — so the cell always points at what to do next.
    -- nil for every class but Druid + Warlock
WarbandeerApi:GetClassMounts(char?)        → { label, mountSpell, icon, owned, source? }[]?
    -- account-wide class mounts for the char's CLASS (Legion order-hall mounts + spec-gated colour
    -- tints): the ns.ClassMounts catalog resolved live against the mount journal — mountID from
    -- C_MountJournal.GetMountFromSpell/Item, then GetMountInfoByID for name/icon/isCollected.
    -- `owned` is identical for every character of the class (no storage); an id that doesn't resolve
    -- yields its row (owned=false, reads "missing").  GetMountFromItem returns nil until the item's
    -- data is loaded, so login.lua warms the catalog items + this getter re-requests any cold one (a
    -- later render resolves).  DK is ONE entry whose colour follows the spec (not three).  nil for a
    -- class with no roster (Evoker).  Drives the Detail card's CLASS MOUNTS list
WarbandeerApi:GetLearnedUnlocks(char?)     → { itemID, label, spell, known, source? }[]?, title
    -- each entry's `source` (GetAppliedGlyphs / GetAppearanceUnlocks / GetLearnedUnlocks) = the
    -- curated "how to obtain" hint from data/collectiblesources.lua, shown in the Detail tooltip for
    -- an unowned/unapplied entry; GetClassMounts instead carries its `source` inline on the catalog entry
    -- learned class unlocks (Druid "Tome of the Wilds", Hunter "Tomes & Tames"): the catalog
    -- (ns.LearnedUnlocks) merged with the char's known set (which folds in innate racial
    -- grants).  per-character LEARNED spells (not per-spec); last-seen.  second return = the
    -- per-class section title.  nil for a class with no unlocks
WarbandeerApi:GetPets(char?)               → PetsData?
    -- a Hunter's last-seen pet roster { scannedAt, active: PetRecord[], stable: PetRecord[] };
    -- each PetRecord = { name, family, level, spec, icon, creatureID, displayID, exotic }.  Captured
    -- at a stable master (the lists aren't readable elsewhere); nil until the character has visited
    -- one, and always nil for non-Hunters.  Drives Warbandeer's Detail Pets button + docked roster panel
WarbandeerApi:GetDemons(char?)             → DemonsData?
    -- a Warlock's last-seen demon roster { scannedAt, list: DemonRecord[] } sorted by npcID; each
    -- DemonRecord = { species, name, npcID, seenAt }.  No enumeration API — fills in per summon
    -- (only the active demon is readable); nil until the Warlock has summoned any, always nil for
    -- non-Warlocks.  Drives the same Detail button + docked panel (a Warlock "Demons" branch)
WarbandeerApi:GetChallengeTames(char?)     → { label, creatureID, displayID?, category, note?, howTo?, owned, icon?, petName? }[]?
    -- a Hunter's curated Challenge-Tames checklist: the static ns.ChallengeTames catalog (rare/
    -- "secret" tames) merged (ns.MergeChallengeTames) against the captured pet roster (active +
    -- stable), matching locale-independent creatureID (+ a pinned displayID for a recolor entry).
    -- owned entries carry the matched pet's family icon + its (renameable) petName.  returns the
    -- full list for any Hunter (empty roster → all-missing, so the aspirational list still shows);
    -- nil for non-Hunters.  aspirational → never feeds /wbc missing.  Drives Warbandeer's ChallengeTamesPanel
WarbandeerApi:GetTitles(char?)             → TitlesBroker?
    -- a character's earned player titles { known: TitleRecord[]?, current: titleMaskID?, currentName:
    -- string? }; each TitleRecord = { id, name } (known sorted by name).  Last-seen (logged-in char
    -- only); nil until the character has been seen since v37.  Drives Warbandeer's Summary Titles
    -- column (current title); `known` feeds a follow-up earned/earnable Titles view
WarbandeerApi:GetHousing(char?)            → { active, title? }?
    -- which neighborhood endeavor a character is feeding now: active = "alliance"|"horde" (the faction house
    -- its endeavor XP flows to) + that endeavor's title; nil when none.  Per-character, last-seen (ns.ShapeHousing).
    -- Drives Warbandeer's Summary Endeavors column
WarbandeerApi:GetHouses()                  → { alliance?, horde? }?
    -- account-wide per-house view (HouseView = { name, level, favor, title, progress, required, resetAt, xp });
    -- xp = GetAvailableHouseXP (House XP still earnable this cycle — a countdown).  nil until a house is captured
    -- (ns.ShapeHouses).  Drives Warbandeer's Overview Houses section
```

`GearCandidate` = `{ link, itemID, ilvl?, equipLoc, classID, subClassID, quality?, reqLevel? }` (ilvl is the
**effective** (context-scaled) level via `C_Item.GetCurrentItemLevel(ItemLocation)`, captured when
warm; recompute from `link` if nil). `quality` (v17, Enum.ItemQuality) is captured at scan time so the
upgrade finder's artifact gate fires even when the candidate is later read for an offline alt with the
item cold (`GetItemQualityByID` is nil for an uncached item); absent on entries cached before v17. `reqLevel`
(v18) is the required character level, also captured at scan time (item warm) so a consumer's "can equip
now?" gate reads consistently for an offline alt's cold gear instead of falling back to a live (cold, →nil)
`GetItemInfo` lookup; absent on entries cached before v18. Effective, not the link's unscaled `GetDetailedItemLevelInfo`,
so it matches how `equipment.slots` measures equipped ilvl — else a downscaled item over-reports and
the upgrade finder fakes a huge gain.

Also on the API table: `ALLIANCE_RACES`, `HORDE_RACES`, `professionInfo`.
(`AliasSettingsCategory` is set on this same table by **Warbandeer_Alias**, not here. Settings-panel nesting now goes through LibNAddOn's shared parent registry — `ns:GetSettingsParent("Warbandeer")` — rather than a published `SettingsCategory` field.)

## Per-Character Struct (`db.characters[name]`)

```lua
-- Top-level (set once at creation in initialize):
name, classId, className, classKey, race, raceId, raceIdx, isAlliance, realm
sex           -- UnitSex code (2=male, 3=female); refreshed each login for the active char (alts seen before this field default to male at render time)
guid          -- "Player-<realmID>-<lowGUID>" UnitGUID; refreshed each login for the active char (alts not yet seen since v30 lack it until next login)
guild         -- guild name (nil when unguilded); refreshed each login + on PLAYER_GUILD_UPDATE for the active char (alts seen before this field lack it until next login)
lastRefresh   -- set by refreshQueue when a full scan completes

-- Sub-tables (one per broker, populated by their fields):
basic = {
  level,
  specialization = { primary, active, role, key, id },  -- active = PLAYED spec, primary = LOOT spec; role/key/id follow the played (active) spec; id = numeric spec ID (locale-independent; v13)
  professions    = { primary, secondary, fishing, cooking },  -- {name, skillID, ...} each
  xp             = { percent, restPercent, isResting, recordedAt }?,
}
stats = {                                              -- v16
  secondary = { crit, haste, mastery, versatility },   -- each { pct, rating }; mastery also { spell } (active-spec passive id)
}
currency = {
  RestoredCofferKey,                                   -- quantity (currency 3028)
  gold,                                                -- GetMoney(), copper
  CofferKeyShard = { quantity, earned, weeklyMax, capped }?, -- (3310) weekly earn cap (capped = earned >= maxWeeklyQuantity, 600); RESET_WEEKLY
  Catalyst       = { quantity, max, capped }?,         -- Dawnlight Manaflux (3378), capped = bank full
  HeroDawncrest  = { quantity, earned, max, capped },
  MythDawncrest  = { quantity, earned, max, capped },
  NebulousVoidcore = { quantity, earned, max, capped }?,   -- (3418) season cap: totalEarned vs maxQuantity, grows +2/week
  UntaintedManaCrystal = { quantity, earned, max, capped }?, -- (3356) weekly-earn cap 250 (hard cap 1000); RESET_WEEKLY
  ShardOfDundun = { quantity, earned, max, weeklyMax, capped }?, -- (3376) earn 8/wk + hold 8 (both caps 8); capped = held >= max OR earned >= weeklyMax; empowers the Abundance world event; RESET_WEEKLY
  FieldAccolade,                                       -- quantity (currency 3405); consumed by Warbandeer's fieldaccolade Summary column
  UnalloyedAbundance,                                  -- quantity (currency 3377); consumed by Warbandeer's unalloyedabundance Summary column
}
items = {
  bags = { [1..N] = {id, slots}, GoblinMiniFridge?, ArathorSatchel?, PortableRefridgerator? },
  reagentBag = { id, slots },
}
inventory = {                                          -- v19
  counts = { [itemID] = qty }?,                        -- every item in bags + reagent bag, summed; last-seen
}
mail = {                                                -- v20; last-seen, scanned at a mailbox
  scannedAt, count,                                     -- inbox-content fields; nil until a mailbox is opened
  expiries = { absExpiryTs, ... },                     -- absolute server-time stamps, ascending (one per mail)
  items    = { [itemID] = qty },                       -- attached items, summed
  money,                                               -- attached gold, copper
  hasMail,                                              -- v25; HasNewMail() state, true while unread mail waits (UPDATE_PENDING_MAIL); nil when clear
}?
questlog = {                                            -- v23; broker, captured each login + on quest events
  active    = { [questID] = true },                     -- currently-active quests
  completed = { [slot] = bits },                         -- completed-quest bitmap (32-bit slots; read via ns.IsQuestCompleted)
}?
delveTimes = {                                          -- v27; event tracker (data/delvetimes.lua), per character
  active = { key, name, tier, start, xp },              -- in-progress run (server-time start; survives /reload); nil between runs
                                                         --   xp = { xp, maxXP, level } run-start snapshot (nil at max level)
  runs   = { [normalizedKey] = {                        -- key = ns.NormalizeDelveKey(name)
    name,                                                -- canonical delve name (most recent)
    tiers = { [tier] = { seconds, ... } },               -- rolling window (last 10) per tier; tier 0 = unknown
    xps   = { [tier] = { xpGained, ... } },              -- v31; parallel window of per-run XP (leveling runs only)
  } },
}?
dungeonTimes = {                                        -- v31; event tracker (data/dungeontimes.lua), per character
  active = { kind, key, name, start, xp,                -- in-progress run; nil between runs. kind = "mplus" | "dungeon"
             level, diffID },                           --   level (keyed M+) / diffID (non-keyed) per kind
  runs   = { [normalizedKey] = {                        -- mirrors delveTimes; key via ns.NormalizeDelveKey(dungeonName)
    name,                                                -- canonical dungeon name (most recent)
    tiers   = { [keyLevel] = { seconds, ... } },         -- v31; keyed M+ durations per keystone level (last 10); 0 = unknown
    xps     = { [keyLevel] = { xpGained, ... } },        -- v31; parallel per-run XP window (nil at max level, i.e. all real M+)
    diffs   = { [difficultyID] = { seconds, ... } },     -- v32; non-keyed (finder) durations per difficulty (last 10)
    diffXps = { [difficultyID] = { xpGained, ... } },    -- v32; parallel per-run XP window (leveling runs only)
  } },
}?
auctions = {                                            -- v22; last-seen, scanned at the AH
  scannedAt, count,                                     -- count = active owned auctions at scan
  expiries = { absExpiryTs, ... },                      -- active auctions only, ascending
  value,                                                -- gold tied up (buyout/bid), copper
  bids,                                                 -- auctions the character is bidding on
}?
reputations = {                                         -- v21; per-faction standings (broker)
  factions = { [factionID] = {                          -- every faction with a standing
    name, label,                                        -- "Exalted" / "Renown 12" / "Best Friend"
    rank, done,                                          -- rank = reaction/renown/friendship level; done = at cap
    paragon,                                             -- earning paragon rewards past the cap
    accountWide,                                         -- shared warband-wide (rendered once, not per character)
    categoryId,                                          -- v24; top-level reputation header's factionID (0 = uncategorized); locale-proof expansion-page key for Warbandeer's Reputations view
    current?, threshold?,                                -- v42; absolute progress within the current rank/level (bar-fill numerator/denominator: renown XP / friendship or reaction points past the tier floor); nil when there's no next tier (e.g. a maxed standard faction)
    paragonCurrent?, paragonThreshold?,                  -- v42; progress within the current paragon reputation-bag cycle, when paragon is true
  } }?,
}?
gearbag = {
  items = { {link, itemID, ilvl?, equipLoc, classID, subClassID} }?,  -- equippable bag gear (v13)
}
professions = {
  details = { [skillLineID] = {
    expansions = { {name, skillLevel, maxSkillLevel} }?, specPoints?,
    recipes = { [expKey] = { learned = { {id, name, quality?, qualityConc?} }, total } }?,
                                                         -- expKey: midnight/tww/df; quality/qualityConc
                                                         -- = crafting tier reachable now w/o and w/ concentration
                                                         -- (current-exp prof-gear recipes only)
  } }?,
  gear = { [parentSkillLineID] = { slots = { [invSlot] = {name,link,ilvl,rarity,tier,expacID} } } }?,
}
concentration = {
  data = { [skillLineID] = { name, currencyId, quantity, maxQuantity,
                             rechargingAmountPerCycle, rechargingCycleDurationMS, lastUpdated } }?,
}
artisanCurrency = {
  data = { [skillLineID] = { name, currencyId, quantity, maxQuantity, lastUpdated } }?,
                                                       -- current-expansion artisan crafting currency per crafting prof
}
professionKnowledge = {                                -- v39; broker (data/professionknowledge.lua); weekly, cleared on RESET_WEEKLY
  data = { [skillLineID] = { treatise = {done,total}?, weeklyQuest = {done,total}?,
                             treasure = {done,total}?, gathering = {done,total}?,
                             done, total } }?,          -- per-Midnight-profession weekly knowledge-point progress
}
glyphs = {                                             -- v33/v34; broker (data/glyphs.lua)
  applied = { [specID] = { [glyph] = true } }?,        -- cosmetic glyph ids applied, per spec (all specs captured where WoW exposes them; active spec always present); last-seen
  unlocks = { [spell] = true }?,                       -- v34; learned class-unlock spell ids (Druid Tome of the Wilds, Hunter Tomes & Tames); per-character (not per-spec); nil for a class with none
}                                                      -- account-wide appearance unlocks (incl. green fire) are read live, not stored here
pets = {                                               -- v35; event scanner (data/pets.lua); Hunter-only, last-seen at a stable master
  scannedAt,                                            -- server time of the last stable-master scan
  active = { PetRecord, ... },                          -- currently-loaded Call Pet slots
  stable = { PetRecord, ... },                          -- stabled pets
                                                         --   PetRecord = { name, family, level, spec, icon, creatureID, displayID, exotic }
}?                                                     -- nil until the Hunter has visited a stable; always nil for non-Hunters
                                                       -- (matched against the static ns.ChallengeTames catalog by GetChallengeTames → Warbandeer's ChallengeTamesPanel checklist; the catalog isn't stored)
demons = {                                             -- v36; event scanner (data/demons.lua); Warlock-only, last-seen per summon
  scannedAt,                                            -- server time of the last demon capture (any demon)
  list = { DemonRecord, ... },                          -- one record per demon family seen, npcID-deduped, first-seen order
                                                         --   DemonRecord = { species, name, npcID, seenAt } — species from UnitCreatureFamily, npcID from the pet GUID
}?                                                     -- nil until the Warlock has summoned a demon (no enumeration API); always nil for non-Warlocks
titles = {                                             -- v37; broker (data/titles.lua); last-seen, logged-in char only
  known = { TitleRecord, ... }?,                        -- earned player titles, sorted by name; TitleRecord = { id = titleMaskID, name = trimmed display name }
  current,                                             -- featured/active titleMaskID (nil when no title is active)
  currentName,                                         -- featured title display name (nil when none) — Summary column source
}?                                                     -- nil until the character is seen since v37; drives Warbandeer's Summary Titles column (current title) via API:GetTitles
housing = {                                             -- v40; broker `active` field (data/housing.lua); per-character
  active,                                              -- neighborhoodGUID this character is currently feeding (nil when in no endeavor)
}?                                                     -- account-wide house/endeavor data lives in db.housing, not here; drives the Summary Endeavors column via API:GetHousing
quests = {
  UndermineStoryMode,
  WWIRep = { complete, missing, Dornogal, Assembly, Hallowfall, Azjkahet, Undermine, Arathi, Karesh },
  LumberAxe,                                           -- has Find-Lumber tracking spell
  delves = { complete, missing, [label] = bool },
  CatalystUnbound,                                     -- bool: achievement 61519 wasEarnedByMe (per-character)
}
worldquests = {                                        -- v14
  rewards = { {                                        -- GearCandidate + quest metadata
    link, itemID, ilvl, equipLoc, classID, subClassID, -- GearCandidate fields
    questID, title, zone, mapID, endTime,              -- source quest + zone uiMapID + expiry (server time)
  } }?,
}
dailies = {}
weeklies = {
  DMF,                                                 -- RESET_SUNDAY
  preMidnight = { eight, three },
  delversBounty,                                       -- boolean, weekly Delver's Bounty claimed (quest 86371)
  caches,                                              -- count
  vault = VaultRewards?, hasUnclaimedVault,
  vaultSlots = VaultTracks?,                           -- per-track (Raid/Dungeons/World) 3-slot detail w/ reward ilvls
  keystone?,                                           -- owned keystone level
  keystoneMap?,                                         -- v41; owned keystone dungeon (challenge-map id; name via C_ChallengeMode.GetMapUIInfo)
  dungeons = { done, max }?,                           -- M+ runs + vault threshold
}
instances = {
  locks = { [instanceID] = { [difficultyID] = { name, total, progress, reset, extended, isRaid } } },
}
equipment = {
  slots = { Head/Neck/.../OffHand = { name, link, ilvl, track?, trackLevel?, equipLoc, classID, subClassID, emptySockets, enchant? } },  -- emptySockets (v15): count of unfilled gem sockets, via GetItemNumSockets − gemmed sockets (GetItemGemID); NOT GetItemStats EMPTY_SOCKET_* (stale under the Midnight Gem Manager). enchant: applied permanent-enchant NAME ("Enchant Helm - Rune of Avoidance") read from the live tooltip's "Enchanted:" line at scan time (trailing quality-tier atlas stripped); nil if unenchanted/un-rescanned. Lets ShadowsOfUI-Upgrade flag a WRONG enchant warband-wide
  ilvl, trackScanned,
}
artifacts = {
  hidden       = { [SpecKey] = bool },
  hiddenColors = { wq = {progress, goal}, dungeon = {...}, kills = {...} },
  classHall,
}
playtime = {
  total,                                               -- total /played in seconds
  byPatch = { ["12.0.5"] = baseSeconds, ... },         -- /played at first login per patch
  byDay   = { ["2026-06-28"] = seconds, ... }?,        -- v29; logged-in seconds per LOCAL calendar day (wall-clock session accounting)
}
```

## Broker Definitions

| Broker | Fields | Events | Resets |
|---|---|---|---|
| `basic` | level, specialization, professions, xp | `PLAYER_LEVEL_UP` (500ms), `PLAYER_SPECIALIZATION_CHANGED` (specialization), `PLAYER_XP_UPDATE`/`UPDATE_EXHAUSTION`/`PLAYER_UPDATE_RESTING` (1000ms) | — |
| `currency` | RestoredCofferKey, gold, CofferKeyShard, Catalyst, HeroDawncrest, MythDawncrest, NebulousVoidcore, UntaintedManaCrystal, ShardOfDundun, FieldAccolade, UnalloyedAbundance | `PLAYER_MONEY` (gold), `CURRENCY_DISPLAY_UPDATE` (Catalyst + NebulousVoidcore + ShardOfDundun, id-filtered) | CofferKeyShard, NebulousVoidcore, UntaintedManaCrystal, ShardOfDundun: `RESET_WEEKLY` |
| `items` | bags, reagentBag | — | — |
| `inventory` | counts | `BAG_UPDATE_DELAYED` (500ms) | — |
| `reputations` | factions | `UPDATE_FACTION` (rate-limited: self-trigger suppression + `ns:debounce` 2s + 6s throttle — full faction walk too heavy per-event) | — |
| `questlog` | active, completed | active: `QUEST_ACCEPTED`/`QUEST_REMOVED`/`QUEST_TURNED_IN` (1000ms); completed: `QUEST_TURNED_IN` (3000ms) | — |
| `gearbag` | items | `BAG_UPDATE_DELAYED` (500ms) | — |
| `professions` | details, gear | `TRADE_SKILL_SHOW` (details, 0.5s C_Timer); `PLAYER_EQUIPMENT_CHANGED` (gear, 500ms + item load) | — |
| `concentration` | data | `CURRENCY_DISPLAY_UPDATE` (1000ms debounce; unfiltered) | — |
| `artisanCurrency` | data | `CURRENCY_DISPLAY_UPDATE` (1000ms debounce; unfiltered) | — |
| `glyphs` | applied, unlocks | `SPELLS_CHANGED`, `PLAYER_SPECIALIZATION_CHANGED` (1000ms debounce) | — |
| `quests` | UndermineStoryMode, WWIRep, LumberAxe, delves, CatalystUnbound | `QUEST_TURNED_IN`, `QUEST_ACCEPTED`, `QUEST_REMOVED`, `UNIT_QUEST_LOG_CHANGED`, `SPELLS_CHANGED`, `ACHIEVEMENT_EARNED` | — |
| `worldquests` | rewards | `QUEST_LOG_UPDATE`, `ZONE_CHANGED_NEW_AREA` (debounced; retries while reward data loads) | — |
| `dailies` | (empty) | — | — |
| `weeklies` | DMF, preMidnight, caches, vault, vaultSlots, hasUnclaimedVault, keystone, keystoneMap, dungeons | `QUEST_TURNED_IN`, `WEEKLY_REWARDS_UPDATE` (1000ms), `CHALLENGE_MODE_COMPLETED` | DMF: `RESET_SUNDAY`; rest: `RESET_WEEKLY` |
| `instances` | locks | `INSTANCE_LOCK_STOP` | `RESET_WEEKLY` |
| `equipment` | slots, ilvl, trackScanned | `PLAYER_EQUIPMENT_CHANGED` (`ITEM_DATA_LOAD_RESULT` + bounded fallback re-scan) | — |
| `stats` | secondary (crit/haste/mastery/versatility {pct,rating}) | `COMBAT_RATING_UPDATE` (1000ms debounce — fires constantly in combat) | — |
| `artifacts` | hidden, hiddenColors, classHall | `QUEST_TURNED_IN` | — |
| `playtime` | total, byPatch, byDay | `TIME_PLAYED_MSG` (via `RequestTimePlayed()` on Init); `PLAYER_LOGOUT` + a 60s `C_Timer.NewTicker` flush the `byDay` session accumulator | — |

Reset constants: `RESET_SUNDAY = 0`, `RESET_DAILY = 1`, `RESET_WEEKLY = 7`.

## How a Broker Field Works

A `Broker` (from `broker.lua`) holds a `fields` table; each field is `{ get, event?, eventDelay?, eventHandler?, eventFilter?, maxLevel?, order?, resetOn?, reset? }`.

- **`get(self, toon, currentValue)`** computes the new value; `currentValue` lets a field merge into / preserve cached data (e.g. `professions.details`, `concentration.data`).
- **`event`** (string or list) auto-registers a handler that re-runs `get`. With `eventDelay` set, that re-run is **debounced** via LibNAddOn's keyed reset-trailing `ns:debounce` (keyed `broker.field`): a burst of the event collapses to a single `get` once it settles `eventDelay` ms after the last event — not one scan per event. Without `eventDelay` the `get` runs synchronously on every event (only do this for rare events or behind an `eventFilter`). Provide a custom `eventHandler` for incremental updates (e.g. `quests.WWIRep` decrements `missing` rather than re-scanning) or tighter rate-limiting (e.g. `reputations`' self-trigger suppression + throttle).
- **`maxLevel = true`** skips the field for sub-max-level characters (both in `refreshQueue` and `RefreshCurrentCharacterField`).
- **`resetOn` / `reset`** clear/seed the field at the matching reset boundary (`InitBrokers` walks all characters at login when a boundary has passed). Fields with `resetOn` but no `reset` are nilled. The daily/weekly anchors are recomputed per login from the seconds-until APIs and can jitter by a second, so a reset only fires when the anchor advanced by more than `RESET_SLACK` (12h). The **Sunday** anchor (`RESET_SUNDAY`, used by `weeklies.DMF`) is derived from the epoch alone (`GetServerTime()` → UTC day-of-week math), never from `GetCurrentCalendarTime()` — that call returns a zeroed struct (`weekday=0`) when the calendar isn't warm yet at addon-load, which turned the old formula's `-(weekday-1)*day` into `+1 day` and pushed the anchor into the future, firing a spurious Sunday reset that wiped every character's DMF flag. The epoch-only anchor needs no calendar API, so it's always valid and identical across all realms/timezones. `InitBrokers` also clamps a stored future Sunday anchor (left by the old bug) back down without resetting, so the next genuine boundary still fires on schedule.
- **`order`** sorts the scan within a broker (e.g. `basic.level` runs first so other fields can read it).

## Gotchas

- **`GetCharacterData` returns a live reference, not a copy** — mutating it writes straight into the DB. (A `--todo` in `api.lua` notes this.)
- **`refreshQueue` paces one *field* (not one broker) per 100ms** via `ns:delay` to avoid a login frame spike. `lastRefresh` is stamped only when the queue drains. **Each field's `get` is `pcall`-isolated**: `ns:delay` clears its `OnUpdate` before invoking the tick, so an unguarded throw inside a `get` (e.g. a currency `GetCurrencyInfo(id).quantity` where the currency is undiscovered → nil index) would skip the chain re-arm and silently strand every field *after* the failing one (and never stamp `lastRefresh`). The `pcall` keeps the cached value on error and continues, so one bad field can't halt the whole refresh.
- **Per-recipe crafting `quality`/`qualityConc` is a conservative skill-floor estimate.** Captured with empty reagents (`GetCraftingOperationInfo(id, {}, nil, false/true)`), so it's the worst-case tier the character reaches on skill alone — better mats only improve on it. Per-character and window-driven like the rest of `details`, so it stays nil until the character reopens that profession window.
- **`professions.details` scans are window-driven and merge-preserving.** Recipes/spec points are only queryable while a trade-skill window is open; the scan captures the opened profession's ID *before* the 0.5s timer (the player may switch professions meanwhile) and per-field-nil-guards against the API returning empty during load, so partial scans never wipe good cached data.
- **`professions.gear` and `equipment.slots` pre-request item data.** WoW item APIs return nil until loaded, so both fire `RequestLoadItemData` on `PLAYER_EQUIPMENT_CHANGED` and re-`Update` from `ITEM_DATA_LOAD_RESULT` once the outstanding request count hits zero. Always merge onto cached values (their `get` preserves a slot whose item isn't loaded yet rather than dropping it). **`ITEM_DATA_LOAD_RESULT` does NOT fire for an item whose data is already cached** (the common case: equipping straight from your bags), which strands the pending set and leaves the cache showing the pre-swap gear until the next reload/refresh. Both `equipment.slots` and `professions.gear` guard this with a bounded generation-guarded fallback re-scan (`scheduleFallback`, `FALLBACK_DELAY`×`MAX_FALLBACKS`, gated by an `anyUnloaded()` slot check); whichever of the event-path Update or the fallback lands first refreshes the cache, the other is idempotent.
- **`playtime` bypasses the field system.** `TIME_PLAYED_MSG` is async, so the broker overrides `Init` to register its own handler and calls `RequestTimePlayed()`; `byPatch[patch]` is written only on the first login of a patch. The `byDay` per-day buckets do **not** use `/played` at all — they're wall-clock (`GetServerTime`) session accounting flushed on a ticker + `PLAYER_LOGOUT` (see `data/playtime.lua` file note). Wall-clock-since-login equals the `/played` delta within a session (both measure logged-in time), but needs no async round-trip and splits cleanly at local midnight.
- **Warband wealth is account-wide, stored once at `db.warband`** (the bank is shared), not duplicated per character. `GetWarbandWealth` = `bankGold` + last-known `currency.gold` of every character. `RolloverWarbandWeek` closes elapsed weeks at the `ns.LAST_RESET` boundary, using last-seen wealth as the closing figure.
- **Evokers (classId 13) have no class hall** — `artifacts.classHall`/`hiddenColors` short-circuit for them.
- **World-quest scanning is bundled-continent, any level.** `data/worldquests.lua`'s `WQ_CONTINENTS` is the current expansion's WQ continent map ID(s) (expanded to zone children at scan time, so all zones are covered regardless of where the player stands); **update it each expansion**. Not max-level-gated — some WQs reward gear before the cap. Reward data is only readable for the logged-in character, so alts keep their last-seen cache (expired entries dropped on read by `endTime`). `WQ_ILVL_CEILING` (220) skips the map walk for fully-geared characters (the only level-related guard). The reward ilvl is the value scaled to the character that scanned it, so it's only ever compared against that same character's slots.

## SavedVariables (`WarbandeerCharDB`)

```lua
{ version = 41, numCharacters, lastDailyReset, lastReset, lastSundayReset,
  characters = { ["Name"] = Character },
  -- account-wide Traveler's Log (Trading Post monthly activity) snapshot (v38); shared,
  -- self-seeded + refreshed by data/travelerslog.lua from the C_Perks* APIs each login/update
  travelersLog = {
    month, monthName, resetAt,             -- activePerksMonth, display name, server-time of reset
    earned, max, pct,                      -- points earned (capped), monthly cap, earned/max
    completedCount, totalCount, tender,    -- activities done/total, current Trader's Tender balance
    rewards = { count, pendingTender, items = { itemID } },  -- uncollected chests waiting + Tender/items
  },
  -- account-wide housing/endeavor store (v40); per-neighborhood faction + endeavor, per-house level/favor
  housing = {
    neighborhoods = { [neighborhoodGUID] = { isAlliance?, name?, title?, progress?, required?, resetAt?, xp? } },  -- xp = GetAvailableHouseXP (still-earnable this cycle)
    houses = { [houseGUID] = { neighborhoodGUID?, name?, level?, favor? } },
  },
  -- account-wide warband wealth (v8); not per-character
  warband = {
    bankGold,                              -- last-known account bank gold (copper)
    week = { start, baseline },            -- open week: reset timestamp + wealth at week start
    history = { { start, ending, made } }, -- closed weeks, oldest first (made = ending − baseline)
  },
  -- account-wide recipe → prof-gear cache (v10); static game data, wiped on client build change
  recipeGear = {
    build,                                 -- "version-buildNum" the cache was resolved against
    recipes = { [recipeID] = { itemID, rarity, equipLoc, skillID } | false },
  },
  -- account-wide bank gear cache (v11; equippable `equip` lists added v13; full
  -- `items` count maps added v19); last-seen, scanned on bank open.  prof-gear
  -- entries: { itemID, skillID, equipLoc, rarity, count }; equip entries (warband +
  -- personal banks only): GearCandidate; items: { [itemID] = count } over everything
  bank = {
    warband    = { scannedAt, gear = {...}, equip = {...}, items = {...} },   -- shared account bank
    characters = { ["Name"]      = { scannedAt, gear = {...}, equip = {...}, items = {...} } },
    guilds     = { ["GuildName"] = { scannedAt, gear = {...}, items = {...} } },  -- no equip (not an upgrade source)
  },
  -- account-wide UI preferences (v12); now legacy/unused — the wmissing copy-
  -- window font size moved to LibNUI's own DB (LibNUIDB.copyFontSize). Kept per
  -- the non-destructive policy; left in place for rollback safety.
  ui = { wmissingFontSize },                               -- legacy (stale)
  -- account-wide addon settings (v28); Settings panel Warbandeer → Logging
  settings = { combatLogging } }                           -- opt-in combat logging, default false
```
