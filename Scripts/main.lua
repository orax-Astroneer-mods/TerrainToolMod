---@class FOutputDevice
---@field Log function

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

local EDeformTypeName = {
    "Subtract",
    "Add",
    "Flatten",
    "ColorPick",
    "ColorPaint",
    "CountCreative",
    "Crater",
    "FlattenSubtractOnly",
    "FlattenAddOnly",
    "TrueFlatStamp",
    "PlatformSurface",
    "RevertModifications",
    "Count",
    "EDeformType_MAX",
}

---@type ESlateVisibility
local ESlateVisibility = {
    Visible = 0,
    Collapsed = 1,
    Hidden = 2,
    HitTestInvisible = 3,
    SelfHitTestInvisible = 4,
    ESlateVisibility_MAX = 5
}

-- Global shared variable between onDeform_color and Paint method.
_G.MaterialIndexImage = 0 ---@type integer

-- functions implemented in the method file
local Methods = {} ---@type TerrainToolMod_Method[]
local MethodNamesList = {}
local CurrenMethod = ""

local FirstInit = true
local IsModEnabled = false
local CachedTerrainTool = CreateInvalidObject() ---@cast CachedTerrainTool ASmallDeform_TERRAIN_EXPERIMENTAL_C
local HelpUI = { showed = false }
local PreId_DeformTool_HandleTerrainTool, PostId_DeformTool_HandleTerrainTool
local PreId_DeformTool_Deactivated, PostId_DeformTool_Deactivated
local WriteMainParamsFileRequired = false

local UEHelpers = require("UEHelpers")
local logging = require("lib.lua-mods-libs.logging")
local utils = require("lib.lua-mods-libs.utils")
local func = require("func")

modules = "lib.LEEF-math.modules." ---@diagnostic disable-line: lowercase-global
Vec3 = require("lib.LEEF-math.modules.vec3")
local vec3 = Vec3

local sqrt = math.sqrt
local format = string.format

local currentModDirectory = debug.getinfo(1, "S").source:match("@?(.+\\Mods\\[^\\]+)")
local mainParamsFile = func.getParamsFileByName("main_params", currentModDirectory, true)
local mainParams = {}

---@param filename string
---@return boolean
local function isFileExists(filename)
    local file = io.open(filename, "r")
    if file ~= nil then
        io.close(file)
        return true
    else
        return false
    end
end

---@return TerrainToolMod_Options
local function loadOptions()
    local file = format([[%s\options.lua]], currentModDirectory)

    if not isFileExists(file) then
        local cmd = format([[copy "%s\options.example.lua" "%s\options.lua"]],
            currentModDirectory,
            currentModDirectory)

        print("Copy example options to options.lua. Execute command: " .. cmd .. "\n")

        os.execute(cmd)
    end

    return dofile(file)
end

local function loadDevOptions()
    local file = format([[%s\options.dev.lua]], currentModDirectory)

    if isFileExists(file) then
        dofile(file)
    end
end

---@return TerrainToolMod_Options_UI
local function loadOptionsUI()
    local file = format([[%s\ui.lua]], currentModDirectory)

    if not isFileExists(file) then
        local cmd = format([[copy "%s\ui.example.lua" "%s\ui.lua"]],
            currentModDirectory,
            currentModDirectory)

        print("Copy example UI to ui.lua. Execute command: " .. cmd .. "\n")

        os.execute(cmd)
    end

    return dofile(file)
end

--------------------------------------------------------------------------------

-- Default logging levels. They can be overwritten in the options file.
LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

local options = loadOptions()
OPTIONS = options
local optUI = loadOptionsUI()
OPTIONS_UI = optUI
loadDevOptions()

Log = logging.new(LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR)
local log = Log
LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR = nil, nil

local onDeform_color = require("onDeform.color.main")

--------------------------------------------------------------------------------

--#region hooks
---@param callback function
local function registerHook_DeformTool_HandleTerrainTool(callback)
    if type(PreId_DeformTool_HandleTerrainTool) == "number" or type(PostId_DeformTool_HandleTerrainTool) == "number" then
        log.warn("DeformTool_HandleTerrainTool is already hooked.")
        return
    end
    PreId_DeformTool_HandleTerrainTool, PostId_DeformTool_HandleTerrainTool = RegisterHook(
        "/Script/Astro.DeformTool:HandleTerrainTool", callback)
