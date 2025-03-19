local methodName = "smoothen"

local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local vec3 = Vec3
local insert = table.insert
local format = string.format

local writeParamsFile = function() end
local updateUI = function() end

-- load PARAMS from "paint" method
local paramsFile_paint = func.getParamsFile("paint")
local params_paint = func.loadParamsFile(paramsFile_paint) ---@type Method__Paint__PARAMS

local DebugObjects = {} ---@type AStaticMeshActor[]
local PaintTerrain = false

---@class Debug
---@field staticMeshActorClassShortName string
---@field staticMeshActorClassName string
---@field staticMeshActorClass UClass?
---@field material UMaterialInterface?
---@field mesh UStaticMesh?
---@field scale FVector
---@field meshClassName string
---@field matClassName string
local dbg = {
    staticMeshActorClassShortName = "StaticMeshActor",
    staticMeshActorClassName = "/Script/Engine.StaticMeshActor",
    staticMeshActorClass = nil,
    material = nil,
    mesh = nil,
    scale = { X = 0.1, Y = 0.1, Z = 0.1 },
    --[[ Cone, Cube, Cylinder, Plane, Sphere ]]
    meshClassName = "/Engine/BasicShapes/Sphere.Sphere",
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
    matClassName = "/Engine/EngineDebugMaterials/DebugMeshMaterial.DebugMeshMaterial"
}

local options = OPTIONS
local optUI = OPTIONS_UI
local UI = {
    presetsComboBox = nil ---@type UComboBoxString
}
local Presets, PresetNamesList = {}, {}
local CurrentPreset ---@type Method__Smoothen__PRESET
local CurrentPresetName = "" ---@type string

local utils = require("lib.lua-mods-libs.utils")

local currentModDirectory = debug.getinfo(1, "S").source:match("@?(.+\\Mods\\[^\\]+)")

-- load PARAMS global table
local paramsFile = func.getParamsFile()
local params = func.loadParamsFile(paramsFile) ---@type Method__Smoothen__PARAMS

local sys = UEHelpers.GetKismetSystemLibrary()
local LineTraceSingleForObjects = sys.LineTraceSingleForObjects
local World = UEHelpers:GetWorld()

local pi2 = math.pi * 2

---@type ESlateVisibility
local ESlateVisibility = {
    Visible = 0,
    Collapsed = 1,
    Hidden = 2,
    HitTestInvisible = 3,
    SelfHitTestInvisible = 4,
    ESlateVisibility_MAX = 5
}

