local _, ns = ...

local Config = ns.Config
local UI = ns.UI
local Settings = {
    activeCategory = "alerts",
    controls = {},
    categoryControls = {},
    categoryFrames = {},
}
ns.Settings = Settings

local FRAME_WIDTH = 720
local FRAME_HEIGHT = 500
local SIDEBAR_WIDTH = 170
local CONTENT_LEFT = SIDEBAR_WIDTH + 20
local CONTENT_RIGHT = 42
local CONTENT_TOP = 58
local CONTENT_BOTTOM = 44

local function AddTooltip(region, text)
    if not text or text == "" or not region or not region.SetScript then return end
    region:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text)
        GameTooltip:Show()
    end)
    region:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function CreatePlainButton(parent, width, height, text)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height)

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.12, 0.12, 0.12, 0.95)
    button.Background = background

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("CENTER")
    label:SetText(text or "")
    button.Label = label
    button.SetText = function(self, value)
        self.Label:SetText(value)
    end
    return button
end

local function CreatePlainCheckButton(parent)
    local checkbox = CreateFrame("CheckButton", nil, parent)
    checkbox:SetSize(26, 26)

    local normal = checkbox:CreateTexture(nil, "ARTWORK")
    normal:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
    normal:SetAllPoints()
    checkbox:SetNormalTexture(normal)

    local pushed = checkbox:CreateTexture(nil, "ARTWORK")
    pushed:SetTexture("Interface\\Buttons\\UI-CheckBox-Down")
    pushed:SetAllPoints()
    checkbox:SetPushedTexture(pushed)

    local checked = checkbox:CreateTexture(nil, "OVERLAY")
    checked:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    checked:SetAllPoints()
    checkbox:SetCheckedTexture(checked)

    local highlight = checkbox:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
    highlight:SetAllPoints()
    checkbox:SetHighlightTexture(highlight)
    return checkbox
end

local function CreatePlainSlider(parent, name)
    local slider = CreateFrame("Slider", name, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.35, 0.35, 0.35, 1)
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(8)
    slider.Track = track

    local low = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
    slider.Low = low

    local high = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    high:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
    slider.High = high
    return slider
end

function Settings:Track(control)
    local controls = self.buildingControls or self.controls
    controls[#controls + 1] = control
    return control
end

function Settings:CloseDropdown()
    if self.dropdownMenu then
        self.dropdownMenu:Hide()
    end
end

function Settings:SavePosition()
    if not self.frame then return end
    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    if point then
        local position = Config:GetDB().settingsPosition
        position.point = point
        position.relativePoint = relativePoint or point
        position.x = x or 0
        position.y = y or 0
    end
end

function Settings:ApplyPosition()
    local position = Config:GetDB().settingsPosition
    self.frame:ClearAllPoints()
    self.frame:SetPoint(
        position.point,
        UIParent,
        position.relativePoint,
        position.x,
        position.y
    )
end

function Settings:AddLabel(text, x, y, width, fontObject)
    local label = self.content:CreateFontString(nil, "OVERLAY", fontObject or "GameFontHighlight")
    label:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, y)
    label:SetWidth(width)
    label:SetWordWrap(true)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    self:Track(label)
    return label
end

function Settings:AddCategoryHeader(category)
    self:AddLabel(category.label, 12, -18, 440, "GameFontNormalLarge")
    local description = self:AddLabel(category.description, 12, -48, 440, "GameFontHighlightSmall")
    description:SetTextColor(0.7, 0.7, 0.7, 1)
end

function Settings:AddBoolean(option, y)
    local checkbox = CreatePlainCheckButton(self.content)
    checkbox:SetPoint("TOPLEFT", self.content, "TOPLEFT", 8, y)
    checkbox:SetChecked(Config:Get(option.key) == true)
    checkbox:SetScript("OnClick", function(self)
        Config:Set(option.key, self:GetChecked() == true)
    end)
    AddTooltip(checkbox, option.tooltip)
    self:Track(checkbox)

    local label = self:AddLabel(option.label, 40, y - 3, 420)
    AddTooltip(label, option.tooltip)
    return y - 42
end

