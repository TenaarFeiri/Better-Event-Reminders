local _, ns = ...

local Config = ns.Config
local UI = ns.UI
local Integration = ns.Integration
local Scheduler = ns.Scheduler
local initialized = false
local SCHEDULER_SETTINGS = {
    suppressInstanceCombat = true,
    suppressRegularCombat = true,
    suppressChallengeMode = true,
    suppressCombatLockdown = true,
}

Config:SetOnChanged(function(key)
    if SCHEDULER_SETTINGS[key] then
        Scheduler:Refresh()
    end
    if key == "showMinimapButton" then
        Integration:ApplyMinimapVisibility()
    end
    if key == "locked" or key == "clickToClose" then
        UI:UpdateMovableState()
        if Config:Get("locked") then
            UI:HidePositioningHint()
        else
            UI:ShowPositioningHint()
        end
    end
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("VARIABLES_LOADED")
eventFrame:RegisterEvent("EVENT_SCHEDULER_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, loadedAddon)
    if event == "ADDON_LOADED" then
        if loadedAddon ~= ns.Name then return end
        Config:Initialize()
        UI:Create()
        Integration:Initialize()
        Scheduler:SetReady(false)
        initialized = true
    elseif initialized and (event == "PLAYER_ENTERING_WORLD" or event == "VARIABLES_LOADED") then
        Integration:Initialize()
        Scheduler:SetReady(true)
        Scheduler:Refresh()
    elseif initialized and event ~= "ADDON_LOADED" then
        Scheduler:QueueRefresh()
    end
end)