---@type ECheckBoxState
local ECheckBoxState = {
    Unchecked    = 0,
    Checked      = 1,
    Undetermined = 2,
}

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
    if isUsingTool:get() == false or canUse:get() == false then
        return
    end

    local deformTool = self:get() ---@cast deformTool ASmallDeform_TERRAIN_EXPERIMENTAL_C
    controller = controller:get() ---@cast controller APlayController
    toolHit = toolHit:get() ---@cast toolHit FHitResult
    startedInteraction = startedInteraction:get() ---@cast startedInteraction boolean

    local operation = deformTool.Operation

    if startedInteraction then
        PaintTerrain = UI.paintCheckBox:GetCheckedState() == ECheckBoxState.Checked
    end

    -- paint terrain
    if PaintTerrain == true and
        operation ~= EDeformType.Subtract and
        operation ~= EDeformType.ColorPick and
        operation ~= EDeformType.Crater and
        operation ~= EDeformType.RevertModifications then
        controller:ClientDoDeformation({
            AutoCreateResourceEfficiency = 0,
            CreativeModeNoResourceCollection = false,
            DeltaTime = 0.03299999982118, -- ???
            ForceRemoveDecorators = false,
            HardnessPenetration = 0,
            Instigator = nil,
            Intensity = 0,
            Location = { X = toolHit.Location.X, Y = toolHit.Location.Y, Z = toolHit.Location.Z },
            MaterialIndex = params_paint.MATERIAL_INDEX,
            Normal = { X = toolHit.Normal.X, Y = toolHit.Normal.Y, Z = toolHit.Normal.Z },
            Operation = EDeformType.ColorPaint,
            Scale = deformTool.BaseBrushIndicatorScale * deformTool.BaseBrushDeformationScale * params_paint.SCALE,
            SequenceNumber = 0,
            Shape = 0,
            bEasyUnbury = false,
            bUseAlternatePolygonization = true
        })
    end

    -- check if a flatten operation is selected
    if operation ~= EDeformType.Flatten and
        operation ~= EDeformType.FlattenAddOnly and
        operation ~= EDeformType.FlattenSubtractOnly and
        operation ~= EDeformType.ColorPick then
        return
    end

    -- check if the hit actor is a SolarBody (planet)
    if not toolHit.Actor:Get():IsA("/Script/Astro.SolarBody") then ---@diagnostic disable-line: undefined-field
        -- Hit actor is not a SolarBody. Try to get a SolarBody.

        toolHit = {}
        local result = controller:GetHitResultUnderCursorForObjects({ 6 }, false, toolHit)
        if not result then
            log.debug("[!!] No hit actor. There is no SolarBody under the cursor.")
            return
        end

        local hitActor = func.getActorFromHitResult(toolHit)
        if not hitActor:IsValid() or not hitActor:IsA("/Script/Astro.SolarBody") then
            log.debug("[!!] New hit actor is not a SolarBody.")
            return
        end
    end

    if startedInteraction == true then
        World = UEHelpers:GetWorld()

        -- select preset
        CurrentPresetName = UI.presetsComboBox:GetSelectedOption():ToString()
        if CurrentPresetName == "" then
            log.warn("No preset found.")
            return
        end
        CurrentPreset = Presets[CurrentPresetName]
        if CurrentPresetName ~= "" and params.LAST_PRESET ~= CurrentPresetName then
            params.LAST_PRESET = CurrentPresetName
            updateUI()
            writeParamsFile()
        end

        local isDebugChecked = UI.debugCheckBox:GetCheckedState() == ECheckBoxState.Checked
        if params.DEBUG_OBJECTS ~= isDebugChecked then
            params.DEBUG_OBJECTS = isDebugChecked
            writeParamsFile()

            -- destroy debug objects
            for _, object in ipairs(DebugObjects) do
                if object and object:IsValid() then
                    object:K2_DestroyActor()
                end
            end
        end
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
        -- destroy debug objects
        for _, object in ipairs(DebugObjects) do
            if object and object:IsValid() then
                object:K2_DestroyActor()
            end
        end

        table.insert(DebugObjects,
            func.spawnDebugObject(World, dbg.staticMeshActorClass, dbg.mesh, dbg.material, toolHit.Location,
                nil, dbg.scale, { R = 50, G = 0, B = 0, A = 1 }))
    end

    local color = { R = 0, G = 0, B = 0, A = 0 }
    local brushScale = deformTool.BaseBrushIndicatorScale * deformTool.BaseBrushDeformationScale

    for _, circle in ipairs(CurrentPreset.CIRCLES) do
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
            local maxOffset = CurrentPreset.MAX_OFFSET
            local endPoint = r + vec3.scale(normal, maxOffset) ---@type vec3

            ---@diagnostic disable-next-line: missing-fields
            local hit = {} ---@type FHitResult
            LineTraceSingleForObjects(sys,
                World, { X = r.x, Y = r.y, Z = r.z },
                { X = endPoint.x, Y = endPoint.y, Z = endPoint.z }, { 6 }, false, {}, 0,
                hit, true, color, color, 0)

            -- If there is a hit, set the max offset to the distance of the hit.
            if hit.Distance > 0 then
                maxOffset = hit.Distance
            end

            r = r + vec3.scale(normal, maxOffset)
            local lineTraceLength = maxOffset + CurrentPreset.TRACE_LENGTH
            endPoint = vec3.add(vec3.scale(vec3.normalize(direction), lineTraceLength), r)

            if dbgObject then
                local c = { R = 50, G = 0, B = 50, A = 1.0 } ---@type FLinearColor
                if hit.Distance ~= 0 then
                    c = { R = 0, G = 50, B = 0, A = 1.0 }
                end
                table.insert(DebugObjects,
                    func.spawnDebugObject(World, dbg.staticMeshActorClass, dbg.mesh, dbg.material,
                        { X = r.x, Y = r.y, Z = r.z },
                        nil, dbg.scale, c))
            end

            ---@diagnostic disable-next-line: missing-fields
            local outHit = {} ---@type FHitResult
            LineTraceSingleForObjects(sys,
                World, { X = r.x, Y = r.y, Z = r.z },
                { X = endPoint.x, Y = endPoint.y, Z = endPoint.z }, { 6 }, false, {}, 0,
                outHit, true, color, color, 0)

            if dbgObject then
                table.insert(DebugObjects,
                    func.spawnDebugObject(World, dbg.staticMeshActorClass, dbg.mesh, dbg.material,
                        outHit.Location,
                        nil, dbg.scale, { R = 0, G = 0, B = 50, A = 1.0 }))
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
        for _, n in ipairs(normals) do
            x_norm = x_norm + n.X
            y_norm = y_norm + n.Y
            z_norm = z_norm + n.Z
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
                table.insert(DebugObjects,
                    func.spawnDebugObject(World, dbg.staticMeshActorClass, dbg.mesh, dbg.material,
                        { X = x_loc + x_norm * i, Y = y_loc + y_norm * i, Z = z_loc + z_norm * i },
                        nil, dbg.scale, { R = 1, G = 1, B = 1, A = 0.1 }))
            end
        end
    end