end
local function unregisterHook_handleTerrainTool()
    if type(PreId_DeformTool_HandleTerrainTool) == "number" and type(PostId_DeformTool_HandleTerrainTool) == "number" then
        UnregisterHook("/Script/Astro.DeformTool:HandleTerrainTool", PreId_DeformTool_HandleTerrainTool,
            PostId_DeformTool_HandleTerrainTool)
        PreId_DeformTool_HandleTerrainTool = nil
        PostId_DeformTool_HandleTerrainTool = nil
    end
end

---@param callback function
local function registerHook_DeformTool_Deactivated(callback)
    if type(PreId_DeformTool_Deactivated) == "number" or type(PostId_DeformTool_Deactivated) == "number" then
        log.warn("DeformTool_Deactivated is already hooked.")
        return
    end
    PreId_DeformTool_Deactivated, PostId_DeformTool_Deactivated = RegisterHook(
        "/Script/Astro.DeformTool:Deactivated", callback)
end
local function unregisterHook_DeformTool_Deactivated()
    if type(PreId_DeformTool_Deactivated) == "number" and type(PostId_DeformTool_Deactivated) == "number" then
        UnregisterHook("/Script/Astro.DeformTool:Deactivated", PreId_DeformTool_Deactivated,
            PostId_DeformTool_Deactivated)
        PreId_DeformTool_Deactivated = nil
        PostId_DeformTool_Deactivated = nil
    end
end
--#endregion hooks

local function writeMainParamsFile()
    log.debug("Write main params file.")

    local file = io.open(mainParamsFile, "w+")
    assert(file, format("\nUnable to open the main params file %q.", mainParamsFile))

    -- defaults
    if mainParams.LATEST_METHOD == nil then mainParams.LATEST_METHOD = "tangent" end

    file:write(format(
        [[return { ---@type TerrainToolMod_Main_PARAMS
LATEST_METHOD="%s"
}]],
        mainParams.LATEST_METHOD))

    file:close()
end

---@return TerrainToolMod_Main_PARAMS
local function loadMainParams()
    if not isFileExists(mainParamsFile) then
        writeMainParamsFile()
    end

    return dofile(mainParamsFile)
end

---Retrieve functions from method files.
---@return TerrainToolMod_Method[], table
local function loadAllMethods()
    ---@type string[]
    local fileList = utils.getFileList(currentModDirectory .. "\\Scripts\\methods\\", "main.lua")
    local methods = {}
    local methodNamesList = {}

    for index, file in ipairs(fileList) do
        local methodName = file:match("([^\\]+)\\main.lua")
        table.insert(methodNamesList, methodName)

        local methodTable = {
            index = index
        }

        local method = dofile(file)

        for key, value in pairs(method) do
            methodTable[key] = value
        end

        methods[methodName] = methodTable
    end

    return methods, methodNamesList
end

---Set current method.
---@param method string|integer
local function setMethod(method)
    local newMethod
    local oldMethod = CurrenMethod

    if type(tonumber(method)) == "number" then
        newMethod = MethodNamesList[tonumber(method)]
    elseif type(method) == "string" then
        newMethod = method
    else
        error("Incorrect method type.")
    end

    -- set default method if nil or incorrect
    if newMethod == nil or Methods[newMethod] == nil then
        newMethod = MethodNamesList[0]
    end

    log.debug(format("Set method: %q.", newMethod))

    -- if same method; no change
    if newMethod == CurrenMethod then
        log.debug("The newMethod == Method. No change.")
        return method
    end

    unregisterHook_handleTerrainTool()
    unregisterHook_DeformTool_Deactivated()

    if mainParams.LATEST_METHOD ~= newMethod then
        WriteMainParamsFileRequired = true
    end
    mainParams.LATEST_METHOD = newMethod
    CurrenMethod = newMethod

    -- register the hooks with the new method
    --
    -- hook HandleTerrainTool (main hook)
    if type(Methods[newMethod].hook_DeformTool_HandleTerrainTool) == "function" then
        registerHook_DeformTool_HandleTerrainTool(Methods[newMethod].hook_DeformTool_HandleTerrainTool)
    end
    -- hook on Terrain Tool deactivated
    if type(Methods[newMethod].hook_DeformTool_Deactivated) == "function" then
        registerHook_DeformTool_Deactivated(Methods[newMethod].hook_DeformTool_Deactivated)
    end

    -- execute onUnload event for the unloaded (old) method
    if oldMethod ~= "" and type(Methods[oldMethod].onUnload) == "function" then
        log.debug("Execute onUnload event for the old method %q.", oldMethod)
        Methods[oldMethod].onUnload()
    end

    -- execute onLoad event for the loaded (new) method
    if type(Methods[newMethod].onLoad) == "function" then
        log.debug("Execute onLoad event for the new method %q.", newMethod)
        Methods[newMethod].onLoad()
    end

    return newMethod
