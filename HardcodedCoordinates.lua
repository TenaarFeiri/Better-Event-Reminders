local _, ns = ...
ns.Hardcoded = {} -- Init.
local Hardcoded = ns.Hardcoded

local coordinateMap = {
    -- The Coiled Isles
    ["Curse Surge: Siege at the Whispering Marsh"] = {
        mapID = 2512,
        coordX = 67.1,
        coordY = 77.5,
    },
    ["Curse Surge: The Malformed Leviathan"] = {
        mapID = 2512,
        coordX = 46.9,
        coordY = 62.2,
    },
    ["Curse Surge: The Broodmother's Nest"] = {
        mapID = 2512,
        coordX = 45.7,
        coordY = 29.6,
    },
    ["Curse Surge: The Looming Mutagenitor"] = {
        mapID = 2512,
        coordX = 26.4,
        coordY = 64.9,
    },
    ["Curse Surge: Mlurkkr Massacre"] = {
        mapID = 2512,
        coordX = 70.5,
        coordY = 32.7,
    },
}

--- Get the name of the event, or nil if nothing exists.
--- @param eventInfo table
--- @return string|nil
local function GetEventName(eventInfo)
    local poiInfo = C_AreaPoiInfo.GetAreaPOIInfo(nil, eventInfo.areaPoiID)
    if poiInfo then
        return poiInfo.name
    end
    return nil
end

--- Normalises coordinates to 0.0-1.0 for the map
--- @param coords table
--- @return table|nil
local function NormaliseCoordinates(coords)
    if type(coords) ~= "table" then
        return nil
    end
    return {
        mapID = coords.mapID,
        x = coords.coordX / 100,
        y = coords.coordY / 100,
    }
end

---Gets the normalised coordinates for the vent and returns them as a table.
---@param eventInfo table
---@return table|nil
function Hardcoded.GetCoordinatesForEvent(eventInfo)
    local eventName = GetEventName(eventInfo)
    if not eventName then
        return nil
    end
    local coords = coordinateMap[eventName] or nil
    if not coords then
        return nil
    end
    return NormaliseCoordinates(coords)
end