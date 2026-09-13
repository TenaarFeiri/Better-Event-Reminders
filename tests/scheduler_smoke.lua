local now = 1000
local hasReminder = true
local lockdown = false
local currentEvent
local alerts = {}

local ns = {
    Config = {
        GetWarningSeconds = function() return 300 end,
        GetDB = function() return {} end,
    },
    UI = {
        ShowAlert = function(_, eventInfo, alertType, seconds)
            alerts[#alerts + 1] = {
                eventKey = eventInfo.eventKey,
                areaPoiID = eventInfo.areaPoiID,
                alertType = alertType,
                seconds = seconds,
            }
        end,
    },
    Hardcoded = {
        GetCoordinatesForEvent = function() return nil end,
    },
}

Constants = {
    EventScheduler = {
        SCHEDULED_EVENT_REMINDER_DEAD_SECONDS = 10,
    },
}

time = function() return now end
InCombatLockdown = function() return lockdown end
securecallfunction = function(func, ...) return func(...) end
CreateFrame = function()
    return {
        RegisterEvent = function() end,
        SetScript = function(self, name, handler) self[name] = handler end,
    }
end
wipe = function(tbl)
    for key in pairs(tbl) do tbl[key] = nil end
end

C_Timer = {
    NewTimer = function(delay, callback)
        return {
            delay = delay,
            callback = callback,
            Cancel = function() end,
        }
    end,
}

C_EventScheduler = {
    HasSavedReminders = function()
        return hasReminder
    end,
    GetScheduledEvents = function()
        return { currentEvent }
    end,
    RequestEvents = function() end,
}

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s: expected %s, got %s", message, tostring(expected), tostring(actual)))
    end
end

local function loadScheduler()
    local chunk = assert(loadfile("Scheduler.lua"))
    chunk("BetterEventReminders", ns)
    ns.Scheduler:SetReady(true)
    return ns.Scheduler
end

local function setEvent(eventKey, startTime)
    currentEvent = {
        eventKey = eventKey,
        eventID = 7,
        areaPoiID = 42,
        startTime = startTime,
        endTime = startTime + 67,
        duration = 67,
        hasReminder = hasReminder,
        displayInfo = {},
    }
end

local Scheduler = loadScheduler()

setEvent("warning-and-start", 1033)
now = 1000
hasReminder = true
currentEvent.hasReminder = true
Scheduler:Refresh()
assertEqual(#alerts, 1, "warning count")
assertEqual(alerts[1].alertType, "warning", "warning type")
assertEqual(Scheduler.reminderStates["warning-and-start"].startTime, 1033, "snapshot start time")
local snapshot = Scheduler.reminderStates["warning-and-start"].eventInfo
local activeReminders = Scheduler.activeReminders
now = 1001
Scheduler:Refresh()
assertEqual(Scheduler.reminderStates["warning-and-start"].eventInfo, snapshot, "snapshot reuse")
assertEqual(Scheduler.activeReminders, activeReminders, "active-reminder table reuse")

now = 1033
hasReminder = false
currentEvent.hasReminder = false
Scheduler:Refresh()
assertEqual(#alerts, 2, "start count after Blizzard clear")
assertEqual(alerts[2].alertType, "started", "start type after Blizzard clear")
assertEqual(alerts[2].areaPoiID, 42, "start snapshot POI")

Scheduler.reminderStates = {}
alerts = {}
setEvent("user-cleared", 2033)
now = 2000
hasReminder = true
currentEvent.hasReminder = true
Scheduler:Refresh()
now = 2010
hasReminder = false
currentEvent.hasReminder = false
Scheduler:Refresh()
now = 2033
Scheduler:Refresh()
assertEqual(#alerts, 1, "user-cleared alert count")
assertEqual(alerts[1].alertType, "warning", "user-cleared alert type")

Scheduler.reminderStates = {}
alerts = {}
setEvent("dead-window", 3033)
now = 3025
hasReminder = true
currentEvent.hasReminder = true
Scheduler:Refresh()
assertEqual(#alerts, 0, "dead-window warning count")
now = 3033
hasReminder = false
currentEvent.hasReminder = false
Scheduler:Refresh()
assertEqual(#alerts, 1, "dead-window start count")
assertEqual(alerts[1].alertType, "started", "dead-window start type")

local refreshCount = Scheduler:GetRefreshCount()
Scheduler.refreshTimer = nil
Scheduler:QueueRefresh()
local queuedRefresh = Scheduler.refreshTimer
Scheduler:QueueRefresh()
assertEqual(Scheduler.refreshTimer, queuedRefresh, "refresh coalescing")
queuedRefresh.callback()
assertEqual(Scheduler:GetRefreshCount(), refreshCount + 1, "queued refresh execution")

-- Refreshes during combat lockdown are deferred until PLAYER_REGEN_ENABLED,
-- because touching C_EventScheduler/C_AreaPoiInfo under lockdown taints
-- Blizzard's protected map pin calls.
lockdown = true
local deferredCount = Scheduler:GetRefreshCount()
Scheduler:Refresh()
assertEqual(Scheduler:GetRefreshCount(), deferredCount, "lockdown refresh deferral")
assertEqual(Scheduler.regenRefreshPending, true, "regen pending flag")
lockdown = false
Scheduler.regenFrame.OnEvent()
assertEqual(Scheduler.regenRefreshPending, nil, "regen flag cleared")
local regenTimer = Scheduler.refreshTimer
assertEqual(regenTimer ~= nil, true, "regen queued refresh")
regenTimer.callback()
assertEqual(Scheduler:GetRefreshCount(), deferredCount + 1, "post-regen refresh")

print("scheduler smoke tests passed")