end

local function enableMod()
    if IsModEnabled == false then
        IsModEnabled = true
        setMethod(mainParams.LATEST_METHOD)

        log.debug("Terrain Tool Mod is ENABLED.")
        return
    end

    -- execute onUpdate event for the (updated) method
    if mainParams.LATEST_METHOD ~= "" and type(Methods[mainParams.LATEST_METHOD].onUpdate) == "function" then
        log.debug("Execute onUpdate event for the current method %q.", mainParams.LATEST_METHOD)
        Methods[mainParams.LATEST_METHOD].onUpdate()
    end

    log.debug(format("Terrain Tool Mod is already ENABLED. Method updated: %q.", mainParams.LATEST_METHOD))
end

local function disableMod()
    unregisterHook_handleTerrainTool()
    unregisterHook_DeformTool_Deactivated()
    -- execute onUnload event for the unloaded method
    if CurrenMethod ~= "" and type(Methods[CurrenMethod].onUnload) == "function" then
        log.debug("Execute onUnload event for the method %q.", CurrenMethod)
        Methods[CurrenMethod].onUnload()
        CurrenMethod = ""
    end

    IsModEnabled = false

    log.debug("Terrain Tool Mod is DISABLED.")
end

local function toggleModStatus()
    if IsModEnabled == true then
        disableMod()
    else
        enableMod()
    end

    log.debug("Terrain Tool Mod is %s.", IsModEnabled and "ENABLED" or "DISABLED")
end

--#region Custom properties
RegisterCustomProperty({
    ["Name"] = "LocalBrushStateNormalX",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x838
})
RegisterCustomProperty({
    ["Name"] = "LocalBrushStateNormalY",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x838 + 4
})
RegisterCustomProperty({
    ["Name"] = "LocalBrushStateNormalZ",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x838 + 8
})

RegisterCustomProperty({
    ["Name"] = "LocalBrushStateLocationX",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x844
})
RegisterCustomProperty({
    ["Name"] = "LocalBrushStateLocationY",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x844 + 4
})
RegisterCustomProperty({
    ["Name"] = "LocalBrushStateLocationZ",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x844 + 8
})

RegisterCustomProperty({
    ["Name"] = "DeformActionStartLocationX",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8C0
})
RegisterCustomProperty({
    ["Name"] = "DeformActionStartLocationY",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8C0 + 4
})
RegisterCustomProperty({
    ["Name"] = "DeformActionStartLocationZ",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8C0 + 8
})

RegisterCustomProperty({
    ["Name"] = "DeformActionStartNormalX",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8CC
})
RegisterCustomProperty({
    ["Name"] = "DeformActionStartNormalY",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8CC + 4
})
RegisterCustomProperty({
    ["Name"] = "DeformActionStartNormalZ",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8CC + 8
})

RegisterCustomProperty({
    ["Name"] = "DeformLaggedLocationX",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8D8
})
RegisterCustomProperty({
    ["Name"] = "DeformLaggedLocationY",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8D8 + 4
})
RegisterCustomProperty({
    ["Name"] = "DeformLaggedLocationZ",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8D8 + 8
})
--#endregion

--#region Initialization

mainParams = loadMainParams()

Methods, MethodNamesList = loadAllMethods()
MethodNamesList[0] = mainParams.LATEST_METHOD -- default method

