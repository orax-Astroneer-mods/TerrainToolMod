---@class FOutputDevice
---@field Log function

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

inf = math.huge ---@diagnostic disable-line: lowercase-global

-- functions implemented in the method file
---@type Method[]
local Methods = {}

local CachedTerrainTool = CreateInvalidObject() ---@cast CachedTerrainTool ASmallDeform_TERRAIN_EXPERIMENTAL_C

local MethodNamesList = {}

local Method = "" -- current method

local HandleTerrainToolStatus = false
local PreId_handleTerrainTool, PostId_handleTerrainTool

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

--------------------------------------------------------------------------------

-- Default logging levels. They can be overwritten in the options file.
LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

local options = loadOptions()
OPTIONS = options

Log = logging.new(LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR)
local log = Log
LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR = nil, nil

--------------------------------------------------------------------------------

--#region hooks
---@param callback function
local function registerHookFor_handleTerrainTool(callback)
    PreId_handleTerrainTool, PostId_handleTerrainTool = RegisterHook("/Script/Astro.DeformTool:HandleTerrainTool",
        callback)
end
local function unregisterHookFor_handleTerrainTool()
    if type(PreId_handleTerrainTool) == "number" and type(PostId_handleTerrainTool) == "number" then
        UnregisterHook("/Script/Astro.DeformTool:HandleTerrainTool", PreId_handleTerrainTool,
            PostId_handleTerrainTool)
    end
end
--#endregion hooks

---Retrieve functions from method files.
---@return Method[], table
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

    -- if same method; no change
    if newMethod == Method then
        log.debug("The newMethod == Method. No change.")
        return method
    end

    unregisterHookFor_handleTerrainTool()

    if type(Methods[newMethod].handleTerrainTool_hook) == "function" then
        if HandleTerrainToolStatus == true then
            -- register the hook with the new method
            registerHookFor_handleTerrainTool(Methods[newMethod].handleTerrainTool_hook)
        end
    end

    log.info(format("Set method: %q. %s", newMethod, Methods[newMethod].getInfo()))

    Method = newMethod

    return newMethod
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

Methods, MethodNamesList = loadAllMethods()
MethodNamesList[0] = options.method -- default method
log.info("Current method: " .. setMethod(options.method) .. ".")

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

local function enable_handleTerrainTool(silent)
    if HandleTerrainToolStatus == false then
        if type(Methods[Method].handleTerrainTool_hook) ~= "function" then
            log.info("handleTerrainTool_hook is not implemented in the current method.")
            return
        end
        registerHookFor_handleTerrainTool(Methods[Method].handleTerrainTool_hook)
        HandleTerrainToolStatus = true
    end

    if not silent then
        log.info(format("HandleTerrainTool is ENABLED. Method: %q. %s", Method, Methods[Method].getInfo()))
    end
end

local function disable_handleTerrainTool()
    if HandleTerrainToolStatus == true then
        unregisterHookFor_handleTerrainTool()
        HandleTerrainToolStatus = false
    end

    log.info("HandleTerrainTool is DISABLED.")
end

local function toggle_handleTerrainTool()
    if HandleTerrainToolStatus == true then
        disable_handleTerrainTool()
    else
        enable_handleTerrainTool()
    end

    log.info("HandleTerrainTool is %s.", HandleTerrainToolStatus and "ENABLED" or "DISABLED")
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
    if Methods[Method].params[property] == nil then
        if outputDevice then
            outputDevice:Log(format(
                "This property does not exist for the method %q. Use the \"method\" command to change the method.",
                Method))
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

registerKeyBind(Key.MIDDLE_MOUSE_BUTTON, { ModifierKey.SHIFT }, function()
    local terrainTool = getTerrainTool()

    terrainTool.BaseBrushDeformationScale = math.min(
        terrainTool.BaseBrushDeformationScale + options.BaseBrushDeformationScale_step,
        options.BaseBrushDeformationScale_max)
end)

registerKeyBind(Key.MIDDLE_MOUSE_BUTTON, { ModifierKey.CONTROL }, function()
    local terrainTool = getTerrainTool()

    terrainTool.BaseBrushDeformationScale = math.max(
        terrainTool.BaseBrushDeformationScale - options.BaseBrushDeformationScale_step,
        options.BaseBrushDeformationScale_min)
end)

registerKeyBind(options.enable_handleTerrainTool_Key,
    options.enable_handleTerrainTool_ModifierKeys,
    enable_handleTerrainTool)

registerKeyBind(options.disable_handleTerrainTool_Key,
    options.disable_handleTerrainTool_ModifierKeys,
    disable_handleTerrainTool)

registerKeyBind(options.toggle_handleTerrainTool_Key,
    options.toggle_handleTerrainTool_ModifierKeys,
    toggle_handleTerrainTool)

registerKeyBind(options.set_deformType_Key,
    options.set_deformType_ModifierKeys,
    setDeformTypeTo)

registerKeyBind(options.set_tangent_method_Key,
    options.set_tangent_method_ModifierKeys,
    function() setMethod("tangent") end)

registerKeyBind(options.set_slope_method_Key,
    options.set_slope_method_ModifierKeys,
    function() setMethod("slope") end)

registerKeyBind(options.set_Flatten_mode_Key,
    options.set_Flatten_mode_ModifierKeys,
    function() setDeformTypeTo(EDeformType.Flatten) end)

