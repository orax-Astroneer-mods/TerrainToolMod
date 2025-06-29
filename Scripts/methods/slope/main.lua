local MethodName = "slope"

local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local vec3 = Vec3
local sqrt, rad = math.sqrt, math.rad
local format = string.format

local CurrentFile = debug.getinfo(1, "S").source

-- load PARAMS global table
local paramsFile = func.getParamsFile(CurrentFile, true)
local params = func.loadParamsFile(paramsFile, true) ---@type Method__Slope__PARAMS

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
    if params.SLOPE_ANGLE == nil then params.SLOPE_ANGLE = 45 end

    file:write(format(
        [[---@type Method__Slope__PARAMS
return {
SLOPE_ANGLE=%.16g
}]],
        params.SLOPE_ANGLE
    ))

    file:close()
end

local function updateParams()
    local updateRequired = false

    -- get slope angle
    local slopeAngle = tonumber(UI.angleTextBox.Text:ToString())
    if slopeAngle ~= nil and params.SLOPE_ANGLE ~= slopeAngle then
        params.SLOPE_ANGLE = slopeAngle
        updateRequired = true
    end

    if updateRequired then
        writeParamsFile()
    end
end

local function updateUI()
    params = func.loadParamsFile(paramsFile) ---@type Method__Slope__PARAMS

    UI.angleTextBox:SetText(FText(tostring(params.SLOPE_ANGLE)))
end

---@param _self RemoteUnrealParam
---@param _controller RemoteUnrealParam
---@param _toolHit RemoteUnrealParam
---@param _clickResult RemoteUnrealParam
---@param _startedInteraction RemoteUnrealParam
---@param _endedInteraction RemoteUnrealParam
---@param _isUsingTool RemoteUnrealParam
---@param _justActivated RemoteUnrealParam
---@param _canUse RemoteUnrealParam
local function hook_HandleTerrainTool(_self, _controller, _toolHit, _clickResult, _startedInteraction, _endedInteraction,
                                      _isUsingTool, _justActivated, _canUse)
    local controller = _controller:get() ---@type APlayController

    if _justActivated:get() == true then
        updateParams()
        -- Planet center is (0, 0, 0) for SYLVA.
        PlanetCenter = controller:GetLocalSolarBody():GetCenter()
    end

    if _isUsingTool:get() == false or _canUse:get() == false then
        return
    end

    local deformTool = _self:get() ---@type ASmallDeform_TERRAIN_EXPERIMENTAL_C
    local toolHit = _toolHit:get() ---@type FHitResult
    local startedInteraction = _startedInteraction:get() ---@type boolean

    local operation = deformTool.Operation

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

        toolHit = {} ---@diagnostic disable-line: missing-fields
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

    deformTool.Deform_NormalX = u_unit.X
    deformTool.Deform_NormalY = u_unit.Y
    deformTool.Deform_NormalZ = u_unit.Z

    deformTool.Deform_Normal2X = u_unit.X
    deformTool.Deform_Normal2Y = u_unit.Y
    deformTool.Deform_Normal2Z = u_unit.Z

    deformTool.Deform_Normal3X = u_unit.X
    deformTool.Deform_Normal3Y = u_unit.Y
    deformTool.Deform_Normal3Z = u_unit.Z

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
        log.warn("Game instance is not valid.")
        return false
    end

    local fontObj = StaticFindObject("/Game/UI/fonts/NDAstroneer-Regular_Font.NDAstroneer-Regular_Font")
    if not fontObj:IsValid() then
        log.warn("Font object is not valid.")
        return false
    end

    local shortcuts = format(
        "%s = %s\n" ..
        "%s = %s\n" ..
        "%s = %s",
        options.set_slope_direction_from_camera_KeyName, options.set_slope_direction_from_camera_text,
        options.set_slope_direction_from_camera_KeyName, options.set_slope_direction_from_camera_reversed_text,
        options.set_slope_direction_from_camera_reversed_KeyName, options.set_slope_direction_from_slope_text)

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
    UI.angleTextBox.SelectAllTextWhenFocused = true

    horizontalBox_angle:AddChildToHorizontalBox(textBlock_angle)
    horizontalBox_angle:AddChildToHorizontalBox(spacer_angle)
    horizontalBox_angle:AddChildToHorizontalBox(UI.angleTextBox)
    --#endregion

    verticalBox:AddChildToVerticalBox(textBlock_title)
    verticalBox:AddChildToVerticalBox(horizontalBox_angle)

    local slot = UI.canvas:AddChildToCanvas(verticalBox)
    slot:SetAutoSize(true)

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    UI.userWidget:SetAnchorsInViewport(optUI._generic.AnchorsInViewport)
    UI.userWidget:SetAlignmentInViewport(optUI._generic.AlignmentInViewport)
    UI.userWidget:SetPadding(optUI._generic.Padding)
    UI.userWidget:AddToViewport(optUI._generic.zOrder)
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
    updateParams()
    UI.showed = false
end

local function toogleUI()
    if UI.showed == true then
        hideUI()
    else
        showUI()
    end
end

local function isUIFocused()
    if not UI.userWidget or not UI.userWidget:IsValid() then
        return false
    end

    return UI.userWidget:HasFocusedDescendants()
end

---@type Method__Slope
return {
    params = params,
    hook_DeformTool_HandleTerrainTool = hook_HandleTerrainTool,
    onLoad = function()
        showUI()
    end,
    onUnload = function()
        hideUI()
    end,
    onUpdate = function()
        updateUI()
    end,
    isUIFocused = isUIFocused,
}
