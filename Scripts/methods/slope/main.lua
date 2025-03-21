local MethodName = "slope"

local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local vec3 = Vec3
local sqrt, rad = math.sqrt, math.rad
local format = string.format

-- load PARAMS from "paint" method
local paramsFile_paint = func.getParamsFile("paint")
local params_paint = func.loadParamsFile(paramsFile_paint) ---@type Method__Paint__PARAMS

local PaintTerrain = false

-- load PARAMS global table
local paramsFile = func.getParamsFile()
local params = func.loadParamsFile(paramsFile) ---@type Method__Slope__PARAMS

local huge = math.huge
local SlopeDirection = vec3(huge, huge, huge)
local PlanetCenter = { X = 0, Y = 0, Z = 0 } ---@type FVector
local UI = {
    angleTextBox = nil ---@type UEditableTextBox
}
local options = OPTIONS
local optUI = OPTIONS_UI

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

---@type ECheckBoxState
local ECheckBoxState = {
    Unchecked    = 0,
    Checked      = 1,
    Undetermined = 2,
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

local function writeParamsFile()
    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    -- defaults
    if params.PAINT == nil then params.PAINT = false end
    if params.SLOPE_ANGLE == nil then params.SLOPE_ANGLE = 45 end

    file:write(format(
        [[return {
PAINT=%s,
SLOPE_ANGLE=%.16g
}]],
        params.PAINT,
        params.SLOPE_ANGLE))

    file:close()
end

local function updateParamsFile()
    local updateRequired = false

    -- get paint CheckBox state
    local paint = UI.paintCheckBox.CheckedState == ECheckBoxState.Checked
    if params.PAINT ~= paint then
        params.PAINT = paint
        updateRequired = true
    end

    -- get slope angle
    local slopeAngle = tonumber(UI.angleTextBox:GetText():ToString())
    if slopeAngle ~= nil and params.SLOPE_ANGLE ~= slopeAngle then
        params.SLOPE_ANGLE = slopeAngle
        updateRequired = true
    end

    if updateRequired then
        writeParamsFile()
    end
end

local function updateUI()
    params = func.loadParamsFile(paramsFile)
    params_paint = func.loadParamsFile(paramsFile_paint)

    UI.angleTextBox:SetText(FText(tostring(params.SLOPE_ANGLE)))

    UI.paintCheckBox:SetCheckedState(params.PAINT == true and
        ECheckBoxState.Checked or ECheckBoxState.Unchecked)
end

local function handleTerrainTool_hook(self, controller, toolHit, clickResult, startedInteraction, endedInteraction,
                                      isUsingTool, justActivated, canUse)
    if justActivated:get() == true then
        updateParamsFile()
        -- Planet center is (0, 0, 0) for SYLVA.
        PlanetCenter = controller:GetLocalSolarBody():GetCenter()
    end

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
        operation ~= EDeformType.FlattenSubtractOnly then
        return
    end

    -- ignored
    if startedInteraction == false and SlopeDirection.x == huge then return end

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
        local keyName_fromCamera = options.set_slope_direction_from_camera_KeyName
        local keyName_fromCamera_reversed = options.set_slope_direction_from_camera_reversed_KeyName
        local keyName_fromSlope = options.set_slope_direction_from_slope_KeyName

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

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createUI()
    local prefix = "TerrainMod_slope_"

    local gameInstance = UEHelpers.GetGameInstance()
    if not gameInstance:IsValid() then
        return false
    end

    local shortcuts = format(
        "%s = %s\n" ..
        "%s = %s\n" ..
        "%s = %s",
        options.set_slope_direction_from_camera_KeyName, options.set_slope_direction_from_camera_text,
        options.set_slope_direction_from_camera_KeyName, options.set_slope_direction_from_camera_reversed_text,
        options.set_slope_direction_from_camera_reversed_KeyName, options.set_slope_direction_from_slope_text)

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
    textBlock_title.Font.Size = optUI.slope.font_size
    textBlock_title.Font.FontObject = fontObj
    textBlock_title:SetText(FText(optUI.slope.txt.title))
    textBlock_title:SetToolTipText(FText(format(optUI.slope.txt.description_tip, shortcuts)))

    --#region angle
    ---@type UHorizontalBox
    local horizontalBox_angle = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_angle"))
    horizontalBox_angle:SetToolTipText(FText(optUI.slope.txt.angle_tip))

    ---@type UTextBlock
    local textBlock_angle = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_angle"))
    textBlock_angle.Font.Size = optUI.slope.font_size
    textBlock_angle.Font.FontObject = fontObj
    textBlock_angle:SetText(FText(optUI.slope.txt.angle))

    ---@type USpacer
    local spacer_angle = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_angle"))
    spacer_angle:SetSize(optUI.slope.spacer_size)

    ---@type UEditableTextBox
    UI.angleTextBox = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_angle"))
    UI.angleTextBox.WidgetStyle.Font.Size = optUI.slope.font_size
    UI.angleTextBox.WidgetStyle.Font.FontObject = fontObj

    horizontalBox_angle:AddChildToHorizontalBox(textBlock_angle)
    horizontalBox_angle:AddChildToHorizontalBox(spacer_angle)
    horizontalBox_angle:AddChildToHorizontalBox(UI.angleTextBox)
    --#endregion

    --#region paint
    ---@type UHorizontalBox
    local horizontalBox_paint = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_paint"))
    horizontalBox_paint:SetToolTipText(FText(format(optUI["*"].txt.paint_tip,
        func.getKeybindName(options.set_paint_method_Key, options.set_paint_method_ModifierKeys))))

    ---@type UTextBlock
    local textBlock_paint = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_paint"))
    textBlock_paint.Font.Size = optUI.slope.font_size
    textBlock_paint.Font.FontObject = fontObj
    textBlock_paint:SetText(FText(optUI.slope.txt.paint))

    ---@type USpacer
    local spacer_paint = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_paint"))
    spacer_paint:SetSize(optUI.slope.spacer_size)

    ---@type UCheckBox
    UI.paintCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_paint"))

    horizontalBox_paint:AddChildToHorizontalBox(textBlock_paint)
    horizontalBox_paint:AddChildToHorizontalBox(spacer_paint)
    horizontalBox_paint:AddChildToHorizontalBox(UI.paintCheckBox)
    --#endregion

    verticalBox:AddChildToVerticalBox(textBlock_title)
    verticalBox:AddChildToVerticalBox(horizontalBox_angle)
    verticalBox:AddChildToVerticalBox(horizontalBox_paint)

    local slot = UI.canvas:AddChildToCanvas(verticalBox)
    slot:SetAutoSize(true)

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    UI.userWidget:SetPositionInViewport(optUI.slope.positionInViewport, false)
    UI.userWidget:AddToViewport(optUI.slope.zOrder)
    UI.userWidget:SetVisibility(ESlateVisibility.Visible)

    log.debug(format("UI created (%s).", MethodName))

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
    updateParamsFile()
    UI.showed = false
end

local function toogleUI()
    if UI.showed == true then
        hideUI()
    else
        showUI()
    end
end

---@type Method__Slope
return {
    params = params,
    handleTerrainTool_hook = handleTerrainTool_hook,
    onEnable = function()
        showUI()
    end,
    onDisable = function()
        hideUI()
    end,
    onLoad = function()
        showUI()
    end,
    onUnload = function()
        hideUI()
    end,
    onUpdate = function()
        updateUI()
    end
}
