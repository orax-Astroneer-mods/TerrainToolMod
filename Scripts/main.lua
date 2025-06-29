-- This list can be overwritten in the options file.
---@type string[]
local MethodsToLoad = {
    "tangent",
    "slope",
    "smoothen",
    "auto",
    "paint",
    "revert",
}

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

local currentModDirectory = debug.getinfo(1, "S").source:gsub("\\", "/"):match("@?(.+)/[Ss]cripts/")
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
    local file = format([[%s\%s]], currentModDirectory, UI_FILE)

    return dofile(file)
end

--------------------------------------------------------------------------------

-- Default logging levels. They can be overwritten in the options file.
LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

local options = loadOptions()
OPTIONS = options
loadDevOptions()
local optUI = loadOptionsUI()
OPTIONS_UI = optUI

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
local function loadMethods()
    local methods = {}
    ---@diagnostic disable-next-line: undefined-field
    local methodNamesList = type(options.methodsToLoad) == "table" and options.methodsToLoad or MethodsToLoad

    for index, methodName in ipairs(methodNamesList) do
        local methodTable = {
            index = index
        }

        local file = format([[%s\Scripts\methods\%s\main.lua]], currentModDirectory, methodName)
        log.debug("Load method file: %q.", file)
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
---@return string|nil
local function setMethod(method)
    if #MethodNamesList == 0 then
        log.info("No method found.")
        return
    end

    local newMethod
    local oldMethod = CurrenMethod
    local number = tonumber(method)

    if type(number) == "number" then
        newMethod = MethodNamesList[math.min(number, #MethodNamesList)]
    elseif type(method) == "string" then
        newMethod = method
    else
        error("Incorrect method type.")
    end

    -- set default method if nil or incorrect
    if newMethod == nil or Methods[newMethod] == nil then
        log.info(format("Method %q is not found or not loaded.", newMethod))
        return
    end

    -- if same method; no change
    if newMethod == CurrenMethod then
        log.debug(format("The newMethod == CurrenMethod (%q). No change.", newMethod))
        return newMethod
    end

    log.debug(format("Set method: %q.", newMethod))


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
        if #MethodNamesList == 0 then
            log.info("No method found.")
            return
        end

        if setMethod(mainParams.LATEST_METHOD) == nil then
            log.debug("Try to set the first method from the list.")
            if setMethod(1) == nil then
                return
            end
        end

        IsModEnabled = true
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
-- Deform_Normal1
RegisterCustomProperty({
    ["Name"] = "Deform_NormalX",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x814
})
RegisterCustomProperty({
    ["Name"] = "Deform_NormalY",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x814 + 4
})
RegisterCustomProperty({
    ["Name"] = "Deform_NormalZ",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x814 + 8
})

-- Deform_Location1
RegisterCustomProperty({
    ["Name"] = "Deform_Location1X",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x820
})
RegisterCustomProperty({
    ["Name"] = "Deform_Location1Y",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x820 + 4
})
RegisterCustomProperty({
    ["Name"] = "Deform_Location1Z",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x820 + 8
})

-- Deform_Normal2
RegisterCustomProperty({
    ["Name"] = "Deform_Normal2X",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x848
})
RegisterCustomProperty({
    ["Name"] = "Deform_Normal2Y",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x848 + 4
})
RegisterCustomProperty({
    ["Name"] = "Deform_Normal2Z",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x848 + 8
})

-- Deform_Location2
RegisterCustomProperty({
    ["Name"] = "Deform_Location2X",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x854
})
RegisterCustomProperty({
    ["Name"] = "Deform_Location2Y",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x854 + 4
})
RegisterCustomProperty({
    ["Name"] = "Deform_Location2Z",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x854 + 8
})

-- Deform_Location3
RegisterCustomProperty({
    ["Name"] = "Deform_Location3X",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8D0
})
RegisterCustomProperty({
    ["Name"] = "Deform_Location3Y",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8D0 + 4
})
RegisterCustomProperty({
    ["Name"] = "Deform_Location3Z",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8D0 + 8
})

-- Deform_Normal3
RegisterCustomProperty({
    ["Name"] = "Deform_Normal3X",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8DC
})
RegisterCustomProperty({
    ["Name"] = "Deform_Normal3Y",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8DC + 4
})
RegisterCustomProperty({
    ["Name"] = "Deform_Normal3Z",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8DC + 8
})

-- Deform_Location4
RegisterCustomProperty({
    ["Name"] = "Deform_Location4X",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8E8
})
RegisterCustomProperty({
    ["Name"] = "Deform_Location4Y",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8E8 + 4
})
RegisterCustomProperty({
    ["Name"] = "Deform_Location4Z",
    ["Type"] = PropertyTypes.FloatProperty,
    ["BelongsToClass"] = "/Script/Astro.DeformTool",
    ["OffsetInternal"] = 0x8E8 + 8
})
--#endregion

--#region Initialization

mainParams = loadMainParams()

Methods, MethodNamesList = loadMethods()
if #MethodNamesList == 0 then
    log.warn("No method found.")
end

local function hook_TerrainToolCreativeMenu_OnColorAndTypePicked()
    RegisterHook("/Game/UI/CreativeMode/TerrainToolCreativeMenu.TerrainToolCreativeMenu_C:OnColorAndTypePicked",
        ---@param TerrainToolCreativeMenu RemoteUnrealParam
        ---@param SelectedColor RemoteUnrealParam
        ---@param SelectedColorIndex RemoteUnrealParam
        ---@param PaintType RemoteUnrealParam
        function(TerrainToolCreativeMenu, SelectedColor, SelectedColorIndex, PaintType)
            local menu = TerrainToolCreativeMenu:get() ---@type UTerrainToolCreativeMenu_C

            if CurrenMethod ~= "" and type(Methods[CurrenMethod].hook_TerrainToolCreativeMenu_OnColorAndTypePicked) == "function" then
                Methods[CurrenMethod].hook_TerrainToolCreativeMenu_OnColorAndTypePicked(menu, SelectedColor:get(),
                    SelectedColorIndex:get(), PaintType:get())
            end

            onDeform_color.hook_TerrainToolCreativeMenu_OnColorAndTypePicked(menu, SelectedColor:get(),
                SelectedColorIndex:get(), PaintType:get())
        end)
end

local function hook_Planet_Marker_HandlePlanetMarkerSelected()
    RegisterHook("/Game/Exploration/Planet_Marker.Planet_Marker_C:HandlePlanetMarkerSelected",
        ---@param self RemoteUnrealParam
        function(self)
            -- execute HandlePlanetMarkerSelected event for the current method
            if CurrenMethod ~= "" and
                type(Methods[CurrenMethod].hook_Planet_Marker_HandlePlanetMarkerSelected) == "function" then
                log.debug("Execute HandlePlanetMarkerSelected event for method %q.", CurrenMethod)
                Methods[CurrenMethod].hook_Planet_Marker_HandlePlanetMarkerSelected(self)
            end

            -- execute HandlePlanetMarkerSelected event for onDeform_color
            if type(onDeform_color.hook_Planet_Marker_HandlePlanetMarkerSelected) == "function" then
                log.debug("Execute HandlePlanetMarkerSelected event for onDeform_color.")
                onDeform_color.hook_Planet_Marker_HandlePlanetMarkerSelected(self)
            end
        end)
end

---@param self RemoteUnrealParam
---@param NewPawn RemoteUnrealParam
RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
    local newPawn = NewPawn:get() ---@type ADesignAstro_C

    if newPawn:IsA("/Game/Character/DesignAstro.DesignAstro_C") and newPawn.LocalSolarBody:IsValid() then
        local firstInitialization = FirstInit

        if firstInitialization == true then
            -- Hooks to register BEFORE the ClientRestart hook is registered.
            hook_TerrainToolCreativeMenu_OnColorAndTypePicked()

            -- Hooks to register BEFORE or AFTER the ClientRestart hook is registered.
            hook_Planet_Marker_HandlePlanetMarkerSelected()
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

        FirstInit = false
    end
end)

RegisterHook("/Script/Engine.PlayerController:ClientReceiveLocalizedMessage",
    function(...)
        -- execute event for the current method
        if CurrenMethod ~= "" and
            type(Methods[CurrenMethod].PlayerController_ClientReceiveLocalizedMessage) == "function" then
            log.debug("Execute PlayerController_ClientReceiveLocalizedMessage event for method %q.", CurrenMethod)
            Methods[CurrenMethod].PlayerController_ClientReceiveLocalizedMessage(...)
        end

        -- execute event for onDeform_color
        if type(onDeform_color.PlayerController_ClientReceiveLocalizedMessage) == "function" then
            log.debug("Execute PlayerController_ClientReceiveLocalizedMessage event for onDeform_color.")
            onDeform_color.PlayerController_ClientReceiveLocalizedMessage(...)
        end
    end)

-- Manage "UE4SS Restart mods" or when the script is injected manually.
if UEHelpers:GetPlayer():IsValid() then
    local player = UEHelpers:GetPlayer() ---@cast player ADesignAstro_C

    if player:IsA("/Game/Character/DesignAstro.DesignAstro_C") and player.LocalSolarBody:IsValid() then
        hook_TerrainToolCreativeMenu_OnColorAndTypePicked()
        hook_Planet_Marker_HandlePlanetMarkerSelected()

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

local function isUIFocused()
    if CurrenMethod ~= "" and type(Methods[CurrenMethod].isUIFocused) == "function" then
        if Methods[CurrenMethod].isUIFocused() == true then
            return true
        end
    end

    if type(onDeform_color.isUIFocused) == "function" then
        if onDeform_color.isUIFocused() == true then
            return true
        end
    end

    return false
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
            RegisterKeyBind(key, modifierKeys, function()
                if not isUIFocused() then
                    callback()
                end
            end)
        else
            RegisterKeyBind(key, function()
                if not isUIFocused() then
                    callback()
                end
            end)
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
    add("create_tangent_terrain")
    add("toggle_colorDeform_ui")
    add("set_tangent_method")
    add("set_slope_method")
    add("set_smoothen_method")
    add("set_auto_method")
    add("set_paint_method")
    add("set_revert_method")
    add("increase_BaseBrushDeformationScale")
    add("decrease_BaseBrushDeformationScale")
    add("set_deformType")
    add("set_Flatten_mode")
    add("set_FlattenSubtractOnly_mode")
    add("set_FlattenAddOnly_mode")

    text = text .. "\n[Method: slope]\n"
    textLeft = textLeft .. "\n[Method: slope]\n"
    textRight = textRight .. "\n\n"
    add("set_slope_direction_from_camera", options.set_slope_direction_from_camera_KeyName)
    add("set_slope_direction_from_camera_reversed", options.set_slope_direction_from_camera_reversed_KeyName)
    add("set_slope_direction_from_slope", options.set_slope_direction_from_slope_KeyName)

    text = text .. "\n[Method: auto]\n"
    textLeft = textLeft .. "\n[Method: auto]\n"
    textRight = textRight .. "\n\n"
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

    text = text .. "\n[Method: revert]\n"
    textLeft = textLeft .. "\n[Method: revert]\n"
    textRight = textRight .. "\n\n"
    add("revert_offset_location_down", options.revert_offset_location_down_KeyName)
    add("revert_offset_location_up", options.revert_offset_location_up_KeyName)
    add("revert_offset_location_fixed_value", options.revert_offset_location_fixed_value_1_KeyName,
        format(options.revert_offset_location_fixed_value_text, options.revert_offset_location_fixed_value_1))
    add("revert_offset_location_fixed_value", options.revert_offset_location_fixed_value_2_KeyName,
        format(options.revert_offset_location_fixed_value_text, options.revert_offset_location_fixed_value_2))
    add("revert_offset_location_fixed_forward_backward_value",
        options.revert_offset_location_modifier_KeyName .. "+" .. options.revert_offset_location_fixed_value_1_KeyName,
        format(options.revert_offset_location_fixed_forward_backward_value_text,
            options.revert_offset_forward_backward_location_fixed_value_1))
    add("revert_offset_location_fixed_forward_backward_value",
        options.revert_offset_location_modifier_KeyName .. "+" .. options.revert_offset_location_fixed_value_2_KeyName,
        format(options.revert_offset_location_fixed_forward_backward_value_text,
            options.revert_offset_forward_backward_location_fixed_value_2))
    add("revert_toggle_revert_once", options.revert_toggle_revert_once_KeyName)

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

    ---@type UHorizontalBox
    local horizontalBox_main = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        HelpUI.userWidget.WidgetTree.RootWidget, FName(prefix .. "HorizontalBox_main"))

    ---@type UVerticalBox
    local verticalBox = StaticConstructObject(StaticFindObject("/Script/UMG.VerticalBox"),
        horizontalBox_main, FName(prefix .. "VerticalBox"))

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
    -- verticalBox:AddChildToVerticalBox(multiLineEditableTextBox_bottom)

    horizontalBox_main:AddChildToHorizontalBox(verticalBox)
    horizontalBox_main:AddChildToHorizontalBox(multiLineEditableTextBox_bottom)

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    local slot = HelpUI.canvas:AddChildToCanvas(horizontalBox_main)
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

