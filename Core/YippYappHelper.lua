local addonName, ns = ...

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGOUT" then
        -- Save raid scan data
        YippYappHelperDB = YippYappHelperDB or {}
        if ns.RaidInspectData and next(ns.RaidInspectData) then
            YippYappHelperDB.raidInspect = ns.RaidInspectData
        else
            YippYappHelperDB.raidInspect = nil
        end
    end
end)