end

---@return Method__Smoothen__PRESET[]
---@return table
local function loadAllPresets()
    ---@type string[]
    local fileList = utils.getFileList(currentModDirectory .. "\\Scripts\\methods\\" .. methodName .. "\\presets\\",
        ".lua")
    local presets = {}
    local presetNamesList = {}

    for index, file in ipairs(fileList) do
        local presetName = file:match("([^\\]+)[.]lua$")
        table.insert(presetNamesList, presetName)

        local presetTable = {
            index = index
        }

        local preset = dofile(file)

        for key, value in pairs(preset) do
            presetTable[key] = value
        end

        presets[presetName] = presetTable
    end

    return presets, presetNamesList
end

updateUI = function()
    if not UI.presetsComboBox:IsValid() then
        return
    end

    local index = UI.presetsComboBox:GetSelectedIndex()
    Presets, PresetNamesList = loadAllPresets()
    UI.presetsComboBox:ClearOptions()

    -- add presets to ComboBox
    for _, preset in ipairs(PresetNamesList) do
        UI.presetsComboBox:AddOption(preset)
    end

    if index == -1 then
        index = 0
    end
    UI.presetsComboBox:SetSelectedIndex(index)
end

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createUI()
    local prefix = "TerrainMod_smoothen_"

    local gameInstance = UEHelpers.GetGameInstance()
    if not gameInstance:IsValid() then
        return false
    end

    local fontObj = StaticFindObject("/Game/UI/fonts/NDAstroneer-Regular_Font.NDAstroneer-Regular_Font")

    ---@diagnostic disable: param-type-mismatch, assign-type-mismatch

    ---@type UUserWidget
    UI.userWidget = StaticConstructObject(StaticFindObject("/Script/UMG.UserWidget"), gameInstance,
        FName(prefix .. "UserWidget"))
    assert(UI.userWidget:IsValid())

    UI.userWidget.WidgetTree = StaticConstructObject(StaticFindObject("/Script/UMG.WidgetTree"), UI.userWidget,
        FName(prefix .. "WidgetTree"))
    assert(UI.userWidget.WidgetTree:IsValid())

    ---@type UCanvasPanel
    UI.canvas = StaticConstructObject(StaticFindObject("/Script/UMG.CanvasPanel"),
        UI.userWidget.WidgetTree, FName(prefix .. "CanvasPanel"))
    assert(UI.canvas:IsValid())
    UI.userWidget.WidgetTree.RootWidget = UI.canvas

    local rootWidget = UI.userWidget.WidgetTree.RootWidget

    ---@type UVerticalBox
    local verticalBox = StaticConstructObject(StaticFindObject("/Script/UMG.VerticalBox"),
        rootWidget, FName(prefix .. "VerticalBox"))

    ---@type UTextBlock
    local textBlock_title = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_title"))
    textBlock_title.Font.Size = optUI.smoothen.font_size
    textBlock_title.Font.FontObject = fontObj
    textBlock_title:SetText(FText(optUI.smoothen.txt.title))
    textBlock_title:SetToolTipText(FText(optUI.smoothen.txt.description_tip))

    ---@type UComboBoxString
    UI.presetsComboBox = StaticConstructObject(StaticFindObject("/Script/UMG.ComboBoxString"),
        rootWidget, FName(prefix .. "ComboBoxString_presets"))
    UI.presetsComboBox.Font.FontObject = fontObj
    UI.presetsComboBox:SetToolTipText(FText(format(optUI.smoothen.txt.presetsComboBox_tip,
        func.getKeybindName(options.enable_handleTerrainTool_Key, options.enable_handleTerrainTool_ModifierKeys))))

    ---@type UHorizontalBox
    local horizontalBox = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox"))
    horizontalBox:SetToolTipText(FText(optUI.smoothen.txt.debug_tip))

    ---@type UTextBlock
    local textBlock = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_debug"))
    textBlock.Font.Size = optUI.smoothen.font_size
    textBlock.Font.FontObject = fontObj
    textBlock:SetText(FText(optUI.smoothen.txt.debug))

    ---@type USpacer
    local spacer = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer"))
    spacer:SetSize(optUI.smoothen.spacer_size)

    ---@type UCheckBox
    UI.debugCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_debug"))
    UI.debugCheckBox:SetCheckedState(params.DEBUG_OBJECTS == true and ECheckBoxState.Checked or ECheckBoxState.Unchecked)

    horizontalBox:AddChildToHorizontalBox(textBlock)
    horizontalBox:AddChildToHorizontalBox(spacer)
    horizontalBox:AddChildToHorizontalBox(UI.debugCheckBox)

    --#region paint
    ---@type UHorizontalBox
    local horizontalBox_paint = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_paint"))
    horizontalBox_paint:SetToolTipText(FText(format(optUI["*"].txt.paint_tip,
        func.getKeybindName(options.set_paint_method_Key, options.set_paint_method_ModifierKeys))))

    ---@type UTextBlock
    local textBlock_paint = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_paint"))
    textBlock_paint.Font.Size = optUI.tangent.font_size
    textBlock_paint.Font.FontObject = fontObj
    textBlock_paint:SetText(FText(optUI.tangent.txt.paint))

    ---@type USpacer
    local spacer_paint = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_paint"))
    spacer_paint:SetSize(optUI.tangent.spacer_size)

    ---@type UCheckBox
    UI.paintCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_paint"))

    horizontalBox_paint:AddChildToHorizontalBox(textBlock_paint)
    horizontalBox_paint:AddChildToHorizontalBox(spacer_paint)
    horizontalBox_paint:AddChildToHorizontalBox(UI.paintCheckBox)
    --#endregion

    verticalBox:AddChildToVerticalBox(textBlock_title)
    verticalBox:AddChildToVerticalBox(UI.presetsComboBox)
    verticalBox:AddChildToVerticalBox(horizontalBox)
    verticalBox:AddChildToVerticalBox(horizontalBox_paint)

    local slot = UI.canvas:AddChildToCanvas(verticalBox)
    slot:SetAutoSize(true)

    updateUI()
    -- select last selected preset
    if params.LAST_PRESET and params.LAST_PRESET ~= "" and UI.presetsComboBox:FindOptionIndex(params.LAST_PRESET) ~= -1 then
        UI.presetsComboBox:SetSelectedOption(params.LAST_PRESET)
    else
        UI.presetsComboBox:SetSelectedIndex(0)
        params.LAST_PRESET = UI.presetsComboBox:GetOptionAtIndex(0):ToString()
        writeParamsFile()
    end

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    UI.userWidget:SetPositionInViewport(optUI.smoothen.positionInViewport, false)
    UI.userWidget:AddToViewport(optUI.smoothen.zOrder)
    UI.userWidget:SetVisibility(ESlateVisibility.Visible)

    log.debug("UI created (smoothen).")

    return true
