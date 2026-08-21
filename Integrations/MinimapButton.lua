local _, ns = ...

------------------------------------------------------------
-- Minimap button via LibDBIcon (works with ElvUI, SexyMap, etc.)
------------------------------------------------------------
local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

-- The art is full bleed, which is what lets it fill the tracking ring.
local ICON_TEXTURE = "Interface\\AddOns\\YippYappHelper\\Media\\YippYappHelper"

-- Create the data broker object
local dataObject = LDB:NewDataObject("YippYappHelper", {
    type = "launcher",
    text = "YippYapp Helper",
    icon = ICON_TEXTURE,

    OnClick = function(self, button)
        if button == "LeftButton" then
            -- Through OpenMain, which is what "open YippYapp" means.
            -- This used to call ToggleApp directly, so the addon's
            -- most-clicked button was the one door that still opened the
            -- pre-shell window. That window is gone; this stays routed
            -- through the front door.
            if ns.OpenMain then ns:OpenMain() end
        elseif button == "RightButton" then
            -- The shell's Gear page, not the standalone gear window.
            --
            -- This shortcut predates both later UIs and still opened the
            -- original frame -- so the same icon handed you two different
            -- addons depending on which button you pressed. The old
            -- window is still built and still opens at an upgrade vendor
            -- and on /yh classic; it is just no longer something you can
            -- arrive at without asking for it.
            if ns.OpenTo and ns:OpenTo("gear") then
                return
            end
            if ns.MainFrame then
                if ns.MainFrame:IsShown() then
                    ns.MainFrame:Hide()
                else
                    if ns.RefreshAllSlots then ns:RefreshAllSlots() end
                    if ns.RefreshCrests then ns:RefreshCrests() end
                    if ns.AnchorFrame then ns:AnchorFrame() end
                    ns.MainFrame:Show()
                end
            end
        end
    end,

    OnTooltipShow = function(tooltip)
        tooltip:SetText("|cff00ff00YippYapp Helper|r")
        tooltip:AddLine("Left-click: Open YippYapp", 1, 1, 1)
        tooltip:AddLine("Right-click: Gear Upgrades", 1, 1, 1)
        tooltip:AddLine("Drag to reposition", 0.5, 0.5, 0.5)
    end,
})

------------------------------------------------------------
-- LibDBIcon sizes the icon at 18x18 inside a 31x31 button and shows only
-- the middle 90% of the texture, so a full-bleed mark ends up floating
-- small inside the tracking ring. Fill the ring instead.
--
-- 20 is as large as the octagon goes before its corners foul the ring:
-- a regular octagon measures 1.082x its width across the corners, so 20
-- wide spans ~21.6, and the ring's opening is roughly 22.
------------------------------------------------------------
-- LibDBIcon anchors the ring texture by its TOPLEFT at 50x50 over a 31x31
-- button, so the ring's centre does not land exactly on the button's. The
-- gap is well under a pixel and invisible at 18px, but it shows once the
-- icon grows enough to approach the ring. Nudge the icon onto the ring's
-- actual centre. Tune live with /yh icon, then bake the numbers in here.
local ICON_SIZE = 20
local ICON_OFF_X = 0.5
local ICON_OFF_Y = 0.7

local function FillMinimapIcon(button)
    local icon = button and button.icon
    if not icon then return end
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", ICON_OFF_X, ICON_OFF_Y)

    -- Show the whole texture. Press feedback is kept but inverted: the
    -- icon dips inward while held, rather than sitting permanently
    -- cropped and springing outward on click.
    icon.UpdateCoord = function(self)
        local d = self:GetParent().isMouseDown and 0.06 or 0
        self:SetTexCoord(d, 1 - d, d, 1 - d)
    end
    icon:UpdateCoord()
end

-- Register with LibDBIcon on load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    YippYappHelperDB = YippYappHelperDB or {}

    -- Migrate old saved angle to LibDBIcon format
    if YippYappHelperDB.minimapAngle and not YippYappHelperDB.libDBIcon then
        YippYappHelperDB.libDBIcon = {}
    end
    YippYappHelperDB.libDBIcon = YippYappHelperDB.libDBIcon or {}

    -- Migrate old hide setting
    if YippYappHelperDB.hideMinimapButton then
        YippYappHelperDB.libDBIcon.hide = true
        YippYappHelperDB.hideMinimapButton = nil
    end

    DBIcon:Register("YippYappHelper", dataObject, YippYappHelperDB.libDBIcon)

    ns.MinimapButton = DBIcon:GetMinimapButton("YippYappHelper")
    FillMinimapIcon(ns.MinimapButton)
end)

--- Live tuning for the ring fit, since it can only be judged on screen.
--- `/yh icon 20 -0.7 0.7`, or `/yh icon` to show the current values.
function ns:TuneMinimapIcon(size, offX, offY)
    local icon = ns.MinimapButton and ns.MinimapButton.icon
    if not icon then
        print("|cffff5555YippYapp:|r minimap button not created yet")
        return
    end
    if size then
        ICON_SIZE = size
        ICON_OFF_X = offX or ICON_OFF_X
        ICON_OFF_Y = offY or ICON_OFF_Y
        icon:SetSize(ICON_SIZE, ICON_SIZE)
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", ICON_OFF_X, ICON_OFF_Y)
    end
    print(("|cff00ff00YippYapp:|r icon size %s, offset %s, %s")
        :format(ICON_SIZE, ICON_OFF_X, ICON_OFF_Y))
end
