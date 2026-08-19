local _, ns = ...

------------------------------------------------------------
-- Add a "Keys" tab to the PVEFrame (Group Finder)
-- Opens the YippYapp Mythic+ page in the app frame
------------------------------------------------------------
local tabCreated = false

local function CreatePVETab()
    if tabCreated then return end
    if not PVEFrame then return end

    tabCreated = true

    -- A button that SITS BESIDE Blizzard's tabs, and is not one of them.
    --
    -- This used to enrol itself properly: it took the next tab index, took
    -- the reserved "PVEFrameTab<n>" global name, appended itself to
    -- PVEFrame.Tabs and wrote PVEFrame.numTabs. Every one of those hands
    -- Blizzard's tab machinery something an addon created, and PVEFrame is
    -- the Group Finder -- PVEFrame_ShowFrame and the PanelTemplates
    -- helpers read numTabs and walk the Tabs list, so the taint travelled
    -- straight into the frame that queues you for things. Queueing is
    -- protected, and a blocked protected call is silent unless
    -- scriptErrors is on: the Join button simply stops working, with no
    -- error to connect it to us. It ran on every login the moment
    -- Blizzard_GroupFinder loaded, whether or not anyone clicked the tab.
    --
    -- None of it bought anything. The OnClick below already refuses to
    -- participate in Blizzard's tab state ("pure launcher"), and the old
    -- code then spent two separate deselect calls undoing the selection
    -- that enrolling had invited. Not enrolling is the same result with
    -- nothing to undo.
    --
    -- What is left touches only our own button: anchoring it after the
    -- last real tab, and the two PanelTemplates helpers, which write to
    -- the button passed in and nothing else.
    local anchorTab
    if PVEFrame.Tabs and #PVEFrame.Tabs > 0 then
        anchorTab = PVEFrame.Tabs[#PVEFrame.Tabs]
    else
        local n = PVEFrame.numTabs or 0
        if n > 0 then anchorTab = _G["PVEFrameTab" .. n] end
    end

    -- Named out of Blizzard's namespace on purpose. PanelTemplates looks
    -- siblings up as _G[parentName .. "Tab" .. i], so a button called
    -- PVEFrameTab5 gets found and driven by tab code we are trying to
    -- stay out of.
    local tab = CreateFrame("Button", "YippYappPVEFrameTab", PVEFrame, "PanelTabButtonTemplate")
    tab:SetText("Keys")
    PanelTemplates_TabResize(tab, 15, nil, 70)
    PanelTemplates_DeselectTab(tab)

    if anchorTab then
        tab:SetPoint("TOPLEFT", anchorTab, "TOPRIGHT", 4, 0)
    end

    tab:SetScript("OnClick", function()
        -- Pure launcher: Blizzard's tab state and content panels are not
        -- ours to touch. Nothing selects this button, so nothing has to
        -- deselect it either.
        if ns.OpenTo then ns:OpenTo("mythicplus") end
    end)
end

-- Wait for PVEFrame to be available
local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "Blizzard_GroupFinder" or addonName == "Blizzard_PVPUI" then
        C_Timer.After(0, function()
            if PVEFrame then
                CreatePVETab()
            end
        end)
    end
end)

-- Also try on PVEFrame show (in case it loaded before us)
if PVEFrame then
    CreatePVETab()
end
