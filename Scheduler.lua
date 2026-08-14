local _, ns = ...

local Config = ns.Config
local UI = ns.UI
local Scheduler = {
    eventTimer = nil,
    retryTimer = nil,
    ready = false,
    reminderStates = {},
}
ns.Scheduler = Scheduler

local function CancelTimer(self, timerName)
    local timer = self[timerName]
    if timer then
        timer:Cancel()
        self[timerName] = nil
    end
end

function Scheduler:SetReady(ready)
    self.ready = ready
end

function Scheduler:ScheduleRetry()
    if self.retryTimer then return end

    self.retryTimer = C_Timer.NewTimer(2, function()
        self.retryTimer = nil
        if self.ready then
            self:Refresh()
        end
    end)
end

local function HasPendingStarts(states)
    for _, state in pairs(states) do
        if state.reminderSeen and not state.started then
            return true
        end
    end
    return false
end

local function SnapshotEventInfo(eventInfo)
    return {
        eventKey = eventInfo.eventKey,
        eventID = eventInfo.eventID,
        areaPoiID = eventInfo.areaPoiID,
        startTime = eventInfo.startTime,
        endTime = eventInfo.endTime,
        duration = eventInfo.duration,
        displayInfo = eventInfo.displayInfo,
    }
end

function Scheduler:Refresh()
    if not self.ready or not C_EventScheduler then return end

    CancelTimer(self, "eventTimer")

    if not C_EventScheduler.HasSavedReminders() and not HasPendingStarts(self.reminderStates) then
        CancelTimer(self, "retryTimer")
        wipe(self.reminderStates)
        return
    end

    local scheduledEvents = C_EventScheduler.GetScheduledEvents()
    if not scheduledEvents then
        C_EventScheduler.RequestEvents()
        self:ScheduleRetry()
        return
    end
    CancelTimer(self, "retryTimer")

    local now = time()
    local nextWait = math.huge
    local activeReminders = {}
    local warningSeconds = Config:GetWarningSeconds()
    local deadSeconds = 10
    if Constants and Constants.EventScheduler and Constants.EventScheduler.SCHEDULED_EVENT_REMINDER_DEAD_SECONDS then
        deadSeconds = Constants.EventScheduler.SCHEDULED_EVENT_REMINDER_DEAD_SECONDS
    end

    for _, eventInfo in ipairs(scheduledEvents) do
        local eventKey = eventInfo.eventKey
        local timeToEvent = eventInfo.startTime - now
        local state = self.reminderStates[eventKey]
        local tracked = false

        if eventInfo.hasReminder then
            if not state then
                state = {}
                self.reminderStates[eventKey] = state
            end
            state.reminderSeen = true
            state.eventInfo = SnapshotEventInfo(eventInfo)
            state.startTime = eventInfo.startTime
            state.endTime = eventInfo.endTime
            state.areaPoiID = eventInfo.areaPoiID
            tracked = true
        elseif state and state.reminderSeen and timeToEvent <= 0 and not state.started then
            -- Blizzard clears its saved reminder when the event starts. Keep
            -- our already-observed state long enough to show BER's start alert.
            tracked = true
        elseif state and timeToEvent > 0 then
            -- A reminder cleared before its start was user-cleared; do not
            -- announce it later.
            self.reminderStates[eventKey] = nil
        end

        if tracked then
            activeReminders[eventKey] = true
            if timeToEvent <= 0 then
                if not state.started then
                    state.started = true
                    local alertInfo = eventInfo.hasReminder and eventInfo or state.eventInfo or eventInfo
                    UI:ShowAlert(alertInfo, "started", 0)
                end
            elseif timeToEvent <= warningSeconds then
                if timeToEvent > deadSeconds and not state.warning then
                    state.warning = true
                    local warningAt = timeToEvent
                    if warningSeconds - timeToEvent <= deadSeconds then
                        warningAt = warningSeconds
                    end
                    UI:ShowAlert(eventInfo, "warning", warningAt)
                end
                if timeToEvent < nextWait then
                    nextWait = timeToEvent
                end
            else
                local wait = timeToEvent - warningSeconds
                if wait < nextWait then
                    nextWait = wait
                end
            end
        end
    end

    for eventKey in pairs(self.reminderStates) do
        if not activeReminders[eventKey] then
            self.reminderStates[eventKey] = nil
        end
    end

    if nextWait < math.huge then
        self.eventTimer = C_Timer.NewTimer(nextWait, function()
            self.eventTimer = nil
            self:Refresh()
        end)
    end
end
