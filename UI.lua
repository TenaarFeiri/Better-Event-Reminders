local _, ns = ...

local Config = ns.Config
local Suppression = ns.Suppression
local UI = {}
ns.UI = UI

local alertSerial = 0
local alertActive = false
local positioning = false

local function FormatDuration(seconds)
    seconds = math.max(0, math.floor(seconds + 0.5))
    if seconds < 60 then
        return seconds .. " second" .. (seconds == 1 and "" or "s")
    end

    local minutes = math.floor((seconds + 30) / 60)
    if minutes < 60 then
        return minutes .. " minute" .. (minutes == 1 and "" or "s")
    end

    local hours = math.floor((minutes + 30) / 60)
    return hours .. " hour" .. (hours == 1 and "" or "s")
end

local function GetEventName(eventInfo)
    local poiInfo
    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
        poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(nil, eventInfo.areaPoiID)
    end
    if poiInfo and poiInfo.name and poiInfo.name ~= "" then
        return poiInfo.name
    end

    if C_EventScheduler and C_EventScheduler.GetEventZoneName then
        local zoneName = C_EventScheduler.GetEventZoneName(eventInfo.areaPoiID)
        if zoneName and zoneName ~= "" then
            return zoneName
        end
    end

    return "Map event"
end

function UI:Create()
    local db = Config:GetDB()
    local frame = CreateFrame("Frame", "BetterEventRemindersAlertFrame", UIParent, "BackdropTemplate")
    self.frame = frame

    frame:SetSize(500, 116)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetPoint(
        db.position.point,
        UIParent,
        db.position.relativePoint,
        db.position.x,
        db.position.y
    )
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0.04, 0.07, 0.12, 0.96)
    frame:SetBackdropBorderColor(0.35, 0.75, 1, 1)

    frame.Title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("TOP", 0, -18)
    frame.Title:SetWidth(450)
    frame.Title:SetJustifyH("CENTER")
    frame.Title:SetTextColor(0.45, 0.85, 1)

    frame.Message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    frame.Message:SetPoint("TOP", frame.Title, "BOTTOM", 0, -10)
    frame.Message:SetWidth(450)
    frame.Message:SetJustifyH("CENTER")

    frame:SetScript("OnDragStart", function(alertFrame)
        local currentDB = Config:GetDB()
        if not currentDB.locked then
            alertFrame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(alertFrame)
        alertFrame:StopMovingOrSizing()
        self:SavePosition()
    end)
    frame:Hide()
    self:UpdateMovableState()
end

function UI:UpdateMovableState()
    if self.frame then
        self.frame:EnableMouse(not Config:GetDB().locked)
    end
end

function UI:ShowPositioningHint()
    if not self.frame then return end

    alertSerial = alertSerial + 1
    alertActive = false
    positioning = true
    self.frame.Title:SetText("Better Event Reminders")
    self.frame.Message:SetText("Drag to reposition, then lock the frame")
    self.frame:SetBackdropBorderColor(0.35, 0.75, 1, 1)
    self.frame:Show()
end

function UI:HidePositioningHint()
    positioning = false
    if self.frame and not alertActive then
        self.frame:Hide()
    end
end

function UI:SavePosition()
    if not self.frame then return end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    if point then
        local position = Config:GetDB().position
        position.point = point
        position.relativePoint = relativePoint or point
        position.x = x or 0
        position.y = y or 0
    end
end

function UI:PlayAlertSound(force)
    local db = Config:GetDB()
    local soundKit = SOUNDKIT and SOUNDKIT[db.soundKit or "UI_EVENT_SCHEDULER_CHIME"]
    if (db.sound or force) and soundKit then
        PlaySound(soundKit, "SFX", true)
    end
end

function UI:PreviewAlertSound()
    self:PlayAlertSound(true)
end

function UI:ShowAlert(eventInfo, alertType, seconds, force)
    if not force and Suppression:IsSuppressed() then
        return false
    end

    alertSerial = alertSerial + 1
    alertActive = true
    positioning = false
    local serial = alertSerial
    local frame = self.frame

    frame.Title:SetText(GetEventName(eventInfo))
    if alertType == "warning" then
        frame.Message:SetText("Starts in " .. FormatDuration(seconds))
        frame:SetBackdropBorderColor(1, 0.72, 0.2, 1)
    else
        frame.Message:SetText("Starting now")
        frame:SetBackdropBorderColor(0.35, 1, 0.45, 1)
    end

    frame:Show()
    self:PlayAlertSound()
    C_Timer.After(Config:GetDB().alertDuration, function()
        if alertSerial == serial then
            alertActive = false
            if not positioning then
                frame:Hide()
            end
        end
    end)
end

function UI:ShowTestAlert()
    self:ShowAlert({ areaPoiID = 0 }, "warning", Config:GetWarningSeconds(), true)
end

UI.FormatDuration = FormatDuration
