local _, ns = ...

local Config = ns.Config
local UI = ns.UI
local Settings = ns.Settings
local Commands = {}
ns.Commands = Commands

local function RequireConfig()
    if Config:IsReady() then
        return true
    end
    ns.Print("The addon is still initialising.")
    return false
end

function Commands:ToggleSound()
    if not RequireConfig() then return end
    local sound = Config:Set("sound", not Config:Get("sound"))
    ns.Print("Sound " .. (sound and "enabled" or "disabled") .. ".")
end

function Commands:ToggleSettings()
    if not RequireConfig() then return end
    Settings:Toggle()
end

function Commands:PrintMemory()
    if UpdateAddOnMemoryUsage then
        UpdateAddOnMemoryUsage()
    end

    local addonMemory = GetAddOnMemoryUsage and GetAddOnMemoryUsage(ns.Name) or 0
    local luaHeap = collectgarbage("count")
    local cachedControls = 0
    for _, category in pairs(Settings.categoryControls or {}) do
        cachedControls = cachedControls + #category.controls
    end

    ns.Print(string.format(
        "Memory: %.1f KB addon, %.1f KB Lua heap, %d cached settings controls.",
        addonMemory,
        luaHeap,
        cachedControls
    ))
end

function BetterEventReminders_Toggle()
    Commands:ToggleSettings()
end

SLASH_BETTEREVENTREMINDERS1 = "/ber"
SlashCmdList.BETTEREVENTREMINDERS = function(message)
    if not RequireConfig() then return end

    local command, argument = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = string.lower(command or "")
    argument = string.lower(argument or "")

    if command == "" or command == "open" or command == "settings" then
        Settings:Toggle()
    elseif command == "help" then
        ns.Print("Commands: /ber, /ber sound [on|off], /ber duration <seconds>, /ber unlock, /ber lock, /ber test, /ber memory")
    elseif command == "memory" then
        Commands:PrintMemory()
    elseif command == "sound" then
        local enabled
        if argument == "on" or argument == "1" then
            enabled = true
        elseif argument == "off" or argument == "0" then
            enabled = false
        else
            enabled = not Config:Get("sound")
        end
        Config:Set("sound", enabled)
        ns.Print("Sound " .. (enabled and "enabled" or "disabled") .. ".")
    elseif command == "duration" then
        local duration = tonumber(argument)
        if duration and duration >= 1 and duration <= 60 then
            Config:Set("alertDuration", duration)
            ns.Print("Alert duration set to " .. duration .. " seconds.")
        else
            ns.Print("Usage: /ber duration 1-60")
        end
    elseif command == "unlock" then
        Config:Set("locked", false)
        UI:UpdateMovableState()
        UI:ShowPositioningHint()
        ns.Print("Alert frame unlocked. Drag it to reposition it, then use /ber lock.")
    elseif command == "lock" then
        Config:Set("locked", true)
        UI:UpdateMovableState()
        UI:SavePosition()
        ns.Print("Alert frame locked.")
    elseif command == "test" then
        UI:ShowTestAlert()
    else
        ns.Print("Unknown command. Use /ber help for available commands.")
    end
end
