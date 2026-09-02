local addonName, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        -- Save raid scan data.
        --
        -- Only for a group that still exists. This is a snapshot of the
        -- people around you, kept so a reload mid-raid does not lose the
        -- scan -- and it is worth nothing at all once you have left.
        -- Written unconditionally, it was the largest thing in the saved
        -- variables file by a factor of three, and every row in it was
        -- about somebody the player would never see again.
        YippYappHelperDB = YippYappHelperDB or {}
        local keep = nil
        if ns.RaidInspectData and next(ns.RaidInspectData)
            and IsInGroup and IsInGroup() then
            keep = ns.RaidInspectData
        end
        YippYappHelperDB.raidInspect = keep
    end
end)
