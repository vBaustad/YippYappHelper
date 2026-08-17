local _, ns = ...

------------------------------------------------------------
-- Letting the client correct the guide.
--
-- Features\Raid\RaidGuideData.lua is written from a transcript, and a
-- transcript is a poor source for proper nouns -- see the note at the
-- top of that file. The Encounter Journal is the authority the client
-- already ships, so on the first time the guide is opened we ask it and
-- overwrite the names we flagged as unsure.
--
-- The reason this is a separate file rather than five lines inside the
-- data: it must NOT run at load. EJ_SelectInstance changes the player's
-- own Encounter Journal state, so it is only safe to do when the player
-- asked to look at the guide, and the Loot Browser already learned that
-- lesson the hard way -- it saves and restores the EJ filter state
-- around every bulk read for exactly this reason.
--
-- The matching is deliberately conservative. Adopting a name by list
-- position would be the obvious approach and it is the one that
-- silently mislabels every boss the moment the journal holds eight
-- encounters and the guide holds seven. A name is adopted only when
-- exactly one journal encounter shares a distinctive word with ours;
-- anything ambiguous is left alone and reported, which is a visible
-- gap rather than a confident lie.
------------------------------------------------------------

local G = ns.RaidGuide
if not G then return end

-- Blizzard moves these between the global EJ_* namespace and
-- C_EncounterJournal between builds. Same compatibility shim the Loot
-- Browser uses, kept local rather than shared because it is four lines
-- and importing it would couple the guide to the loot page's load order.
local CEJ = C_EncounterJournal or {}
local function Call(cejName, globalName, ...)
    if CEJ[cejName] then return CEJ[cejName](...) end
    if _G[globalName] then return _G[globalName](...) end
    return nil
end

------------------------------------------------------------
-- Name matching
------------------------------------------------------------

-- Words too common to identify anything. Matching on "the" would tie
-- every boss to every other one.
-- Bracketed keys throughout: several of these are Lua keywords, and
-- `and = true` inside a table constructor is a syntax error rather than
-- a field -- the kind that takes the whole file with it at load.
local STOPWORD = {
    ["the"] = true, ["of"] = true, ["and"] = true, ["a"] = true, ["an"] = true,
    ["lord"] = true, ["lady"] = true, ["sister"] = true, ["brother"] = true,
}

--- The distinctive words in a name, lowercased.
---
--- Apostrophes are stripped rather than treated as separators, so
--- "Zul'jin" is one token and not two useless ones. Both the ASCII
--- apostrophe and the typographic one, spelled out in its UTF-8 bytes
--- because this is Lua 5.1 and \u{2019} is not an escape it knows -- and
--- because a multi-byte character inside a pattern set matches its
--- individual bytes rather than the character.
local function tokens(name)
    local out = {}
    if type(name) ~= "string" then return out end
    local clean = name:gsub("'", ""):gsub("\226\128\153", "")
    -- Lowercased into a fresh local rather than onto the loop variable.
    -- WoW's Lua 5.1 allows assigning to it; the load harness runs a
    -- newer Lua where the control variable is const, and rather than
    -- have this file quietly SKIPPED by the one tool that checks it,
    -- the copy costs nothing.
    for rawWord in clean:gmatch("[%a]+") do
        local word = rawWord:lower()
        -- Three letters is the floor. Below it the tokens are almost all
        -- stopwords anyway, and a two-letter collision is noise.
        if #word >= 3 and not STOPWORD[word] then out[word] = true end
    end
    return out
end

--- How many distinctive words two names share.
local function overlap(a, b)
    local n = 0
    for word in pairs(a) do if b[word] then n = n + 1 end end
    return n
end

------------------------------------------------------------
-- Reading the journal
------------------------------------------------------------

--- The instance ID for a raid whose name contains `needle`, or nil.
---
--- Searched by name across every tier rather than read from a constant,
--- because an instance ID for a raid that did not exist when this was
--- written is a number nobody can verify. Walking the tiers costs a few
--- dozen calls once per session and cannot be wrong.
local function FindInstance(needle)
    local numTiers = Call("GetNumTiers", "EJ_GetNumTiers") or 0
    local restore = Call("GetCurrentTier", "EJ_GetCurrentTier")
    needle = needle:lower()

    local found
    for tier = numTiers, 1, -1 do  -- newest first; this is a current raid
        Call("SelectTier", "EJ_SelectTier", tier)
        local index = 1
        while true do
            local id, name = Call("GetInstanceByIndex", "EJ_GetInstanceByIndex", index, true)
            if not id then break end
            if type(name) == "string" and name:lower():find(needle, 1, true) then
                found = { id = id, name = name, tier = tier }
                break
            end
            index = index + 1
        end
        if found then break end
    end

    -- Put the player's journal back where we found it. They may have had
    -- it open on a different tier.
    if restore then Call("SelectTier", "EJ_SelectTier", restore) end
    return found
