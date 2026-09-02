local _, ns = ...

------------------------------------------------------------
-- Trinket index.
--
-- TrinketData.lua is stored per spec ("what should I equip?").
-- Loot decisions run the other way — you are staring at a trinket that
-- just dropped and want to know who in the raid it is actually good for.
-- This file builds that inverted index once at load and answers both
-- questions from the same data.
------------------------------------------------------------

ns.Trinkets = ns.Trinkets or {}
local T = ns.Trinkets

------------------------------------------------------------
-- Spec metadata derived from the "CLASS_SPEC" keys used by the
-- generated data files.
------------------------------------------------------------
local SPEC_LABEL = {
    DEATHKNIGHT_BLOOD     = { class = "DEATHKNIGHT", spec = "Blood",         role = "TANK"    },
    DEATHKNIGHT_FROST     = { class = "DEATHKNIGHT", spec = "Frost",         role = "DAMAGER" },
    DEATHKNIGHT_UNHOLY    = { class = "DEATHKNIGHT", spec = "Unholy",        role = "DAMAGER" },
    DEMONHUNTER_HAVOC     = { class = "DEMONHUNTER", spec = "Havoc",         role = "DAMAGER" },
    DEMONHUNTER_VENGEANCE = { class = "DEMONHUNTER", spec = "Vengeance",     role = "TANK"    },
    DEMONHUNTER_DEVOURER  = { class = "DEMONHUNTER", spec = "Devourer",      role = "DAMAGER" },
    DRUID_BALANCE         = { class = "DRUID",       spec = "Balance",       role = "DAMAGER" },
    DRUID_FERAL           = { class = "DRUID",       spec = "Feral",         role = "DAMAGER" },
    DRUID_GUARDIAN        = { class = "DRUID",       spec = "Guardian",      role = "TANK"    },
    DRUID_RESTORATION     = { class = "DRUID",       spec = "Restoration",   role = "HEALER"  },
    EVOKER_DEVASTATION    = { class = "EVOKER",      spec = "Devastation",   role = "DAMAGER" },
    EVOKER_PRESERVATION   = { class = "EVOKER",      spec = "Preservation",  role = "HEALER"  },
    EVOKER_AUGMENTATION   = { class = "EVOKER",      spec = "Augmentation",  role = "DAMAGER" },
    HUNTER_BEASTMASTERY   = { class = "HUNTER",      spec = "Beast Mastery", role = "DAMAGER" },
    HUNTER_MARKSMANSHIP   = { class = "HUNTER",      spec = "Marksmanship",  role = "DAMAGER" },
    HUNTER_SURVIVAL       = { class = "HUNTER",      spec = "Survival",      role = "DAMAGER" },
    MAGE_ARCANE           = { class = "MAGE",        spec = "Arcane",        role = "DAMAGER" },
    MAGE_FIRE             = { class = "MAGE",        spec = "Fire",          role = "DAMAGER" },
    MAGE_FROST            = { class = "MAGE",        spec = "Frost",         role = "DAMAGER" },
    MONK_BREWMASTER       = { class = "MONK",        spec = "Brewmaster",    role = "TANK"    },
    MONK_MISTWEAVER       = { class = "MONK",        spec = "Mistweaver",    role = "HEALER"  },
    MONK_WINDWALKER       = { class = "MONK",        spec = "Windwalker",    role = "DAMAGER" },
    PALADIN_HOLY          = { class = "PALADIN",     spec = "Holy",          role = "HEALER"  },
    PALADIN_PROTECTION    = { class = "PALADIN",     spec = "Protection",    role = "TANK"    },
    PALADIN_RETRIBUTION   = { class = "PALADIN",     spec = "Retribution",   role = "DAMAGER" },
    PRIEST_DISCIPLINE     = { class = "PRIEST",      spec = "Discipline",    role = "HEALER"  },
    PRIEST_HOLY           = { class = "PRIEST",      spec = "Holy",          role = "HEALER"  },
    PRIEST_SHADOW         = { class = "PRIEST",      spec = "Shadow",        role = "DAMAGER" },
    ROGUE_ASSASSINATION   = { class = "ROGUE",       spec = "Assassination", role = "DAMAGER" },
    ROGUE_OUTLAW          = { class = "ROGUE",       spec = "Outlaw",        role = "DAMAGER" },
    ROGUE_SUBTLETY        = { class = "ROGUE",       spec = "Subtlety",      role = "DAMAGER" },
    SHAMAN_ELEMENTAL      = { class = "SHAMAN",      spec = "Elemental",     role = "DAMAGER" },
    SHAMAN_ENHANCEMENT    = { class = "SHAMAN",      spec = "Enhancement",   role = "DAMAGER" },
    SHAMAN_RESTORATION    = { class = "SHAMAN",      spec = "Restoration",   role = "HEALER"  },
    WARLOCK_AFFLICTION    = { class = "WARLOCK",     spec = "Affliction",    role = "DAMAGER" },
    WARLOCK_DEMONOLOGY    = { class = "WARLOCK",     spec = "Demonology",    role = "DAMAGER" },
    WARLOCK_DESTRUCTION   = { class = "WARLOCK",     spec = "Destruction",   role = "DAMAGER" },
    WARRIOR_ARMS          = { class = "WARRIOR",     spec = "Arms",          role = "DAMAGER" },
    WARRIOR_FURY          = { class = "WARRIOR",     spec = "Fury",          role = "DAMAGER" },
    WARRIOR_PROTECTION    = { class = "WARRIOR",     spec = "Protection",    role = "TANK"    },
}
T.SPEC_LABEL = SPEC_LABEL

