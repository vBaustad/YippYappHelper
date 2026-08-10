local _, ns = ...

------------------------------------------------------------
-- Spec / class metadata used by the raid-swap balancer.
--
-- Position encoding loosely follows NSRT's SetupManager:
--   1 = melee DPS
--   2 = melee healer (toggles with melee density checks)
--   3 = ranged DPS
--   4 = ranged healer
--   5 = tank
-- Role itself is authoritative for tank/heal counting; pos adds melee
-- vs ranged nuance for dps-side balance.
--
-- canLust: the raid-wide haste buff. Shamans/Mages/Evokers cast it;
-- Hunters bring it via Primal Rage through their pet.
-- canBrez: combat rez. Druid (Rebirth), DK (Raise Ally), Warlock
-- (Soulstone), Paladin (Intercession in TWW).
------------------------------------------------------------

ns.SpecMeta = ns.SpecMeta or {}
local M = ns.SpecMeta

M.POS = {
    -- Death Knight
    [250] = 5,  -- Blood
    [251] = 1,  -- Frost
    [252] = 1,  -- Unholy
    -- Demon Hunter
    [577] = 1,  -- Havoc
    [581] = 5,  -- Vengeance
    [1480] = 1, -- Devourer (TWW)
    -- Druid
    [102] = 3,  -- Balance
    [103] = 1,  -- Feral
    [104] = 5,  -- Guardian
    [105] = 4,  -- Restoration
    -- Evoker
    [1467] = 3, -- Devastation
    [1468] = 4, -- Preservation
    [1473] = 3, -- Augmentation
    -- Hunter
    [253] = 3,  -- Beast Mastery
    [254] = 3,  -- Marksmanship
    [255] = 1,  -- Survival
    -- Mage
    [62] = 3,   -- Arcane
    [63] = 3,   -- Fire
    [64] = 3,   -- Frost
    -- Monk
    [268] = 5,  -- Brewmaster
    [270] = 2,  -- Mistweaver (melee healer)
    [269] = 1,  -- Windwalker
    -- Paladin
    [65] = 4,   -- Holy (technically melee but usually positioned ranged)
    [66] = 5,   -- Protection
    [70] = 1,   -- Retribution
    -- Priest
    [256] = 4,  -- Discipline
    [257] = 4,  -- Holy
    [258] = 3,  -- Shadow
    -- Rogue
    [259] = 1,  -- Assassination
    [260] = 1,  -- Outlaw
    [261] = 1,  -- Subtlety
    -- Shaman
    [262] = 3,  -- Elemental
    [263] = 1,  -- Enhancement
    [264] = 4,  -- Restoration
    -- Warlock
    [265] = 3,  -- Affliction
    [266] = 3,  -- Demonology
    [267] = 3,  -- Destruction
    -- Warrior
    [71] = 1,   -- Arms
    [72] = 1,   -- Fury
    [73] = 5,   -- Protection
}

-- Classes with a class-wide lust (Heroism / Bloodlust / Time Warp /
-- Fury of the Aspects / Primal Rage via pet). Not spec-gated because
-- every Shaman/Mage/Evoker/Hunter can provide it.
M.CAN_LUST_BY_CLASS = {
    MAGE    = true,
    SHAMAN  = true,
    EVOKER  = true,
    HUNTER  = true,
}

-- Classes with a combat rez (Rebirth / Raise Ally / Soulstone /
-- Intercession). Class-wide because any of their specs can cast it.
M.CAN_BREZ_BY_CLASS = {
    DRUID       = true,
    DEATHKNIGHT = true,
    WARLOCK     = true,
    PALADIN     = true,
}

-- Query helpers. Pass whatever you have — specID preferred, class
-- fallback — and we'll return the best answer available.
function M:GetPos(specID, classFile, role)
    if specID and self.POS[specID] then return self.POS[specID] end
    -- Role-based fallback when we don't have a spec (e.g. target isn't
    -- inspected yet). Tank → 5, Healer → 4, DPS → 1 by default.
    if role == "TANK" then return 5 end
    if role == "HEALER" then return 4 end
    return 1
end

function M:CanLust(specID, classFile)
    if classFile and self.CAN_LUST_BY_CLASS[classFile] then return true end
    return false
end

function M:CanBrez(specID, classFile)
    if classFile and self.CAN_BREZ_BY_CLASS[classFile] then return true end
    return false
end
