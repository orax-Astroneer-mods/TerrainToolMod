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

---@type EDeformType
local EDeformType = {
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

---@class TerrainToolMod_Options
local options = {
    help_ui = {
        font_size = 16,
        title_left = "[Terrain Tool Mod]\n",
        title_right = "\n",
        positionInViewport = { X = 0, Y = 0 },
        zOrder = 1
    },

    -- Delay in milliseconds at which the main_params.lua file will be updated. You should not change this.
    writeMainParamsFileEvery = 30000,

    --
    -- Note: You can modify/translate the contents of variables that end with _text.
    --

    toggle_help_ui_text = "Show this help text",
    toggle_help_ui_Key = Key.F1,
    toggle_help_ui_ModifierKeys = {},

    -- Keybinds to ENABLE/DISABLE/TOGGLE the mod when you use the terrain tool.
    -- ENABLE, turn on
    enable_handleTerrainTool_text = "Enable Terrain Tool Mod; update/reload UI",
    enable_handleTerrainTool_Key = Key.F2,
    enable_handleTerrainTool_ModifierKeys = {},
    -- DISABLE, turn off
    disable_handleTerrainTool_text = "Disable Terrain Tool Mod",
    disable_handleTerrainTool_Key = Key.F3,
    disable_handleTerrainTool_ModifierKeys = {},
    -- TOGGLE
    toggle_handleTerrainTool_text = "Toggle Terrain Tool Mod",
    toggle_handleTerrainTool_Key = nil,
    toggle_handleTerrainTool_ModifierKeys = {},

    -- Keybinds to turn on the "tangent" method. It is used with the Flatten mode.
    -- When using Flatten mode, the Terrain tool will flatten the terrain following the planet's curvature.
    set_tangent_method_text = "Set \"tangent\" method",
    set_tangent_method_Key = Key.ONE,
    set_tangent_method_ModifierKeys = {},

    -- Keybinds to turn on the "slope" method. It is used with the Flatten mode.
    set_slope_method_text = "Set \"slope\" method",
    set_slope_method_Key = Key.TWO,
    set_slope_method_ModifierKeys = {},

    -- Keybinds to turn on the "slope" method. It is used with the Smoothen mode.
    set_smoothen_method_text = "Set \"smoothen\" method",
    set_smoothen_method_Key = Key.THREE,
    set_smoothen_method_ModifierKeys = {},

    -- Keybinds to turn on the "auto" (automatic) method.
    set_auto_method_text = "Set \"auto\" method",
    set_auto_method_Key = Key.FOUR,
    set_auto_method_ModifierKeys = {},

    -- Keybinds to turn on the "paint" method.
    set_paint_method_text = "Set \"paint\" method",
    set_paint_method_Key = Key.FIVE,
    set_paint_method_ModifierKeys = {},

    -- Keybinds to turn on the "revert" method.
    set_revert_method_text = "Set \"revert\" method",
    set_revert_method_Key = Key.SIX,
    set_revert_method_ModifierKeys = {},

    toggle_colorDeform_ui_text = "Toggle the visibility of the \"color\" UI",
    toggle_colorDeform_ui_Key = Key.ONE,
    toggle_colorDeform_ui_ModifierKeys = { ModifierKey.SHIFT },

    -- Brush scale/size
    -- Default size (without augment) is 350.
    -- 120 is the minimum size in Creative mode.
    -- 700 is the maximum size in Creative mode.
    -- 550 seems to be the size with the Wide mod augment.
    -- Note: these modifications do NOT work in Creative mode.
    BaseBrushDeformationScale_min = 120, -- default: 120
    BaseBrushDeformationScale_max = 550, -- default: 550
    BaseBrushDeformationScale_step = 50, -- default: 100
    decrease_BaseBrushDeformationScale_text = "Decrease brush (min: 50, step: 50)",
    decrease_BaseBrushDeformationScale_Key = Key.MIDDLE_MOUSE_BUTTON,
    decrease_BaseBrushDeformationScale_ModifierKeys = { ModifierKey.CONTROL },
    increase_BaseBrushDeformationScale_text = "Increase brush (max: 550, step: 50)",
    increase_BaseBrushDeformationScale_Key = Key.MIDDLE_MOUSE_BUTTON,
    increase_BaseBrushDeformationScale_ModifierKeys = { ModifierKey.SHIFT },

    -- DeformType to use when you press the "set_deformType_Key" key below.
    deformType = EDeformType.RevertModifications,
    -- Keybinds to set a deform type.
    set_deformType_text = "Set \"Revert modifications\" mode",
    set_deformType_Key = Key.R,
    set_deformType_ModifierKeys = {},

    -- Shortcuts to the flatten modes.
    -- Classic Flatten mode.
    set_Flatten_mode_text = "Set \"Flatten\" mode",
    set_Flatten_mode_Key = Key.F,
    set_Flatten_mode_ModifierKeys = { ModifierKey.SHIFT },
    -- Subtract only Flatten mode.
    set_FlattenSubtractOnly_mode_text = "Set \"Flatten subtract only\" mode",
    set_FlattenSubtractOnly_mode_Key = Key.F,
    set_FlattenSubtractOnly_mode_ModifierKeys = { ModifierKey.CONTROL, ModifierKey.SHIFT },
    -- Add only Flatten mode.
    set_FlattenAddOnly_mode_text = "Set \"Flatten add only\" mode",
    set_FlattenAddOnly_mode_Key = Key.F,
    set_FlattenAddOnly_mode_ModifierKeys = { ModifierKey.CONTROL, ModifierKey.ALT, ModifierKey.SHIFT },

    --#region Method "tangent". These options ONLY work in the "tangent" method.
    --#endregion

    --#region Method "smoothen". These options ONLY work in the "smoothen" method.
    --#endregion

    --#region Method "slope". These options ONLY work in the "slope" method.
    -- See the link below for the key names:
    -- (List of Key/Gamepad Input Names) https://michaeljcole.github.io/wiki.unrealengine.com/List_of_Key/Gamepad_Input_Names/
    set_slope_direction_from_camera_text = "Set slope direction from camera",
    set_slope_direction_from_camera_KeyName = "w",
    set_slope_direction_from_camera_reversed_text = "Set slope direction from camera (reversed)",
    set_slope_direction_from_camera_reversed_KeyName = "x",
    set_slope_direction_from_slope_text = "Set slope direction from slope (under cursor)",
    set_slope_direction_from_slope_KeyName = "LeftShift",
    --#endregion Method "slope".

    --#region Method "auto". These options ONLY work in the "auto" method.
    -- See the link below for the key names:
    -- (List of Key/Gamepad Input Names) https://michaeljcole.github.io/wiki.unrealengine.com/List_of_Key/Gamepad_Input_Names/
    auto__value1 = 1,
    auto__value2 = 5,
    auto__increase_angle_text = "Increase angle by 1",
    auto__increase_angle_KeyName = "Home",
    auto__decrease_angle_text = "Decrease angle by 1",
    auto__decrease_angle_KeyName = "End",

    auto__increase_expected_angle_text = "Increase expected angle by 5",
    auto__decrease_expected_angle_text = "Decrease expected angle by 5",
    auto__increase_or_decrease_expected_angle_KeyName = "LeftAlt",

    auto__angle_value1 = 45,
    auto__angle_value2 = -45,
    auto__set_angle_to_value1_text = "Set expected angle to 45",
    auto__set_angle_to_value1_KeyName = "PageUp",
    auto__set_angle_to_value2_text = "Set expected angle to -45",
    auto__set_angle_to_value2_KeyName = "PageDown",

    auto__set_angle_to_zero_text = "Set expected angle to 0",
    auto__set_angle_to_zero_KeyName = "Delete",

    auto__set_angle_from_slope_text = "Set angle equal to slope angle (under cursor)",
    auto__set_angle_from_slope_KeyName = "Insert",
    auto__set_angle_from_inverse_slope_text = "Set angle equal to -slope angle (under cursor)",
    auto__set_angle_from_slope_Modifier_KeyName = "LeftAlt",

    auto__set_angle_to_expectedAngle_KeyName = "Delete",
    auto__set_angle_to_expectedAngle_Modifier_KeyName = "LeftAlt",
    auto__set_angle_to_expectedAngle_text = "Set angle equal to expected angle"
    --#endregion Method "auto".

    --#region Method "paint". These options ONLY work in the "paint" method.
    --#endregion
}

----------------------------------------

--#region debug/log
local directory = [[ue4ss\Mods\TerrainToolMod\Scripts\debug\]]
-- dofile(directory .. "onDeform.lua")

-- Uncomment the line below to display the "Material Index" in logs.
-- Go in Creative Mode, select a brush color. Paint the terrain.
-- dofile(directory .. "getMaterialIndex.lua")
--#endregion

----------------------------------------

return options
