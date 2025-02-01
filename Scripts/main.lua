---@class FOutputDevice
---@field Log function

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

local HandleTerrainToolStatus = false
local PlanetCenter = { X = 0, Y = 0, Z = 0 } ---@type FVector
local CustomAltitude = nil ---@type number?
local PreId_handleTerrainTool, PostId_handleTerrainTool

local UEHelpers = require("UEHelpers")
local logging = require("lib.lua-mods-libs.logging")
modules = "lib.LEEF-math.modules." ---@diagnostic disable-line: lowercase-global
local floor, sqrt = math.floor, math.sqrt

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

---@param HitResult FHitResult
---@return AActor
local function GetActorFromHitResult(HitResult)
    if UnrealVersion:IsBelow(5, 0) then
        return HitResult.Actor:Get() ---@diagnostic disable-line: undefined-field
    elseif UnrealVersion:IsBelow(5, 4) then
        return HitResult.HitObjectHandle.Actor:Get() ---@diagnostic disable-line: undefined-field
    else
        return HitResult.HitObjectHandle.ReferenceObject:Get() ---@diagnostic disable-line: undefined-field
    end
end

local function loadOptions()
    local file = string.format([[%s\options.lua]], currentModDirectory)

    if not isFileExists(file) then
        local cmd = string.format([[copy "%s\options.example.lua" "%s\options.lua"]],
            currentModDirectory,
            currentModDirectory)

        print("Copy example options to options.lua. Execute command: " .. cmd .. "\n")

        os.execute(cmd)
    end

    return dofile(file)
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
LOG_LEVEL = "INFO" ---@type _LogLevel
MIN_LEVEL_OF_FATAL_ERROR = "ERROR" ---@type _LogLevel

local options = loadOptions()

local AltitudeStep = options.altitudeStep ~= nil and options.altitudeStep or 50.0

local log = logging.new(LOG_LEVEL, MIN_LEVEL_OF_FATAL_ERROR)
LOG_LEVEL = nil
MIN_LEVEL_OF_FATAL_ERROR = nil
ALTITUDE_STEP = nil

local RootComponent -- 0x160
local RoundedAltitude = 0
--#endregion

---Get nearest multiple of base.
---@param a number
---@param base number
---@return number
local function roundToBase(a, base)
    return floor(a / base + 0.5) * base
end

--- Get the length of a vector.
---@param u FVector
---@return number len
local function getVectorLen(u)
    return sqrt(u.X * u.X + u.Y * u.Y + u.Z * u.Z)
end

