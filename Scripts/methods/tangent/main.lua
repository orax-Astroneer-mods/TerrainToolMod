local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local sqrt = math.sqrt
local format = string.format

local huge = math.huge -- inf

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
    EDeformType_MAX = 13,
}

local RoundedAltitude = 0
local RootComponent -- 0x160

local PlanetCenter = { X = 0, Y = 0, Z = 0 } ---@type FVector

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
                local hitActor = func.getActorFromHitResult(hitResult)
                if not hitActor:IsValid() or not hitActor:IsA("/Script/Astro.SolarBody") then
                    log.debug("[!!] New hit actor is not a SolarBody.")
                    return
                end
            end

            location = hitResult.Location
        end

        if params.CUSTOM_ALTITUDE ~= huge then
            RoundedAltitude = params.CUSTOM_ALTITUDE
            log.info("Altitude is defined to %.16g.", params.CUSTOM_ALTITUDE)
        else
            assert(type(params.ALTITUDE_STEP) == "number", "ALTITUDE_STEP is not a number.")
            assert(params.ALTITUDE_STEP ~= huge, "ALTITUDE_STEP is not defined.")
            RoundedAltitude = func.roundToBase(func.getVectorLen(location), params.ALTITUDE_STEP)
            log.info("Rounded altitude is %.16g.", RoundedAltitude)
        end
    end

    ---@type FVector
    local u = {
        X = location.X - PlanetCenter.X,
        Y = location.Y - PlanetCenter.Y,
        Z = location.Z - PlanetCenter.Z
    }

    local pointLocationAltitude = sqrt(u.X * u.X + u.Y * u.Y + u.Z * u.Z)

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
    deformTool.RepBrushState.CurrentDeformNormal = angle
    deformTool.RepBrushState.CurrentDeformLocation = u

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

    deformTool.HitLocation = u
    deformTool.HitNormal = angle

    ---@diagnostic enable: inject-field
end

local function writeParamsFile()
    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    -- defaults
    if params.ALTITUDE_STEP == nil then params.ALTITUDE_STEP = 50 end
    if params.CUSTOM_ALTITUDE == nil then params.CUSTOM_ALTITUDE = huge end

    file:write(format(
        [[return {
ALTITUDE_STEP=%.16g,
CUSTOM_ALTITUDE=%.16g
}]],
        params.ALTITUDE_STEP,
        params.CUSTOM_ALTITUDE))

    file:close()
end

local function getInfo()
    return format("Altitude step: %.16g. Custom altitude: %.16g.", params.ALTITUDE_STEP, params.CUSTOM_ALTITUDE)
end

---@type Method__tangent
return {
    params = params,
    handleTerrainTool_hook = handleTerrainTool_hook,
    writeParamsFile = writeParamsFile,
    getInfo = getInfo
}