end

--- Every encounter in an instance, in journal order.
---
--- rootSectionID is kept because it is the door to the rest of the
--- journal: every ability the encounter has hangs off it, and it is only
--- handed out here.
local function ReadEncounters(instanceID)
    Call("SelectInstance", "EJ_SelectInstance", instanceID)
    local out = {}
    local index = 1
    while true do
        local name, _, encounterID, rootSectionID, _, _, dungeonEncounterID =
            Call("GetEncounterInfoByIndex", "EJ_GetEncounterInfoByIndex", index)
        if not name then break end
        out[#out + 1] = {
            name = name,
            encounterID = encounterID,          -- journal encounter ID
            rootSectionID = rootSectionID,
            dungeonEncounterID = dungeonEncounterID,
            index = index,
        }
        index = index + 1
    end
    return out
end

------------------------------------------------------------
-- The section tree
--
-- An encounter's abilities are a linked tree, not a list: each section
-- points at its first child and at its next sibling, and the ones with a
-- spellID are the abilities. Walking it is the only way to ask the
-- client "what does this boss actually do", which is the question the
-- guide is answering from a transcript.
--
-- Read on demand, one boss at a time. Eight encounters' worth of tree is
-- several hundred API calls, and doing that when the player clicks Boss
-- Guide -- rather than when they click one boss -- is a stall they would
-- feel for no benefit.
------------------------------------------------------------

-- A ceiling on the walk. The tree is client data and the walk is
-- pointer-chasing, so a malformed sibling link would otherwise be an
-- infinite loop inside the UI thread.
local MAX_SECTIONS = 400

local function SectionInfo(id)
    if CEJ.GetSectionInfo then return CEJ.GetSectionInfo(id) end
    if _G.EJ_GetSectionInfo then
        -- The pre-table form returned a positional list. Only the fields
        -- this file uses are mapped; the rest were never read.
        local title, description, _, _, siblingID, _, firstChildID,
              filteredByDifficulty, link, startsOpen, _, spellID =
              _G.EJ_GetSectionInfo(id)
        if not title then return nil end
        return {
            title = title, description = description,
            siblingSectionID = siblingID, firstChildSectionID = firstChildID,
            filteredByDifficulty = filteredByDifficulty, link = link,
            startsOpen = startsOpen, spellID = spellID,
        }
    end
    return nil
end

--- Every section under `rootID`, flattened, with its depth.
local function ReadSectionTree(rootID)
    local out, seen, budget = {}, {}, MAX_SECTIONS

    local function walk(id, depth)
        while id and budget > 0 do
            -- A tree that points back at itself would otherwise be read
            -- forever; cheaper to notice than to guess a depth limit.
            if seen[id] then return end
            seen[id] = true
            budget = budget - 1

            local info = SectionInfo(id)
            if not info then return end
            out[#out + 1] = {
                id = id,
                title = info.title,
                description = info.description,
                spellID = info.spellID,
                filtered = info.filteredByDifficulty and true or false,
                depth = depth,
            }
            if info.firstChildSectionID then
                walk(info.firstChildSectionID, depth + 1)
            end
            id = info.siblingSectionID
        end
    end

    walk(rootID, 0)
    return out
end

------------------------------------------------------------
-- Enrichment
------------------------------------------------------------

