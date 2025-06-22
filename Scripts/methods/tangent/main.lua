local MethodName = "tangent"

local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local sqrt = math.sqrt
local format = string.format

local huge = math.huge -- inf
local SmallestNumber = 2 ^ -149

local CurrentFile = debug.getinfo(1, "S").source
local options = OPTIONS
local optUI = OPTIONS_UI
local UI = {
    ---@diagnostic disable: assign-type-mismatch
    altitudeComboBox = nil, ---@type UComboBoxString
    forceAltitudeCheckBox = nil, ---@type UCheckBox
    altitudeTextBox = nil, ---@type UEditableTextBox
    roundedAltitude = nil, ---@type UEditableTextBox
    ---@diagnostic enable: assign-type-mismatch
}

-- load PARAMS global table
local paramsFile = func.getParamsFile(CurrentFile, true)
local params = func.loadParamsFile(paramsFile, true) ---@type Method__Tangent__PARAMS

local RoundedAltitude = 0
local PlanetCenter = { X = 0, Y = 0, Z = 0 } ---@type FVector

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

local function writeParamsFile()
    log.debug("Write params file.")

    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    -- defaults
    if params.ALTITUDES == nil then params.ALTITUDES = {} end
    if params.ALTITUDE_ROUND == nil then params.ALTITUDE_ROUND = 50 end
    if params.FORCE_ALTITUDE == nil then params.FORCE_ALTITUDE = false end
    if params.SELECTED_ALTITUDE_INDEX == nil then params.SELECTED_ALTITUDE_INDEX = 0 end
    file:write(format(
        [[---@type Method__Tangent__PARAMS
return {
ALTITUDES=%s,
ALTITUDE_ROUND=%.16g,
FORCE_ALTITUDE=%s,
SELECTED_ALTITUDE_INDEX=%d,
}]],
        func.tableToString(params.ALTITUDES, "%.16g"),
        params.ALTITUDE_ROUND,
        params.FORCE_ALTITUDE,
        params.SELECTED_ALTITUDE_INDEX
    ))

    file:close()
end

