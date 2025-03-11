local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local vec3 = Vec3
local insert = table.insert
local format = string.format

---@class Debug
---@field staticMeshActorClassShortName string
---@field staticMeshActorClassName string
---@field staticMeshActorClass UClass?
---@field material UMaterialInterface?
---@field mesh UStaticMesh?
---@field scale FVector
local debug = {
    staticMeshActorClassShortName = "StaticMeshActor",
    staticMeshActorClassName = "/Script/Engine.StaticMeshActor",
    staticMeshActorClass = nil,
    material = nil,
    mesh = nil,
    scale = { X = 0.1, Y = 0.1, Z = 0.1 }
}

-- load PARAMS global table
local paramsFile = func.getParamsFile()
local params = func.loadParamsFile(paramsFile) ---@type Method__Smoothen__PARAMS

local sys = UEHelpers.GetKismetSystemLibrary()
local LineTraceSingleForObjects = sys.LineTraceSingleForObjects
local world = UEHelpers:GetWorld()

local pi2 = math.pi * 2

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
        return vec3.new(1, 0, 0)
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

    controller = controller:get()
    toolHit = toolHit:get()
    startedInteraction = startedInteraction:get()

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
        world = UEHelpers:GetWorld()
    end

    -- for debugging
    local dbgObject = params.DEBUG_OBJECTS and startedInteraction

    local start = vec3.new(toolHit.Location.X, toolHit.Location.Y, toolHit.Location.Z)
    local normal = vec3.new(toolHit.Normal.X, toolHit.Normal.Y, toolHit.Normal.Z)
    local direction = vec3.new(-normal.x, -normal.y, -normal.z)
    local perp = vec3.normalize(perpendicular(normal))

    local normals = {} ---@type FVector[]
    local locations = {} ---@type FVector[]

    insert(normals, toolHit.Normal)

    if dbgObject then
        local dbgObjectsInst = FindAllOf(debug.staticMeshActorClassShortName) ---@type AActor[]?
        if dbgObjectsInst then
            for _, value in ipairs(dbgObjectsInst) do
                value:K2_DestroyActor()
            end
        end

        func.spawnDebugObject(world, debug.staticMeshActorClass, debug.mesh, debug.material, toolHit.Location,
            nil, debug.scale, { R = 50, G = 0, B = 0, A = 1 })
    end

    local color = { R = 0, G = 0, B = 0, A = 0 }
    local brushScale = deformTool.BaseBrushIndicatorScale * deformTool.BaseBrushDeformationScale

    for _, circle in ipairs(params.CIRCLES) do
        local numberOfHits = circle.HITS
        local stepAngle = pi2 / numberOfHits

        for i = 0, numberOfHits - 1, 1 do
            -- deformTool.BaseBrush... works only in Adventure mode.
            local scaledPerp = vec3.scale(perp, brushScale * circle.RADIUS)

            P = vec3.add(start, scaledPerp)
            local startP = P - start

            local angle = i * stepAngle
            local r = vec3.rotate(startP, angle, normal) + start

            -- determine max offset
            local maxOffset = params.MAX_OFFSET
            local endPoint = r + vec3.scale(normal, maxOffset) ---@type vec3

            ---@diagnostic disable-next-line: missing-fields
            local hit = {} ---@type FHitResult
            LineTraceSingleForObjects(sys,
                world, { X = r.x, Y = r.y, Z = r.z },
                { X = endPoint.x, Y = endPoint.y, Z = endPoint.z }, { 6 }, false, {}, 0,
                hit, true, color, color, 0)

            -- If there is a hit, set the max offset to the distance of the hit.
            if hit.Distance > 0 then
                maxOffset = hit.Distance
            end

            r = r + vec3.scale(normal, maxOffset)
            local lineTraceLength = maxOffset + params.TRACE_LENGTH
            endPoint = vec3.add(vec3.scale(vec3.normalize(direction), lineTraceLength), r)

            if dbgObject then
                local c = { R = 50, G = 0, B = 50, A = 1.0 } ---@type FLinearColor
                if hit.Distance ~= 0 then
                    c = { R = 0, G = 50, B = 0, A = 1.0 }
                end
                func.spawnDebugObject(world, debug.staticMeshActorClass, debug.mesh, debug.material,
                    { X = r.x, Y = r.y, Z = r.z },
                    nil, debug.scale, c)
            end

            ---@diagnostic disable-next-line: missing-fields
            local outHit = {} ---@type FHitResult
            LineTraceSingleForObjects(sys,
                world, { X = r.x, Y = r.y, Z = r.z },
                { X = endPoint.x, Y = endPoint.y, Z = endPoint.z }, { 6 }, false, {}, 0,
                outHit, true, color, color, 0)

            if dbgObject then
                func.spawnDebugObject(world, debug.staticMeshActorClass, debug.mesh, debug.material,
                    outHit.Location,
                    nil, debug.scale, { R = 0, G = 0, B = 50, A = 1.0 })
            end

            if outHit.Normal.X ~= 0 or outHit.Normal.Y ~= 0 or outHit.Normal.Z ~= 0 then
                insert(normals, outHit.Normal)
            end
            if outHit.Location.X ~= 0 or outHit.Location.Y ~= 0 or outHit.Location.Z ~= 0 then
                insert(locations, outHit.Location)
            end
        end
    end

    ---@diagnostic disable: inject-field

    if #normals > 0 then
        local x_norm, y_norm, z_norm = 0, 0, 0
        for _, normal in ipairs(normals) do
            x_norm = x_norm + normal.X
            y_norm = y_norm + normal.Y
            z_norm = z_norm + normal.Z
        end
        x_norm = x_norm / #normals
        y_norm = y_norm / #normals
        z_norm = z_norm / #normals

        -- RepBrushState (0x804)
        deformTool.RepBrushState.CurrentDeformNormal = { X = x_norm, Y = y_norm, Z = z_norm }

        -- LocalBrushState (0x838)
        deformTool.LocalBrushStateNormalX = x_norm
        deformTool.LocalBrushStateNormalY = y_norm
        deformTool.LocalBrushStateNormalZ = z_norm

        -- DeformActionStartNormal (0x8CC)
        deformTool.DeformActionStartNormalX = x_norm
        deformTool.DeformActionStartNormalY = y_norm
        deformTool.DeformActionStartNormalZ = z_norm

        deformTool.HitNormal = { X = x_norm, Y = y_norm, Z = z_norm }
    end

    if #locations > 0 then
        local x_loc, y_loc, z_loc = 0, 0, 0
        for _, loc in ipairs(locations) do
            x_loc = x_loc + loc.X
            y_loc = y_loc + loc.Y
            z_loc = z_loc + loc.Z
        end
        x_loc = x_loc / #locations
        y_loc = y_loc / #locations
        z_loc = z_loc / #locations

        -- RepBrushState (0x804)
        deformTool.RepBrushState.CurrentDeformLocation = { X = x_loc, Y = y_loc, Z = z_loc }

        -- LocalBrushState (0x838)
        deformTool.LocalBrushStateLocationX = x_loc
        deformTool.LocalBrushStateLocationY = y_loc
        deformTool.LocalBrushStateLocationZ = z_loc

        -- DeformActionStartLocation (0x8C0)
        deformTool.DeformActionStartLocationX = x_loc
        deformTool.DeformActionStartLocationY = y_loc
        deformTool.DeformActionStartLocationZ = z_loc

        -- DeformLaggedLocation (0x8D8)
        deformTool.DeformLaggedLocationX = x_loc
        deformTool.DeformLaggedLocationY = y_loc
        deformTool.DeformLaggedLocationZ = z_loc

        deformTool.HitLocation = { X = x_loc, Y = y_loc, Z = z_loc }
    end

    ---@diagnostic enable: inject-field

    if dbgObject then
        if #normals > 0 and #locations > 0 then
            local x_loc, y_loc, z_loc = 0, 0, 0
            for _, loc in ipairs(locations) do
                x_loc = x_loc + loc.X
                y_loc = y_loc + loc.Y
                z_loc = z_loc + loc.Z
            end
            x_loc = x_loc / #locations
            y_loc = y_loc / #locations
            z_loc = z_loc / #locations

            local x_norm, y_norm, z_norm = 0, 0, 0
            for _, normal in ipairs(normals) do
                x_norm = x_norm + normal.X
                y_norm = y_norm + normal.Y
                z_norm = z_norm + normal.Z
            end
            x_norm = x_norm / #normals
            y_norm = y_norm / #normals
            z_norm = z_norm / #normals

            -- new normal
            for i = 50, 500, 50 do
                func.spawnDebugObject(world, debug.staticMeshActorClass, debug.mesh, debug.material,
                    { X = x_loc + x_norm * i, Y = y_loc + y_norm * i, Z = z_loc + z_norm * i },
                    nil, debug.scale, { R = 1, G = 1, B = 1, A = 0.1 })
            end
        end
    end
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

