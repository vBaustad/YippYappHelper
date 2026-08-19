local _, ns = ...

------------------------------------------------------------
-- Delves data.
--
-- Everything here is asked of the client. Nothing in this file records
-- a companion id, a faction id, a curio id or a season number, because
-- all four change between seasons and a stale one does not error -- it
-- reads as zero, or as nothing found, and turns the page into a
-- confident lie.
--
-- What is verified, and where that verification came from:
--
--   C_DelvesUI.GetFactionForCompanion    XPBarEnhanced, Plumber
--   C_DelvesUI.HasActiveDelve            Plumber, Vaultloom
--   C_DelvesUI.GetCurrentDelvesSeasonNumber   Plumber
--   C_PartyInfo.IsDelveInProgress        XPBarEnhanced, Plumber
--   C_GossipInfo.GetFriendshipReputationRanks / GetFriendshipReputation
--                                        seven addons on this machine
--
-- The companion's "level" is a FRIENDSHIP rank, not a character level
-- and not plain reputation. Valeera reads 57 with a percentage toward
-- 58, which is GetFriendshipReputationRanks for the number and
-- GetFriendshipReputation for the bar within it.
--
-- Deliberately absent: curios and the Delver's Journey. Both are on
-- screen in the game and neither is reachable through any API used by
-- any addon installed here, so there is nothing to read and guessing
-- would fill the page with silence dressed as data.
--
-- The companion's PORTRAIT was in that list and is no longer. It is on
-- the friendship record this file already reads -- see
-- D:GetCompanionPortrait.
------------------------------------------------------------

ns.Delves = ns.Delves or {}
local D = ns.Delves

