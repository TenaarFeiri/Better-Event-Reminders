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

local function GetNextTestEvent()
    if not C_EventScheduler or not C_EventScheduler.GetScheduledEvents then
        return { areaPoiID = 0 }
    end

    local now = time()
    local nextEvent
    local scheduledEvents = C_EventScheduler.GetScheduledEvents()
    if scheduledEvents then
        for _, eventInfo in ipairs(scheduledEvents) do
            if eventInfo.areaPoiID and eventInfo.startTime and eventInfo.startTime >= now
                and (not nextEvent or eventInfo.startTime < nextEvent.startTime) then
                nextEvent = eventInfo
            end
        end
    end
    return nextEvent or { areaPoiID = 0 }
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

    local mapButton = CreateFrame("Button", nil, frame)
    mapButton:SetSize(100, 22)
    mapButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    local mapBackground = mapButton:CreateTexture(nil, "BACKGROUND")
    mapBackground:SetAllPoints()
    mapBackground:SetColorTexture(0.12, 0.12, 0.12, 0.95)
    local mapHighlight = mapButton:CreateTexture(nil, "HIGHLIGHT")
    mapHighlight:SetAllPoints()
    mapHighlight:SetColorTexture(1, 1, 1, 0.08)
    local mapLabel = mapButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    mapLabel:SetPoint("CENTER")
    mapLabel:SetText("Open Map")
    mapButton:SetScript("OnClick", function()
        self:OpenEventMap()
    end)
    mapButton:SetScript("OnMouseDown", function()
        frame._mapButtonClick = true
        C_Timer.After(0.1, function()
            frame._mapButtonClick = false
        end)
    end)
    mapButton:Hide()
    frame.MapButton = mapButton

    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    local closeHighlight = closeButton:CreateTexture(nil, "HIGHLIGHT")
    closeHighlight:SetAllPoints()
    closeHighlight:SetColorTexture(1, 1, 1, 0.08)
    local closeLabel = closeButton:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    closeLabel:SetPoint("CENTER")
    closeLabel:SetText("X")
    closeButton:SetScript("OnClick", function()
        self:CloseAlert()
    end)
    frame.CloseButton = closeButton

    local glowFrame = CreateFrame("Frame", nil, frame)
    glowFrame:SetFrameLevel(math.max(0, frame:GetFrameLevel()))
    glowFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
    glowFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 8, -8)
    glowFrame:EnableMouse(false)
    local glow = glowFrame:CreateTexture(nil, "OVERLAY")
    glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.35, 0.75, 1, 1)
    glow:SetAllPoints()
    glowFrame:SetAlpha(0)
    frame.Glow = glow
    frame.GlowFrame = glowFrame

    local fadeIn = frame:CreateAnimationGroup()
    fadeIn:SetToFinalAlpha(true)
    local fadeInAlpha = fadeIn:CreateAnimation("Alpha")
    fadeInAlpha:SetFromAlpha(0)
    fadeInAlpha:SetToAlpha(1)
    fadeInAlpha:SetDuration(0.35)
    fadeInAlpha:SetSmoothing("OUT")
    frame.FadeIn = fadeIn

    local glowIn = glowFrame:CreateAnimationGroup()
    glowIn:SetToFinalAlpha(true)
    local glowAlpha = glowIn:CreateAnimation("Alpha")
    glowAlpha:SetFromAlpha(0)
    glowAlpha:SetToAlpha(0.85)
    glowAlpha:SetDuration(0.25)
    glowAlpha:SetSmoothing("OUT")
    local glowFade = glowIn:CreateAnimation("Alpha")
    glowFade:SetFromAlpha(0.85)
    glowFade:SetToAlpha(0)
    glowFade:SetDuration(0.9)
    glowFade:SetStartDelay(0.25)
    glowFade:SetSmoothing("OUT")
    frame.GlowIn = glowIn

    local fadeOut = frame:CreateAnimationGroup()
    fadeOut:SetToFinalAlpha(true)
    local fadeOutAlpha = fadeOut:CreateAnimation("Alpha")
    fadeOutAlpha:SetFromAlpha(1)
    fadeOutAlpha:SetToAlpha(0)
    fadeOutAlpha:SetDuration(0.4)
    fadeOutAlpha:SetSmoothing("IN")
    frame.FadeOut = fadeOut
    fadeOut:SetScript("OnFinished", function()
        if not alertActive and not positioning then
            frame:Hide()
            frame:SetAlpha(1)
            glowFrame:SetAlpha(0)
        end
    end)

    frame:SetScript("OnDragStart", function(alertFrame)
        local currentDB = Config:GetDB()
        if not currentDB.locked then
            alertFrame._dragging = true
            alertFrame:StartMoving()
        end
    end)
    frame:SetScript("OnDragStop", function(alertFrame)
        if alertFrame._dragging then
            alertFrame:StopMovingOrSizing()
            alertFrame._dragging = nil
            alertFrame._wasDragged = true
            C_Timer.After(0, function()
                alertFrame._wasDragged = nil
            end)
            self:SavePosition()
        end
    end)
    frame:SetScript("OnMouseUp", function(alertFrame, button)
        if button == "LeftButton" and not alertFrame._wasDragged
            and not alertFrame._mapButtonClick and Config:Get("clickToClose") then
            self:CloseAlert()
        end
    end)
    frame:Hide()
    self:UpdateMovableState()