local function hook_TerrainToolCreativeMenu_OnColorAndTypePicked()
    RegisterHook("/Game/UI/CreativeMode/TerrainToolCreativeMenu.TerrainToolCreativeMenu_C:OnColorAndTypePicked",
        ---@param TerrainToolCreativeMenu RemoteUnrealParam
        ---@param SelectedColor RemoteUnrealParam
        ---@param SelectedColorIndex RemoteUnrealParam
        ---@param PaintType RemoteUnrealParam
        function(TerrainToolCreativeMenu, SelectedColor, SelectedColorIndex, PaintType)
            local menu = TerrainToolCreativeMenu:get() ---@type UTerrainToolCreativeMenu_C
            local menuName = menu:GetFName():ToString()

            log.debug("Menu name: %q.", menuName)

            if CurrenMethod ~= "" and type(Methods[CurrenMethod].hook_TerrainToolCreativeMenu_OnColorAndTypePicked) == "function" then
                Methods[CurrenMethod].hook_TerrainToolCreativeMenu_OnColorAndTypePicked(menu, SelectedColor:get(),
                    SelectedColorIndex:get(), PaintType:get())
            end

            onDeform_color.hook_TerrainToolCreativeMenu_OnColorAndTypePicked(menu, SelectedColor:get(),
                SelectedColorIndex:get(), PaintType:get())
        end)
end

---@param self RemoteUnrealParam
---@param NewPawn RemoteUnrealParam
RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
    local newPawn = NewPawn:get() ---@type ADesignAstro_C

    if newPawn:IsA("/Game/Character/DesignAstro.DesignAstro_C") and newPawn.LocalSolarBody:IsValid() then
        local firstInitialization = FirstInit

        if firstInitialization == true then
            FirstInit = false
            hook_TerrainToolCreativeMenu_OnColorAndTypePicked()
        end

        -- execute onClientRestart event for the current method
        if CurrenMethod ~= "" and
            type(Methods[CurrenMethod].onClientRestart) == "function" then
            log.debug("Execute onClientRestart event for method %q.", CurrenMethod)
            Methods[CurrenMethod].onClientRestart(self, newPawn, firstInitialization)
        end

        -- execute onClientRestart event for onDeform_color
        if type(onDeform_color.hook_PlayerController_ClientRestart) == "function" then
            log.debug("Execute PlayerController ClientRestart event for onDeform_color.")
            onDeform_color.hook_PlayerController_ClientRestart(self, newPawn, firstInitialization)
        end
    end
end)

-- Manage "UE4SS Restart mods" or when the script is injected manually.
if UEHelpers:GetPlayer():IsValid() then
    local player = UEHelpers:GetPlayer() ---@cast player ADesignAstro_C

    if player:IsA("/Game/Character/DesignAstro.DesignAstro_C") and player.LocalSolarBody:IsValid() then
        hook_TerrainToolCreativeMenu_OnColorAndTypePicked()

        -- execute onModRestartedOrStartedManually event for the current method
        if CurrenMethod ~= "" and
            type(Methods[CurrenMethod].onModRestartedOrStartedManually) == "function" then
            log.debug("Execute onModRestartedOrStartedManually event for method %q.", CurrenMethod)
            Methods[CurrenMethod].onModRestartedOrStartedManually(FirstInit)
        end

        if type(onDeform_color.onModRestartedOrStartedManually) == "function" then
            log.debug("Execute onModRestartedOrStartedManually event for onDeform_color.")
            onDeform_color.onModRestartedOrStartedManually(FirstInit)
        end
    end
end

LoopAsync(options.writeMainParamsFileEvery or 10000, function()
    if WriteMainParamsFileRequired == true then
        WriteMainParamsFileRequired = false
        writeMainParamsFile()
    end

    return false
end)

--#endregion

--- Get the length of a vector.
---@param u FVector
---@return number len
local function getVectorLen(u)
    return sqrt(u.X * u.X + u.Y * u.Y + u.Z * u.Z)
end

local function getTerrainTool()
    if CachedTerrainTool:IsValid() and CachedTerrainTool.bHidden == false and CachedTerrainTool.bReplicateHidden == false then
        return CachedTerrainTool
    end

    local objects = FindAllOf("SmallDeform_TERRAIN_EXPERIMENTAL_C") ---@type ASmallDeform_TERRAIN_EXPERIMENTAL_C[]?
    if objects then
        for index, terrainTool in ipairs(objects) do
            if terrainTool.bHidden == false and terrainTool.bReplicateHidden == false then
                CachedTerrainTool = terrainTool
                return terrainTool
            end
        end
    end

    return CreateInvalidObject()
