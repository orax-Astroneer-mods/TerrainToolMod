local default = {
    font_size = 14,
    positionInViewport = { X = 0, Y = 0 }, ---@type FVector2D
    spacer_size = { X = 5, Y = 1 }, ---@type FVector2D
    zOrder = 0,
}

local modName = "[TerrainToolMod]\n"

---@class TerrainToolMod_Options_UI
local ui = {
    ["*"] = {
        txt = {
            paint_tip =
                "In addition to what this \"method\" does, it paints the terrain when this CheckBox is checked.\n" ..
                "Press %s to configure the color and the scale.\n" ..
                "Notes:\n" ..
                "- The \"paint\" operation is not similar to the one in Creative mode. It doesn't work as well and can cause lag.\n" ..
                "- The hardness of the terrain may be modified."
        }
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
            paint = "Paint",
        },
        font_size = default.font_size,
        positionInViewport = default.positionInViewport,
        spacer_size = default.spacer_size,
        zOrder = default.zOrder,
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
            paint = "Paint",
        },
        font_size = default.font_size,
        positionInViewport = default.positionInViewport,
        spacer_size = default.spacer_size,
        zOrder = default.zOrder,
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
            paint = "Paint",
        },
        font_size = default.font_size,
        positionInViewport = default.positionInViewport,
        spacer_size = default.spacer_size,
        zOrder = default.zOrder,
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
            "The angle will be increased/decreased every n milliseconds until it is equal to the expected angle (in degrees).",
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
        },
        font_size = default.font_size,
        positionInViewport = default.positionInViewport,
        spacer_size = default.spacer_size,
        zOrder = default.zOrder,
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
                "Valid value: a positive float number (example: 2.5).",
            material_index = "Material index",
            material_index_tip = "A material index of the current planet.\n" ..
                "Click on a color below to change the current material index.\n" ..
                "You can also manually change the material index, then press %s to update the color preview below.",
        },
        font_size = default.font_size,
        positionInViewport = default.positionInViewport,
        spacer_size = default.spacer_size,
        zOrder = default.zOrder,
        creativeMenu_position = { X = -500, Y = 120 }, ---@type FVector2D
        activeColorImage_translation = { X = 217, Y = -239 }, ---@type FVector2D
        colorPicker_padding = { Bottom = 0, Left = 500, Right = 0, Top = 0 },
    },
}

return ui
