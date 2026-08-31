local _, ns = ...

local Config = ns.Config
local Suppression = ns.Suppression
local UI = {}
ns.UI = UI

local alertSerial = 0
local alertActive = false
local positioning = false
local zoneMapCache = {}

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

local function ResolveMapByName(mapName)
    if not mapName or mapName == "" or not C_Map
        or not C_Map.GetBestMapForUnit or not C_Map.GetMapInfo
        or not C_Map.GetMapChildrenInfo then
        return nil
    end
    if zoneMapCache[mapName] then
        return zoneMapCache[mapName]
    end

    local currentMapID = C_Map.GetBestMapForUnit("player")
    local roots = {}
    local seen = {}
    while currentMapID and not seen[currentMapID] do
        seen[currentMapID] = true
        local ok, mapInfo = pcall(C_Map.GetMapInfo, currentMapID)
        if not ok or not mapInfo then break end
        if not mapInfo.parentMapID or mapInfo.parentMapID == 0 then
            roots[#roots + 1] = currentMapID
            break
        end
        currentMapID = mapInfo.parentMapID
    end

    for _, rootMapID in ipairs(roots) do
        local ok, mapInfo = pcall(C_Map.GetMapInfo, rootMapID)
        if ok and mapInfo and mapInfo.name == mapName then
            zoneMapCache[mapName] = rootMapID
            return rootMapID
        end

        local childrenOK, children = pcall(C_Map.GetMapChildrenInfo, rootMapID, nil, true)
        if childrenOK and children then
            for _, child in ipairs(children) do
                if child.name == mapName then
                    zoneMapCache[mapName] = child.mapID
                    return child.mapID
                end
            end
        end
    end
end

local function MapContainsAreaPoi(mapID, areaPoiID)
    if not mapID or not C_AreaPoiInfo then
        return false
    end

    local apis = {
        C_AreaPoiInfo.GetEventsForMap,
        C_AreaPoiInfo.GetAreaPOIForMap,
    }
    for _, api in ipairs(apis) do
        if api then
            local ok, areaPoiIDs = pcall(api, mapID)
            if ok and areaPoiIDs then
                for _, id in ipairs(areaPoiIDs) do
                    if id == areaPoiID then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function FindAreaPoiMap(rootMapID, areaPoiID)
    if not rootMapID or not C_Map or not C_Map.GetMapChildrenInfo then
        return nil
    end
    if MapContainsAreaPoi(rootMapID, areaPoiID) then
        return rootMapID
    end

    local ok, children = pcall(C_Map.GetMapChildrenInfo, rootMapID, nil, true)
    if ok and children then
        for _, child in ipairs(children) do
            if MapContainsAreaPoi(child.mapID, areaPoiID) then
                return child.mapID
            end
        end
    end
end

local function ResolveMapForAreaPoi(areaPoiID, searchChildren)
    if not areaPoiID or areaPoiID == 0 then
        return nil
    end

    if C_EventScheduler and C_EventScheduler.GetEventUiMapID then
        local ok, mapID = pcall(C_EventScheduler.GetEventUiMapID, areaPoiID)
        if ok and mapID then
            return FindAreaPoiMap(mapID, areaPoiID) or mapID
        end
    end

    if C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
        local ok, poiInfo = pcall(C_AreaPoiInfo.GetAreaPOIInfo, nil, areaPoiID)
        if ok and poiInfo and poiInfo.linkedUiMapID then
            return FindAreaPoiMap(poiInfo.linkedUiMapID, areaPoiID) or poiInfo.linkedUiMapID
        end
    end

    if C_EventScheduler and C_EventScheduler.GetEventZoneName then
        local ok, zoneName = pcall(C_EventScheduler.GetEventZoneName, areaPoiID)
        if ok then
            local mapID = ResolveMapByName(zoneName)
            if mapID then
                return FindAreaPoiMap(mapID, areaPoiID) or mapID
            end
        end
    end

    if searchChildren ~= false and C_Map and C_Map.GetBestMapForUnit then
        local playerMapID = C_Map.GetBestMapForUnit("player")
        local poiMapID = FindAreaPoiMap(playerMapID, areaPoiID)
        if poiMapID then
            return poiMapID
        end
    end

    return nil
end

local function GetNextTestEvent()
    if not C_EventScheduler or not C_EventScheduler.GetScheduledEvents then
        return { areaPoiID = 0 }
    end

    local now = time()
    local activeEvent
    local nextEvent
    local nextResolvableEvent
    local scheduledEvents = C_EventScheduler.GetScheduledEvents()
    if scheduledEvents then
        for _, eventInfo in ipairs(scheduledEvents) do
            if not eventInfo.areaPoiID or not eventInfo.startTime then
                -- pass
            elseif eventInfo.startTime <= now
                and (not eventInfo.endTime or eventInfo.endTime >= now) then
                if ResolveMapForAreaPoi(eventInfo.areaPoiID, false)
                    and (not activeEvent or eventInfo.startTime > activeEvent.startTime) then
                    activeEvent = eventInfo
                end
            elseif eventInfo.startTime >= now then
                if not nextEvent or eventInfo.startTime < nextEvent.startTime then
                    nextEvent = eventInfo
                end
                if not nextResolvableEvent
                    and (ResolveMapForAreaPoi(eventInfo.areaPoiID, false)
                        or (eventInfo.coords and eventInfo.coords.mapID)) then
                    nextResolvableEvent = eventInfo
                end
            end
        end
    end
    return nextResolvableEvent or nextEvent or { areaPoiID = 0 }
    --activeEvent or nextResolvableEvent or nextEvent or { areaPoiID = 0 }
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
    mapButton:SetFrameLevel(frame:GetFrameLevel() + 10)
    mapButton:EnableMouse(true)
    mapButton:SetSize(100, 22)
    mapButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
    mapButton:RegisterForClicks("LeftButtonUp")
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
        C_Timer.After(0.3, function()
            frame._mapButtonClick = false
        end)
    end)
    mapButton:Hide()
    frame.MapButton = mapButton

    local closeButton = CreateFrame("Button", nil, frame)
    closeButton:SetFrameLevel(frame:GetFrameLevel() + 10)
    closeButton:EnableMouse(true)
    closeButton:SetSize(24, 24)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    closeButton:RegisterForClicks("LeftButtonUp")
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
    glowFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -12, 12)
    glowFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 12, -12)
    glowFrame:EnableMouse(false)

    local cornerSize = 24
    local function AddGlowTexture(file, r, g, b, a, setPoints)
        local tex = glowFrame:CreateTexture(nil, "BORDER")
        tex:SetDrawLayer("BORDER", -1)
        tex:SetTexture(file)
        tex:SetBlendMode("ADD")
        tex:SetVertexColor(r, g, b, a)
        setPoints(tex)
        return tex
    end

    local r, g, b, a = 0.35, 0.75, 1, 1

    local topLeft = AddGlowTexture("Interface\\Common\\GlowBorder-Corner", r, g, b, a, function(tex)
        tex:SetSize(cornerSize, cornerSize)
        tex:SetPoint("TOPLEFT", glowFrame, "TOPLEFT")
    end)

    local topRight = AddGlowTexture("Interface\\Common\\GlowBorder-Corner", r, g, b, a, function(tex)
        tex:SetSize(cornerSize, cornerSize)
        tex:SetPoint("TOPRIGHT", glowFrame, "TOPRIGHT")
        tex:SetTexCoord(1, 0, 0, 1)
    end)

    local bottomLeft = AddGlowTexture("Interface\\Common\\GlowBorder-Corner", r, g, b, a, function(tex)
        tex:SetSize(cornerSize, cornerSize)
        tex:SetPoint("BOTTOMLEFT", glowFrame, "BOTTOMLEFT")
        tex:SetTexCoord(0, 1, 1, 0)
    end)

    local bottomRight = AddGlowTexture("Interface\\Common\\GlowBorder-Corner", r, g, b, a, function(tex)
        tex:SetSize(cornerSize, cornerSize)
        tex:SetPoint("BOTTOMRIGHT", glowFrame, "BOTTOMRIGHT")
        tex:SetTexCoord(1, 0, 1, 0)
    end)

    AddGlowTexture("Interface\\Common\\GlowBorder-Top", r, g, b, a, function(tex)
        tex:SetPoint("TOPLEFT", topLeft, "TOPRIGHT")
        tex:SetPoint("BOTTOMRIGHT", topRight, "BOTTOMLEFT")
    end)

    AddGlowTexture("Interface\\Common\\GlowBorder-Top", r, g, b, a, function(tex)
        tex:SetTexCoord(0, 1, 1, 0)
        tex:SetPoint("TOPLEFT", bottomLeft, "TOPRIGHT")
        tex:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")
    end)

    AddGlowTexture("Interface\\Common\\GlowBorder-Left", r, g, b, a, function(tex)
        tex:SetPoint("TOPLEFT", topLeft, "BOTTOMLEFT")
        tex:SetPoint("BOTTOMRIGHT", bottomLeft, "TOPRIGHT")
    end)

    AddGlowTexture("Interface\\Common\\GlowBorder-Left", r, g, b, a, function(tex)
        tex:SetTexCoord(1, 0, 0, 1)
        tex:SetPoint("TOPLEFT", topRight, "BOTTOMLEFT")
        tex:SetPoint("BOTTOMRIGHT", bottomRight, "TOPRIGHT")
    end)

    glowFrame:SetAlpha(0)
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
        self.frame:EnableMouse(true)
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

