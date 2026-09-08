local _, ns = ...

local Config = ns.Config
local Suppression = {}
ns.Suppression = Suppression

local function IsCombatLockdownActive()
    return InCombatLockdown()
end

local function IsChallengeModeActive()
    return C_ChallengeMode.IsChallengeModeActive()
end

local function IsRegularCombatActive()
    return UnitAffectingCombat("player")
end

local function IsPlayerInInstance()
    return select(1, IsInInstance())
end

function Suppression:GetReason()
    local db = Config:GetDB()
    if not db then return nil end

    if db.suppressChallengeMode and IsChallengeModeActive() then
        return "challengeMode"
    end

    local regularCombat = IsRegularCombatActive()
    if db.suppressInstanceCombat and IsPlayerInInstance() and regularCombat then
        return "instanceCombat"
    end

    if db.suppressRegularCombat and regularCombat then
        return "regularCombat"
    end

    local inCombatLockdown = IsCombatLockdownActive()
    if db.suppressCombatLockdown and inCombatLockdown then
        return "combatLockdown"
    end
end

function Suppression:IsSuppressed()
    return self:GetReason() ~= nil
end