function Settings:ToggleDropdown(dropdown, option)
    if self.dropdownMenu and self.dropdownMenu:IsShown() then
        self:CloseDropdown()
        return
    end

    local menu = self.dropdownMenu
    if not menu then
        menu = CreateFrame("Frame", nil, UIParent)
        menu:SetFrameStrata("TOOLTIP")
        menu:SetSize(190, #option.choices * 26 + 8)
        menu:EnableMouse(true)

        local background = menu:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints()
        background:SetColorTexture(0.04, 0.04, 0.04, 0.98)

        for index, choice in ipairs(option.choices) do
            local item = CreatePlainButton(menu, 182, 24, choice.label)
            item:SetPoint("TOPLEFT", menu, "TOPLEFT", 4, -4 - ((index - 1) * 26))
            item:SetScript("OnClick", function()
                Config:Set(option.key, choice.value)
                dropdown.Refresh()
                self:CloseDropdown()
            end)
        end
        self.dropdownMenu = menu
    end

    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
    menu:Show()
end

function Settings:AddSelect(option, y)
    local label = self:AddLabel(option.label, 12, y, 195, "GameFontHighlight")

    local dropdown = CreatePlainButton(self.content, 180, 24, "")
    dropdown:SetPoint("TOPLEFT", self.content, "TOPLEFT", 220, y + 4)

    local function GetChoice(value)
        for _, choice in ipairs(option.choices) do
            if choice.value == value then return choice end
        end
    end

    local function Refresh()
        local choice = GetChoice(Config:Get(option.key)) or option.choices[1]
        dropdown:SetText(choice.label)
    end

    dropdown.Refresh = Refresh
    dropdown:SetScript("OnClick", function()
        self:ToggleDropdown(dropdown, option)
    end)
    Refresh()
    AddTooltip(dropdown, option.tooltip)
    self:Track(dropdown)

    if option.key == "soundKit" then
        local preview = CreatePlainButton(self.content, 64, 24, "Preview")
        preview:SetPoint("TOPLEFT", self.content, "TOPLEFT", 406, y + 4)
        preview:SetScript("OnClick", function()
            UI:PreviewAlertSound()
        end)
        self:Track(preview)
    end

    return y - 52
end

function Settings:AddNumber(option, y)
    local label = self:AddLabel(option.label, 12, y, 270, "GameFontHighlight")
    AddTooltip(label, option.tooltip)

    local valueText = self:AddLabel("", 310, y, 135, "GameFontHighlightSmall")
    valueText:SetJustifyH("RIGHT")
    valueText:SetTextColor(1, 0.82, 0, 1)

    local name = "BetterEventReminders" .. option.key .. "Slider"
    local slider = CreatePlainSlider(self.content, name)
    slider:SetPoint("TOPLEFT", self.content, "TOPLEFT", 12, y - 28)
    slider:SetWidth(360)
    slider:SetHeight(24)
    slider:SetMinMaxValues(option.min, option.max)
    slider:SetValueStep(option.step)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText(tostring(option.min))
    slider.High:SetText(tostring(option.max))

    local function refresh(value)
        value = math.floor(value + 0.5)
        valueText:SetText(option.format and option.format(value) or tostring(value))
    end

    slider:SetScript("OnValueChanged", function(_, value)
        local stored = Config:Set(option.key, value)
        refresh(stored or value)
    end)
    slider:SetValue(Config:Get(option.key))
    refresh(Config:Get(option.key))
    AddTooltip(slider, option.tooltip)
    self:Track(slider)

    local reset = CreatePlainButton(self.content, 58, 22, "Reset")
    reset:SetPoint("TOPLEFT", self.content, "TOPLEFT", 390, y - 27)
    reset:SetScript("OnClick", function()
        local value = Config:Reset(option.key)
        slider:SetValue(value)
        refresh(value)
    end)
    self:Track(reset)
    return y - 82
end

function Settings:BuildCategory(categoryId)
    local category
    for _, candidate in ipairs(Config.Categories) do
        if candidate.id == categoryId then
            category = candidate
            break
        end
    end
    if not category then return end

    self:CloseDropdown()
    if self.content then
        self.content:Hide()
    end

    local cached = self.categoryFrames[categoryId]
    if cached then
        self.content = cached.frame
        self.content:Show()
        self.scroll:SetScrollChild(self.content)
        self.controls = self.categoryControls[categoryId].controls
        self.content:SetHeight(cached.height)
        self.scroll:SetVerticalScroll(0)
        return
    end

    local content = CreateFrame("Frame", nil, self.scroll)
    content:SetSize(FRAME_WIDTH - CONTENT_LEFT - CONTENT_RIGHT, 400)
    self.content = content
    self.scroll:SetScrollChild(content)
    self.buildingControls = {}
    self:AddCategoryHeader(category)

    local y = -82
    for _, option in ipairs(category.options) do
        if option.kind == "boolean" then
            y = self:AddBoolean(option, y)
        elseif option.kind == "select" then
            y = self:AddSelect(option, y)
        elseif option.kind == "number" then
            y = self:AddNumber(option, y)
        end
    end

    local height = math.max(360, math.abs(y) + 30)
    self.content:SetHeight(height)
    self.categoryControls[categoryId] = {
        controls = self.buildingControls,
        height = height,
    }
    self.categoryFrames[categoryId] = {
        frame = content,
        height = height,
    }
    self.controls = self.buildingControls
    self.buildingControls = nil
end

function Settings:UpdateSidebarSelection()
    for id, button in pairs(self.sidebarButtons) do
        local selected = id == self.activeCategory
        button.SelectedBar:SetShown(selected)
        button.SelectedBackground:SetShown(selected)
        button.Label:SetFontObject(selected and GameFontHighlight or GameFontNormal)
    end
end

function Settings:SelectCategory(categoryId)
    self.activeCategory = categoryId
    self:UpdateSidebarSelection()
    self:BuildCategory(categoryId)
end

function Settings:CreateSidebar()
    self.sidebarButtons = {}
    local y = -12
    for _, category in ipairs(Config.Categories) do
        local button = CreatePlainButton(self.frame, SIDEBAR_WIDTH - 16, 32, category.label)
        button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 8, y)
        y = y - 36
        button.Label:SetPoint("LEFT", button, "LEFT", 10, 0)

        local selectedBackground = button:CreateTexture(nil, "BACKGROUND")
        selectedBackground:SetAllPoints()
        selectedBackground:SetColorTexture(1, 1, 1, 0.05)
        selectedBackground:Hide()
        button.SelectedBackground = selectedBackground

        local selectedBar = button:CreateTexture(nil, "OVERLAY")
        selectedBar:SetWidth(3)
        selectedBar:SetPoint("TOPLEFT")
        selectedBar:SetPoint("BOTTOMLEFT")
        selectedBar:SetColorTexture(0.9, 0.75, 0.2, 1)
        selectedBar:Hide()
        button.SelectedBar = selectedBar

        button:SetScript("OnClick", function()
            self:SelectCategory(category.id)
        end)
        self.sidebarButtons[category.id] = button
    end