local function updateParams()
    local updateRequired = false

    -- get the selected altitude index from the altitude list (ComboBox)
    local selectedIndex = UI.altitudeComboBox:GetSelectedIndex()
    if params.SELECTED_ALTITUDE_INDEX ~= selectedIndex then
        params.SELECTED_ALTITUDE_INDEX = selectedIndex
        updateRequired = true
    end

    -- get altitude round
    local round = tonumber(UI.altitudeRound.Text:ToString())
    if round == nil then
        round = params.ALTITUDE_ROUND
    end
    if params.ALTITUDE_ROUND ~= round then
        params.ALTITUDE_ROUND = round
        updateRequired = true
    end

    -- get force altitude CheckBox state
    local forceAltitude = UI.forceAltitudeCheckBox.CheckedState == ECheckBoxState.Checked
    if params.FORCE_ALTITUDE ~= forceAltitude then
        params.FORCE_ALTITUDE = forceAltitude
        updateRequired = true
    end

    if updateRequired then
        writeParamsFile()
    end
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

    -- check if the hit actor is a SolarBody (planet)
    if not toolHit.Actor:Get():IsA("/Script/Astro.SolarBody") then ---@diagnostic disable-line: undefined-field
        -- Hit actor is not a SolarBody. Try to get a SolarBody.

        toolHit = {} ---@diagnostic disable-line: missing-fields

        --[[ How to get Object types?
            Create a GetHitResultUnderCursorForObjects node in Blueprint. Make an array on "Object Types".
            List: WorldStatic, WorldDynamic, Pawn, PhysicsBody, Vehicle, Destructible, TerrainObj, BuriedObj, HazardObj, InteractObj, CameraObj.

            Another solution is to do tests with this code:
                local hitResult = {}
                local playerController = UEHelpers:GetPlayerController()
                for i = 1, 33, 1 do
                    playerController:GetHitResultUnderCursorForObjects({ i }, false, hitResult)
                    local hitActor = GetActorFromHitResult(hitResult)
                    print(i, hitActor:GetFullName())
                end
        --]]
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

    local operation = deformTool.Operation

    -- check if a flatten operation is selected
    if operation ~= EDeformType.Flatten and
        operation ~= EDeformType.FlattenAddOnly and
        operation ~= EDeformType.FlattenSubtractOnly then
        return
    end

    if startedInteraction then
        local forceAltitude = params.FORCE_ALTITUDE

        if forceAltitude == true then
            -- get altitude from the TextBox
            local alt = tonumber(UI.altitudeTextBox.Text:ToString())

            -- if altitude is empty, try to get it from the ComboBox
            if alt == nil or alt == "" then
                alt = tonumber(string.match(UI.altitudeComboBox.SelectedOption:ToString(), "%(([0-9.]+)%)$"))
            end

            if alt ~= nil then
                RoundedAltitude = alt
                log.debug("Altitude is defined to %.16g.", RoundedAltitude)
            else
                log.warn("Unable to get altitude from the UI.")
                forceAltitude = false -- altitude will be get automatically
            end
        end

        if forceAltitude == false then
            assert(type(params.ALTITUDE_ROUND) == "number", "ALTITUDE_ROUND is not a number.")
            assert(params.ALTITUDE_ROUND ~= huge, "ALTITUDE_ROUND is not defined.")

            RoundedAltitude = func.roundToBase(func.getVectorLen({
                X = toolHit.Location.X - PlanetCenter.X,
                Y = toolHit.Location.Y - PlanetCenter.Y,
                Z = toolHit.Location.Z - PlanetCenter.Z
            }), params.ALTITUDE_ROUND)

            log.debug("Rounded altitude is %.16g.", RoundedAltitude)
        end

        UI.roundedAltitude:SetText(FText(tostring(RoundedAltitude)))
    end

    ---@type FVector
    local u = {
        X = toolHit.Location.X - PlanetCenter.X,
        Y = toolHit.Location.Y - PlanetCenter.Y,
        Z = toolHit.Location.Z - PlanetCenter.Z
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

    deformTool.Deform_NormalX = angle.X
    deformTool.Deform_NormalY = angle.Y
    deformTool.Deform_NormalZ = angle.Z

    deformTool.Deform_Normal2X = angle.X
    deformTool.Deform_Normal2Y = angle.Y
    deformTool.Deform_Normal2Z = angle.Z

    deformTool.Deform_Normal3X = angle.X
    deformTool.Deform_Normal3Y = angle.Y
    deformTool.Deform_Normal3Z = angle.Z

    deformTool.Deform_Location1X = u.X
    deformTool.Deform_Location1Y = u.Y
    deformTool.Deform_Location1Z = u.Z

    deformTool.Deform_Location2X = u.X
    deformTool.Deform_Location2Y = u.Y
    deformTool.Deform_Location2Z = u.Z

    deformTool.Deform_Location3X = u.X
    deformTool.Deform_Location3Y = u.Y
    deformTool.Deform_Location3Z = u.Z

    deformTool.Deform_Location4X = u.X
    deformTool.Deform_Location4Y = u.Y
    deformTool.Deform_Location4Z = u.Z

    deformTool.HitLocation = u
    deformTool.HitNormal = angle

    ---@diagnostic enable: inject-field
end

local function updateAltitudeList()
    if not UI.altitudeComboBox:IsValid() then
        return
    end

    local index = UI.altitudeComboBox:GetSelectedIndex()
    UI.altitudeComboBox:ClearOptions()

    for key, value in func.pairsByKeys(params.ALTITUDES) do
        ---@diagnostic disable-next-line: param-type-mismatch
        UI.altitudeComboBox:AddOption(format("%s (%.16g)", key, value))
    end

    if index == -1 then
        index = 0
    end
    UI.altitudeComboBox:SetSelectedIndex(index)
end

local function updateUI()
    params = func.loadParamsFile(paramsFile) ---@type Method__Tangent__PARAMS

    updateAltitudeList()

    if UI.altitudeRound:IsValid() then
        UI.altitudeRound:SetText(FText(tostring(params.ALTITUDE_ROUND)))
    end

    if UI.forceAltitudeCheckBox:IsValid() then
        UI.forceAltitudeCheckBox:SetCheckedState(params.FORCE_ALTITUDE == true and
            ECheckBoxState.Checked or ECheckBoxState.Unchecked)
    end
end

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createUI()
    local prefix = "TerrainMod_tangent_"

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
    textBlock_title.Font.Size = optUI.tangent.font_size
    textBlock_title.Font.FontObject = fontObj
    textBlock_title:SetText(FText(optUI.tangent.txt.title))
    textBlock_title:SetToolTipText(FText(optUI.tangent.txt.description_tip))

    ---@type UComboBoxString
    UI.altitudeComboBox = StaticConstructObject(StaticFindObject("/Script/UMG.ComboBoxString"),
        rootWidget, FName(prefix .. "ComboBoxString"))
    UI.altitudeComboBox.Font.FontObject = fontObj
    UI.altitudeComboBox.Font.Size = optUI.tangent.font_size
    UI.altitudeComboBox:SetToolTipText(FText(format(optUI.tangent.txt.altitudeList_tip,
        func.getKeybindName(options.enable_handleTerrainTool_Key, options.enable_handleTerrainTool_ModifierKeys))))

    ---@type UEditableTextBox
    UI.altitudeTextBox = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_altitude"))
    UI.altitudeTextBox.WidgetStyle.Font.Size = optUI.tangent.font_size
    UI.altitudeTextBox.WidgetStyle.Font.FontObject = fontObj
    UI.altitudeTextBox.HintText = FText(optUI.tangent.txt.temporaryAltitude)
    UI.altitudeTextBox:SetToolTipText(FText(optUI.tangent.txt.temporaryAltitude_tip))
    UI.altitudeTextBox.SelectAllTextWhenFocused = true

    ---@type UEditableTextBox
    UI.roundedAltitude = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_roundedAltitude"))
    UI.roundedAltitude.WidgetStyle.Font.Size = optUI.tangent.font_size
    UI.roundedAltitude.WidgetStyle.Font.FontObject = fontObj
    UI.roundedAltitude.IsReadOnly = true
    UI.roundedAltitude:SetToolTipText(FText(optUI.tangent.txt.roundedAltitude_tip))
    UI.roundedAltitude.SelectAllTextWhenFocused = true

    --#region force altitude
    ---@type UHorizontalBox
    local horizontalBox = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox"))
    horizontalBox:SetToolTipText(FText(optUI.tangent.txt.forceAltitude_tip))

    ---@type UTextBlock
    local textBlock_forceAltitude = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_forceAltitude"))
    textBlock_forceAltitude.Font.Size = optUI.tangent.font_size
    textBlock_forceAltitude.Font.FontObject = fontObj
    textBlock_forceAltitude:SetText(FText(optUI.tangent.txt.forceAltitude))

    ---@type USpacer
    local spacer1 = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer1"))
    spacer1:SetSize(optUI.tangent.spacer_size)

    ---@type UCheckBox
    UI.forceAltitudeCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_forceAltitude"))

    horizontalBox:AddChildToHorizontalBox(textBlock_forceAltitude)
    horizontalBox:AddChildToHorizontalBox(spacer1)
    horizontalBox:AddChildToHorizontalBox(UI.forceAltitudeCheckBox)
    --#endregion

    --#region round altitude to
    ---@type UHorizontalBox
    local horizontalBox_altitudeRound = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox2"))
    horizontalBox_altitudeRound:SetToolTipText(FText(optUI.tangent.txt.altitudeRound_tip))

    ---@type UTextBlock
    local textBlock_altitudeRound = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_altitudeRound"))
    textBlock_altitudeRound.Font.Size = optUI.tangent.font_size
    textBlock_altitudeRound.Font.FontObject = fontObj
    textBlock_altitudeRound:SetText(FText(optUI.tangent.txt.altitudeRound))

    ---@type USpacer
    local spacer2 = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer2"))
    spacer2:SetSize(optUI.tangent.spacer_size)

    ---@type UEditableTextBox
    UI.altitudeRound = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_altitudeRound"))
    UI.altitudeRound.WidgetStyle.Font.Size = optUI.tangent.font_size
    UI.altitudeRound.WidgetStyle.Font.FontObject = fontObj
    UI.altitudeRound.SelectAllTextWhenFocused = true

    horizontalBox_altitudeRound:AddChildToHorizontalBox(textBlock_altitudeRound)
    horizontalBox_altitudeRound:AddChildToHorizontalBox(spacer2)
    horizontalBox_altitudeRound:AddChildToHorizontalBox(UI.altitudeRound)
    --#endregion

    verticalBox:AddChildToVerticalBox(textBlock_title)
    verticalBox:AddChildToVerticalBox(UI.altitudeComboBox)
    verticalBox:AddChildToVerticalBox(UI.altitudeTextBox)
    verticalBox:AddChildToVerticalBox(horizontalBox)
    verticalBox:AddChildToVerticalBox(horizontalBox_altitudeRound)
    verticalBox:AddChildToVerticalBox(UI.roundedAltitude)

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    local slot = UI.canvas:AddChildToCanvas(verticalBox)
    slot:SetAutoSize(true)

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

---@type Method__tangent
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
