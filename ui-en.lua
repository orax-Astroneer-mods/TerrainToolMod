local default = {
    font_size = 14,
    spacer_size = { X = 5, Y = 1 }, ---@type FVector2D
    spacer_size2 = { X = 10, Y = 1 }, ---@type FVector2D
}

local modName = "[TerrainToolMod]\n"

---@class TerrainToolMod_Options_UI
local ui = {
    _generic = {
        -- top, left
        AnchorsInViewport = { Minimum = { X = 0, Y = 0 }, Maximum = { X = 0, Y = 0 } }, ---@type FAnchors
        -- bottom, left
        AnchorsInViewport2 = { Minimum = { X = 0, Y = 1 }, Maximum = { X = 0, Y = 1 } }, ---@type FAnchors
        AlignmentInViewport = { X = 0, Y = 0 }, ---@type FVector2D
        AlignmentInViewport2 = { X = 0, Y = 1 }, ---@type FVector2D
        -- top, left
        Padding = { Left = 5, Top = 0, Right = 0, Bottom = 0 }, ---@type FMargin
        -- bottom, left
        Padding2 = { Left = 5, Top = 0, Right = 0, Bottom = 5 }, ---@type FMargin
        zOrder = 0, ---@type number
        zOrder2 = 1, ---@type number

        txt = {
            paint_tip =
                "In addition to what this \"method\" does, it paints the terrain when this CheckBox is checked.\n" ..
                "Press %s to configure the color and the scale.\n" ..
                "Notes:\n" ..
                "- The \"paint\" operation is not similar to the one in Creative mode. It doesn't work as well and can cause lag.\n" ..
                "- The hardness of the terrain may be modified.",
            paint_scale_tip = "The brush scale.\n" ..
                "Valid value: a positive float number (examples: 2.5, 0.4, .4).\n" ..
                "Note: For example, the values ​​0.4 and 0.4 are the same. You can omit the zero.",
        }
    },

    _main = {
        helpText_bottom =
            "Commands: deform_type, get_altitude, ttmod, look.\n" ..
            "Notes:\n" ..
            "- Method-specific shortcuts only work when your terrain tool is equipped.\n" ..
            "- Some features do not work in Creative mode."
    },

    tangent = {
        txt = {
            title = "tangent",
            description_tip = modName ..
                "The \"tangent\" method flattens the terrain following the planet's curvature.\n" ..
                "Usage: Equip your Terrain Tool and choose a Flatten mode.",
            altitudeList_tip =
                "List of predefined altitudes.\n" ..
                "The \"Force Altitude\" checkbox needs to be checked to use this selected altitude; otherwise, the altitude will be the one under the cursor.\n" ..
                [[You can modify them in the "methods\tangent\params.lua". After editing the file, press %s to update the list.]],
            temporaryAltitude = "Temporary altitude",
            temporaryAltitude_tip =
                "You can set an altitude manually. This value will override the preset altitude in the ComboBox list above.\n" ..
                "The \"Force Altitude\" checkbox needs to be checked to use this selected altitude; otherwise, the altitude will be the one under the cursor.",
            forceAltitude = "Force altitude",
            forceAltitude_tip =
                "Check to force the altitude to the set value when using a Flatten mode.\n" ..
                "Otherwise, the altitude will be the one under the cursor.",
            altitudeRound = "Round altitude to",
            altitudeRound_tip = "The altitude will be rounded to this value.\n" ..
                [[For example, if the value is "100": "120124" will be rounded to "120100"; "100165" will be rounded to "100200.]],
            roundedAltitude_tip = "Last altitude used (read only).",
        },
        font_size = default.font_size,
        spacer_size = default.spacer_size,
        spacer_size2 = default.spacer_size2,
    },

    slope = {
        txt = {
            title = "slope",
            description_tip = modName ..
                "The \"slope\" method creates a sloped terrain with the chosen angle.\n" ..
                "Usage: press one of these keys below (hold it) and click somewhere on the terrain.\n" ..
                "Note: This method only work with a Flatten mode.\n" ..
                "%s", -- shortcuts
            angle = "Angle",
            angle_tip = "Desired angle (in degrees) for the terraformed slope.",
        },
        font_size = default.font_size,
        spacer_size = default.spacer_size,
    },

    smoothen = {
        txt = {
            title = "smoothen",
            description_tip = modName ..
                "The \"smoothen\" method smooths the terrain.\n" ..
                "Usage: Equip your terrain tool with a Flatten mode and smooth a surface by holding the click.\n" ..
                "Note: This method only work with a Flatten mode.\n",
            debug = "debug",
            debug_tip =
                "Shows debug lights.\n" ..
                "The lights represent the points used to calculate an average of the terrain (altitude, direction, etc.).",
            presetsComboBox_tip = "Avalaible presets.\n" ..
                [[You can add/modify prests in the "methods\smoothen\presets\" folder.]] .. "\n" ..
                "After editing a preset file, press %s to update the list/data.",
        },
        font_size = default.font_size,
        spacer_size = default.spacer_size,
    },

    auto = {
        txt = {
            title = "auto",
            description_tip = modName ..
                "The \"auto\" (automatic) method create a \"deformation\" (terraforming) at the player's location.\n" ..
                "Usage: Equip your Terrain Tool and walk. You don't have to click on the terrain.\n" ..
                "Note: Resources inside the terrain are not collected and will be destroyed.\n" ..
                "Troubleshooting:\n" ..
                "- Unequip (if necessary) and equip your Terrain Tool if something doesn't work.\n" ..
                "- This method only activates when your character is moving with your Terrain Tool equipped.",
            loop_delay = "Loop delay",
            loop_delay_tip =
                "The angle will be increased/decreased every n milliseconds until it is equal to the expected angle (in degrees).\n" ..
                "Unequip and equip your Terrain Tool to take into account the modifications.",
            angle = "Angle",
            angle_tip =
                "Terraforming angle.\n" ..
                "An angle of 0° corresponds to flat terraforming.\n" ..
                "Note that terraforming follows the curvature of the planet.\n" ..
                "The angle shouldn't matter if you're just \"painting\" the surface.\n" ..
                "Press %s to set angle to 0.",
            expected_angle = "Expected angle",
            expected_angle_tip = "Expected angle (in degrees).\n" ..
                [["inf" means "infinite". This is a special value that indicates the current angle is the same as the expected angle.]],
            presetsComboBox_tip = "Avalaible presets.\n" ..
                [[You can add/modify prests in the "methods\auto\presets\" folder.]] .. "\n" ..
                "After editing a preset file, press %s to update the list/data and unequip (if necessary) and equip your Terrain Tool.",
            speed_limit = "Speed limit",
            speed_limit_tip = "Limit your maximum speed.\n" ..
                "Game defaults are 1360.0 (sprinting), 850.0 (walking).\n" ..
                "Open you Terrain Tool to apply the speed limit.\n" ..
                "Disable this \"method\" (press F3, by default) to restore the original speed limit.",
            no_sliding = "No sliding",
            no_sliding_tip = "Prevents sliding.\n" ..
                "Open you Terrain Tool to apply the change.",
        },
        font_size = default.font_size,
        spacer_size = default.spacer_size,
    },

    paint = {
        txt = {
            title = "paint",
            description_tip = modName ..
                "Paint the selected color and material on terrain.\n" ..
                "Usage: Click on a color (square) below. Unequip (if necessary) and equip your Terrain Tool.\n" ..
                "Notes:\n" ..
                "- The \"paint\" operation is not similar to the one in Creative mode. It doesn't work as well and can cause lag.\n" ..
                "- The hardness of the terrain may be modified.",
            scale = "Scale",
            scale_tip = "The brush scale.\n" ..
                "Valid value: a positive float number (examples: 2.5, 0.4, .4).\n" ..
                "Note: For example, the values ​​0.4 and 0.4 are the same. You can omit the zero.",
            material_index = "Material index",
            material_index_tip = "Selected material index (read only).",
        },
        font_size = default.font_size,
        spacer_size = default.spacer_size,
        spacer_size2 = default.spacer_size2,
        ActiveColorImage_RenderTransformPivot = { X = 0, Y = 1 }, ---@type FVector2D
        ActiveColorImage_RenderTransform_Scale = { X = 0.65, Y = 0.8 }, ---@type FVector2D
        CreativeTerrainPlanetColorPicker_Padding = { Left = 0, Top = 0, Right = 60, Bottom = 0 }, ---@type FMargin
    },

    revert = {
        txt = {
            title = "revert",
            description_tip = modName ..
                "The \"revert\" method reverts modifications of the terrain.\n" ..
                "Usage: Equip your Terrain Tool and click somewhere on a terraformed terrain.",
            scale = "Scale",
            scale_tip = "Scale of the revert modifications.",
            intensity = "Intensity",
            intensity_tip = "The intensity of the revert.\n" ..
                "Valid value: a positive float number (examples: 2.5, 0.4, .4).\n" ..
                "Recommended value range: between 0.01 and 5.\n" ..
                "Note: For example, the values ​0.4 and 0.4 are the same. You can omit the zero.",
            revertOnce = "Revert once",
            revertOnce_tip =
                "If checked, the \"Revert modifications\" action will only be performed once when you click on the terrain.\n\n" ..
                "Keyboard shortcut to enable or disable the checkbox: %s",
            revertColorOnly = "Revert color only",
            revertColorOnly_tip = "If checked, only the color of the terrain will be reverted.\n" ..
                "Intensity is ignored.",
            offset = "Offset (up/down)",
            offset_tip = "Offset (up/down) of the sphere. Check `debug` to see the sphere.",
            altitude = "Altitude",
            altitude_tip = "Alitude of the sphere. Check `debug` to see the sphere.\n" ..
                "The altitude is automatically taken under the cursor when you open your Terrain tool (unless `Freeze altitude` is checked).",
            keybinds = "\nKeybinds (while the Terrain tool is OPEN):\n\n",
            freezeAltitude = "Freeze altitude",
            freezeAltitude_tip = "Freeze altitude of the sphere. Check `debug` to see the sphere.\n" ..
                "If checked, the terrain modification will only be reverted at the given altitude (above).",
            debug = "Debug",
            debug_tip = "Show a debug sphere.\n" ..
                "The debug sphere shows you which area of ​​the terrain will be restored.",
            wireframe = "Wireframe",
            wireframe_tip = "The debug sphere will be rendered in wireframe.",
            rgba = "RGBA",
            rgba_tip = "Color values (RED, GREEN, BLUE, ALPHA).\n" ..
                "Valid values for colors are between 0 to 1 (examples: 1, 0.4, .4).\n" ..
                "Notes:\n" ..
                "- For example, the values ​​0.4 and 0.4 are the same. You can omit the zero.\n" ..
                "- The wireframe material has no alpha color.",
        },
        font_size = default.font_size,
        spacer_size = default.spacer_size,
        spacer_size2 = { X = 1, Y = 1 }, ---@type FVector2D
    },

    onDeform_color = {
        txt = {
            title = "color",
            description_tip = modName ..
                "Change the color of the terrain when you terraform it.\n" ..
                "Press %s to toggle the visibility of this UI.\n" ..
                "Notes:\n" ..
                "- This feature ONLY works with the Add or Flatten modes of your Terrain Tool.\n" ..
                "- This feature does NOT work properly in Creative mode.",
            scale = "Scale",
            scale_tip = "Scale of the area that will be colored.\n" ..
                "Valid value: a positive float number (examples: 2.5, 0.4, .4).\n" ..
                "Notes:\n" ..
                "- For example, the values ​​0.4 and 0.4 are the same. You can omit the zero.\n" ..
                "- This feature may cause lag when enabled.\n" ..
                "- The hardness of the terrain may be modified.",
            material_index = "Material index",
            material_index_tip = "Selected material index (read only).",
            enable = "Enable",
            enable_tip = "Check to enable this feature.",
            revertColor = "Original color",
            revertColor_tip =
            "If checked, the brush will use the original terrain color instead of the selected color below.",
        },
        font_size = default.font_size,
        positionInViewport = { X = 0, Y = 0 }, ---@type FVector2D

        spacer_size = default.spacer_size,
        zOrder = 1,
        ActiveColorImage_RenderTransformPivot = { X = 0, Y = 1 }, ---@type FVector2D
        ActiveColorImage_RenderTransform_Scale = { X = 0.65, Y = 0.8 }, ---@type FVector2D
        CreativeTerrainPlanetColorPicker_Padding = { Left = 0, Top = 0, Right = 60, Bottom = 0 }, ---@type FMargin
    }
}

return ui