end

function Settings:Create()
    if self.frame then return end

    local frame = CreateFrame("Frame", "BetterEventRemindersSettingsFrame", UIParent, "BackdropTemplate")
    self.frame = frame
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0.06, 0.06, 0.06, 0.98)
    frame:SetBackdropBorderColor(0.35, 0.75, 1, 1)
    frame:SetScript("OnDragStart", function(selfFrame) selfFrame:StartMoving() end)
    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        self:SavePosition()
    end)
    frame:SetScript("OnHide", function()
        self:CloseDropdown()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", frame, "TOP", 0, -16)
    title:SetText("Better Event Reminders")
    title:SetTextColor(1, 0.82, 0, 1)

    local close = CreatePlainButton(frame, 24, 24, "X")
    close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() self:Close() end)

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetColorTexture(0.4, 0.4, 0.4, 0.6)
    divider:SetWidth(1)
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_WIDTH, -48)
    divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", SIDEBAR_WIDTH, 42)

    local scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", CONTENT_LEFT, -CONTENT_TOP)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -CONTENT_RIGHT, CONTENT_BOTTOM)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(selfFrame, delta)
        local current = selfFrame:GetVerticalScroll()
        local maximum = selfFrame:GetVerticalScrollRange()
        selfFrame:SetVerticalScroll(math.max(0, math.min(maximum, current - delta * 40)))
    end)
    self.scroll = scroll

    self:CreateSidebar()
    self:ApplyPosition()
    self:SelectCategory(self.activeCategory)
    frame:Hide()

    UISpecialFrames = UISpecialFrames or {}
    table.insert(UISpecialFrames, "BetterEventRemindersSettingsFrame")
end

function Settings:Show(categoryId)
    if not Config:IsReady() then return end
    self:Create()
    if categoryId then
        self:SelectCategory(categoryId)
    end
    self:ApplyPosition()
    self.frame:Show()
end

function Settings:Close()
    if self.frame then
        self:SavePosition()
        self.frame:Hide()
    end
    self:CloseDropdown()
end

function Settings:Toggle()
    if not self.frame or not self.frame:IsShown() then
        self:Show()
    else
        self:Close()
    end
end