end

---@param deformType? EDeformType
---@param deformTool? ASmallDeform_TERRAIN_EXPERIMENTAL_C|UObject
local function setDeformTypeTo(deformType, deformTool)
    if deformTool == nil then
        deformTool = getTerrainTool()
    end

    if not deformTool:IsValid() then
        log.warn("DeformTool is invalid.")
    end

    deformType = deformType or options.deformType
    deformType = math.min(EDeformType.EDeformType_MAX, deformType)
    deformType = math.max(0, deformType)

    deformTool.Operation = deformType
    deformTool.TerrainBrush:ChangeBrushOperation(deformType)
    log.info("DeformType is set to %s (%d).", EDeformTypeName[deformType + 1], deformType)
end

---@param property string
---@param outputDevice FOutputDevice
---@return boolean
local function checkIfPropertyExists(property, outputDevice)
    if Methods[mainParams.LATEST_METHOD].params[property] == nil then
        if outputDevice then
            outputDevice:Log(format(
                "This property does not exist for the method %q. Use the \"method\" command to change the method.",
                mainParams.LATEST_METHOD))
        end

        return false
    end

    return true
end

local function registerKeyBind(key, modifierKeys, callback)
    if key ~= nil then
        if IsKeyBindRegistered(key, modifierKeys or {}) then
            local keyName = ""
            for k, v in pairs(Key) do
                if key == v then
                    keyName = k
                    break
                end
            end

            local modifierKeysList = ""
            for _, keyValue in ipairs(modifierKeys) do
                for k, v in pairs(ModifierKey) do
                    if keyValue == v then
                        modifierKeysList = modifierKeysList .. k .. "+"
                    end
                end
            end

            log.warn("Key bind %q is already registered.", modifierKeysList .. keyName)
        end

        if modifierKeys ~= nil and type(modifierKeys) == "table" and #modifierKeys > 0 then
            RegisterKeyBind(key, modifierKeys, callback)
        else
            RegisterKeyBind(key, callback)
        end
    end
