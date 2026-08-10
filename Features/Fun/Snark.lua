local _, ns = ...

------------------------------------------------------------
-- Snark: the addon's opinion of you.
--
-- A single voice -- dry, faintly exasperated, machine-ish -- that reacts
-- to things it can already see: how much you jump, how your gear is
-- coming along, and whether crests are rotting in your bags.
--
-- Two rules keep this from getting tiresome:
--
--   1. It only ever teases about effort, never about ability. "You have
--      jumped a lot" is funny; "you are bad at this game" is not, and a
--      tool that insults its user stops being used.
--   2. Lines are chosen deterministically from the value itself, not at
--      random. A remark that changes every time you mouse over reads as
--      noise; one that stays put until the number moves reads as an
--      opinion.
------------------------------------------------------------

ns.Snark = ns.Snark or {}
local SN = ns.Snark

--- Picks an entry from `lines` using `value` as the seed, so the same
--- state always produces the same remark.
local function pick(lines, value)
    if #lines == 0 then return nil end
    return lines[(math.floor(value or 0) % #lines) + 1]
end

--- Highest tier whose threshold the value has passed.
local function tierFor(tiers, value)
    local found
    for _, t in ipairs(tiers) do
        if (value or 0) >= t.at then found = t else break end
    end
    return found
end

------------------------------------------------------------
-- Jumps
------------------------------------------------------------

SN.JUMP_TIERS = {
    { at = 0, lines = {
        "Movement logged. No notes.",
    } },
    { at = 50, lines = {
        "You have jumped %s times. I am counting, apparently.",
        "%s jumps. The ground remains where you left it.",
    } },
    { at = 250, lines = {
        "%s jumps. Stairs exist, for reference.",
        "%s jumps. None of them were necessary.",
    } },
    { at = 1000, lines = {
        "%s jumps. I have started rounding.",
        "%s jumps. At some point this became a hobby.",
        "%s jumps. Your keyboard has feelings about the spacebar.",
    } },
    { at = 5000, lines = {
        "%s jumps. I am no longer sure you can walk.",
        "%s jumps. This is a lifestyle now.",
        "%s jumps. I have run out of ways to say this.",
    } },
    { at = 20000, lines = {
        "%s jumps. I have told the other addons.",
        "%s jumps. Somewhere, a physicist is upset.",
    } },
}

function SN:Jumps()
    local n = (ns.FunStats and ns.FunStats:Get("jumps")) or 0
    local tier = tierFor(self.JUMP_TIERS, n)
    if not tier then return nil end
    local line = pick(tier.lines, n)
    if not line then return nil end
    if line:find("%%s") then
        return line:format(BreakUpLargeNumbers(n))
    end
    return line
end

------------------------------------------------------------
-- Gear
------------------------------------------------------------
-- Phrased against the player's own goal rather than a fixed number, so a
-- Normal-content player is never nagged with Mythic expectations.

--- Target is the top of the track the player's goal implies, so a Normal
--- player is measured against Champion rather than Mythic gear.
local PROFILE_TARGET_TRACK = {
    normal = "Champion",
    heroic = "Hero",
    mythic = "Myth",
}

function SN:Gear()
    local _, equipped = GetAverageItemLevel()
    local ilvl = math.floor(equipped or 0)
    if ilvl <= 0 then return nil end

    local profile = ns.GetCurrentProfile and ns:GetCurrentProfile()
    local track = PROFILE_TARGET_TRACK[(profile and profile.id) or "normal"]
    local target = track and ns.GetMaxIlvlForTrack and ns:GetMaxIlvlForTrack(track)
    if not target or target <= 0 then return nil end

    local gap = target - ilvl
    if gap <= 0 then
        return pick({
            "Item level %d. Ahead of your own goal. Suspicious.",
            "Item level %d. Nothing left to nag you about here.",
        }, ilvl):format(ilvl)
    elseif gap <= 6 then
        return pick({
            "Item level %d. Close enough that I will stop mentioning it.",
            "Item level %d. Nearly there. Do not get distracted.",
        }, ilvl):format(ilvl)
    elseif gap <= 20 then
        return pick({
            "Item level %d. There is work outstanding.",
            "Item level %d. The vault is not going to fill itself.",
        }, ilvl):format(ilvl)
    end
    return pick({
        "Item level %d. We are some distance from the stated plan.",
        "Item level %d. I remain optimistic. Barely.",
    }, ilvl):format(ilvl)
end

------------------------------------------------------------
-- Crests
------------------------------------------------------------
-- Unspent crests are the one genuinely actionable thing here: they cap,
-- and a full wallet is wasted weekly income.

function SN:Crests()
    if not ns.GetCrestInfo then return nil end
    local ok, crests = pcall(ns.GetCrestInfo, ns)
    if not ok or type(crests) ~= "table" then return nil end

    -- The largest unspent pile is the one worth mentioning.
    local worst, worstAmount = nil, 0
    for _, c in ipairs(crests) do
        if (c.quantity or 0) > worstAmount then
            worst, worstAmount = c.track or c.name, c.quantity
        end
    end
    if not worst or worstAmount < 30 then return nil end

    if worstAmount >= 120 then
        return pick({
            "%d %s crests, unspent. They do not accrue interest.",
            "%d %s crests. Sitting in a bag, achieving nothing.",
        }, worstAmount):format(worstAmount, worst)
    end
    return pick({
        "%d %s crests waiting on you.",
        "%d %s crests. Whenever you are ready.",
    }, worstAmount):format(worstAmount, worst)
end

------------------------------------------------------------
-- Pick something to say
------------------------------------------------------------

--- One remark, preferring whatever is most actionable. Crests first
--- because they are the only one the player can fix this minute; jumps
--- last because it is pure decoration.
function SN:Remark()
    return self:Crests() or self:Gear() or self:Jumps()
end