end

function UI:UpdateMovableState()
    if self.frame then
        local db = Config:GetDB()
        self.frame:EnableMouse(not db.locked or db.clickToClose)
    end
end

function UI:PlayOpenAnimation()
    if not self.frame then return end
    if not self.frame.FadeIn or not self.frame.GlowIn or not self.frame.FadeOut then
        self.frame:SetAlpha(1)
        self.frame.GlowFrame:SetAlpha(0)
        self.frame:Show()
        return
    end
    self.frame.FadeOut:Stop()
    self.frame.FadeIn:Stop()
    self.frame.GlowIn:Stop()
    self.frame:SetAlpha(0)
    self.frame.GlowFrame:SetAlpha(0)
    self.frame:Show()
    self.frame.FadeIn:Play()
    self.frame.GlowIn:Play()
end

function UI:PlayCloseAnimation()
    if not self.frame or not self.frame:IsShown() then return end
    if not self.frame.FadeIn or not self.frame.GlowIn or not self.frame.FadeOut then
        self.frame:Hide()
        self.frame:SetAlpha(1)
        self.frame.GlowFrame:SetAlpha(0)
        return
    end
    self.frame.FadeIn:Stop()
    self.frame.GlowIn:Stop()
    self.frame.FadeOut:Stop()
    self.frame.FadeOut:Play()
end

function UI:CloseAlert()
    alertSerial = alertSerial + 1
    alertActive = false
    positioning = false
    self.currentEventInfo = nil
    if self.frame then
        self.frame.MapButton:Hide()
        self:PlayCloseAnimation()
    end
end

function UI:ShowPositioningHint()
    if not self.frame then return end

    alertSerial = alertSerial + 1
    alertActive = false
    positioning = true
    self.frame.Title:SetText("Better Event Reminders")
    self.currentEventInfo = nil
    self.frame.Message:SetText("Drag to reposition, then lock the frame")
    self.frame.MapButton:Hide()
    self.frame:SetBackdropBorderColor(0.35, 0.75, 1, 1)
    self:PlayOpenAnimation()
end

function UI:HidePositioningHint()
    positioning = false
    if self.frame and not alertActive then
        self:PlayCloseAnimation()
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

function UI:OpenEventMap()
    local eventInfo = self.currentEventInfo
    if not eventInfo or not eventInfo.areaPoiID or eventInfo.areaPoiID == 0 then return end

    local mapID
    if C_EventScheduler and C_EventScheduler.GetEventUiMapID then
        mapID = C_EventScheduler.GetEventUiMapID(eventInfo.areaPoiID)
    end

    local poiInfo
    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
        poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(mapID, eventInfo.areaPoiID)
            or C_AreaPoiInfo.GetAreaPOIInfo(nil, eventInfo.areaPoiID)
    end
    mapID = mapID or (poiInfo and poiInfo.linkedUiMapID)

    if mapID and poiInfo and poiInfo.position and C_Map
        and C_Map.CanSetUserWaypointOnMap and C_Map.SetUserWaypoint
        and UiMapPoint and UiMapPoint.CreateFromVector2D
        and C_Map.CanSetUserWaypointOnMap(mapID) then
        local point = UiMapPoint.CreateFromVector2D(mapID, poiInfo.position)
        if C_Map.SetUserWaypoint(point) then
            if OpenMapToUserWaypoint then
                OpenMapToUserWaypoint()
            elseif OpenWorldMap then
                OpenWorldMap(mapID)
            end
            return
        end
    end

    if OpenMapToEventPoi then
        OpenMapToEventPoi(eventInfo.areaPoiID)
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
    self.currentEventInfo = eventInfo
    frame.MapButton:SetShown(eventInfo.areaPoiID ~= nil and eventInfo.areaPoiID ~= 0)

    frame.Title:SetText(GetEventName(eventInfo))
    if alertType == "warning" then
        frame.Message:SetText("Starts in " .. FormatDuration(seconds))
        frame:SetBackdropBorderColor(1, 0.72, 0.2, 1)
    else
        frame.Message:SetText("Starting now")
        frame:SetBackdropBorderColor(0.35, 1, 0.45, 1)
    end

    self:PlayOpenAnimation()
    self:PlayAlertSound()
    C_Timer.After(Config:GetDB().alertDuration, function()
        if alertSerial == serial then
            alertActive = false
            self.currentEventInfo = nil
            frame.MapButton:Hide()
            if not positioning then
                self:PlayCloseAnimation()
            end
        end
    end)
end

function UI:ShowTestAlert()
    self:ShowAlert(GetNextTestEvent(), "warning", Config:GetWarningSeconds(), true)
end

UI.FormatDuration = FormatDuration