end

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createHelpUI()
    local umg_MultiLineEditableTextBox = StaticFindObject("/Script/UMG.MultiLineEditableTextBox")
    local prefix = "TerrainMod_helpUI_"

    local gameInstance = UEHelpers.GetGameInstance()
    if not gameInstance:IsValid() then
        return false
    end

    local fmt = "%-50s%30s"
    local text = ""
    local textLeft = options.help_ui.title_left
    local textRight = options.help_ui.title_right

    local function add(name, keyName, description)
        local key = options[name .. "_Key"]
        local modifierKeys = options[name .. "_ModifierKeys"]
        description = description or options[name .. "_text"]
        keyName = keyName or func.getKeybindName(key, modifierKeys)
        text = text .. string.format(fmt, description, keyName) .. "\n"
        textLeft = textLeft .. description .. "\n"
        textRight = textRight .. keyName .. "\n"
    end

    text = text .. "[Globals]\n"
    textLeft = textLeft .. "[Globals]\n"
    textRight = textRight .. "\n"
    add("toggle_help_ui")
    add("enable_handleTerrainTool")
    add("disable_handleTerrainTool")
    add("toggle_handleTerrainTool")
    add("toggle_colorDeform_ui")
    add("set_tangent_method")
    add("set_slope_method")
    add("set_smoothen_method")
    add("set_auto_method")
    add("set_paint_method")
    add("increase_BaseBrushDeformationScale")
    add("decrease_BaseBrushDeformationScale")
    add("set_deformType")
    add("set_Flatten_mode")
    add("set_FlattenSubtractOnly_mode")
    add("set_FlattenAddOnly_mode")

    text = text .. "[Method: slope]\n"
    textLeft = textLeft .. "[Method: slope]\n"
    textRight = textRight .. "\n"
    add("set_slope_direction_from_camera", options.set_slope_direction_from_camera_KeyName)
    add("set_slope_direction_from_camera_reversed", options.set_slope_direction_from_camera_reversed_KeyName)
    add("set_slope_direction_from_slope", options.set_slope_direction_from_slope_KeyName)

    text = text .. "[Method: auto]\n"
    textLeft = textLeft .. "[Method: auto]\n"
    textRight = textRight .. "\n"
    add("auto__increase_angle", options.auto__increase_angle_KeyName)
    add("auto__decrease_angle", options.auto__decrease_angle_KeyName)
    add("auto__increase_expected_angle",
        options.auto__increase_or_decrease_expected_angle_KeyName .. "+" .. options.auto__increase_angle_KeyName,
        options.auto__increase_expected_angle_text)
    add("auto__decrease_expected_angle",
        options.auto__increase_or_decrease_expected_angle_KeyName .. "+" .. options.auto__decrease_angle_KeyName,
        options.auto__decrease_expected_angle_text)
    add("auto__set_angle_to_value1", options.auto__set_angle_to_value1_KeyName)
    add("auto__set_angle_to_value2", options.auto__set_angle_to_value2_KeyName)
    add("auto__set_angle_to_zero", options.auto__set_angle_to_zero_KeyName)
    add("auto__set_angle_from_slope", options.auto__set_angle_from_slope_KeyName)
    add("auto__set_angle_from_inverse_slope",
        options.auto__set_angle_from_slope_Modifier_KeyName .. "+" .. options.auto__set_angle_from_slope_KeyName,
        options.auto__set_angle_from_inverse_slope_text)
    add("auto__set_angle_to_expectedAngle",
        options.auto__set_angle_to_expectedAngle_Modifier_KeyName ..
        "+" .. options.auto__set_angle_to_expectedAngle_KeyName, options.auto__set_angle_to_expectedAngle_text)

    -- remove new line (\n) at the end
    textLeft = textLeft:sub(1, -2)
    textRight = textRight:sub(1, -2)

    text = text .. "\n" .. optUI._main.helpText_bottom

    local fontObj = StaticFindObject("/Game/UI/fonts/NDAstroneer-Regular_Font.NDAstroneer-Regular_Font")

    ---@diagnostic disable: param-type-mismatch, assign-type-mismatch

    ---@type UUserWidget
    HelpUI.userWidget = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), gameInstance,
        FName(prefix .. "UserWidget"))
    assert(HelpUI.userWidget:IsValid())

    HelpUI.userWidget.WidgetTree = StaticConstructObject(StaticFindObject("/Script/UMG.WidgetTree"), HelpUI.userWidget,
        FName(prefix .. "WidgetTree"))
    assert(HelpUI.userWidget.WidgetTree:IsValid())

    ---@type UCanvasPanel
    HelpUI.canvas = StaticConstructObject(StaticFindObject("/Script/UMG.CanvasPanel"),
        HelpUI.userWidget.WidgetTree, FName(prefix .. "CanvasPanel"))
    assert(HelpUI.canvas:IsValid())
    HelpUI.userWidget.WidgetTree.RootWidget = HelpUI.canvas

    ---@type UVerticalBox
    local verticalBox = StaticConstructObject(StaticFindObject("/Script/UMG.VerticalBox"),
        HelpUI.userWidget.WidgetTree.RootWidget, FName(prefix .. "VerticalBox"))

    ---@type UHorizontalBox
    local horizontalBox = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        verticalBox, FName(prefix .. "HorizontalBox1"))

    ---@type UMultiLineEditableTextBox
    local multiLineEditableTextBox_left = StaticConstructObject(umg_MultiLineEditableTextBox,
        horizontalBox, FName(prefix .. "multiLineEditableTextBox_left"))
    multiLineEditableTextBox_left.WidgetStyle.Font.FontObject = fontObj
    multiLineEditableTextBox_left.WidgetStyle.Font.Size = options.help_ui.font_size
    multiLineEditableTextBox_left.bIsReadOnly = true
    multiLineEditableTextBox_left:SetText(FText(textLeft))
    horizontalBox:AddChildToHorizontalBox(multiLineEditableTextBox_left)

    ---@type UMultiLineEditableTextBox
    local multiLineEditableTextBox_right = StaticConstructObject(umg_MultiLineEditableTextBox,
        horizontalBox, FName(prefix .. "MultiLineEditableTextBox_right"))
    multiLineEditableTextBox_right.WidgetStyle.Font.FontObject = fontObj
    multiLineEditableTextBox_right.WidgetStyle.Font.Size = options.help_ui.font_size
    multiLineEditableTextBox_right.bIsReadOnly = true
    multiLineEditableTextBox_right:SetText(FText(textRight))
    horizontalBox:AddChildToHorizontalBox(multiLineEditableTextBox_right)

    ---@type UMultiLineEditableTextBox
    local multiLineEditableTextBox_bottom = StaticConstructObject(umg_MultiLineEditableTextBox,
        horizontalBox, FName(prefix .. "MultiLineEditableTextBox_bottom"))
    multiLineEditableTextBox_bottom.WidgetStyle.Font.FontObject = fontObj
    multiLineEditableTextBox_bottom.WidgetStyle.Font.Size = options.help_ui.font_size
    multiLineEditableTextBox_bottom.bIsReadOnly = true
    multiLineEditableTextBox_bottom:SetText(FText(optUI._main.helpText_bottom))

    verticalBox:AddChildToVerticalBox(horizontalBox)
    verticalBox:AddChildToVerticalBox(multiLineEditableTextBox_bottom)

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    local slot = HelpUI.canvas:AddChildToCanvas(verticalBox)
    slot:SetAutoSize(true)

    HelpUI.userWidget:SetPositionInViewport(options.help_ui.positionInViewport, false)
    HelpUI.userWidget:AddToViewport(options.help_ui.zOrder)
    HelpUI.userWidget:SetVisibility(ESlateVisibility.Visible)

    log.debug("\n" .. text)

    log.debug("Help UI created.")

    return true
