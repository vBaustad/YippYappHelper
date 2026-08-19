local _, ns = ...

------------------------------------------------------------
-- Which secondary stats this spec wants, and in what order.
--
-- Shared because two places ask the same question of the same data and
-- would otherwise answer it differently. The Best in Slot page draws a
-- card per hero talent build and can afford to show a disagreement; the
-- shell's character column has four rows and has to pick the one build
-- you are actually specced into.
--
-- The parsing lives here rather than in either caller because what the
-- generated guide holds is not a list of stats -- it is prose that
-- happens to be short:
--
--   "Mastery / Critical Strike / Versatility"  one rank, three stats
--   "Haste (until 800/18%-20%)"                one stat, and a slash
--                                              that must NOT be split on
--   "Mastery>=Critical Strike"                 two ranks
--   "Critical Strike and Haste"                one rank, two stats
--   "Item Level / Agility / Armor / Stamina"   no secondaries at all
--
-- Guessing at that in two files means guessing differently in two
-- files, and the card and the column then contradict each other about
-- the same character.
------------------------------------------------------------

------------------------------------------------------------
-- Spec identity
------------------------------------------------------------

--- The key into ns.ClassGuideData, plus a class-coloured display name.
---
--- Built the same way the scraper builds its keys: class file name,
--- underscore, spec name with everything but letters stripped.
function ns:PlayerSpecKey()
    local className, classFile = UnitClass("player")
    if not classFile then return nil end
    local idx = GetSpecialization and GetSpecialization()
    if not idx then return nil end
    local _, specName = GetSpecializationInfo(idx)
    if not specName then return nil end

    local key = classFile:upper() .. "_" .. specName:upper():gsub("[^A-Z]", "")
    local display = specName .. " " .. (className or "")
    local colour = RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
    if colour and colour.WrapTextInColorCode then
        display = colour:WrapTextInColorCode(display)
    end
    return key, display
end

--- Every hero talent tree this spec offers, keyed by lowercased name,
--- with the icon to draw for it and whether it is the one you took.
---
--- An unknown active tree leaves every entry unlit rather than lighting
--- a guess: callers use that to say nothing at all instead of asserting
--- the wrong build.
function ns:HeroTalentSubtrees()
    local out = {}
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID
            and C_ClassTalents.GetHeroTalentSpecsForClassSpec
            and C_Traits and C_Traits.GetSubTreeInfo) then
        return out
    end

    local ok, configID = pcall(C_ClassTalents.GetActiveConfigID)
    if not ok or not configID then return out end

    local idx = GetSpecialization and GetSpecialization()
    local specID = idx and GetSpecializationInfo(idx)
    if not specID then return out end

    local okIDs, ids = pcall(C_ClassTalents.GetHeroTalentSpecsForClassSpec,
        configID, specID)
    if not okIDs or type(ids) ~= "table" then return out end

    -- Which tree you actually took. Asked for directly where the client
    -- offers it, since that is the question, and read back off each
    -- subtree otherwise.
    local activeID
    if C_ClassTalents.GetActiveHeroTalentSpec then
        local okA, id = pcall(C_ClassTalents.GetActiveHeroTalentSpec)
        if okA then activeID = id end
    end

    for _, subTreeID in ipairs(ids) do
        local okInfo, info = pcall(C_Traits.GetSubTreeInfo, configID, subTreeID)
        if okInfo and type(info) == "table" and info.name then
            -- Zero is not an icon, and in Lua it is not false either --
            -- which is how the first version of this reserved space for
            -- a tile, indented the label past it, and drew nothing.
            local icon = info.iconElementID
            if type(icon) == "number" and icon <= 0 then icon = nil end

            -- Merged rather than overwritten. Two subtrees sharing a
            -- name should not happen and does not in a live client, but
            -- a plain assignment means the LAST one wins -- so the one
            -- case where it did happen turned an active tree inactive,
            -- and the answer to "which build am I in" became "none".
            local key = info.name:lower()
            local prev = out[key]
            out[key] = {
                icon   = icon or (prev and prev.icon),
                active = (prev and prev.active)
                          or (activeID ~= nil and subTreeID == activeID)
                          or info.isActive == true,
            }
        end
    end
    return out
end

------------------------------------------------------------
-- Parsing
------------------------------------------------------------

-- Matched as substrings, not compared whole, because a line can be
-- "Mastery to 1200 rating" or "Item Level (Agility+Stamina)". Longest
-- form first so the specific spelling wins where both would match.
local SECONDARY = {
    { "critical strike", "crit"    },
    { "crit",            "crit"    },
    { "haste",           "haste"   },
    { "mastery",         "mastery" },
    { "versatility",     "vers"    },
    { "vers",            "vers"    },
}

-- Separators that mean "and then", in the order they must be tried:
-- ">=" before ">", or the ">" pass eats half of it.
local ORDER_SEPS = { ">=", ">" }
-- Separators that mean "these are the same rank".
local TIE_SEPS = { "/", "=", " and " }

