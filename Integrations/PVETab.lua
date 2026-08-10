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

    -- Capture the existing last tab BEFORE creating ours — PanelTabButtonTemplate's
    -- OnLoad may auto-insert the new tab into PVEFrame.Tabs, which would otherwise
    -- make us anchor to ourselves.
    local numTabs = PVEFrame.numTabs or (PVEFrame.Tabs and #PVEFrame.Tabs) or 0
    local tabIndex = numTabs + 1
    local anchorTab
    if PVEFrame.Tabs and #PVEFrame.Tabs > 0 then
        anchorTab = PVEFrame.Tabs[#PVEFrame.Tabs]
    elseif numTabs > 0 then
        anchorTab = _G["PVEFrameTab" .. numTabs]
    end

    local tab = CreateFrame("Button", "PVEFrameTab" .. tabIndex, PVEFrame, "PanelTabButtonTemplate")
    tab:SetText("Keys")
    tab:SetID(tabIndex)
    PanelTemplates_TabResize(tab, 15, nil, 70)
    PanelTemplates_DeselectTab(tab)

    if anchorTab and anchorTab ~= tab then
        tab:SetPoint("TOPLEFT", anchorTab, "TOPRIGHT", 4, 0)
    end

    -- Register in PVEFrame's tab system
    if PVEFrame.Tabs then
        table.insert(PVEFrame.Tabs, tab)
    end
    PVEFrame.numTabs = tabIndex

    tab:SetScript("OnClick", function()
        -- Pure launcher: don't touch PVEFrame's tab state or content panels.
        -- Just open our app to the mythic+ page. Defer the tab visual reset
        -- one frame so it never runs inline with Blizzard's click dispatch,
        -- keeping the PVEFrame tab-state machine untouched in combat.
        C_Timer.After(0, function()
            if tab then PanelTemplates_DeselectTab(tab) end
        end)
        if not ns.AppFrame then return end
        ns.AppFrame:Hide()
        ns:ShowAppPage("mythicplus")
        ns.AppFrame:Show()
    end)

    -- Ensure our tab never ends up visually "selected"
    hooksecurefunc("PVEFrame_ShowFrame", function()
        if tab then PanelTemplates_DeselectTab(tab) end
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
