local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local sqrt = math.sqrt
local format = string.format

local huge = math.huge -- inf

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
local paramsFile = func.getParamsFile()
local params = func.loadParamsFile(paramsFile) ---@type Method__Tangent__PARAMS

-- load PARAMS from "paint" method
local paramsFile_paint = func.getParamsFile("paint")
local params_paint = func.loadParamsFile(paramsFile_paint) ---@type Method__Paint__PARAMS

local PaintTerrain = false
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

---@param t table
local function numberTableToString(t)
    local str = "{"
    for key, value in pairs(t) do
        str = str .. format("[\"%s\"]=%.16g,", key, value)
    end
    str = str .. "}"

    return str
end

local function writeParamsFile()
    log.debug("Write params file.")

    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    -- defaults
    if params.ALTITUDES == nil then params.ALTITUDES = {} end
    if params.ALTITUDE_ROUND == nil then params.ALTITUDE_ROUND = 50 end
    if params.FORCE_ALTITUDE == nil then params.FORCE_ALTITUDE = false end
    if params.PAINT == nil then params.PAINT = false end
    if params.SELECTED_ALTITUDE_INDEX == nil then params.SELECTED_ALTITUDE_INDEX = 0 end
    file:write(format(
        [[return {
ALTITUDES=%s,
ALTITUDE_ROUND=%.16g,
FORCE_ALTITUDE=%s,
PAINT=%s,
SELECTED_ALTITUDE_INDEX=%d,
}]],
        numberTableToString(params.ALTITUDES),
        params.ALTITUDE_ROUND,
        params.FORCE_ALTITUDE,
        params.PAINT,
        params.SELECTED_ALTITUDE_INDEX
    ))

    file:close()
end

local function updateParamsFile()
    local updateRequired = false

    -- get the selected altitude index from the altitude list (ComboBox)
    local selectedIndex = UI.altitudeComboBox:GetSelectedIndex()
    if params.SELECTED_ALTITUDE_INDEX ~= selectedIndex then
        params.SELECTED_ALTITUDE_INDEX = selectedIndex
        updateRequired = true
    end

    -- get altitude round
    local round = tonumber(UI.altitudeRound:GetText():ToString())
    if round == nil then
        round = params.ALTITUDE_ROUND
        UI.altitudeRound:SetText(FText(tostring(round)))
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

    -- get paint CheckBox state
    local paint = UI.paintCheckBox.CheckedState == ECheckBoxState.Checked
    if params.PAINT ~= paint then
        params.PAINT = paint
        updateRequired = true
    end

    if updateRequired then
        writeParamsFile()
    end
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

    -- check if the hit actor is a SolarBody (planet)
    if not toolHit.Actor:Get():IsA("/Script/Astro.SolarBody") then ---@diagnostic disable-line: undefined-field
        -- Hit actor is not a SolarBody. Try to get a SolarBody.

        toolHit = {}

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
    params = func.loadParamsFile(paramsFile)
    params_paint = func.loadParamsFile(paramsFile_paint)

    updateAltitudeList()

    if UI.altitudeRound:IsValid() then
        UI.altitudeRound:SetText(FText(tostring(params.ALTITUDE_ROUND)))
    end

    if UI.forceAltitudeCheckBox:IsValid() then
        UI.forceAltitudeCheckBox:SetCheckedState(params.FORCE_ALTITUDE == true and
            ECheckBoxState.Checked or ECheckBoxState.Unchecked)
    end

    if UI.paintCheckBox:IsValid() then
        UI.paintCheckBox:SetCheckedState(params.PAINT == true and
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

    ---@type UEditableTextBox
    UI.roundedAltitude = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_roundedAltitude"))
    UI.roundedAltitude.WidgetStyle.Font.Size = optUI.tangent.font_size
    UI.roundedAltitude.WidgetStyle.Font.FontObject = fontObj
    UI.roundedAltitude.IsReadOnly = true
    UI.roundedAltitude:SetToolTipText(FText(optUI.tangent.txt.roundedAltitude_tip))

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

    horizontalBox_altitudeRound:AddChildToHorizontalBox(textBlock_altitudeRound)
    horizontalBox_altitudeRound:AddChildToHorizontalBox(spacer2)
    horizontalBox_altitudeRound:AddChildToHorizontalBox(UI.altitudeRound)
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
    verticalBox:AddChildToVerticalBox(UI.altitudeComboBox)
    verticalBox:AddChildToVerticalBox(UI.altitudeTextBox)
    verticalBox:AddChildToVerticalBox(horizontalBox)
    verticalBox:AddChildToVerticalBox(horizontalBox_altitudeRound)
    verticalBox:AddChildToVerticalBox(UI.roundedAltitude)
    verticalBox:AddChildToVerticalBox(horizontalBox_paint)

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    local slot = UI.canvas:AddChildToCanvas(verticalBox)
    slot:SetAutoSize(true)

    UI.userWidget:SetPositionInViewport(optUI.tangent.positionInViewport, false)
    UI.userWidget:AddToViewport(optUI.tangent.zOrder)
    UI.userWidget:SetVisibility(ESlateVisibility.Visible)

    log.debug("UI created (tangent).")

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

---@type Method__tangent
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
    end,
}