--- Ask the client what these bosses are really called.
---
--- Runs at most once per session and is safe to call from anywhere --
--- if the journal has not loaded the raid yet, it simply reports that
--- and leaves the guide exactly as written.
---
--- Returns a small report table so the UI can say what happened rather
--- than silently changing text under the player.
function G:EnrichFromJournal()
    if self._enriched then return self._enriched end

    local report = { adopted = {}, ambiguous = {}, ok = false }

    if not (Call("GetNumTiers", "EJ_GetNumTiers")) then
        report.reason = "The Encounter Journal is not available yet."
        self._enriched = report
        return report
    end

    local inst = FindInstance(self.instance.name)
    if not inst then
        -- Not an error. The journal only carries a raid once the client
        -- has the data for it, and the guide stands on its own without.
        report.reason = "The Encounter Journal does not list "
            .. self.instance.name .. " on this client yet."
        self._enriched = report
        return report
    end

    self.instance.ejInstanceID = inst.id
    self.instance.ejName = inst.name

    local encounters = ReadEncounters(inst.id)
    report.encounters = encounters
    report.ok = true

    -- Every journal name, tokenised once rather than per boss.
    local ejTokens = {}
    for i, e in ipairs(encounters) do ejTokens[i] = tokens(e.name) end

    -- By ID, where we have one.
    local byEJ = {}
    for _, e in ipairs(encounters) do
        if e.encounterID then byEJ[e.encounterID] = e end
    end

    for _, boss in ipairs(self.bosses) do
        -- The ID path, which is not a guess at all.
        --
        -- The names in RaidGuideData now come with the journal ID they
        -- were read from, so for those the word-overlap matcher below is
        -- not needed -- and must not run, because it is a heuristic and
        -- this is an identity. It stays for anything without an ID and
        -- as the thing that catches an ID we got WRONG: if the journal
        -- has that ID under a name sharing no distinctive word with
        -- ours, that is worth reporting rather than adopting.
        local direct = boss.ejID and byEJ[boss.ejID]
        if direct then
            boss.ejName = direct.name
            boss.rootSectionID = direct.rootSectionID
            boss.dungeonEncounterID = direct.dungeonEncounterID
            if boss.name ~= direct.name then
                if overlap(tokens(boss.name), tokens(direct.name)) > 0 then
                    report.adopted[#report.adopted + 1] =
                        { was = boss.name, now = direct.name }
                    boss.name = direct.name
                else
                    report.mismatched = report.mismatched or {}
                    report.mismatched[#report.mismatched + 1] =
                        { ours = boss.name, journal = direct.name, ejID = boss.ejID }
                end
            end
            boss.unsure = nil
        else
            local ours = tokens(boss.name)
            local best, bestScore, tied = nil, 0, false
            for i, e in ipairs(encounters) do
                local score = overlap(ours, ejTokens[i])
                if score > bestScore then
                    best, bestScore, tied = e, score, false
                elseif score == bestScore and score > 0 then
                    tied = true
                end
            end

            boss.ejName = best and best.name or nil
            if best and bestScore > 0 and not tied then
                -- ejID, not encounterID. Those are two different numbers
                -- in this file's vocabulary -- the journal's encounter ID
                -- and the combat-log one -- and writing the journal's
                -- into the field the guide uses for the other would put
                -- a wrong ID in place of a missing one.
                boss.ejID = best.encounterID
                boss.rootSectionID = best.rootSectionID
                boss.dungeonEncounterID = best.dungeonEncounterID
                if boss.name ~= best.name then
                    report.adopted[#report.adopted + 1] = {
                        was = boss.name, now = best.name,
                    }
                    boss.name = best.name
                end
                -- The journal agreed with us, so the flag comes off and
                -- the UI stops apologising for the spelling.
                boss.unsure = nil
            elseif boss.unsure then
                report.ambiguous[#report.ambiguous + 1] = boss.name
            end
        end
    end

    self._enriched = report
    return report
end

------------------------------------------------------------
-- Abilities
------------------------------------------------------------

--- Everything the journal lists for one boss, read once and kept.
---
--- Returns the flat section list, or nil with a reason. Safe to call on
--- every refresh: after the first read it is a table lookup.
function G:ReadAbilities(boss)
    if not boss then return nil, "no boss" end
    if boss.journal then return boss.journal end

    self:EnrichFromJournal()
    if not boss.rootSectionID then
        return nil, "the Encounter Journal has no sections for this boss yet"
    end

    -- Selecting the encounter first, because the journal is a stateful
    -- API: the section calls answer for whatever is currently selected on
    -- some builds, and a read that happens to work on this client and
    -- returns nil on the next is the worst kind of dependency.
    Call("SelectEncounter", "EJ_SelectEncounter", boss.ejID)

    local sections = ReadSectionTree(boss.rootSectionID)
    boss.journal = sections
    return sections
end

--- Ability titles the journal lists and our text never mentions.
---
--- The guide is written from a video, so the interesting failure is not a
--- wrong sentence -- it is a mechanic the video skipped and we therefore
--- never knew about. This is the check for that, and it runs against the
--- client's own list rather than against anybody's memory.
---
--- Conservative on purpose: a title counts as mentioned when all of its
--- distinctive words appear somewhere in our text for that boss, so
--- "Hungering Pyre" is matched by a line that says "the Pyre" only if it
--- also says "hungering" -- and a false "you missed this" is a cheap
--- error while a false "all covered" is the expensive one.
function G:UnmentionedAbilities(boss)
    local sections = self:ReadAbilities(boss)
    if not sections then return {} end

    -- One haystack from every line we print for this boss.
    local parts = { boss.oneLiner or "", boss.shape or "" }
    local function add(list)
        for _, line in ipairs(list or {}) do parts[#parts + 1] = line end
    end
    add(boss.rules)
    add(boss.heroic)
    for _, phase in ipairs(boss.phases or {}) do
        parts[#parts + 1] = phase.name or ""
        parts[#parts + 1] = phase.tag or ""
        add(phase.lines)
    end
    for _, role in pairs(boss.roles or {}) do add(role) end
    local haystack = table.concat(parts, " "):lower():gsub("'", "")

    local out, seen = {}, {}
    for _, section in ipairs(sections) do
        -- Only the sections that are abilities. A heading with no spell
        -- behind it is the journal's own structure ("Stage One"), and
        -- reporting those as missing mechanics would bury the real ones.
        if section.spellID and section.title and not seen[section.title] then
            seen[section.title] = true
            local missing = false
            for word in section.title:gsub("'", ""):gmatch("[%a]+") do
                if #word >= 4 and not haystack:find(word:lower(), 1, true) then
                    missing = true
                    break
                end
            end
            if missing then out[#out + 1] = section.title end
        end
    end
    return out
end

------------------------------------------------------------
-- /yh ejdump — what the journal actually holds
--
-- A developer command, not a player one, and deliberately not in /yh
-- help. Its whole purpose is to answer "is the guide's spelling right"
-- from inside the client, since that cannot be checked from outside it.
------------------------------------------------------------
--- `/yh ejdump` for the encounter list, `/yh ejdump abilities` for every
--- ability of every boss and which ones our text never mentions.
function G:DumpJournal(mode)
    local report = self:EnrichFromJournal()
    print("|cff00ff00=== YippYapp raid guide vs Encounter Journal ===|r")
    if not report.ok then
        print("  " .. (report.reason or "unavailable"))
        return
    end
    print(("  instance: %s (id %d)"):format(
        self.instance.ejName or "?", self.instance.ejInstanceID or 0))
    for _, e in ipairs(report.encounters or {}) do
        print(("  |cff888888%d.|r %s |cff555555(journal %s, combat log %s)|r"):format(
            e.index, e.name, tostring(e.encounterID),
            tostring(e.dungeonEncounterID)))
    end
    for _, a in ipairs(report.adopted) do
        print(("  |cffffcc00renamed|r %s -> %s"):format(a.was, a.now))
    end
    -- Louder than "ambiguous", because it means one of the IDs written
    -- into RaidGuideData points at a boss it should not.
    for _, m in ipairs(report.mismatched or {}) do
        print(("  |cffff4444ID MISMATCH|r ejID %s is %s, we call it %s"):format(
            tostring(m.ejID), m.journal, m.ours))
    end
    for _, name in ipairs(report.ambiguous) do
        print(("  |cffff4444no confident match|r for %s"):format(name))
    end

    if mode ~= "abilities" then
        print("  |cff888888/yh ejdump abilities|r for the full section tree.")
        return
    end

    for _, boss in ipairs(self.bosses) do
        local sections, why = self:ReadAbilities(boss)
        print(("|cff00ff00-- %s|r"):format(boss.name))
        if not sections then
            print("   " .. (why or "no sections"))
        else
            for _, s in ipairs(sections) do
                print(("   %s%s%s%s"):format(
                    string.rep("  ", s.depth),
                    s.title or "?",
                    s.spellID and ("|cff555555 (spell %d)|r"):format(s.spellID) or "",
                    s.filtered and " |cff886600[other difficulty]|r" or ""))
            end
            local missing = self:UnmentionedAbilities(boss)
            if #missing > 0 then
                print(("   |cffffcc00not mentioned by our guide:|r %s"):format(
                    table.concat(missing, ", ")))
            end
        end
    end
end