--- Call an API that may not exist on this client, and never let it
--- take the page down with it.
local function try(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if not ok then return nil end
    return a, b
end

------------------------------------------------------------
-- Companion
------------------------------------------------------------
--- The delve companion's faction, or nil if this client has no such
--- concept or the player has not met them yet.
function D:GetCompanionFactionID()
    local id = try(C_DelvesUI and C_DelvesUI.GetFactionForCompanion)
    id = tonumber(id)
    return (id and id > 0) and id or nil
end

------------------------------------------------------------
-- The companion's face.
--
-- It comes off the friendship record -- the same call the rank already
-- comes from, so this costs nothing and cannot disagree with the rest
-- of the card.
--
-- FriendshipReputationInfo.texture is the field. Verified the way
-- everything else in this file is verified, against an addon on this
-- machine that is maintained against a live client:
-- AllTheThings/src/Classes/Factions.lua defines a faction's `icon` as
-- exactly `friendInfo.texture`.
--
-- The first attempt at this went looking in Blizzard's companion window
-- instead, on the theory that whatever draws the portrait must have a
-- texture to hand. It walked the frame's regions for anything that
-- looked like art and used the first hit. That found something -- just
-- not the portrait, which is why the card drew a gold ring around
-- nothing. Almost certainly because that window shows the companion as
-- a 3D model rather than a picture, so there was no portrait texture in
-- it to find and the walk settled on a border.
--
-- The lesson kept here: matching on SHAPE ("a texture holding a
-- fileID") accepts any texture in the frame, so it cannot fail
-- visibly. It returns confidently wrong art instead of nothing, which
-- is the failure this file's header warns about in a different costume.
------------------------------------------------------------

--- The companion's portrait: a fileID or texture path, or nil.
---
--- nil is a legitimate answer -- a client with no friendship record for
--- the companion has no icon to give -- and callers must draw something
--- sensible for it rather than an empty frame.
function D:GetCompanionPortrait()
    local factionID = self:GetCompanionFactionID()
    if not factionID then return nil end

    local rep = try(C_GossipInfo and C_GossipInfo.GetFriendshipReputation, factionID)
    if type(rep) ~= "table" then return nil end

    local tex = rep.texture
    if type(tex) == "number" and tex > 0 then return tex end
    if type(tex) == "string" and tex ~= "" then return tex end
    return nil
end

--- The companion, as far as the client will say.
---
--- Returns nil rather than a table of zeroes when there is nothing to
--- report: a card that renders "Level 0, 0%" for a companion the player
--- has simply not unlocked is worse than no card.
---
--- `level`/`maxLevel` come from the friendship RANKS call and `pct` from
--- the reputation within the current rank. Either half can be missing
--- on its own -- a companion at maximum rank has no next threshold --
--- so both are optional and the caller decides what to draw.
function D:GetCompanion()
    local factionID = self:GetCompanionFactionID()
    if not factionID then return nil end

    local out = { factionID = factionID }

    local rep = try(C_GossipInfo and C_GossipInfo.GetFriendshipReputation, factionID)
    if type(rep) == "table" then
        out.name = rep.name
        out.standing = rep.reaction        -- the wordy rank name
        -- Same record, so the face and the rank can never be a patch
        -- apart from each other.
        local tex = rep.texture
        if (type(tex) == "number" and tex > 0)
            or (type(tex) == "string" and tex ~= "") then
            out.icon = tex
        end
        local cur, nxt = tonumber(rep.standing), tonumber(rep.nextThreshold)
        local base = tonumber(rep.reactionThreshold) or 0
        if cur and nxt and nxt > base then
            out.value, out.max = cur - base, nxt - base
            out.pct = math.min(math.max(out.value / out.max, 0), 1)
        end
    end

    local ranks = try(C_GossipInfo and C_GossipInfo.GetFriendshipReputationRanks, factionID)
    if type(ranks) == "table" then
        out.level = tonumber(ranks.currentLevel)
        out.maxLevel = tonumber(ranks.maxLevel)
    end

    -- The faction's own name is the fallback, since a companion with no
    -- friendship record still has one.
    if not out.name and C_Reputation and C_Reputation.GetFactionDataByID then
        local data = try(C_Reputation.GetFactionDataByID, factionID)
        if type(data) == "table" then out.name = data.name end
    end

    if not (out.name or out.level) then return nil end
    return out
end

------------------------------------------------------------
-- State
------------------------------------------------------------
--- Is the player in a delve right now? Two sources, because they answer
--- slightly different questions and either can be absent.
function D:IsActive()
    if try(C_PartyInfo and C_PartyInfo.IsDelveInProgress) == true then return true end
    if try(C_DelvesUI and C_DelvesUI.HasActiveDelve) == true then return true end
    return false
end

function D:GetSeasonNumber()
    return tonumber(try(C_DelvesUI and C_DelvesUI.GetCurrentDelvesSeasonNumber))
end

------------------------------------------------------------
-- The week
------------------------------------------------------------
--- Coffer keys, by name rather than by id.
---
--- The player's own dump of every weekly-capped currency came back with
--- Coffer Key Shards at 600 -- and NOT with "Restored Coffer Key", which
--- was the name guessed at first. The shards carry the cap; the keys are
--- what the shards become. Both are reported when present, and the one
--- with a weekly cap is the one worth a bar.
function D:GetKeys()
    if not ns.FindCurrencyByName then return nil end
    local out = {}

    local shards = ns:FindCurrencyByName("Coffer Key Shards")
    if shards and shards.currencyID and C_CurrencyInfo then
        local info = try(C_CurrencyInfo.GetCurrencyInfo, shards.currencyID)
        if type(info) == "table" then
            out.shards = tonumber(info.quantity) or 0
            out.shardCap = tonumber(info.maxWeeklyQuantity) or 0
            out.shardEarned = tonumber(info.quantityEarnedThisWeek) or 0
        end
    end

    local keys = ns:FindCurrencyByName("Restored Coffer Key")
    if keys then out.keys = tonumber(keys.quantity) or 0 end

    if out.shards == nil and out.keys == nil then return nil end
    return out
end

--- The delve slots of the Great Vault, from the snapshot the rest of the
--- addon already reads. No second source, so the page cannot disagree
--- with the dashboard about the same three slots.
function D:GetVaultTrack()
    if not (ns.Planner and ns.Planner.GetVaultSnapshot) then return nil end
    local snap = ns.Planner:GetVaultSnapshot()
    return snap and snap.world or nil
end

--- The tier ladder, straight from the Progression page's table.
---
--- Not retyped. That table carries a comment saying it was confirmed
--- against the Encounter Journal, and a second copy here would be a
--- second thing to correct when a season turns -- and the one that gets
--- forgotten.
function D:GetTiers()
    return (ns.PROGRESSION and ns.PROGRESSION.DELVES) or {}
end

--- The tiers that are gates rather than steps.
---
--- A ladder of eleven rows says what each tier pays and not which ones
--- are worth reaching, and those are different questions. Only two of
--- the eleven change what you can do rather than how much you get.
---
--- Both are stated independently by two season guides, which is why
--- they are here and the more contested claims from the same sources
--- are not: the crest track at tier 11 is disputed against this addon's
--- own Encounter Journal table, so it is left to that table to answer.
---
--- Nothing here is a reading of the player's state. There is no API in
--- use by any addon on this machine for the tier a character has
--- unlocked, so this says what the gates ARE, never where you stand
--- against them.
function D:GetTierGates()
    return {
        [8]  = "The lowest tier the Trove Hunter's Bounty map works in.",
        [10] = "Clearing one unlocks tier 11.",
    }
end