registerKeyBind(options.set_FlattenSubtractOnly_mode_Key,
    options.set_FlattenSubtractOnly_mode_ModifierKeys,
    function() setDeformTypeTo(EDeformType.FlattenSubtractOnly) end)

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
RegisterConsoleCommandHandler("slope_angle", function(fullCommand, parameters, outputDevice)
    if not checkIfPropertyExists("SLOPE_ANGLE", outputDevice) then
        return true
    end

    local helpMsg =
        "Usage: slope_angle <angle in degrees (-360 to 360)>\n" ..
        "Examples: slope_angle 45"

    if #parameters < 1 then
        outputDevice:Log(helpMsg)
        return true
    end

    local angle = tonumber(parameters[1])
    if angle == nil then
        outputDevice:Log(helpMsg)
        return true
    end
    Methods[Method].params.SLOPE_ANGLE = angle

    local msg = format("Set slope angle: %d°.", Methods[Method].params.SLOPE_ANGLE)
    log.info(msg)
    outputDevice:Log(msg)

    Methods[Method].writeParamsFile()

    return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("altitude", function(fullCommand, parameters, outputDevice)
    if not checkIfPropertyExists("CUSTOM_ALTITUDE", outputDevice) then
        return true
    end

    local helpMsg =
        "Usage: altitude <altitude (number)>\n" ..
        "Examples: altitude 121000"

    if #parameters < 1 then
        outputDevice:Log(helpMsg)
        Methods[Method].params.CUSTOM_ALTITUDE = inf
        local msg = format("Unfreeze altitude.")
        log.info(msg)
        outputDevice:Log(msg)
        return true
    end

    local altitude = tonumber(parameters[1])
    if altitude == nil then
        outputDevice:Log(helpMsg)
        return true
    end
    Methods[Method].params.CUSTOM_ALTITUDE = altitude

    local msg = format("Set altitude: %s.", Methods[Method].params.CUSTOM_ALTITUDE)
    log.info(msg)
    outputDevice:Log(msg)

    Methods[Method].writeParamsFile()

    return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("alt", function(fullCommand, parameters, outputDevice)
    if not checkIfPropertyExists("CUSTOM_ALTITUDE", outputDevice) then
        return true
    end

    local helpMsg =
        "Set altitude to a predefined value in options.lua file.\n" ..
        "Usage: alt <name>\n" ..
        "Example: alt base1"

    if #parameters < 1 then
        outputDevice:Log(helpMsg)
        Methods[Method].params.CUSTOM_ALTITUDE = inf
        local msg = format("Unfreeze altitude.")
        log.info(msg)
        outputDevice:Log(msg)
        return true
    end

    local name = table.concat(parameters, " ")
    local altitude = tonumber(options.altitudes_userList[name])
    if type(altitude) ~= "number" then
        outputDevice:Log(format("Predefined altitude %q not found or not valid."), name)
        return true
    end

    Methods[Method].params.CUSTOM_ALTITUDE = altitude

    local msg = format("Set altitude %q: %s.", name, Methods[Method].params.CUSTOM_ALTITUDE)
    log.info(msg)
    outputDevice:Log(msg)

    Methods[Method].writeParamsFile()

    return true
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

    local msg = format("Altitude: %.16g", getVectorLen(hitResult.Location))
    outputDevice:Log(msg)
    log.info(msg)

    return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("altitude_step", function(fullCommand, parameters, outputDevice)
    if not checkIfPropertyExists("ALTITUDE_STEP", outputDevice) then
        return true
    end

    Methods[Method].writeParamsFile()
    local helpMsg =
        "Usage: altitude_step <step>\n" ..
        "Example: altitude_step 100\n" ..
        format("Current altitude step: %.16g", Methods[Method].params.ALTITUDE_STEP)

    if #parameters < 1 then
        outputDevice:Log(helpMsg)
        return true
    end

    local step = tonumber(parameters[1])
    if step == nil then
        outputDevice:Log(helpMsg)
        return true
    end
    Methods[Method].params.ALTITUDE_STEP = step

    local msg = format("Set altitude step: %.16g", Methods[Method].params.ALTITUDE_STEP)
    log.info(msg)
    outputDevice:Log(msg)

    Methods[Method].writeParamsFile()

    return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("ttmod", function(fullCommand, parameters, outputDevice)
    local function getStatus()
        return HandleTerrainToolStatus == true and "enabled" or "disabled"
    end

    local fmt = "Terrain Tool mod is %s."

    if #parameters < 1 then
        toggle_handleTerrainTool()
        outputDevice:Log(format(fmt, getStatus()))
        return true
    end

    local arg = string.lower(parameters[1])
    if arg == "on" then
        enable_handleTerrainTool()
    elseif arg == "off" then
        disable_handleTerrainTool()
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
RegisterConsoleCommandHandler("method", function(fullCommand, parameters, outputDevice)
    local helpMsg =
        "You can choose a method by this index or name.\n" ..
        "Index 0 corresponds to the method in defined in options.lua.\n" ..
        "Available methods:\n"

    helpMsg = helpMsg .. format("index: 0 name: %s\n", options.method)

    for index, name in ipairs(MethodNamesList) do
        helpMsg = helpMsg .. format("index: %d name: %s\n", index, name)
    end

    if #parameters < 1 then
        outputDevice:Log(helpMsg)
        return true
    end

    setMethod(parameters[1])

    outputDevice:Log(format("Current method is set to %s.", Method))

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

enable_handleTerrainTool()
