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
local byItem, allItems

local function build()
    if byItem then return end
    byItem, allItems = {}, {}

    local data = ns.TrinketData
    if type(data) ~= "table" then return end

    for specKey, styles in pairs(data) do
        local block = styles and styles.ST
        local list = block and block.list
        if type(list) == "table" then
            for rank, row in ipairs(list) do
                local id = row.id
                if id and id ~= 0 then
                    local bucket = byItem[id]
                    if not bucket then
                        bucket = { name = row.name, id = id, specs = {} }
                        byItem[id] = bucket
                        allItems[#allItems + 1] = bucket
                    end
                    bucket.specs[#bucket.specs + 1] = {
                        key = specKey, rank = rank, rel = row.rel or 0,
                    }
                end
            end
        end
    end

    -- Best rank first: the spec that wants it most leads the list.
    for _, bucket in pairs(byItem) do
        table.sort(bucket.specs, function(a, b)
            if a.rank ~= b.rank then return a.rank < b.rank end
            return a.key < b.key
        end)
        bucket.bestRank = bucket.specs[1] and bucket.specs[1].rank or 99
    end

    table.sort(allItems, function(a, b)
        if a.bestRank ~= b.bestRank then return a.bestRank < b.bestRank end
        return (a.name or "") < (b.name or "")
    end)
end

function T:Rebuild()
    byItem = nil
    build()
end

--- All specs that sim this trinket, best rank first. nil if unknown.
function T:GetSpecsFor(itemID)
    build()
    local bucket = byItem[itemID]
    return bucket and bucket.specs or nil, bucket
end

--- Every trinket we have data for, best-ranked first.
function T:GetAllTrinkets()
    build()
    return allItems
end

--- The ST ranking for one spec: list, itemLevel.
function T:GetForSpec(specKey)
    local entry = ns.TrinketData and ns.TrinketData[specKey]
    local block = entry and entry.ST
    if not block then return nil end
    return block.list, block.ilvl, block.timestamp
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

--- True when the sim data predates the season the addon targets.
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

------------------------------------------------------------
-- Tooltip integration.
--
-- The point of the raid-night use case is not to open a window; it is to
-- hover the trinket that just dropped and immediately see who wants it.
-- Hooking the tooltip covers every surface at once — loot windows, bags,
-- chat links, the Encounter Journal, other people's gear.
------------------------------------------------------------
local MAX_TOOLTIP_SPECS = 5

local function describeRank(entry)
    local suffix = entry.rel and entry.rel < -0.005
        and ("  |cff888888%.1f%%|r"):format(entry.rel) or ""
    return ("  #%d %s%s"):format(entry.rank, T:ColorSpec(entry.key), suffix)
end

local function addTrinketLines(tooltip, itemID)
    if not itemID then return end
    local specs = T:GetSpecsFor(itemID)
    if not specs or #specs == 0 then return end

    tooltip:AddLine(" ")
    tooltip:AddLine("|cff00ccffTrinket sims|r |cff666666(bloodmallet)|r")

    local playerKey = T:GetPlayerSpecKey()
    local shown, playerShown = 0, false

    for _, entry in ipairs(specs) do
        if shown >= MAX_TOOLTIP_SPECS then break end
        tooltip:AddLine(describeRank(entry))
        if entry.key == playerKey then playerShown = true end
        shown = shown + 1
    end

    -- Always tell the player where it lands for them, even if their spec
    -- ranks it far enough down to fall outside the top few.
    if playerKey and not playerShown then
        for _, entry in ipairs(specs) do
            if entry.key == playerKey then
                tooltip:AddLine(" ")
                tooltip:AddLine("|cffffffffFor you:|r" .. describeRank(entry))
                break
            end
        end
    end

    if #specs > shown then
        tooltip:AddLine(("|cff666666+%d more specs — see the Trinkets page|r")
            :format(#specs - shown))
    end
    if T:IsStale() then
        tooltip:AddLine("|cff886600" .. (ns.TRINKET_TIER or "old") .. " sim data|r")
    end
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
                local ok = pcall(addTrinketLines, tooltip, id)
                if ok and tooltip.Show then tooltip:Show() end
            end)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    build()
    hookTooltips()
end)
