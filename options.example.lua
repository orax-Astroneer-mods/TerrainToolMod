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
    method = "tangent", -- tangent | slope | smoothen

    -- Predefined altitudes.
    altitudes_userList = {
        ["base 1"] = 120400,
    },

    -- Keybinds to ENABLE/DISABLE/TOGGLE the mod when you use the terrain tool.
    -- ENABLE, turn on
    enable_handleTerrainTool_Key = Key.F2,
    enable_handleTerrainTool_ModifierKeys = {},
    -- DISABLE, turn off
    disable_handleTerrainTool_Key = Key.F3,
    disable_handleTerrainTool_ModifierKeys = {},
    -- TOGGLE
    toggle_handleTerrainTool_Key = nil,
    toggle_handleTerrainTool_ModifierKeys = {},

    -- Keybinds to turn on the "tangent" method. It is used with the Flatten mode.
    -- When using Flatten mode, the Terrain tool will flatten the terrain following the planet's curvature.
    set_tangent_method_Key = Key.ONE,
    set_tangent_method_ModifierKeys = {},

    -- Keybinds to turn on the "slope" method. It is used with the Flatten mode.
    set_slope_method_Key = Key.TWO,
    set_slope_method_ModifierKeys = {},

    -- Keybinds to turn on the "slope" method. It is used with the Smoothen mode.
    set_smoothen_method_Key = Key.THREE,
    set_smoothen_method_ModifierKeys = {},

    -- Brush scale/size
    -- Default size (without augment) is 350.
    -- 120 is the minimum size in Creative mode.
    -- 700 is the maximum size in Creative mode.
    -- 550 seems to be the size with the Wide mod augment.
    -- Note: these modifications do NOT work in Creative mode.
    BaseBrushDeformationScale_min = 50,   -- default: 120
    BaseBrushDeformationScale_max = 550,  -- default: 550
    BaseBrushDeformationScale_step = 100, -- default: 100
    decrease_BaseBrushDeformationScale_Key = Key.XBUTTON_ONE,
    decrease_BaseBrushDeformationScale_ModifierKeys = {},
    increase_BaseBrushDeformationScale_Key = Key.XBUTTON_TWO,
    increase_BaseBrushDeformationScale_ModifierKeys = {},

    -- DeformType to use when you press the "set_deformType_Key" key below.
    deformType = DeformType.RevertModifications,
    -- Keybinds to set a deform type.
    set_deformType_Key = Key.R,
    set_deformType_ModifierKeys = {},

    -- Sshortcuts to the flatten modes.
    -- Classic Flatten mode.
    set_Flatten_mode_Key = Key.F,
    set_Flatten_mode_ModifierKeys = {},
    -- Subtract only Flatten mode.
    set_FlattenSubtractOnly_mode_Key = Key.F,
    set_FlattenSubtractOnly_mode_ModifierKeys = { ModifierKey.SHIFT },

    --#region Method "slope". These options ONLY work in the "slope" method.
    -- See the link below for the key names:
    -- (List of Key/Gamepad Input Names) https://michaeljcole.github.io/wiki.unrealengine.com/List_of_Key/Gamepad_Input_Names/
    set_slope_direction_from_camera_KeyName = "w",
    set_slope_direction_from_camera_reversed_KeyName = "x",
    set_slope_direction_from_slope_KeyName = "LeftShift",
    --#endregion Method "slope".
}

----------------------------------------

return options