--- Split on any of a set of literal separators, trimming the pieces.
local function splitOn(text, seps)
    local s = text
    for _, sep in ipairs(seps) do
        s = s:gsub((sep:gsub("%W", "%%%0")), "\1")
    end
    local out = {}
    for piece in (s .. "\1"):gmatch("([^\1]*)\1") do
        local trimmed = piece:gsub("^%s+", ""):gsub("%s+$", "")
        if trimmed ~= "" then out[#out + 1] = trimmed end
    end
    return out
end

local function statKey(segment)
    local s = segment:lower()
    for _, def in ipairs(SECONDARY) do
        if s:find(def[1], 1, true) then return def[2] end
    end
    return nil
end

--- Turn a guide's `stats` list into a rank per secondary stat.
---
--- Ranks are 1-based over SECONDARIES ONLY. Every list opens with the
--- primary stat, and letting Strength take rank 1 would report Blood's
--- Haste as second-best when it is the top stat the column can show.
---
--- A line that names no secondary consumes no rank, so
--- "Item Level / Agility / Armor / Stamina" is skipped rather than
--- leaving a hole in the numbering.
function ns:ParseStatPriority(stats)
    if type(stats) ~= "table" then return nil end
    local ranks, rank, any = {}, 0, false

    for _, line in ipairs(stats) do
        if type(line) == "string" then
            -- Qualifiers go first, and they have to: "Haste (until
            -- 800/18%-20%)" carries a slash inside the bracket, and
            -- splitting before stripping turns one stat into two
            -- segments, neither of which is a stat.
            local clean = line:gsub("%b()", "")

            for _, subLine in ipairs(splitOn(clean, ORDER_SEPS)) do
                local tied, found = {}, false
                for _, segment in ipairs(splitOn(subLine, TIE_SEPS)) do
                    local key = statKey(segment)
                    -- First mention wins. A stat named twice is named
                    -- once as a priority and once as a footnote, and the
                    -- priority is the earlier one.
                    if key and not ranks[key] then
                        tied[#tied + 1] = key
                        found = true
                    end
                end
                if found then
                    rank = rank + 1
                    for _, key in ipairs(tied) do
                        ranks[key] = rank
                        any = true
                    end
                end
            end
        end
    end

    if not any then return nil end
    return ranks
end

------------------------------------------------------------
-- The answer for THIS character
------------------------------------------------------------

--- Whether a guide's build label names the hero talent tree you took.
---
--- Containment, not equality, because the scraper does not always come
--- away with a clean name: Arcane's first entry is labelled with a
--- whole sentence of guide prose ending in "Spellslinger". Requiring an
--- exact match there means Spellslinger mages resolve to nothing, and
--- the tree names are distinctive enough proper nouns that finding one
--- inside a longer string is not a coincidence.
local function namesTree(label, trees)
    local lower = label:lower()
    local tree = trees[lower]
    if tree then return tree.active end
    for name, info in pairs(trees) do
        if info.active and lower:find(name, 1, true) then return true end
    end
    return false
end

--- Every stat priority entry that could apply to this character.
---
--- @return table entries  the candidates, in guide order
--- @return table|nil entry  the single one that applies, if there is one
--- @return string|nil build the hero talent build that picked it
function ns:StatPriorityCandidates(specKey)
    specKey = specKey or self:PlayerSpecKey()
    local data = specKey and ns.ClassGuideData and ns.ClassGuideData[specKey]
    local list = data and data.statPriority
    if type(list) ~= "table" or #list == 0 then return {} end
    if #list == 1 then
        local builds = list[1].builds
        return list, list[1], builds and builds[1] or nil
    end

    local trees = self:HeroTalentSubtrees()
    local hits, hitBuild = {}, nil
    for _, entry in ipairs(list) do
        for _, build in ipairs(entry.builds or {}) do
            if namesTree(build, trees) then
                hits[#hits + 1] = entry
                hitBuild = hitBuild or build
                break
            end
        end
    end

    -- Exactly one, or nothing decided. Two entries that both name your
    -- tree are split by CONTEXT rather than by build -- Holy priest
    -- ranks Crit first for raid and Versatility first for Mythic+ --
    -- and the addon cannot know which one you are about to do.
    if #hits == 1 then return list, hits[1], hitBuild end
    if #hits > 1 then return hits end
    return list
end

--- The single stat priority entry that applies to the player, or nil.
---
--- Nil rather than a best guess when the guide lists several builds and
--- the client will not say which one is active. The difference is not
--- academic: Blood wants Haste under San'layn and Critical Strike under
--- Deathbringer, so picking the first entry would tell half of Blood
--- death knights to stack the wrong stat, in the styling the addon uses
--- for things it actually knows.
---
--- @return table|nil entry, string|nil buildName
function ns:StatPriorityEntry(specKey)
    local _, entry, build = self:StatPriorityCandidates(specKey)
    return entry, build
end

--- Ranks for the four secondaries, for the build the player is in.
---
--- Where the build cannot be pinned down, this falls back to what every
--- candidate AGREES on: a stat keeps its rank only if each of them puts
--- it there, and drops out otherwise. That is not a guess. Protection
--- paladin's two entries disagree about Crit and Mastery but both open
--- with Haste, so Haste is still the answer; Blood's two disagree about
--- which of Haste and Crit leads, so neither is marked and the column
--- says nothing rather than something wrong.
---
--- @return table|nil ranks  { crit = 1, haste = 2, mastery = 3, vers = 3 }
--- @return table|nil entry  the entry the ranks came from, if just one
--- @return string|nil build the hero talent build it covers
function ns:StatPriorityRanks(specKey)
    local entries, entry, build = self:StatPriorityCandidates(specKey)
    if entry then return self:ParseStatPriority(entry.stats), entry, build end
    if type(entries) ~= "table" or #entries == 0 then return nil end

    local consensus
    for _, candidate in ipairs(entries) do
        local ranks = self:ParseStatPriority(candidate.stats)
        if not ranks then return nil end
        if not consensus then
            consensus = ranks
        else
            for key, rank in pairs(consensus) do
                if ranks[key] ~= rank then consensus[key] = nil end
            end
        end
    end

    if not consensus or not next(consensus) then return nil end
    return consensus
end