local function handleTerrainTool_hook(self, controller, toolHit, clickResult, startedInteraction, endedInteraction,
                                      isUsingTool, justActivated, canUse)
    if canUse:get() == false then
        return
    end

    local deformTool = self:get() ---@diagnostic disable-line: undefined-field
    ---@cast deformTool ASmallDeform_TERRAIN_EXPERIMENTAL_C

    -- check if a flatten operation is selected
    local operation = deformTool.Operation
    if operation ~= DeformType.Flatten and operation ~= DeformType.FlattenAddOnly and operation ~= DeformType.FlattenSubtractOnly then
        return
    end

    startedInteraction = startedInteraction:get()
    toolHit = toolHit:get()
    clickResult = clickResult:get()

    ---@cast controller APlayController
    ---@cast toolHit FHitResult
    ---@cast clickResult FClickResult
    ---@cast startedInteraction boolean
    ---@cast endedInteraction boolean
    ---@cast isUsingTool boolean
    ---@cast justActivated boolean
    ---@cast canUse boolean

    local location = toolHit.Location

    if startedInteraction then
        local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
        if not playerController:IsValid() then
            log.warn("PlayerController invalid.")
        end

        local homeBody = playerController.HomeBody -- 0xC98
        RootComponent = homeBody.RootComponent     -- 0x160

        -- Planet center is (0, 0, 0) for SYLVA.
        PlanetCenter = RootComponent.RelativeLocation

        -- check if the hit actor is a SolarBody (planet)
        local actor = toolHit.Actor:Get() ---@diagnostic disable-line: undefined-field
        if not actor:IsA("/Script/Astro.SolarBody") then
            log.debug("Hit actor is not a SolarBody. Try to get a SolarBody.")

            ---@diagnostic disable-next-line: missing-fields
            local hitResult = {} ---@type FHitResult

            --[[ Why 6? It's (maybe) the ObjectType for the terrain. You can do tests with this code:
                local hitResult = {}
                local playerController = UEHelpers:GetPlayerController()
                for i = 1, 33, 1 do
                    playerController:GetHitResultUnderCursorForObjects({ i }, false, hitResult)
                    local hitActor = GetActorFromHitResult(hitResult)
                    print(i, hitActor:GetFullName())
                end --]]
            local result = playerController:GetHitResultUnderCursorForObjects({ 6 }, false, hitResult)
            if result then
                local hitActor = GetActorFromHitResult(hitResult)
                if not hitActor:IsValid() or not hitActor:IsA("/Script/Astro.SolarBody") then
                    log.debug("[!!] New hit actor is not a SolarBody.")
                    return
                end
            end

            location = hitResult.Location
        end

        if type(CustomAltitude) == "number" then
            RoundedAltitude = CustomAltitude
            log.info("Altitude is defined to %.16g.", CustomAltitude)
        else
            RoundedAltitude = roundToBase(getVectorLen(location), AltitudeStep)
            log.info("Rounded altitude is %.16g.", RoundedAltitude)
        end
    end

    ---@type FVector
    local u = {
        X = location.X - PlanetCenter.X,
        Y = location.Y - PlanetCenter.Y,
        Z = location.Z - PlanetCenter.Z
    }

    local pointLocationAltitude = getVectorLen(u)

    -- resize vector to the rounded altitude
    u = {
        X = (u.X / pointLocationAltitude) * RoundedAltitude,
        Y = (u.Y / pointLocationAltitude) * RoundedAltitude,
        Z = (u.Z / pointLocationAltitude) * RoundedAltitude
    }

    -- get cosines of the angle between the vector and the normal
    local angle = {
        X = u.X / RoundedAltitude,
        Y = u.Y / RoundedAltitude,
        Z = u.Z / RoundedAltitude
    }

    -- add planet center location to the vector
    u = {
        X = u.X + PlanetCenter.X,
        Y = u.Y + PlanetCenter.Y,
        Z = u.Z + PlanetCenter.Z
    }

    -- RepBrushState (0x804)
    -- deformTool.RepBrushState.CurrentDeformNormal = newAngle
    deformTool.RepBrushState.CurrentDeformNormal.X = angle.X
    deformTool.RepBrushState.CurrentDeformNormal.Y = angle.Y
    deformTool.RepBrushState.CurrentDeformNormal.Z = angle.Z
    deformTool.RepBrushState.CurrentDeformLocation.X = u.X
    deformTool.RepBrushState.CurrentDeformLocation.Y = u.Y
    deformTool.RepBrushState.CurrentDeformLocation.Z = u.Z

    ---@diagnostic disable: inject-field

    -- LocalBrushState (0x838)
    deformTool.LocalBrushStateNormalX = angle.X
    deformTool.LocalBrushStateNormalY = angle.Y
    deformTool.LocalBrushStateNormalZ = angle.Z
    deformTool.LocalBrushStateLocationX = u.X
    deformTool.LocalBrushStateLocationY = u.Y
    deformTool.LocalBrushStateLocationZ = u.Z

    -- DeformActionStartLocation (0x8C0)
    deformTool.DeformActionStartLocationX = u.X
    deformTool.DeformActionStartLocationY = u.Y
    deformTool.DeformActionStartLocationZ = u.Z

    -- DeformActionStartNormal (0x8CC)
    deformTool.DeformActionStartNormalX = angle.X
    deformTool.DeformActionStartNormalY = angle.Y
    deformTool.DeformActionStartNormalZ = angle.Z

    -- DeformLaggedLocation (0x8D8)
    deformTool.DeformLaggedLocationX = u.X
    deformTool.DeformLaggedLocationY = u.Y
    deformTool.DeformLaggedLocationZ = u.Z

    deformTool.HitLocation.X = u.X
    deformTool.HitLocation.Y = u.Y
    deformTool.HitLocation.Z = u.Z
    deformTool.HitNormal.X = angle.X
    deformTool.HitNormal.Y = angle.Y
    deformTool.HitNormal.Z = angle.Z

    ---@diagnostic enable: inject-field
end

local function enable_handleTerrainTool()
    if HandleTerrainToolStatus == false then
        PreId_handleTerrainTool, PostId_handleTerrainTool = RegisterHook("/Script/Astro.DeformTool:HandleTerrainTool",
            handleTerrainTool_hook)
        HandleTerrainToolStatus = true
    end

    log.info("HandleTerrainTool is ENABLED.")
