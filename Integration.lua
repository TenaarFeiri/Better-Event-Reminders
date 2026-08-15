local _, ns = ...

local Config = ns.Config
local Integration = {}
ns.Integration = Integration

local function CreatePlainButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)
    button:RegisterForClicks("LeftButtonUp")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.12, 0.12, 0.12, 0.95)

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    label:SetText(text or "")
    button.Label = label
    return button
end

function Integration:OpenBERSettings()
    if SettingsPanel and SettingsPanel:IsShown() then
        SettingsPanel:Hide()
    elseif InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        InterfaceOptionsFrame:Hide()
    end

    C_Timer.After(0, function()
        ns.Settings:Show()
    end)
end

function Integration:RegisterSettingsCategory()
    if self.settingsRegistered then return true end

    local blizzardSettings = _G.Settings
    if blizzardSettings and blizzardSettings.RegisterCanvasLayoutCategory then
        local panel = CreateFrame("Frame")
        panel:SetSize(600, 300)

        local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -24)
        title:SetText("Better Event Reminders")
        title:SetTextColor(1, 0.82, 0, 1)

        local description = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        description:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -58)
        description:SetWidth(540)
        description:SetJustifyH("LEFT")
        description:SetText("Open Better Event Reminders to configure alerts, suppression rules, and the minimap launcher.")

        local button = CreatePlainButton(panel, 240, 28, "Open Better Event Reminders")
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -104)
        button:SetScript("OnClick", function()
            self:OpenBERSettings()
        end)

        local category = blizzardSettings.RegisterCanvasLayoutCategory(panel, ns.Name)
        blizzardSettings.RegisterAddOnCategory(category)
        self.settingsPanel = panel
        self.settingsCategory = category
        self.settingsRegistered = true
        return true
    end

    if InterfaceOptions_AddCategory then
        local panel = CreateFrame("Frame")
        panel.name = ns.Name
        local button = CreatePlainButton(panel, 240, 28, "Open Better Event Reminders")
        button:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, -24)
        button:SetScript("OnClick", function()
            self:OpenBERSettings()
        end)
        InterfaceOptions_AddCategory(panel)
        self.settingsPanel = panel
        self.settingsRegistered = true
        return true
    end

    return false
end

function Integration:PositionMinimapButton()
    if not self.minimapButton or not Minimap then return end

    local config = Config:Get("minimap")
    local angle = math.rad(config.angle or 220)
    local width = Minimap:GetWidth() or 140
    local radius = width / 2 + 10
    self.minimapButton:ClearAllPoints()
    self.minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

function Integration:UpdateMinimapButtonAngle()
    if not Minimap or not self.minimapButton then return end

    local centerX, centerY = Minimap:GetCenter()
    local cursorX, cursorY = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    if not centerX or not centerY or not scale then return end

    cursorX = cursorX / scale
    cursorY = cursorY / scale
    local angle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
    Config:Get("minimap").angle = angle
    self:PositionMinimapButton()
end

function Integration:CreateFallbackMinimapButton()
    if self.minimapButton or not Minimap then return end

    local button = CreateFrame("Button", "BetterEventRemindersMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(20, 20)
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    background:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("TOPLEFT", button, "TOPLEFT", 7, -5)
    if icon.SetAtlas then
        icon:SetAtlas("event-scheduler-reminder-icon")
    else
        icon:SetTexture("Interface\\Icons\\INV_Misc_Note_06")
    end

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(53, 53)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetPoint("TOPLEFT", button, "TOPLEFT")

    button:SetScript("OnClick", function()
        self:OpenBERSettings()
    end)
    button:SetScript("OnDragStart", function(selfButton)
        selfButton:SetScript("OnUpdate", function()
            self:UpdateMinimapButtonAngle()
        end)
    end)
    button:SetScript("OnDragStop", function(selfButton)
        selfButton:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(selfButton)
        GameTooltip:SetOwner(selfButton, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(ns.Name)
        GameTooltip:AddLine("Open settings", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    self.minimapButton = button
    self:PositionMinimapButton()
end

function Integration:ApplyDBIconAtlas()
    if not self.dbIcon or not self.dbIcon.GetMinimapButton then return end

    local button = self.dbIcon:GetMinimapButton(ns.Name)
    if button and button.icon and button.icon.SetAtlas
        and C_Texture and C_Texture.GetAtlasInfo
        and C_Texture.GetAtlasInfo("event-scheduler-reminder-icon") then
        button.icon:SetAtlas("event-scheduler-reminder-icon")
    end
end

function Integration:CreateMinimapLauncher()
    if self.minimapRegistered then return true end

    local libStub = _G.LibStub
    local ldb = libStub and libStub("LibDataBroker-1.1", true)
    local dbIcon = libStub and libStub("LibDBIcon-1.0", true)
    if ldb and dbIcon then
        local dataObject = ldb:NewDataObject(ns.Name, {
            type = "launcher",
            icon = "event-scheduler-reminder-icon",
            OnClick = function()
                self:OpenBERSettings()
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine(ns.Name)
                tooltip:AddLine("Open settings", 0.7, 0.7, 0.7)
            end,
        })
        local config = Config:Get("minimap")
        dbIcon:Register(ns.Name, dataObject, config)
        self.dbIcon = dbIcon
        self.ldbObject = dataObject
        self.minimapRegistered = true
        self:ApplyDBIconAtlas()
        self:ApplyMinimapVisibility()
        return true
    end

    if Minimap then
        self:CreateFallbackMinimapButton()
        self.minimapRegistered = self.minimapButton ~= nil
        self:ApplyMinimapVisibility()
        return self.minimapRegistered
    end

    return false
end

function Integration:ApplyMinimapVisibility()
    local enabled = Config:Get("showMinimapButton") ~= false
    local config = Config:Get("minimap")
    config.hide = not enabled

    if self.dbIcon and self.ldbObject then
        self:ApplyDBIconAtlas()
        if enabled then
            self.dbIcon:Show(ns.Name)
        else
            self.dbIcon:Hide(ns.Name)
        end
    elseif self.minimapButton then
        self.minimapButton:SetShown(enabled)
        if enabled then
            self:PositionMinimapButton()
        end
    end
end

function Integration:Initialize()
    self:RegisterSettingsCategory()
    self:CreateMinimapLauncher()
end