local function GetUsablePoiPosition(poiInfo)
    if not poiInfo or not poiInfo.position or not poiInfo.position.GetXY then
        return nil
    end

    local ok, x, y = pcall(poiInfo.position.GetXY, poiInfo.position)
    if not ok or type(x) ~= "number" or type(y) ~= "number" or (x == 0 and y == 0) then
        return nil
    end
    return poiInfo.position
end

local function TrySuperTrackEvent(eventInfo, mapID)
    if not mapID or not eventInfo or not eventInfo.areaPoiID
        or (eventInfo.startTime and eventInfo.startTime > time())
        or not C_SuperTrack or not C_SuperTrack.SetSuperTrackedMapPin
        or not Enum or not Enum.SuperTrackingMapPinType
        or not Enum.SuperTrackingMapPinType.AreaPOI then
        return false
    end

    local ok = pcall(
        C_SuperTrack.SetSuperTrackedMapPin,
        Enum.SuperTrackingMapPinType.AreaPOI,
        eventInfo.areaPoiID
    )
    if not ok then return false end

    if OpenMapToEventPoi then
        pcall(OpenMapToEventPoi, eventInfo.areaPoiID)
    end
    if OpenWorldMap then
        pcall(OpenWorldMap, mapID)
    end
    if EventRegistry then
        EventRegistry:TriggerEvent("PingAreaPOIEvent", eventInfo.areaPoiID)
    end
    return true
