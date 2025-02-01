--[[
# This file is a Lua file.
Lua (programming language): https://en.wikipedia.org/wiki/Lua_(programming_language)

## Comments
Everything after -- (two hyphens/dashes) is ignored (it's a commentary),
so if you want to turn off any option, just put -- in the beginning of the line.
https://www.codecademy.com/resources/docs/lua/comments

## Key and ModifierKey tables
https://docs.ue4ss.com/lua-api/table-definitions/key.html
https://docs.ue4ss.com/lua-api/table-definitions/modifierkey.html
--]]

local DeformType = {
    Subtract = 0,
    Add = 1,
    Flatten = 2,
    ColorPick = 3,
    ColorPaint = 4,
    CountCreative = 5,
    Crater = 6,
    FlattenSubtractOnly = 7,
    FlattenAddOnly = 8,
    TrueFlatStamp = 9,
    PlatformSurface = 10,
    RevertModifications = 11,
    Count = 12,
    EDeformType_MAX = 13,
}

-- ALL TRACE DEBUG INFO WARN ERROR FATAL OFF
LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

local options = {
    -- Altitude will be rounded to the nearest multiple of this value.
    altitudeStep = 50,

    -- Predefined altitudes.
    altitudes_userList = {
        ["base 1"] = 120400,
    },

    -- Keybinds to ENABLE/DISABLE/TOGGLE the "tangent mod" when you use the terrain tool.
    -- ENABLE
    enable_handleTerrainTool_Key = Key.F2,
    enable_handleTerrainTool_ModifierKeys = {},
    -- DISABLE
    disable_handleTerrainTool_Key = Key.F3,
    disable_handleTerrainTool_ModifierKeys = {},
    -- TOGGLE
    toggle_handleTerrainTool_Key = nil,
    toggle_handleTerrainTool_ModifierKeys = {},

    -- DeformType to use when you press the "set_deformType_Key" key.
    deformType = DeformType.RevertModifications,
    -- Keybinds to set a deform type.
    set_deformType_Key = Key.F2,
    set_deformType_ModifierKeys = { ModifierKey.SHIFT },
}

----------------------------------------

return options