end

local function showUI()
    if UI.userWidget and UI.userWidget:IsValid() then
        UI.userWidget:SetVisibility(ESlateVisibility.Visible)
    else
        createUI()
    end
    updateUI()
    UI.showed = true
end

local function hideUI()
    if UI.userWidget and UI.userWidget:IsValid() then
        UI.userWidget:SetVisibility(ESlateVisibility.Hidden)
    end
    UI.showed = false
end

local function toogleUI()
    if UI.showed == true then
        hideUI()
    else
        showUI()
    end
end

writeParamsFile = function()
    log.debug("Write params file.")

    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    -- defaults
    if params.DEBUG_OBJECTS == nil then params.DEBUG_OBJECTS = false end
    if params.LAST_PRESET == nil then params.LAST_PRESET = "" end
    file:write(format(
        [[return {
DEBUG_OBJECTS=%s,
LAST_PRESET="%s"
}]],
        params.DEBUG_OBJECTS, params.LAST_PRESET))

    file:close()
end

local function init()
    World = UEHelpers:GetWorld()

    ExecuteInGameThread(function()
        LoadAsset(dbg.matClassName) ---@diagnostic disable-line: undefined-global
        LoadAsset(dbg.meshClassName) ---@diagnostic disable-line: undefined-global

        if dbg.staticMeshActorClass == nil or dbg.staticMeshActorClass:IsValid() == false then
            dbg.staticMeshActorClass = StaticFindObject(dbg.staticMeshActorClassName) ---@diagnostic disable-line: assign-type-mismatch
        end

        if dbg.material == nil or dbg.material:IsValid() == false then
            dbg.material = StaticFindObject(dbg.matClassName) ---@diagnostic disable-line: assign-type-mismatch
        end

        if dbg.mesh == nil or dbg.mesh:IsValid() == false then
            dbg.mesh = StaticFindObject(dbg.meshClassName) ---@diagnostic disable-line: assign-type-mismatch
        end
    end)
end

ExecuteWithDelay(5000, function()
    ---@param self RemoteUnrealParam
    ---@param NewPawn RemoteUnrealParam
    RegisterHook("/Script/Engine.PlayerController:ClientRestart", function(self, NewPawn)
        init()
    end)
end)

init()

Presets, PresetNamesList = loadAllPresets()

---@type Method__Smoothen
return {
    params = params,
    handleTerrainTool_hook = handleTerrainTool_hook,
    writeParamsFile = writeParamsFile,
    onEnable = function()
        params_paint = func.loadParamsFile(paramsFile_paint)
        showUI()
    end,
    onDisable = function()
        hideUI()
    end,
    onLoad = function()
        params_paint = func.loadParamsFile(paramsFile_paint)
        showUI()
    end,
    onUnload = function()
        hideUI()
    end,
    onUpdate = function()
        updateUI()
    end
}