end

local function TrySetEventWaypoint(eventInfo)
    local fallbackMapID = nil
    local coords = eventInfo and eventInfo.coords
    if coords and coords.mapID and coords.x and coords.y then
        fallbackMapID = coords.mapID
        if C_Map.SetUserWaypoint and C_SuperTrack.SetSuperTrackedUserWaypoint then
            -- This should always exist, but we can fall back to normal behaviour should
            -- that change.
            local point = UiMapPoint.CreateFromCoordinates(coords.mapID, coords.x, coords.y)
            local ok, wasSet = pcall(C_Map.SetUserWaypoint, point)
            if ok and wasSet then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
                OpenMapToUserWaypoint()
                return true, coords.mapID
            elseif ok and not wasSet then
                -- SetUserWaypoint ran but returned false, so use fallback areaPoiID path
                -- in other words, this is just here to break out of the conditional and allow
                -- fallthrough to fallback
            elseif not ok and type(wasSet) == "string" then
                ns.Print("Failed to set a hardcoded waypoint: " .. wasSet)
                return false, coords.mapID
            end
        end
    end

    ---- If no hardcoded coords, continue as normal.
    local areaPoiID = eventInfo and eventInfo.areaPoiID
    if not areaPoiID or areaPoiID == 0 then
        return false, fallbackMapID
    end

    local mapID = ResolveMapForAreaPoi(areaPoiID)
    local poiInfo
    if mapID and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
        local ok, result = pcall(C_AreaPoiInfo.GetAreaPOIInfo, mapID, areaPoiID)
        if ok then poiInfo = result end
    end
    if not poiInfo and C_AreaPoiInfo and C_AreaPoiInfo.GetAreaPOIInfo then
        local ok, result = pcall(C_AreaPoiInfo.GetAreaPOIInfo, nil, areaPoiID)
        if ok then poiInfo = result end
    end

    local position = GetUsablePoiPosition(poiInfo)
    if mapID and position and C_Map
        and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromVector2D then
        local point = UiMapPoint.CreateFromVector2D(mapID, position)
        local ok, wasSet = pcall(C_Map.SetUserWaypoint, point)
        if ok and wasSet then
            if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
                C_SuperTrack.SetSuperTrackedUserWaypoint(true)
            end
            if OpenMapToUserWaypoint then
                OpenMapToUserWaypoint()
            elseif OpenWorldMap then
                pcall(OpenWorldMap, mapID)
                if EventRegistry then
                    EventRegistry:TriggerEvent("MapCanvas.PingWaypointLocation")
                end
            end
            return true, mapID
        end
    end

    return false, fallbackMapID or mapID
end

local function HasEventLocation(eventInfo)
    if not eventInfo then return false end
    return (eventInfo.areaPoiID and eventInfo.areaPoiID ~= 0)
        or (eventInfo.coords and eventInfo.coords.mapID)
end

function UI:OpenEventMap()
    local eventInfo = self.currentEventInfo
    if not HasEventLocation(eventInfo) then
        ns.Print("No event location is available for this alert.")
        return
    end

    local wasSet, mapID = TrySetEventWaypoint(eventInfo)
    if wasSet then
        return
    end
    if TrySuperTrackEvent(eventInfo, mapID) then
        return
    end

    if OpenWorldMap then
        local ok = pcall(OpenWorldMap, mapID)
        if ok then
            if mapID and EventRegistry then
                EventRegistry:TriggerEvent("PingAreaPOIEvent", eventInfo.areaPoiID)
            end
            return
        end
    end

    ns.Print("Unable to open a map for this event.")
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
    local hasMap = (eventInfo.areaPoiID and eventInfo.areaPoiID ~= 0)
        or (eventInfo.coords and eventInfo.coords.mapID)
    frame.MapButton:SetShown(hasMap)

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
    local eventInfo = GetNextTestEvent()
    eventInfo.coords = ns.Hardcoded.GetCoordinatesForEvent(eventInfo)
    if not HasEventLocation(eventInfo) then
        ns.Print("No scheduled event is available to test.")
        return
    end
    local isActive = eventInfo.startTime and eventInfo.startTime <= time()
    local alertType = isActive and "started" or "warning"
    local seconds = isActive and 0 or Config:GetWarningSeconds()
    self:ShowAlert(eventInfo, alertType, seconds, true)
end

UI.FormatDuration = FormatDuration