local function init()
    world = UEHelpers:GetWorld()

    if params.DEBUG_OBJECTS == true then
        ExecuteInGameThread(function()
            --[[
        Open FModel, go in Engine > Content > EngineDebugMaterials

        "/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"
        "/Engine/EngineDebugMaterials/WireframeMaterial.WireframeMaterial" -- Params: Color (wireframe, emissive).
        "/Engine/EngineDebugMaterials/DebugMeshMaterial.DebugMeshMaterial" -- Params: Color (emissive).
        "/Engine/EngineDebugMaterials/DebugEditorMaterial.DebugEditorMaterial" -- Params: Color, Desaturation, Opacity (emissive).
        "/Engine/EngineDebugMaterials/M_SimpleTranslucent.M_SimpleTranslucent" -- Params: Color (translucent).
        "/Engine/EngineMaterials/EmissiveTexturedMaterial.EmissiveTexturedMaterial" -- Params: Texture.
        "/Engine/EngineMaterials/WorldGridMaterial.WorldGridMaterial" -- Params: None.
        ]]
            local mat = "/Engine/EngineDebugMaterials/DebugMeshMaterial.DebugMeshMaterial"
            LoadAsset(mat) ---@diagnostic disable-line: undefined-global

            -- Cone, Cube, Cylinder, Plane, Sphere
            local mesh = "/Engine/BasicShapes/Sphere.Sphere"
            LoadAsset(mesh) ---@diagnostic disable-line: undefined-global

            debug.staticMeshActorClass = StaticFindObject(debug.staticMeshActorClassName) ---@diagnostic disable-line: assign-type-mismatch
            debug.material = StaticFindObject(mat) ---@diagnostic disable-line: assign-type-mismatch
            debug.mesh = StaticFindObject(mesh) ---@diagnostic disable-line: assign-type-mismatch
        end)
    end
end

ExecuteWithDelay(5000, function()
    ---@param self RemoteUnrealParam
    ---@param NewPawn RemoteUnrealParam
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
        init()
    end)
end)

init()

---@type Method__Smoothen
return {
    params = params,
    handleTerrainTool_hook = handleTerrainTool_hook,
    writeParamsFile = writeParamsFile,
    getInfo = getInfo
}
