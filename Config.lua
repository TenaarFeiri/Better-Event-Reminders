local _, ns = ...

local Config = {}
ns.Config = Config

local DEFAULTS = {
    alertDuration = 8,
    sound = true,
    showMinimapButton = true,
    soundKit = "UI_EVENT_SCHEDULER_CHIME",
    locked = true,
    clickToClose = false,
    suppressInstanceCombat = true,
    suppressRegularCombat = false,
    suppressChallengeMode = true,
    suppressCombatLockdown = true,
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 180,
    },
    settingsPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
    },
}

local ALERT_OPTIONS = {
    {
        key = "sound",
        kind = "boolean",
        label = "Play a sound",
        tooltip = "Play a sound with the on-screen alert.",
    },
    {
        key = "soundKit",
        kind = "select",
        label = "Alert sound",
        tooltip = "Choose which Blizzard sound plays with an alert.",
        choices = {
            { value = "UI_EVENT_SCHEDULER_CHIME", label = "Event Scheduler Chime" },
            { value = "RAID_WARNING", label = "Raid Warning" },
            { value = "READY_CHECK", label = "Ready Check" },
            { value = "UI_BATTLEGROUND_COUNTDOWN_TIMER", label = "Battleground Countdown" },
        },
    },
    {
        key = "alertDuration",
        kind = "number",
        label = "Alert duration",
        tooltip = "How long each on-screen alert remains visible.",
        min = 1,
        max = 60,
        step = 1,
        format = function(value)
            return string.format("%d seconds", value)
        end,
    },
    {
        key = "locked",
        kind = "boolean",
        label = "Lock alert frame position",
        tooltip = "Prevent the alert frame from being moved by dragging.",
    },
    {
        key = "clickToClose",
        kind = "boolean",
        label = "Close alert when clicked",
        tooltip = "Close the alert by clicking anywhere on its background or text. The Open Map button remains separate.",
    },
}

local INTERFACE_OPTIONS = {
    {
        key = "showMinimapButton",
        kind = "boolean",
        label = "Show minimap button",
        tooltip = "Show a minimap button that opens Better Event Reminders.",
    },
}

local SUPPRESSION_OPTIONS = {
    {
        key = "suppressInstanceCombat",
        kind = "boolean",
        label = "Suppress alerts in instances during combat",
        tooltip = "Do not show a frame or play a sound while in an instance and in combat.",
    },
    {
        key = "suppressRegularCombat",
        kind = "boolean",
        label = "Suppress alerts in regular combat",
        tooltip = "Do not show a frame or play a sound while the player is in ordinary combat.",
    },
    {
        key = "suppressChallengeMode",
        kind = "boolean",
        label = "Suppress alerts in Mythic+",
        tooltip = "Do not show a frame or play a sound while a Mythic+ challenge is active.",
    },
    {
        key = "suppressCombatLockdown",
        kind = "boolean",
        label = "Suppress alerts during combat lockdown",
        tooltip = "Do not show a frame or play a sound while WoW is in combat lockdown.",
    },
}

Config.Categories = {
    {
        id = "alerts",
        label = "Alerts",
        description = "Control when and how Better Event Reminders announces events.",
        options = ALERT_OPTIONS,
    },
    {
        id = "interface",
        label = "Interface",
        description = "Choose how Better Event Reminders is opened.",
        options = INTERFACE_OPTIONS,
    },
    {
        id = "suppression",
        label = "Suppression",
        description = "Prevent alerts from interrupting combat and challenging content.",
        options = SUPPRESSION_OPTIONS,
    },
}

local OPTION_BY_KEY = {}
local SETTINGS_VERSION = 1
for _, category in ipairs(Config.Categories) do
    for _, option in ipairs(category.options) do
        OPTION_BY_KEY[option.key] = option
    end
end

local function CopyPosition(position)
    return {
        point = position.point,
        relativePoint = position.relativePoint,
        x = position.x,
        y = position.y,
    }
end

local function EnsureMinimap(db)
    if type(db.minimap) ~= "table" then
        db.minimap = { hide = false, angle = 220 }
    end
    if type(db.minimap.hide) ~= "boolean" then db.minimap.hide = false end
    if type(db.minimap.angle) ~= "number" then db.minimap.angle = 220 end
end

local function EnsurePosition(db, key)
    if type(db[key]) ~= "table" then
        db[key] = CopyPosition(DEFAULTS[key])
    end
    local position = db[key]
    local default = DEFAULTS[key]
    if type(position.point) ~= "string" then position.point = default.point end
    if type(position.relativePoint) ~= "string" then position.relativePoint = default.relativePoint end
    if type(position.x) ~= "number" then position.x = default.x end
    if type(position.y) ~= "number" then position.y = default.y end
end

function Config:Initialize()
    if type(BetterEventRemindersDB) ~= "table" then
        BetterEventRemindersDB = {}
    end

    self.db = BetterEventRemindersDB
    local db = self.db
    for key, default in pairs(DEFAULTS) do
        if type(default) ~= "table" and type(db[key]) ~= type(default) then
            db[key] = default
        end
    end

    if (tonumber(db._settingsVersion) or 0) < SETTINGS_VERSION then
        if db.sound == false then
            db.sound = true
        end
        db._settingsVersion = SETTINGS_VERSION
    end

    EnsureMinimap(db)
    EnsurePosition(db, "position")
    EnsurePosition(db, "settingsPosition")
end

function Config:IsReady()
    return self.db ~= nil
end

function Config:GetDB()
    return self.db
end

function Config:GetWarningSeconds()
    if Constants and Constants.EventScheduler and Constants.EventScheduler.SCHEDULED_EVENT_REMINDER_WARNING_SECONDS then
        return Constants.EventScheduler.SCHEDULED_EVENT_REMINDER_WARNING_SECONDS
    end
    return 300
end

function Config:Get(key)
    return self.db and self.db[key]
end

function Config:GetOption(key)
    return OPTION_BY_KEY[key]
end

function Config:SetOnChanged(callback)
    self.onChanged = callback
end

function Config:Set(key, value)
    if not self.db then return nil end
    local option = OPTION_BY_KEY[key]
    if not option then return nil end

    if option.kind == "boolean" then
        value = value == true
    elseif option.kind == "select" then
        local valid = false
        for _, choice in ipairs(option.choices) do
            if choice.value == value then
                valid = true
                break
            end
        end
        if not valid then return nil end
    elseif option.kind == "number" then
        value = tonumber(value)
        if not value then return nil end
        value = math.max(option.min, math.min(option.max, value))
        value = math.floor(value / option.step + 0.5) * option.step
    end

    self.db[key] = value
    if self.onChanged then
        self.onChanged(key, value)
    end
    return value
end

function Config:Reset(key)
    local option = OPTION_BY_KEY[key]
    if not option then return nil end
    return self:Set(key, DEFAULTS[key])
end
