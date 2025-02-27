local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local vec3 = Vec3
local sqrt, rad = math.sqrt, math.rad
local insert = table.insert
local format = string.format

-- load PARAMS global table
local paramsFile = func.getParamsFile()
local params = func.loadParamsFile(paramsFile)


local sys = UEHelpers.GetKismetSystemLibrary()
local LineTraceSingleForObjects = sys.LineTraceSingleForObjects
local world = CreateInvalidObject()

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

--- Get the perpendicular vector of a vector.
---@param a vec3 Vector to get perpendicular axes from
---@return vec3 out
local function perpendicular(a)
    if a.x ~= 0 or a.y ~= 0 then
        return vec3.new(-a.y, a.x, 0)
    else
        return vec3.new(a.z, 0, a.z)
    end
end

---@param self any
---@param controller any
---@param toolHit any
---@param clickResult any
---@param startedInteraction any
---@param endedInteraction any
---@param isUsingTool any
---@param justActivated any
---@param canUse any
local function handleTerrainTool_hook(self, controller, toolHit, clickResult, startedInteraction, endedInteraction,
                                      isUsingTool, justActivated, canUse)
    if isUsingTool:get() == false then
        return
    end

    if canUse:get() == false then
        return
    end

    local deformTool = self:get() ---@diagnostic disable-line: undefined-field
    ---@cast deformTool ASmallDeform_TERRAIN_EXPERIMENTAL_C

    -- check if a flatten operation is selected
    local operation = deformTool.Operation
    if operation ~= DeformType.Flatten and
        operation ~= DeformType.FlattenAddOnly and
        operation ~= DeformType.FlattenSubtractOnly and
        operation ~= DeformType.ColorPick then
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

    if startedInteraction == true then
        local playerController = UEHelpers:GetPlayerController() ---@cast playerController APlayControllerInstance_C
        if not playerController:IsValid() then
            log.warn("PlayerController invalid.")
        end

        world = UEHelpers:GetWorld()

        -- check if the hit actor is a SolarBody (planet)
        local actor = toolHit.Actor:Get() ---@diagnostic disable-line: undefined-field
        if not actor:IsA("/Script/Astro.SolarBody") then
            log.debug("Hit actor is not a SolarBody. Try to get a SolarBody.")

            toolHit = {}

            local result = playerController:GetHitResultUnderCursorForObjects({ 6 }, false, toolHit)
            if result then
                local hitActor = func.getActorFromHitResult(toolHit)
                if not hitActor:IsValid() or not hitActor:IsA("/Script/Astro.SolarBody") then
                    log.debug("[!!] New hit actor is not a SolarBody.")
                    return
                end
            end
        end
    end

    -- local dbgcube = startedInteraction
    -- local cubeactor, cuberot, cubeloc, cubeclass

    local radiusScale = 1
    local startOffset = 100

    local Location = vec3.new(toolHit.Location.X, toolHit.Location.Y, toolHit.Location.Z)
    local Normal = vec3.new(toolHit.Normal.X, toolHit.Normal.Y, toolHit.Normal.Z)
    local direction = vec3.new(-Normal.x, -Normal.y, -Normal.z)
    local perp = vec3.normalize(perpendicular(Normal))

    perp = vec3.scale(perp, deformTool.BaseBrushIndicatorScale * deformTool.BaseBrushDeformationScale * radiusScale)

    local normals = {} ---@type FVector[]
    local locations = {} ---@type FVector[]

    insert(normals, toolHit.Normal)

    local start = Location + vec3.scale(Normal, startOffset)
    local P = vec3.add(start, perp)
    local startP = P - start

    -- Cube (debug)
    -- if dbgcube then
    --     local cubes = FindAllOf("Cube_BP_C") ---@type AActor[]?
    --     if cubes then
    --         for _, value in ipairs(cubes) do
    --             value:K2_DestroyActor()
    --         end
    --     end
    --     local cubeclassName = "/Game/Mods/orax/CubeMod/Cube_BP.Cube_BP_C"
    --     cubeclass = StaticFindObject(cubeclassName)
    --     assert(cubeclass:IsValid())
    --     cubeloc = { X = toolHit.Location.X, Y = toolHit.Location.Y, Z = toolHit.Location.Z } ---@type FVector
    --     cuberot = { Pitch = 0, Roll = 0, Yaw = 0 } ---@type FRotator
    --     ---@diagnostic disable-next-line: undefined-field
    --     cubeactor = world:SpawnActor(cubeclass, cubeloc, cuberot) ---@type AActor
    --     cubeactor:SetActorScale3D({ X = 0.2, Y = 0.2, Z = 0.2 })
    --     cubeactor:SetActorEnableCollision(false)
    -- end

    local numberOfHits = 16
    local numberOfCircles = 2
    local lineTraceLength = startOffset + 300
    local numberOfHitsModifier = 0

    local color = { A = 0, B = 0, G = 0, R = 0 }

    for j = 1, numberOfCircles, 2 do
        numberOfHits = numberOfHits + numberOfHitsModifier
        if numberOfHits <= 0 then
            break
        end

        local stepAngle = 360 / numberOfHits
        for i = 0, numberOfHits - 1, 1 do
            P = vec3.add(start, vec3.scale(perp, 1 / j))
            startP = P - start

            local angle = i * stepAngle
            local r = vec3.rotate(startP, math.rad(angle), Normal)
            r = vec3.add(start, r)
            local endPoint = vec3.add(vec3.scale(vec3.normalize(direction), lineTraceLength), r)

            -- if dbgcube then
            --     cubeloc = { X = r.x, Y = r.y, Z = r.z } ---@type FVector
            --     ---@diagnostic disable-next-line: undefined-field
            --     cubeactor = world:SpawnActor(cubeclass, cubeloc, cuberot) ---@type AActor
            --     cubeactor:SetActorScale3D({ X = 0.1, Y = 0.1, Z = 0.1 })
            --     cubeactor:SetActorEnableCollision(false)
            -- end

            ---@diagnostic disable-next-line: missing-fields
            local outHit = {} ---@type FHitResult
            LineTraceSingleForObjects(sys,
                world, { X = r.x, Y = r.y, Z = r.z },
                { X = endPoint.x, Y = endPoint.y, Z = endPoint.z }, { 6 }, false, {}, 0,
                outHit, true, color, color, 0)

            -- if dbgcube then
            --     cubeloc = { X = outHit.Location.X, Y = outHit.Location.Y, Z = outHit.Location.Z } ---@type FVector
            --     ---@diagnostic disable-next-line: undefined-field
            --     cubeactor = world:SpawnActor(cubeclass, cubeloc, cuberot) ---@type AActor
            --     cubeactor:SetActorScale3D({ X = 0.2, Y = 0.2, Z = 0.2 })
            --     cubeactor:SetActorEnableCollision(false)
            -- end

            if outHit.Normal.X ~= 0 or outHit.Normal.Y ~= 0 or outHit.Normal.Z ~= 0 then
                insert(normals, outHit.Normal)
            end
            if outHit.Location.X ~= 0 or outHit.Location.Y ~= 0 or outHit.Location.Z ~= 0 then
                insert(locations, outHit.Location)
            end
        end
    end

    local x_norm, y_norm, z_norm = 0, 0, 0
    for _, normal in ipairs(normals) do
        x_norm = x_norm + normal.X
        y_norm = y_norm + normal.Y
        z_norm = z_norm + normal.Z
    end
    x_norm = x_norm / #normals
    y_norm = y_norm / #normals
    z_norm = z_norm / #normals

    local x_loc, y_loc, z_loc = 0, 0, 0
    for _, loc in ipairs(locations) do
        x_loc = x_loc + loc.X
        y_loc = y_loc + loc.Y
        z_loc = z_loc + loc.Z
    end
    x_loc = x_loc / #locations
    y_loc = y_loc / #locations
    z_loc = z_loc / #locations

    -- if dbgcube then
    --     ---@diagnostic disable-next-line: undefined-field
    --     cubeactor = world:SpawnActor(cubeclass, { X = x_loc, Y = y_loc, Z = z_loc }, {})
    --     cubeactor:SetActorScale3D({ X = 0.1, Y = 0.1, Z = 0.1 })
    --     cubeactor:SetActorEnableCollision(false)
    --     cuberot = { Pitch = 0, Roll = 0, Yaw = 0 } ---@type FRotator
    --     for i = 100, 1000, 100 do
    --         ---@diagnostic disable-next-line: undefined-field
    --         cubeactor = world:SpawnActor(cubeclass,
    --             { X = x_loc + x_norm * i, Y = y_loc + y_norm * i, Z = z_loc + z_norm * i },
    --             cuberot) ---@type AActor

    --         cubeactor:SetActorScale3D({ X = 0.1, Y = 0.1, Z = 0.1 })
    --         cubeactor:SetActorEnableCollision(false)
    --     end
    -- end

    -- -- RepBrushState (0x804)
    deformTool.RepBrushState.CurrentDeformNormal = { X = x_norm, Y = y_norm, Z = z_norm }
    deformTool.RepBrushState.CurrentDeformLocation = { X = x_loc, Y = y_loc, Z = z_loc }

    ---@diagnostic disable: inject-field

    -- LocalBrushState (0x838)
    deformTool.LocalBrushStateNormalX = x_norm
    deformTool.LocalBrushStateNormalY = y_norm
    deformTool.LocalBrushStateNormalZ = z_norm
    deformTool.LocalBrushStateLocationX = x_loc
    deformTool.LocalBrushStateLocationY = y_loc
    deformTool.LocalBrushStateLocationZ = z_loc

    -- -- DeformActionStartLocation (0x8C0)
    deformTool.DeformActionStartLocationX = x_loc
    deformTool.DeformActionStartLocationY = y_loc
    deformTool.DeformActionStartLocationZ = z_loc

    -- -- DeformActionStartNormal (0x8CC)
    deformTool.DeformActionStartNormalX = x_norm
    deformTool.DeformActionStartNormalY = y_norm
    deformTool.DeformActionStartNormalZ = z_norm

    -- -- DeformLaggedLocation (0x8D8)
    deformTool.DeformLaggedLocationX = x_loc
    deformTool.DeformLaggedLocationY = y_loc
    deformTool.DeformLaggedLocationZ = z_loc

    deformTool.HitLocation = { X = x_loc, Y = y_loc, Z = z_loc }
    deformTool.HitNormal = { X = x_norm, Y = y_norm, Z = z_norm }

    ---@diagnostic enable: inject-field
end

local function writeParamsFile()
    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    file:write(
        [[return {
}]])

    file:close()
end

---@return string
local function getInfo()
    return ""
end

---@type Method__Smoothen
return {
    params = params,
    handleTerrainTool_hook = handleTerrainTool_hook,
    writeParamsFile = writeParamsFile,
    getInfo = getInfo
}
