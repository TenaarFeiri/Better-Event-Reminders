local now = 1000
local hasReminder = true
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
}

Constants = {
    EventScheduler = {
        SCHEDULED_EVENT_REMINDER_DEAD_SECONDS = 10,
    },
}

time = function() return now end
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

print("scheduler smoke tests passed")
