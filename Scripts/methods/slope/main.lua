local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local vec3 = Vec3
local sqrt, rad = math.sqrt, math.rad
local format = string.format

-- load PARAMS global table
local paramsFile = func.getParamsFile()
local params = func.loadParamsFile(paramsFile)

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
}

local huge = math.huge
local SlopeDirection = vec3(huge, huge, huge)
local PlanetCenter = { X = 0, Y = 0, Z = 0 } ---@type FVector

---https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Runtime/Engine/Kismet/UKismetMathLibrary/FindLookAtRotation
---@param start vec3
---@param target vec3
---@return FRotator
function vec3.findLookAtRotation(start, target)
    local d = target - start ---@type vec3 direction vector
    local yaw = math.atan(d.y, d.x)

    local d_norm_xOy = math.sqrt(d.x * d.x + d.y * d.y)
    local pitch = math.atan(d.z, d_norm_xOy)

    return { Pitch = math.deg(pitch), Yaw = math.deg(yaw), Roll = 0 }
end

local function setSlopeDirectionFromCamera(reversed)
    log.debug("Set slope direction from camera. Reversed: " .. tostring(reversed) .. ".")
    local pc = UEHelpers.GetPlayerController()
    local cam = pc:GetViewTarget()
    local right = cam:GetActorRightVector()
    local right_unit = vec3.normalize(vec3.new(right.X, right.Y, right.Z))

    if reversed then
        SlopeDirection = -right_unit
    else
        SlopeDirection = right_unit
    end
end

---@param location vec3
---@param normal vec3
local function setSlopeDirectionFromSlope(location, normal)
    log.debug("Set slope direction from slope.")
    SlopeDirection = vec3.cross(location, normal)
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

    -- ignored
    if startedInteraction == false and SlopeDirection.x == huge then return end

    controller = controller:get()
    toolHit = toolHit:get()

    ---@cast controller APlayController
    ---@cast toolHit FHitResult
    -- ---@cast clickResult FClickResult
    ---@cast startedInteraction boolean
    -- ---@cast endedInteraction boolean
    -- ---@cast isUsingTool boolean
    -- ---@cast justActivated boolean
    -- ---@cast canUse boolean

    -- check if the hit actor is a SolarBody (planet)
    if not toolHit.Actor:Get():IsA("/Script/Astro.SolarBody") then ---@diagnostic disable-line: undefined-field
        log.debug("Hit actor is not a SolarBody. Try to get a SolarBody.")

        toolHit = {}
        local result = controller:GetHitResultUnderCursorForObjects({ 6 }, false, toolHit)
        if not result then
            return
        end

        local hitActor = func.getActorFromHitResult(toolHit)
        if not hitActor:IsValid() or not hitActor:IsA("/Script/Astro.SolarBody") then
            log.debug("[!!] New hit actor is not a SolarBody.")
            return
        end
    end

    if startedInteraction == true then
        -- Planet center is (0, 0, 0) for SYLVA.
        PlanetCenter = controller:GetLocalSolarBody():GetCenter()

        local keyName_fromCamera = OPTIONS.set_slope_direction_from_camera_KeyName
        local keyName_fromCamera_reversed = OPTIONS.set_slope_direction_from_camera_reversed_KeyName
        local keyName_fromSlope = OPTIONS.set_slope_direction_from_slope_KeyName

        if keyName_fromCamera and controller:IsInputKeyDown({ KeyName = FName(keyName_fromCamera) }) then
            setSlopeDirectionFromCamera(false)
        elseif keyName_fromCamera_reversed and controller:IsInputKeyDown({ KeyName = FName(keyName_fromCamera_reversed) }) then
            setSlopeDirectionFromCamera(true)
        elseif keyName_fromSlope and controller:IsInputKeyDown({ KeyName = FName(keyName_fromSlope) }) then
            setSlopeDirectionFromSlope(
                vec3.new(
                    toolHit.Location.X - PlanetCenter.X,
                    toolHit.Location.Y - PlanetCenter.Y,
                    toolHit.Location.Z - PlanetCenter.Z),
                vec3.new(
                    toolHit.Normal.X,
                    toolHit.Normal.Y,
                    toolHit.Normal.Z)
            )
        else
            if keyName_fromCamera or keyName_fromCamera_reversed or keyName_fromSlope then
                SlopeDirection = vec3.new(huge, huge, huge)
                log.debug("Slope is not modified.")
                return
            end
        end
    end

    ---@type FVector
    local u = {
        X = toolHit.Location.X - PlanetCenter.X,
        Y = toolHit.Location.Y - PlanetCenter.Y,
        Z = toolHit.Location.Z - PlanetCenter.Z
    }

    local altitude = sqrt(u.X * u.X + u.Y * u.Y + u.Z * u.Z)

    -- normalize the vector
    local u_unit = {
        X = u.X / altitude,
        Y = u.Y / altitude,
        Z = u.Z / altitude
    }

    local v = vec3.rotate(vec3.new(u_unit.X, u_unit.Y, u_unit.Z), rad(params.SLOPE_ANGLE), SlopeDirection)

    u_unit = { X = v.x, Y = v.y, Z = v.z }

    -- RepBrushState (0x804)
    deformTool.RepBrushState.CurrentDeformNormal = u_unit

    ---@diagnostic disable: inject-field

    -- LocalBrushState (0x838)
    deformTool.LocalBrushStateNormalX = u_unit.X
    deformTool.LocalBrushStateNormalY = u_unit.Y
    deformTool.LocalBrushStateNormalZ = u_unit.Z

    -- DeformActionStartNormal (0x8CC)
    deformTool.DeformActionStartNormalX = u_unit.X
    deformTool.DeformActionStartNormalY = u_unit.Y
    deformTool.DeformActionStartNormalZ = u_unit.Z

    deformTool.HitNormal = u_unit

    ---@diagnostic enable: inject-field
end

local function writeParamsFile()
    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    -- defaults
    if params.SLOPE_ANGLE == nil then params.SLOPE_ANGLE = 45 end

    file:write(format(
        [[return {
SLOPE_ANGLE=%.16g
}]],
        params.SLOPE_ANGLE))

    file:close()
end

---@return string
local function getInfo()
    return format("Slope angle: %.16g.", params.SLOPE_ANGLE)
end

---@type Method__slop
return {
    params = params,
    handleTerrainTool_hook = handleTerrainTool_hook,
    writeParamsFile = writeParamsFile,
    getInfo = getInfo
}