end

local function showHelpUI()
    if HelpUI.userWidget and HelpUI.userWidget:IsValid() then
        HelpUI.userWidget:SetVisibility(ESlateVisibility.Visible)
    else
        createHelpUI()
    end
    HelpUI.showed = true
end

local function hideHelpUI()
    if HelpUI.userWidget and HelpUI.userWidget:IsValid() then
        HelpUI.userWidget:SetVisibility(ESlateVisibility.Hidden)
    end
    HelpUI.showed = false
end

local function toogleHelpUI()
    if HelpUI.showed == true then
        hideHelpUI()
    else
        showHelpUI()
    end
end

registerKeyBind(options.toggle_help_ui_Key, options.toggle_help_ui_ModifierKeys, toogleHelpUI)

registerKeyBind(options.enable_handleTerrainTool_Key,
    options.enable_handleTerrainTool_ModifierKeys,
    enableMod)

registerKeyBind(options.disable_handleTerrainTool_Key,
    options.disable_handleTerrainTool_ModifierKeys,
    disableMod)

registerKeyBind(options.toggle_handleTerrainTool_Key,
    options.toggle_handleTerrainTool_ModifierKeys,
    toggleModStatus)

registerKeyBind(options.set_deformType_Key,
    options.set_deformType_ModifierKeys,
    setDeformTypeTo)

registerKeyBind(options.set_tangent_method_Key,
    options.set_tangent_method_ModifierKeys,
    function() setMethod("tangent") end)

registerKeyBind(options.set_slope_method_Key,
    options.set_slope_method_ModifierKeys,
    function() setMethod("slope") end)

registerKeyBind(options.set_smoothen_method_Key,
    options.set_smoothen_method_ModifierKeys,
    function() setMethod("smoothen") end)

registerKeyBind(options.set_auto_method_Key,
    options.set_auto_method_ModifierKeys,
    function() setMethod("auto") end)

registerKeyBind(options.set_paint_method_Key,
    options.set_paint_method_ModifierKeys,
    function() setMethod("paint") end)

registerKeyBind(options.set_revert_method_Key,
    options.set_revert_method_ModifierKeys,
    function() setMethod("revert") end)

registerKeyBind(options.toggle_colorDeform_ui_Key,
    options.toggle_colorDeform_ui_ModifierKeys,
    function()
        onDeform_color.toggleUI()
    end)

registerKeyBind(options.set_Flatten_mode_Key,
    options.set_Flatten_mode_ModifierKeys,
    function() setDeformTypeTo(EDeformType.Flatten) end)

registerKeyBind(options.set_FlattenSubtractOnly_mode_Key,
    options.set_FlattenSubtractOnly_mode_ModifierKeys,
    function() setDeformTypeTo(EDeformType.FlattenSubtractOnly) end)

registerKeyBind(options.set_FlattenAddOnly_mode_Key,
    options.set_FlattenAddOnly_mode_ModifierKeys,
    function() setDeformTypeTo(EDeformType.FlattenAddOnly) end)