end

local function disable_handleTerrainTool()
    if HandleTerrainToolStatus == true then
        if type(PreId_handleTerrainTool) == "number" and type(PostId_handleTerrainTool) == "number" then
            UnregisterHook("/Script/Astro.DeformTool:HandleTerrainTool", PreId_handleTerrainTool,
                PostId_handleTerrainTool)
        end
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

---@param deformTool ASmallDeform_TERRAIN_EXPERIMENTAL_C
local function setDeformTypeTo(deformTool)
    if deformTool == nil then
        deformTool = FindFirstOf("SmallDeform_TERRAIN_EXPERIMENTAL_C") ---@diagnostic disable-line: cast-local-type
    end

    if not deformTool:IsValid() then
        log.warn("DeformTool is invalid.")
        return
    end

    deformTool.Operation = options.deformType
    log.info("DeformType is set to %d.", options.deformType)
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

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("altitude", function(fullCommand, parameters, outputDevice)
    local helpMsg =
        "Usage: altitude <altitude (number)>\n" ..
        "Examples: altitude 121000"

    if #parameters < 1 then
        outputDevice:Log(helpMsg)
        CustomAltitude = nil
        local msg = string.format("Unfreeze altitude.")
        log.info(msg)
        outputDevice:Log(msg)
        return true
    end

    local altitude = tonumber(parameters[1])
    if altitude == nil then
        outputDevice:Log(helpMsg)
        return true
    end
    CustomAltitude = altitude

    local msg = string.format("Set altitude: %s.", CustomAltitude)
    log.info(msg)
    outputDevice:Log(msg)

    return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("alt", function(fullCommand, parameters, outputDevice)
    local helpMsg =
        "Set altitude to a predefined value in options.lua file.\n" ..
        "Usage: alt <name>\n" ..
        "Example: alt base1"

    if #parameters < 1 then
        outputDevice:Log(helpMsg)
        CustomAltitude = nil
        local msg = string.format("Unfreeze altitude.")
        log.info(msg)
        outputDevice:Log(msg)
        return true
    end

    local name = table.concat(parameters, " ")
    local altitude = tonumber(options.altitudes_userList[name])
    if type(altitude) ~= "number" then
        outputDevice:Log(string.format("Predefined altitude %q not found or not valid."), name)
        return true
    end

    CustomAltitude = altitude

    local msg = string.format("Set altitude %q: %s.", name, CustomAltitude)
    log.info(msg)
    outputDevice:Log(msg)

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

    local hitActor = GetActorFromHitResult(hitResult)
    if not result or not hitActor:IsA("/Script/Astro.SolarBody") then
        outputDevice:Log("Cannot get altitude.")
        return true
    end

    local msg = string.format("Altitude: %.16g", getVectorLen(hitResult.Location))
    outputDevice:Log(msg)
    log.info(msg)

    return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("altitude_step", function(fullCommand, parameters, outputDevice)
    local helpMsg =
        "Usage: altitude_step <step>\n" ..
        "Example: altitude_step 100\n" ..
        string.format("Current altitude step: %.16g", AltitudeStep)

    if #parameters < 1 then
        outputDevice:Log(helpMsg)
        return true
    end

    local step = tonumber(parameters[1])
    if step == nil then
        outputDevice:Log(helpMsg)
        return true
    end
    AltitudeStep = step


    local msg = string.format("Set altitude step: %.16g", AltitudeStep)
    log.info(msg)
    outputDevice:Log(msg)

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
        outputDevice:Log(string.format(fmt, getStatus()))
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
    local msg = string.format(fmt, getStatus())
    log.info(msg)
    outputDevice:Log(msg)

    return true
end)

---@param fullCommand string
---@param parameters table
---@param outputDevice FOutputDevice
---@return boolean
RegisterConsoleCommandHandler("deform_type", function(fullCommand, parameters, outputDevice)
    local deformTool = FindFirstOf("SmallDeform_TERRAIN_EXPERIMENTAL_C")
    ---@cast deformTool ASmallDeform_TERRAIN_EXPERIMENTAL_C

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

    deformTool.Operation = deformType
    outputDevice:Log(string.format("DeformType is set to %d.", deformType))

    return true
end)