local function createTangentTerrain()
    local baseArcLength = options.TangentTerrain.ALC_LENGTH
    local iterations = options.TangentTerrain.ITERATIONS
    local scale = options.TangentTerrain.SCALE
    local materialIndex = options.TangentTerrain.MATERIAL_INDEX -- Color. Default: 128. Valid values: 0 to ...

    ExecuteInGameThread(function()
        local designAstro = UEHelpers:GetPlayer() ---@cast designAstro ADesignAstro_C
        local controller = UEHelpers:GetPlayerController() ---@cast controller APlayControllerInstance_C


        local loc = designAstro:K2_GetActorLocation()
        local fw = designAstro:GetActorForwardVector()
        local right = designAstro:GetActorRightVector()
        local up = designAstro:GetActorUpVector()

        local planetCenter = designAstro:GetLocalSolarBody():GetCenter()

        local capsule = designAstro:K2_GetRootComponent() ---@cast capsule UCapsuleComponent
        local capsuleHalfHeight = capsule:GetScaledCapsuleHalfHeight()

        local floor1 = {
            X = loc.X - (up.X * capsuleHalfHeight),
            Y = loc.Y - (up.Y * capsuleHalfHeight),
            Z = loc.Z - (up.Z * capsuleHalfHeight)
        }

        local relativeFloor = {
            X = floor1.X - planetCenter.X,
            Y = floor1.Y - planetCenter.Y,
            Z = floor1.Z - planetCenter.Z
        }

        local altitude = getVectorLen(relativeFloor)
        local floor2 = { X = relativeFloor.X, Y = relativeFloor.Y, Z = relativeFloor.Z }

        for i = -iterations, iterations, 1 do
            for j = -iterations, iterations, 1 do
                local arcLength1 = baseArcLength * i
                local arcLength2 = baseArcLength * j

                local theta1 = arcLength1 / altitude
                local theta2 = arcLength2 / altitude

                -- to left
                local u = vec3.rotate(
                    vec3.new(relativeFloor.X, relativeFloor.Y, relativeFloor.Z),
                    theta2,
                    vec3.new(fw.X, fw.Y, fw.Z))

                floor2 = { X = u.x, Y = u.y, Z = u.z }

                -- to forward
                local v = vec3.rotate(
                    vec3.new(floor2.X, floor2.Y, floor2.Z),
                    theta1,
                    vec3.new(right.X, right.Y, right.Z))

                local normal = vec3.normalize(v)
                local v_absolute = vec3.new(v.x + planetCenter.X, v.y + planetCenter.Y, v.z + planetCenter.Z)

                controller:ClientDoDeformation({
                    AutoCreateResourceEfficiency = 0,
                    CreativeModeNoResourceCollection = false,
                    DeltaTime = 1000, -- ???
                    ForceRemoveDecorators = false,
                    HardnessPenetration = 10,
                    Instigator = nil,
                    Intensity = 10,
                    Location = {
                        X = v_absolute.x,
                        Y = v_absolute.y,
                        Z = v_absolute.z,
                    },
                    MaterialIndex = materialIndex,
                    Normal = { X = normal.x, Y = normal.y, Z = normal.z },
                    Operation = 2,
                    Scale = scale, -- min: 120, max: 700, default: 350
                    SequenceNumber = 0,
                    Shape = 0,
                    bEasyUnbury = false,
                    bUseAlternatePolygonization = true
                })
            end
        end
    end)
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

registerKeyBind(options.create_tangent_terrain_Key,
    options.create_tangent_terrain_ModifierKeys,
    createTangentTerrain)

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
