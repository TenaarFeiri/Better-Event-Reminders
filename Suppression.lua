local _, ns = ...

local Config = ns.Config
local Suppression = {}
ns.Suppression = Suppression

local function IsCombatLockdownActive()
    return InCombatLockdown and InCombatLockdown() or false
end

local function IsChallengeModeActive()
    return C_ChallengeMode
        and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive() or false
end

local function IsRegularCombatActive()
    return UnitAffectingCombat and UnitAffectingCombat("player") or false
end

local function IsPlayerInInstance()
    return IsInInstance and select(1, IsInInstance()) or false
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