registerKeyBind(options.increase_BaseBrushDeformationScale_Key,
    options.increase_BaseBrushDeformationScale_ModifierKeys,
    function()
        local terrainTool = getTerrainTool()
        terrainTool.BaseBrushDeformationScale = math.min(
            terrainTool.BaseBrushDeformationScale + options.BaseBrushDeformationScale_step,
            options.BaseBrushDeformationScale_max)
    end)

registerKeyBind(options.decrease_BaseBrushDeformationScale_Key,
    options.decrease_BaseBrushDeformationScale_ModifierKeys,
    function()
        local terrainTool = getTerrainTool()
        terrainTool.BaseBrushDeformationScale = math.max(
            terrainTool.BaseBrushDeformationScale - options.BaseBrushDeformationScale_step,
            options.BaseBrushDeformationScale_min)
    end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("get_altitude", function(fullCommand, parameters, outputDevice)
    ---@diagnostic disable-next-line: missing-fields
    local hitResult = {} ---@type FHitResult

    local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
    if not playerController:IsValid() then
        log.warn("PlayerController invalid.")
    end
    local result = playerController:GetHitResultUnderCursorForObjects({ 6 }, false, hitResult)

    local hitActor = func.getActorFromHitResult(hitResult)
    if not result or not hitActor:IsA("/Script/Astro.SolarBody") then
        outputDevice:Log("Cannot get altitude.")
        return true
    end

    local msg = format("Altitude under cursor: %.16g", getVectorLen(hitResult.Location))
    outputDevice:Log(msg)
    log.info(msg)

    return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("ttmod", function(fullCommand, parameters, outputDevice)
    local function getStatus()
        return IsModEnabled == true and "enabled" or "disabled"
    end

    local fmt = "Terrain Tool mod is %s."

    if #parameters < 1 then
        toggleModStatus()
        outputDevice:Log(format(fmt, getStatus()))
        return true
    end

    local arg = string.lower(parameters[1])
    if arg == "on" then
        enableMod()
    elseif arg == "off" then
        disableMod()
    else
        local helpMsg =
            "Usage: ttmod [on | off]>\n" ..
            "Example: ttmod on\n"
        outputDevice:Log(helpMsg)
    end

    -- show status
    local msg = format(fmt, getStatus())
    log.info(msg)
    outputDevice:Log(msg)

    return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("deform_type", function(fullCommand, parameters, outputDevice)
    local values = [[
    Subtract = 0
    Add = 1
    Flatten = 2
    ColorPick = 3
    ColorPaint = 4
    CountCreative = 5
    Crater = 6
    FlattenSubtractOnly = 7
    FlattenAddOnly = 8
    TrueFlatStamp = 9
    PlatformSurface = 10
    RevertModifications = 11
    Count = 12]]

    local helpMsg =
        "Force the terrain tool to use a specific deform type.\n" ..
        "Usage: deform_type <DeformType>\n" ..
        "Example: operation 11\n" ..
        "DeformType values:\n" ..
        values

    if #parameters < 1 then
        outputDevice:Log(helpMsg)
        return true
    end

    local deformType = tonumber(parameters[1])
    if deformType == nil or type(deformType) ~= "number" then
        outputDevice:Log(helpMsg)
        return true
    end

    outputDevice:Log(format("DeformType is set to %d.", deformType))
    setDeformTypeTo(deformType)

    return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("look", function(fullCommand, parameters, outputDevice)
    local helpMsg =
        "Look in the north or east direction." ..
        "Usage: look {n | e}\n" ..
        "Example: look n"

    if #parameters < 1 then
        outputDevice:Log(helpMsg)
        return true
    end

    local player = UEHelpers:GetPlayer()
    local uePlayerLoc = player:K2_GetActorLocation()
    local playerLoc = vec3.new(uePlayerLoc.X, uePlayerLoc.Y, uePlayerLoc.Z)

    local direction = vec3.cross(vec3.new(1, 0, 0), playerLoc) -- East

    if parameters[1] ~= "e" then
        direction = vec3.cross(playerLoc, direction) -- North
    end

    local rot = vec3.findLookAtRotation(playerLoc, direction)

    player:K2_SetActorRotation(rot, false)

    return true
end)