local CLASS_NAME = {
    DEATHKNIGHT = "Death Knight", DEMONHUNTER = "Demon Hunter",
    DRUID = "Druid", EVOKER = "Evoker", HUNTER = "Hunter", MAGE = "Mage",
    MONK = "Monk", PALADIN = "Paladin", PRIEST = "Priest", ROGUE = "Rogue",
    SHAMAN = "Shaman", WARLOCK = "Warlock", WARRIOR = "Warrior",
}

function T:SpecName(key)
    local meta = SPEC_LABEL[key]
    if not meta then return key end
    return meta.spec .. " " .. (CLASS_NAME[meta.class] or meta.class)
end

function T:SpecColor(key)
    local meta = SPEC_LABEL[key]
    local c = meta and RAID_CLASS_COLORS and RAID_CLASS_COLORS[meta.class]
    if c then return c.r, c.g, c.b end
    return 0.8, 0.8, 0.8
end

function T:ColorSpec(key)
    local r, g, b = self:SpecColor(key)
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255,
        self:SpecName(key))
end

------------------------------------------------------------
-- Inverted index: itemID -> { {specKey, rank, rel}, ... }
--
-- Built lazily so a missing/partial TrinketData.lua can never break
-- login. Ranks are 1-based positions inside that spec's own list, which
-- is what "only Frost DKs should roll on this" actually means: it is a
-- top pick for them and buried for everyone else.
------------------------------------------------------------
-- One index per fight style. bloodmallet sims single target and 5-target
-- separately and the orders differ a lot -- a trinket that leads on one
-- target can be mid-list in AoE -- so they cannot share a cache.
local cache = {}

-- Rankings recomputed at a specific item level, keyed spec|style|ilvl.
-- Declared up here so Rebuild can drop it: the item-level views are
-- derived from the same data and would otherwise outlive it.
local atCache = {}

T.DEFAULT_STYLE = "ST"

-- What a loot council actually hands out. Crafted trinkets, conquest
-- gear and world boss drops are all obtainable and some of them sim
-- well, but none of them is going to be linked in raid chat with five
-- people typing "need" -- so they are not what this page is for.
local COUNCIL_SOURCES = { Dungeon = true, Raid = true }

local function build(style)
    style = style or T.DEFAULT_STYLE
    local c = cache[style]
    if c then
        return c.byItem, c.allItems, c.thisTierItems, c.councilItems
    end

    local byItem, allItems = {}, {}
    cache[style] = { byItem = byItem, allItems = allItems }

    local data = ns.TrinketData
    if type(data) ~= "table" then return byItem, allItems end

    -- Which trinkets are current is decided by the specs bloodmallet has
    -- re-simmed for this season: if none of them rank an item, it is
    -- last season's and nobody is passing it round tonight.
    --
    -- Recorded on the bucket rather than filtered out here. The browse
    -- list wants only the current ones, but the tooltip is answering a
    -- different question -- you are hovering the thing, so you already
    -- know it exists, and who ranked it is still worth saying.
    --
    -- Specs still on last season's data keep contributing rankings to
    -- the trinkets that survive, tagged with the tier they came from.
    -- Dropping those as well would take a spec's opinion off the page
    -- entirely, which is a bigger loss than the tag is a caveat.
    local current, anyCurrent = {}, false
    local srcOf, anySource = {}, false
    local scaling, anyScaling = {}, false
    local ceilOf = {}
    local pendingSpecs = {}
    for specKey, styles in pairs(data) do
        local block = styles and styles[style]
        if block and type(block.list) == "table"
            and T:IsStaleTier(block.tier) then
            -- Awaiting a re-sim: has last season's ranking, has no
            -- opinion on anything that dropped since.
            pendingSpecs[#pendingSpecs + 1] = specKey
        end
        if block and type(block.list) == "table"
            and not T:IsStaleTier(block.tier) then
            anyCurrent = true
            for _, row in ipairs(block.list) do
                if row.id then
                    current[row.id] = true
                    -- Being in a current run is not the same as being
                    -- from current content: bloodmallet goes on simming
                    -- last tier's trinkets, and a couple from expansions
                    -- ago. What separates them is the upgrade ladder. A
                    -- trinket that drops now is simmed from 292 up to
                    -- 331, 334 or 344; one carried forward is stuck at
                    -- the single item level it capped out at.
                    if row.lo then
                        anyScaling = true
                        if row.lo < row.ilvl then scaling[row.id] = true end
                    end
                    -- The ceiling the item reaches, which is the level
                    -- every list ranks it at. Taken as the highest any
                    -- current spec sims it to: they agree, but a spec
                    -- whose list stops short should not lower it.
                    if row.ilvl and row.ilvl > (ceilOf[row.id] or 0) then
                        ceilOf[row.id] = row.ilvl
                    end
                end
            end
            -- Where each one drops. Taken from the current blocks only:
            -- last season's were scraped before this was recorded, and
            -- an item's source is not something they would disagree
            -- about anyway.
            for id, src in pairs(block.source or {}) do
                srcOf[id] = src
                anySource = true
            end
        end
    end

    for specKey, styles in pairs(data) do
        local block = styles and styles[style]
        local list = block and block.list
        if type(list) == "table" then
            for rank, row in ipairs(list) do
                local id = row.id
                if id and id ~= 0 then
                    local bucket = byItem[id]
                    if not bucket then
                        -- Nothing current anywhere means the whole file
                        -- is a season behind, and calling every trinket
                        -- in it stale would empty the browse list rather
                        -- than tidy it. The page-wide staleness banner
                        -- is the honest answer in that case.
                        bucket = { name = row.name, id = id, specs = {},
                                   source = srcOf[id],
                                   ilvl = ceilOf[id] or row.ilvl,
                                   current = current[id] or not anyCurrent,
                                   thisTier = scaling[id] or not anyScaling }
                        byItem[id] = bucket
                        allItems[#allItems + 1] = bucket
                    end
                    bucket.specs[#bucket.specs + 1] = {
                        key = specKey, rank = rank, rel = row.rel or 0,
                        tier = block.tier,
                        -- Carried per entry, not read back from the spec
                        -- later: a tooltip listing five specs can be
                        -- quoting both sources at once, and it has to be
                        -- able to say so.
                        provider = block.provider or "bloodmallet",
                    }
                end
            end
        end
    end

    -- Strongest claim first, which is `rel` and NOT `rank`.
    --
    -- The two answer different questions and only one of them is the
    -- council's. `rank` is where this trinket sits in that spec's own
    -- list; `rel` is how far behind that spec's BEST trinket it is. A
    -- spec holding it at #7 but 0.6% off their best wants it more than
    -- one holding it at #4 but 1.6% off -- rank cannot see that, because
    -- it says nothing about how tightly packed the options behind it
    -- are.
    --
    -- Sorted by rank, the list also read as broken: the percentages
    -- beside the ranks came out in no order at all (-1.6, then -2.5,
    -- then -0.6), because there is no reason for two different specs'
    -- rankings to agree. By rel it descends cleanly, and a spec whose
    -- rank is 1 has rel 0 by construction, so the top picks still lead.
    for _, bucket in pairs(byItem) do
        table.sort(bucket.specs, function(a, b)
            if a.rel ~= b.rel then return a.rel > b.rel end
            if a.rank ~= b.rank then return a.rank < b.rank end
            return a.key < b.key
        end)
        -- The lowest rank any re-simmed spec gives it, found by looking
        -- rather than by reading the first element. It used to take
        -- specs[1], which was only the best rank while the array was
        -- sorted by rank -- re-sorting above would have quietly turned
        -- the browse list's ordering into "rank of whichever spec has
        -- the best rel", which is not what "best: #N" claims to be.
        --
        -- Re-simmed specs only. A last-season spec placing it first is
        -- not a reason to lead the browse list with it, because that
        -- placing was made against a different set of trinkets.
        bucket.bestRank = 99
        local anyFresh = false
        for _, entry in ipairs(bucket.specs) do
            if not T:IsStaleTier(entry.tier) then
                anyFresh = true
                if entry.rank < bucket.bestRank then
                    bucket.bestRank = entry.rank
                end
            end
        end
        if not anyFresh then
            for _, entry in ipairs(bucket.specs) do
                if entry.rank < bucket.bestRank then
                    bucket.bestRank = entry.rank
                end
            end
        end
    end

    table.sort(allItems, function(a, b)
        if a.bestRank ~= b.bestRank then return a.bestRank < b.bestRank end
        return (a.name or "") < (b.name or "")
    end)

    -- Both built here rather than filtered on the way out: "show older
    -- trinkets" is a checkbox, and re-deriving either list on every
    -- keystroke in the search box would be work for nothing.
    local councilItems, thisTierItems = {}, {}
    for _, bucket in ipairs(allItems) do
        -- anySource false means the file predates sources being
        -- recorded, and filtering on one would empty the page.
        if bucket.current
            and (not anySource or COUNCIL_SOURCES[bucket.source]) then
            councilItems[#councilItems + 1] = bucket
            if bucket.thisTier then
                thisTierItems[#thisTierItems + 1] = bucket
            end
        end
    end
    table.sort(pendingSpecs, function(a, b)
        return T:SpecName(a) < T:SpecName(b)
    end)
    cache[style].pendingSpecs = pendingSpecs
    cache[style].councilItems = councilItems
    cache[style].thisTierItems = thisTierItems

    return byItem, allItems, thisTierItems, councilItems
end

function T:Rebuild()
    cache = {}
    atCache = {}
    build(T.DEFAULT_STYLE)
end

--- True when any spec has data for this fight style. A few specs have no
--- AoE chart at all, so the UI asks before offering a tab that would open
--- on an empty list. Healers count here too: QE Live's dungeon chart is
--- filed under AOE, so the tab has content for them even when the spec
--- next to them on the council list has none.
function T:HasStyle(style)
    local _, items = build(style)
    return #items > 0
end

--- Specs still on last season's data for this fight style.
---
--- A property of the page, not of any one trinket. The point is that
--- these specs have no current opinion on *anything*, so their absence
--- from a ranking is not a judgement on the item. Deriving it per
--- trinket from who ranked it gets that backwards: this season's items
--- were never in last season's lists, so the group would come out empty
--- for exactly the trinkets where the caveat matters.
function T:PendingSpecs(style)
    style = style or T.DEFAULT_STYLE
    build(style)
    local c = cache[style]
    return c and c.pendingSpecs or {}
end

--- All specs that sim this trinket, strongest claim first. nil if unknown.
function T:GetSpecsFor(itemID, style)
    local byItem = build(style)
    local bucket = byItem[itemID]
    return bucket and bucket.specs or nil, bucket
end

------------------------------------------------------------
-- Grouping by what the percentage measures.
--
-- `rel` is percent behind that spec's best trinket, and the two sources
-- divide by different things to get there. bloodmallet's is a share of
-- the profile's TOTAL DPS, so a spec's whole 25-trinket list spans about
-- three and a half percent. QE Live's is the difference between two
-- trinkets' own healing contributions, with no total underneath it, so
-- the same list spans forty.
--
-- Sorted into one list by that number, the sort stops ranking interest
-- and starts ranking which project simmed you: a Holy Priest's 4th best
-- trinket reads -16.4% and lands below an Arcane Mage's 16th at -2.0%.
-- The numbers are each right about their own spec and meaningless
-- against each other, so they are never placed in the same column.
--
-- Split by the unit rather than by role. That it currently separates
-- healers from everyone else is a consequence, not the rule -- the rule
-- is that two numbers only go in one list when they divide by the same
-- thing.
------------------------------------------------------------
local GROUPS = {
    percent = { order = 1, label = "Damage & tanks",
                note = "% of total DPS" },
    score   = { order = 2, label = "Healers",
                note = "% of the best trinket's healing" },
}

--- The same specs, split by unit, with the player's own group first.
---
--- Groups keep the order build() sorted them into, which is by rel --
--- correct inside a group, since every entry in one divides by the same
--- thing.
function T:GroupedSpecsFor(itemID, style)
    local specs, bucket = self:GetSpecsFor(itemID, style)
    if not specs then return nil, bucket end

    local out, index = {}, {}
    for _, entry in ipairs(specs) do
        local unit = self:ProviderInfo(entry.provider).unit
        local group = index[unit]
        if not group then
            local meta = GROUPS[unit] or GROUPS.percent
            group = { unit = unit, label = meta.label, note = meta.note,
                      order = meta.order, source = self:ProviderInfo(entry.provider).label,
                      entries = {} }
            index[unit] = group
            out[#out + 1] = group
        end
        group.entries[#group.entries + 1] = entry
    end

    -- The player's own group first, because the question a player opens
    -- this on is "do I want it", and the answer should not be below a
    -- list of eight specs they will never play. Falls back to the fixed
    -- order when the player's spec is not simmed at all.
    local mine = self:GetPlayerSpecKey()
    local myUnit = mine and self:ProviderInfo(self:Provider(mine, style)).unit
    table.sort(out, function(a, b)
        if myUnit and (a.unit == myUnit) ~= (b.unit == myUnit) then
            return a.unit == myUnit
        end
        return a.order < b.order
    end)
    return out, bucket
end

--- Trinkets worth browsing, best-ranked first.
---
--- What drops in this season's dungeons and raid, and nothing else.
--- `includeOld` widens that to trinkets bloodmallet still sims from
--- previous content -- they are real items and someone may still be
--- wearing one, but they are not what is dropping tonight.
---
--- Crafted gear, PvP rewards and items no current spec ranks are left
--- out either way. They are still in the index and still answer a
--- tooltip -- see GetSpecsFor -- but someone scrolling for the drop in
--- front of them should not have to read past them to find it.
function T:GetAllTrinkets(style, includeOld)
    local _, all, thisTier, council = build(style)
    local items = includeOld and council or thisTier
    return items or all
end

--- The ranking for one spec in one fight style: list, itemLevel, when it
--- was simmed, and which tier it is from.
function T:GetForSpec(specKey, style)
    local block = self:GetBlock(specKey, style)
    if not block then return nil end
    return block.list, block.ilvl, block.timestamp, block.tier
end

------------------------------------------------------------
-- Where a block came from.
--
-- Two sources feed the same table. bloodmallet sims damage and covers
-- everything that deals it; QE Live covers the seven healing specs it
-- has never published and never will. They disagree about more than the
-- name in the footer -- what the numbers measure, what the two fight
-- style tabs mean, and whether a spec waiting on a re-sim is a thing
-- that can happen -- so anything user-facing asks which one it holds
-- rather than assuming bloodmallet.
------------------------------------------------------------
local PROVIDERS = {
    bloodmallet = { label = "bloodmallet", site = "bloodmallet.com",
                    unit = "percent" },
    qe          = { label = "QE Live", site = "questionablyepic.com",
                    unit = "score" },
}

--- The raw block, for the callers that need more than list and tier.
function T:GetBlock(specKey, style)
    local entry = ns.TrinketData and ns.TrinketData[specKey]
    return entry and entry[style or T.DEFAULT_STYLE] or nil
end

--- Provider key for one block. bloodmallet by default: it wrote every
--- block in the file before QE Live was added, and none of them say so.
function T:Provider(specKey, style)
    local block = self:GetBlock(specKey, style)
    return block and block.provider or "bloodmallet"
end

--- Display name, site and curve unit for a provider key.
function T:ProviderInfo(provider)
    return PROVIDERS[provider or "bloodmallet"] or PROVIDERS.bloodmallet
end

--- What the two style tabs mean for this spec.
---
--- ST and AOE are target counts to bloodmallet and content to QE Live,
--- which files its raid chart under ST and its dungeon chart under AOE
--- so healers land in the same loot council index as everyone else. The
--- label follows the block rather than the key, so a Mistweaver is not
--- told their dungeon ranking is an AoE one.
function T:StyleLabel(specKey, style)
    local block = specKey and self:GetBlock(specKey, style)
    if block and block.profile then return block.profile end
    return style == "AOE" and "AoE" or "Single Target"
end

------------------------------------------------------------
-- Item-level curves.
--
-- bloodmallet sims each trinket across the item levels it can actually
-- drop at, and those ladders do not line up -- a crafted trinket and a
-- raid drop share almost no steps. The flat "best available" ranking
-- hides what follows from that: two trinkets can rank one way at 311
-- and the other way at 331. The curve is kept for the top rows so the
-- question can be asked at a chosen item level instead.
------------------------------------------------------------

--- curve[itemID][ilvl] = what the trinket is worth at that item level,
--- every item level present in the block, where each trinket drops, and
--- which unit the values are in.
---
--- The unit is not decoration. bloodmallet's curve is a percent gain
--- over an empty trinket slot; QE Live's is an HPS-equivalent score.
--- Both rank the same way, so every caller that only sorts can ignore
--- it -- but anything that subtracts two of them, or prints one, cannot.
--- nil curve for a spec bloodmallet has not re-simmed: the detail was
--- never scraped and cannot be recovered, only re-run.
function T:GetCurve(specKey, style)
    local block = self:GetBlock(specKey, style)
    if not block then return nil end
    return block.curve, block.steps, block.source,
        self:ProviderInfo(block.provider).unit
end

--- The ranking as it stands at one item level, best first.
---
--- Only trinkets simmed at exactly that level appear. The ladders are
--- per source, so asking for 331 excludes everything that never drops
--- at 331, and a short list is the honest answer: filling it out from
--- each trinket's nearest step would rank a 331 against a 318 and
--- present the item level gap as trinket quality.
function T:GetAtItemLevel(specKey, style, ilvl)
    style = style or T.DEFAULT_STYLE
    local key = specKey .. "|" .. style .. "|" .. ilvl
    local hit = atCache[key]
    if hit ~= nil then
        if hit == false then return nil end
        return hit
    end

    local list = self:GetForSpec(specKey, style)
    local curve = self:GetCurve(specKey, style)
    if not list or not curve then return nil end

    local out = {}
    for _, row in ipairs(list) do
        local points = curve[row.id]
        local gain = points and points[ilvl]
        if gain then
            out[#out + 1] = { id = row.id, name = row.name,
                              ilvl = ilvl, gain = gain }
        end
    end
    if #out == 0 then
        atCache[key] = false
        return nil
    end

    table.sort(out, function(a, b)
        if a.gain ~= b.gain then return a.gain > b.gain end
        return (a.name or "") < (b.name or "")
    end)

    -- Percent behind the best at this item level, which is arithmetic
    -- the unit decides.
    --
    -- bloodmallet's gains are percentages over an empty slot, so the
    -- difference is taken against that same baseline rather than
    -- subtracted outright -- a 9% trinket is not "1% better" than an 8%
    -- one, it is 0.93% better. QE Live's are absolute scores with no
    -- baseline in them, so there the ratio is against the best score.
    -- Using the percent formula on scores would divide by 100 more than
    -- it should, which at QE's magnitudes is a rounding error and
    -- therefore the kind of wrong that survives review.
    local _, _, _, unit = self:GetCurve(specKey, style)
    local top = out[1].gain
    for _, r in ipairs(out) do
        if unit == "score" then
            r.rel = (r.gain - top) / top * 100.0
        else
            r.rel = (r.gain - top) / (100.0 + top) * 100.0
        end
    end

    atCache[key] = out
    return out
end

--- "CLASS_SPEC" key for the player's current specialization.
function T:GetPlayerSpecKey()
    local _, classFile = UnitClass("player")
    if not classFile then return nil end
    local idx = GetSpecialization and GetSpecialization()
    if not idx then return nil end
    local _, specName = GetSpecializationInfo(idx)
    if not specName then return nil end
    local key = classFile:upper() .. "_" .. specName:upper():gsub("[^A-Z]", "")
    if SPEC_LABEL[key] then return key end
    return nil
end

--- True when a tier tag predates the season the addon targets.
---
--- Tiers arrive per spec, not all at once, so this answers the question
--- about one block. A file can hold both at the same time and usually
--- does for the first few weeks of a season.
function T:IsStaleTier(tier)
    local want = ns.TRINKET_TARGET_TIER
    if not want then return false end
    return (tier or ns.TRINKET_TIER) ~= want
end

--- True only when nothing in the file is current — the whole addon is
--- behind, rather than the handful of specs still waiting on a re-sim.
function T:IsStale()
    local have, want = ns.TRINKET_TIER, ns.TRINKET_TARGET_TIER
    if not have or not want then return false end
    return have ~= want
end

function T:StaleText()
    return ("|cffffcc00Sim data is %s|r — bloodmallet has not published %s runs yet.")
        :format(ns.TRINKET_TIER or "from an earlier tier",
                ns.TRINKET_TARGET_TIER or "current-season")
end

--- The same warning for one spec, while other specs are current.
---
--- Named after the provider that owes the update. Telling a Holy Priest
--- that bloodmallet has not re-simmed them would be a wait with no end:
--- bloodmallet sims damage and has never published a healer chart.
function T:StaleSpecText(tier, provider)
    return ("|cffffcc00This is %s data.|r %s has not re-run this spec for %s yet, so the order below is last tier's.")
        :format(tier or ns.TRINKET_TIER or "older",
                self:ProviderInfo(provider).label,
                ns.TRINKET_TARGET_TIER or "the current tier")
end

------------------------------------------------------------
-- Guide tier list.
--
-- The second opinion on the same trinkets, and a different kind of
-- claim from the sim's. bloodmallet answers "how much damage", which is
-- the whole question only when the two trinkets are otherwise
-- interchangeable. Wowhead's authors grade knowing which on-use wants
-- pairing with which cooldown, which drop is Vault-only, and which pair
-- nobody would wear together -- and they grade for Augmentation Evoker,
-- which no sim covers at all.
--
-- Kept beside the sim rather than blended into it. Averaging a letter
-- with a percentage would produce a number neither source stands behind.
------------------------------------------------------------
local tierIndex

local function buildTiers()
    if tierIndex then return tierIndex end
    tierIndex = {}
    for key, block in pairs(ns.TrinketTiers or {}) do
        local total = #(block.tiers or {})
        for _, tier in ipairs(block.tiers or {}) do
            for _, item in ipairs(tier.items or {}) do
                local bySpec = tierIndex[item.id]
                if not bySpec then
                    bySpec = {}
                    tierIndex[item.id] = bySpec
                end
                bySpec[key] = {
                    label = tier.label,
                    rank  = tier.rank,
                    of    = total,
                    from  = item.from,
                    note  = item.note,
                }
            end
        end
    end
    return tierIndex
end

--- The guide's grade for one trinket and one spec, or nil.
---
--- nil has two meanings and the caller has to keep them apart: the guide
--- did not list this trinket, or there is no guide for the spec at all.
--- HasTierList answers the second, so ask it before reading anything
--- into the first.
function T:GetTier(itemID, specKey)
    if not itemID or not specKey then return nil end
    local bySpec = buildTiers()[itemID]
    return bySpec and bySpec[specKey] or nil
end

--- Every spec whose guide grades this trinket, best grade first.
function T:GetTiersFor(itemID)
    local bySpec = itemID and buildTiers()[itemID]
    if not bySpec then return nil end
    local out = {}
    for key, entry in pairs(bySpec) do
        out[#out + 1] = {
            key = key, label = entry.label, rank = entry.rank,
            of = entry.of, from = entry.from, note = entry.note,
        }
    end
    table.sort(out, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.key < b.key
    end)
    return out
end

--- True when the guide publishes a tier list for this spec.
function T:HasTierList(specKey)
    local block = specKey and (ns.TrinketTiers or {})[specKey]
    return block ~= nil and #(block.tiers or {}) > 0
end

--- The spec's tiers in order, for a page that wants to draw the ladder.
function T:TierList(specKey)
    local block = specKey and (ns.TrinketTiers or {})[specKey]
    return block and block.tiers or nil
end

--- The guide's prose above the tier list: which stats the spec wants out
--- of the slot, and how it likes to pair on-use with passive. The part a
--- ranking cannot say.
function T:TierIntro(specKey)
    local block = specKey and (ns.TrinketTiers or {})[specKey]
    return block and block.intro or nil
end

--- True when this spec's sim data is behind, in either fight style.
---
--- Asked of the spec rather than of one style, because the question it
--- answers is "should this character be reading the guide first" and a
--- spec whose raid chart is current but whose dungeon chart is not is
--- still a spec being shown last season's numbers on one of its tabs.
function T:IsSpecSimStale(specKey)
    local styles = specKey and (ns.TrinketData or {})[specKey]
    if not styles then return false end
    for _, block in pairs(styles) do
        if type(block) == "table" and block.list and self:IsStaleTier(block.tier) then
            return true
        end
    end
    return false
end

--- True when the guide for this spec is written for an older season.
function T:IsTierListStale(specKey)
    local block = specKey and (ns.TrinketTiers or {})[specKey]
    local want = ns.TRINKET_TIER_TARGET_SEASON
    if not block or not want then return false end
    return block.season ~= want
end

--- Skin colour for a grade, by where it sits in this spec's ladder.
---
--- By position, not by letter. The forty guides use six different
--- ladders between them -- one runs S+ to F, another A+ to F, one stops
--- at C -- so a table keyed on "D" would paint the bottom of a six-tier
--- list the same as the middle of a seven-tier one.
function T:TierColorKey(entry)
    if not entry then return "faint" end
    if entry.rank == 1 then return "good" end
    if entry.rank == 2 then return "accent" end
    if entry.of and entry.rank >= entry.of then return "warn" end
    return "muted"
end

--- "S", coloured. The label is the guide author's own wording.
function T:ColorTier(entry)
    if not entry then return "" end
    return ns.Widgets:Tint(self:TierColorKey(entry), entry.label)
end

--- A name for a trinket, for the search box to match on.
---
--- The tier list stores IDs alone, on purpose -- names resolve at
--- runtime and localise for free. Search runs before anything is drawn
--- though, so it needs a string from somewhere: the sim index holds one
--- for most of the same trinkets and is asked first, the client second.
--- Empty is an acceptable last answer. A row that fails to match is a
--- row the reader can still see by clearing the box; guessing a name
--- would be worse.
function T:KnownName(itemID)
    if not itemID then return "" end
    for _, style in ipairs({ "ST", "AOE" }) do
        local _, bucket = self:GetSpecsFor(itemID, style)
        if bucket and bucket.name then return bucket.name end
    end
    if C_Item and C_Item.GetItemInfo then
        local name = C_Item.GetItemInfo(itemID)
        if name then return name end
    end
    return ""
end

--- The spec's tier list flattened into rows the page can draw.
---
--- Tier boundaries survive as `first` on the row that opens each band,
--- so the view can put a heading above it without walking the nested
--- shape a second time while it lays out.
function T:GuideRows(specKey)
    local tiers = self:TierList(specKey)
    if not tiers then return nil end
    local out = {}
    for _, tier in ipairs(tiers) do
        for i, item in ipairs(tier.items or {}) do
            out[#out + 1] = {
                id    = item.id,
                name  = self:KnownName(item.id),
                from  = item.from,
                note  = item.note,
                label = tier.label,
                rank  = tier.rank,
                of    = #tiers,
                first = (i == 1),
                count = #(tier.items or {}),
            }
        end
    end
    return out
end

------------------------------------------------------------
-- Tooltip integration.
--
-- The point of the raid-night use case is not to open a window; it is to
-- hover the trinket that just dropped and immediately see who wants it.
-- Hooking the tooltip covers every surface at once — loot windows, bags,
-- chat links, the Encounter Journal, other people's gear.
------------------------------------------------------------
-- Other people's specs, and only in a group.
--
-- This used to be five lines shown to everyone on every hover, and on a
-- character whose own sim is a tier behind it was the entire tooltip:
-- eight lines about five specs you are not playing, a "+29 more", and
-- nothing at all about you. "Who else wants this" is a real question,
-- but it is the loot council's question, and it only has an answer worth
-- reading when there is a council -- so it is gated on being grouped and
-- cut to three. The page's Loot Council tab is where the full list has
-- always lived.
local MAX_COUNCIL_SPECS = 3

local function describeRank(entry)
    local suffix = entry.rel and entry.rel < -0.005
        and ("  |cff888888%.1f%%|r"):format(entry.rel) or ""
    -- Marked per line, not once at the bottom. Specs come off last
    -- tier's data one at a time, so a single footer would either
    -- discredit the current rankings above it or vouch for the old ones.
    if T:IsStaleTier(entry.tier) then
        suffix = suffix .. ("  |cff886600(%s)|r"):format(entry.tier or "old")
    end
    return ("  #%d %s%s"):format(entry.rank, T:ColorSpec(entry.key), suffix)
end

-- A guide note is a sentence or two on the commonest trinkets and a
-- paragraph on a handful. Past this the tooltip stops being a glance,
-- so it is cut at the last sentence that fits and the page keeps the
-- rest. Cutting mid-word instead would be shorter and read as damage.
local MAX_NOTE = 240

local function shortenNote(note)
    if #note <= MAX_NOTE then return note end
    local head = note:sub(1, MAX_NOTE)
    local stop = head:match(".*()[.!?]")
    if stop and stop > MAX_NOTE / 2 then
        return head:sub(1, stop)
    end
    return head:gsub("%s+%S*$", "") .. "..."
end

--- True when some other spec ranks or grades this trinket.
---
--- What licenses the "not on your list" line, and the reason it is not
--- an item-type test. Two problems with asking the client what an item
--- is: on a cold cache it answers by going and finding out, which is one
--- more uncached lookup per hover and the shape of the freeze after a
--- loading screen; and a level-20 trinket would pass it, so every spec
--- would get told about every trinket ever made.
---
--- Membership in either dataset settles both at once. It proves the item
--- is a trinket someone currently cares about, using tables already in
--- memory, and it scopes the line to the case that prompted it: a drop
--- other people are rolling on, and you want to know if it is for you.
local function rankedBySomeone(itemID)
    if T:GetTiersFor(itemID) then return true end
    local specs = T:GetSpecsFor(itemID)
    return specs ~= nil and #specs > 0
end

--- Appends the guide's verdict for the player's own spec.
---
--- The player's spec only, unlike the sim block. A percentage is a loot
--- council argument -- everyone's numbers divide by the same thing --
--- but a letter is graded inside one spec's own ladder, so "S for Fire
--- Mage" and "S for Blood" are not comparable quantities and lining them
--- up would invite exactly that comparison.
---
--- Says so when the guide does NOT list the trinket, which is the whole
--- point for anything below the grades: a hover that adds nothing is
--- indistinguishable from a hover on an item the addon has never heard
--- of. Stated as a fact about the guide rather than about the item --
--- the guide's silence is not a verdict, and several things it does not
--- rate are simply out of its scope.
local function addGuideLines(tooltip, itemID)
    local specKey = T:GetPlayerSpecKey()
    if not specKey or not T:HasTierList(specKey) then return false end

    local entry = T:GetTier(itemID, specKey)
    local faint = ns.Widgets:Hex("faint")

    if entry then
        tooltip:AddLine(" ")
        local head = ("|cff00ccffGuide|r  %s |cff%sfor %s|r")
            :format(T:ColorTier(entry), faint, T:SpecName(specKey))
        if entry.from then
            head = head .. ("  |cff%s%s|r"):format(faint, entry.from)
        end
        tooltip:AddLine(head)
        if entry.note then
            tooltip:AddLine(shortenNote(entry.note), 0.8, 0.8, 0.8, true)
        end
        if T:IsTierListStale(specKey) then
            tooltip:AddLine(("|cff886600Guide written for %s|r")
                :format((ns.TrinketTiers[specKey] or {}).season or "an older season"))
        end
        return true
    end

    if not rankedBySomeone(itemID) then return false end
    tooltip:AddLine(" ")
    tooltip:AddLine(("|cff%sGuide: not on the %s trinket list.|r")
        :format(faint, T:SpecName(specKey)), nil, nil, nil, true)
    return true
end

--- Appends the sim block. Returns true only if it actually added lines.
---
--- The return value is the point: this runs on EVERY item tooltip in the
--- game and the overwhelming majority are not trinkets we have data for,
--- so the caller needs to know the difference between "added something"
--- and "looked and left".
--- Where this trinket lands for the player's own spec, in one line.
---
--- One line, not a block. The guide line above it has already named the
--- spec, so repeating it here would spend a third of the width saying
--- "Balance Druid" twice; `named` is false when there was no guide line
--- to do that, and only then does this say it itself.
local function addOwnRank(tooltip, itemID, named)
    local playerKey = T:GetPlayerSpecKey()
    if not playerKey then return false end
    local specs = T:GetSpecsFor(itemID)
    if not specs then return false end
    for _, entry in ipairs(specs) do
        if entry.key == playerKey then
            local rel = entry.rel and entry.rel < -0.005
                and ("  |cff888888%.1f%%|r"):format(entry.rel) or ""
            local who = named and ""
                or ("  |cff%sfor %s|r"):format(ns.Widgets:Hex("faint"),
                    T:SpecName(playerKey))
            local stale = T:IsStaleTier(entry.tier)
                and ("  |cff886600(%s)|r"):format(entry.tier or "old") or ""
            tooltip:AddLine(("|cff00ccffSim|r  #%d%s%s%s")
                :format(entry.rank, who, rel, stale))
            return true
        end
    end
    return false
end

--- Who else in the group wants it. Skipped entirely when solo.
local function addCouncilLines(tooltip, itemID)
    if IsInGroup and not IsInGroup() then return false end

    local specs = T:GetSpecsFor(itemID)
    if not specs or #specs == 0 then return false end
    local playerKey = T:GetPlayerSpecKey()

    -- Grouped for the same reason the page groups -- the percentages
    -- divide by different things, DPS against HPS -- and with a second
    -- job here: three lines sorted into one list is three damage specs
    -- every time, and a healer would never see another healer on it.
    -- The budget is split so both sides get a look in, and whichever
    -- group the player is in goes first and takes the larger share.
    local groups = T:GroupedSpecsFor(itemID) or {}
    local budget = {}
    local room = MAX_COUNCIL_SPECS
    for i = #groups, 1, -1 do
        -- Back to front, so the rounding lands on the player's group.
        local share = math.floor(room / i)
        local want = #groups[i].entries
        budget[i] = (share < want) and share or want
        room = room - budget[i]
    end
    -- Whatever the smaller group did not need goes to the first one,
    -- rather than shortening the tooltip for no reason.
    if room > 0 and groups[1] then
        local want = #groups[1].entries - budget[1]
        budget[1] = budget[1] + ((room < want) and room or want)
    end

    -- Counted, not assumed: the player's spec is subtracted from the
    -- "+N more" tail only when it was actually in the list to begin
    -- with, which for a spec still on last tier's data it is not.
    local mine = 0
    for _, entry in ipairs(specs) do
        if entry.key == playerKey then mine = 1 break end
    end

    local lines, shown = {}, 0
    for i, group in ipairs(groups) do
        local take = budget[i] or 0
        local head = false
        for n, entry in ipairs(group.entries) do
            if n > take then break end
            -- The player's own spec is already above, under Sim.
            if entry.key ~= playerKey then
                if not head and #groups > 1 then
                    -- Attributed per group. A trinket good for a Warlock
                    -- and a Holy Priest is ranked by two different
                    -- projects, and crediting one for both is wrong in
                    -- the direction that matters: the healer numbers are
                    -- the ones a reader would otherwise assume
                    -- bloodmallet publishes, which it does not.
                    lines[#lines + 1] = ("|cff666666%s — %s|r")
                        :format(group.label, group.source)
                    head = true
                end
                lines[#lines + 1] = describeRank(entry)
                shown = shown + 1
            end
        end
    end
    if shown == 0 then return false end

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff00ccffAlso wanted by|r")
    for _, line in ipairs(lines) do tooltip:AddLine(line) end

    local rest = #specs - shown - mine
    if rest > 0 then
        tooltip:AddLine(("|cff%s+%d more — see the Trinkets page|r")
            :format(ns.Widgets:Hex("faint"), rest))
    end
    return true
end

--- Appends everything the addon has to say about a trinket.
---
--- Ordered by who is asking. The player's own answer comes first and is
--- the only part shown when they are alone: hovering a trinket is nearly
--- always "is this good for me", and the loot council's question needs a
--- council before it is worth four lines.
---
--- The return value is the point: this runs on EVERY item tooltip in the
--- game and the overwhelming majority are not trinkets we have data for,
--- so the caller needs to know the difference between "added something"
--- and "looked and left".
local function addTrinketLines(tooltip, itemID)
    if not itemID then return false end

    local graded = addGuideLines(tooltip, itemID)
    local own = addOwnRank(tooltip, itemID, graded)
    local council = addCouncilLines(tooltip, itemID)

    -- Only when the entire file is behind. A single spec on last tier's
    -- data is marked on its own line by describeRank and by addOwnRank.
    if (own or council) and T:IsStale() then
        tooltip:AddLine("|cff886600" .. (ns.TRINKET_TIER or "old") .. " sim data|r")
    end
    return graded or own or council
end

local function enabled()
    YippYappHelperDB = YippYappHelperDB or {}
    if type(YippYappHelperDB.trinketTooltips) ~= "boolean" then
        YippYappHelperDB.trinketTooltips = true
    end
    return YippYappHelperDB.trinketTooltips
end
T.TooltipsEnabled = enabled

function T:SetTooltipsEnabled(v)
    YippYappHelperDB = YippYappHelperDB or {}
    YippYappHelperDB.trinketTooltips = v and true or false
end

local hooked = false
local function hookTooltips()
    if hooked then return end
    hooked = true

    -- Retail's tooltip data post-call, which covers every tooltip that
    -- shows an item regardless of which frame owns it.
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
        and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item,
            function(tooltip, data)
                if not enabled() then return end
                if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip
                    and tooltip ~= GameTooltipTooltip then
                    -- Still allow shopping/compare tooltips through.
                    if not tooltip.GetName or not tooltip:GetName() then return end
                end
                local id = data and data.id
                if not id then return end
                -- Show() ONLY when we actually appended something.
                --
                -- It used to fire on every item tooltip in the game,
                -- trinket or not, because the pcall's `ok` says the call
                -- did not error rather than that it did anything. Calling
                -- Show on a tooltip we did not touch is at best pointless
                -- work on every hover, and at worst a second opinion
                -- about visibility offered while the client is busy
                -- forming its own -- which is the shape of a tooltip that
                -- appears and vanishes.
                local ok, added = pcall(addTrinketLines, tooltip, id)
                if ok and added and tooltip.Show then tooltip:Show() end
            end)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    build()
    hookTooltips()
end)
