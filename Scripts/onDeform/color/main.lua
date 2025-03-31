local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local format = string.format

local UICreated = false
local currentModDirectory = debug.getinfo(1, "S").source:match("@?(.+\\Mods\\[^\\]+)")
local currentDirectory = debug.getinfo(1, "S").source:match("@(.+)\\")
local paramsFile = func.getParamsFileByName("params", currentDirectory, true)
local params = {} ---@cast params TerrainToolMod__onDeform_color__PARAMS

local m = {}
local UI = {
    userWidget = CreateInvalidObject(),
    enableCheckBox = CreateInvalidObject(),
    revertColorCheckBox = CreateInvalidObject(),
    scale = CreateInvalidObject(),
    menu = CreateInvalidObject(),
}
local options = OPTIONS
local optUI = OPTIONS_UI
local PreId_AstroPlanet_OnDeformationComplete, PostId_AstroPlanet_OnDeformationComplete
local SmallestNumber = 2 ^ -149
local Controller = CreateInvalidObject() ---@cast Controller APlayControllerInstance_C
local PlanetCenter = { X = 0, Y = 0, Z = 0 } ---@type FVector

local deform = {
    Intensity = 0,
    MaterialIndex = 0,
    Operation = 0,
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

---@type EPaintIndexType
local EPaintIndexType = {
    SpencerPalette = 0,
    PlanetPalette = 1,
    SpecialPalette = 2,
    Invalid = 3,
    EPaintIndexType_MAX = 4,
}

---@type ESlateBrushDrawType
local ESlateBrushDrawType = {
    NoDrawType = 0,
    Box = 1,
    Border = 2,
    Image = 3,
    ESlateBrushDrawType_MAX = 4,
}

local EDeformTypeName = {
    "Subtract",
    "Add",
    "Flatten",
    "ColorPick",
    "ColorPaint",
    "CountCreative",
    "Crater",
    "FlattenSubtractOnly",
    "FlattenAddOnly",
    "TrueFlatStamp",
    "PlatformSurface",
    "RevertModifications",
    "Count",
    "EDeformType_MAX",
}

local function writeParamsFile()
    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    if params.PLANET_MATERIAL_INDEX == nil then params.PLANET_MATERIAL_INDEX = {} end
    if params.ENABLE == nil then params.ENABLE = false end
    if params.REVERT_COLOR == nil then params.REVERT_COLOR = false end
    if params.SCALE == nil then params.SCALE = 1.25 end
    if params.VISIBILITY == nil then params.VISIBILITY = ESlateVisibility.Visible end

    file:write(format(
        [[return {
PLANET_MATERIAL_INDEX=%s,
ENABLE=%s,
REVERT_COLOR=%s,
SCALE=%.16g,
VISIBILITY=%d,
}]],
        func.tableToString(params.PLANET_MATERIAL_INDEX, "%d"),
        params.ENABLE,
        params.REVERT_COLOR,
        params.SCALE,
        params.VISIBILITY
    ))

    file:close()
end

local function updateParams()
    if UI.userWidget:IsValid() == false or UICreated == false then
        return
    end

    local updateRequired = false

    -- get enable CheckBox state
    local enable = UI.enableCheckBox.CheckedState == ECheckBoxState.Checked
    if params.ENABLE ~= enable then
        params.ENABLE = enable
        updateRequired = true
    end


    local scale = tonumber(UI.scale.Text:ToString())
    if scale == nil then
        scale = params.SCALE
    end
    if scale ~= params.SCALE then
        params.SCALE = scale
        updateRequired = true
    end

    -- get revertColor CheckBox state
    local revertColor = UI.revertColorCheckBox.CheckedState == ECheckBoxState.Checked
    if params.REVERT_COLOR ~= revertColor then
        params.REVERT_COLOR = revertColor
        updateRequired = true
    end

    local visibility = UI.userWidget.Visibility
    if visibility ~= params.VISIBILITY then
        params.VISIBILITY = visibility
        updateRequired = true
    end

    local designAstro = UEHelpers:GetPlayer()
    if designAstro:IsValid() then ---@cast designAstro ADesignAstro_C
        local planetName = designAstro:GetLocalSolarBody().Name:ToString()

        local materialIndex = MaterialIndexImage
        if materialIndex == nil then
            materialIndex = params.PLANET_MATERIAL_INDEX[planetName]
        end
        if materialIndex ~= nil and materialIndex ~= params.PLANET_MATERIAL_INDEX[planetName] then
            params.PLANET_MATERIAL_INDEX[planetName] = materialIndex
            updateRequired = true
        end
    end

    if updateRequired then
        writeParamsFile()
    end
end

local function updateUI()
    if UI.userWidget:IsValid() == false or UICreated == false then
        return
    end

    params = func.loadParamsFile(paramsFile) ---@type TerrainToolMod__onDeform_color__PARAMS

    if UI.enableCheckBox:IsValid() then
        UI.enableCheckBox:SetCheckedState(params.ENABLE == true and
            ECheckBoxState.Checked or ECheckBoxState.Unchecked)
    end

    if UI.revertColorCheckBox:IsValid() then
        UI.revertColorCheckBox:SetCheckedState(params.REVERT_COLOR == true and
            ECheckBoxState.Checked or ECheckBoxState.Unchecked)
    end

    if UI.scale:IsValid() then
        UI.scale:SetText(FText(tostring(params.SCALE)))
    end

    local materialIndex = 0
    if UI.menu:IsValid() then
        local designAstro = UEHelpers:GetPlayer()
        if designAstro:IsValid() then ---@cast designAstro ADesignAstro_C
            local planetName = designAstro:GetLocalSolarBody().Name:ToString()
            materialIndex = params.PLANET_MATERIAL_INDEX[planetName]
            if materialIndex == nil then materialIndex = 0 end
        end

        UI.menu:OnColorAndTypePicked({ R = 0, G = 0, B = 0, A = 0 },
            materialIndex, EPaintIndexType.PlanetPalette)
    end
    MaterialIndexImage = materialIndex
    _G.MaterialIndexImage = materialIndex
end

local function update()
    if UI.userWidget:IsValid() == false or UICreated == false then
        return
    end

    -- if not enabled
    if UI.enableCheckBox.CheckedState ~= ECheckBoxState.Checked then
        return
    end

    if UI.revertColorCheckBox.CheckedState == ECheckBoxState.Checked then
        deform.Intensity = SmallestNumber
        deform.MaterialIndex = 0
        deform.Operation = EDeformType.RevertModifications
    else
        deform.Intensity = 0
        deform.MaterialIndex = MaterialIndexImage
        deform.Operation = EDeformType.ColorPaint
    end
end

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createUI()
    local prefix = "TerrainMod_onDeform_color_"

    local gameInstance = UEHelpers.GetGameInstance()
    if not gameInstance:IsValid() then
        return false
    end

    local fontObj = StaticFindObject("/Game/UI/fonts/NDAstroneer-Regular_Font.NDAstroneer-Regular_Font")
    if not fontObj:IsValid() then
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
    textBlock_title.Font.Size = optUI.onDeform_color.font_size
    textBlock_title.Font.FontObject = fontObj
    textBlock_title:SetText(FText(optUI.onDeform_color.txt.title))
    textBlock_title:SetToolTipText(FText(format(optUI.onDeform_color.txt.description_tip,
        func.getKeybindName(options.toggle_colorDeform_ui_Key, options.toggle_colorDeform_ui_ModifierKeys))))

    --#region enable
    ---@type UHorizontalBox
    local horizontalBox_enable = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_enable"))
    horizontalBox_enable:SetToolTipText(FText(optUI.onDeform_color.txt.enable_tip))

    ---@type UTextBlock
    local textBlock_enable = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_enable"))
    textBlock_enable.Font.Size = optUI.onDeform_color.font_size
    textBlock_enable.Font.FontObject = fontObj
    textBlock_enable:SetText(FText(optUI.onDeform_color.txt.enable))

    ---@type USpacer
    local spacer_enable = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_enable"))
    spacer_enable:SetSize(optUI.onDeform_color.spacer_size)

    ---@type UCheckBox
    UI.enableCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_enable"))

    horizontalBox_enable:AddChildToHorizontalBox(textBlock_enable)
    horizontalBox_enable:AddChildToHorizontalBox(spacer_enable)
    horizontalBox_enable:AddChildToHorizontalBox(UI.enableCheckBox)
    --#endregion

    --#region scale
    ---@type UHorizontalBox
    local horizontalBox_scale = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_scale"))
    horizontalBox_scale:SetToolTipText(FText(optUI.onDeform_color.txt.scale_tip))

    ---@type UTextBlock
    local textBlock_scale = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_scale"))
    textBlock_scale.Font.Size = optUI.onDeform_color.font_size
    textBlock_scale.Font.FontObject = fontObj
    textBlock_scale:SetText(FText(optUI.onDeform_color.txt.scale))

    ---@type USpacer
    local spacer_scale = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_scale"))
    spacer_scale:SetSize(optUI.onDeform_color.spacer_size)

    ---@type UEditableTextBox
    UI.scale = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_scale"))
    UI.scale.WidgetStyle.Font.Size = optUI.onDeform_color.font_size
    UI.scale.WidgetStyle.Font.FontObject = fontObj
    UI.scale.SelectAllTextWhenFocused = true

    horizontalBox_scale:AddChildToHorizontalBox(textBlock_scale)
    horizontalBox_scale:AddChildToHorizontalBox(spacer_scale)
    horizontalBox_scale:AddChildToHorizontalBox(UI.scale)
    --#endregion

    --#region revert original color
    ---@type UHorizontalBox
    local horizontalBox_revertColor = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_revertColor"))
    horizontalBox_revertColor:SetToolTipText(FText(optUI.onDeform_color.txt.revertColor_tip))

    ---@type UTextBlock
    local textBlock_revertColor = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_revertColor"))
    textBlock_revertColor.Font.Size = optUI.onDeform_color.font_size
    textBlock_revertColor.Font.FontObject = fontObj
    textBlock_revertColor:SetText(FText(optUI.onDeform_color.txt.revertColor))

    ---@type USpacer
    local spacer_revertColor = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_revertColor"))
    spacer_revertColor:SetSize(optUI.onDeform_color.spacer_size)

    ---@type UCheckBox
    UI.revertColorCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_revertColor"))

    horizontalBox_revertColor:AddChildToHorizontalBox(textBlock_revertColor)
    horizontalBox_revertColor:AddChildToHorizontalBox(spacer_revertColor)
    horizontalBox_revertColor:AddChildToHorizontalBox(UI.revertColorCheckBox)
    --#endregion

    --#region material index
    ---@type UHorizontalBox
    local horizontalBox_material_index = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_material_index"))
    horizontalBox_material_index:SetToolTipText(FText(format(optUI.onDeform_color.txt.material_index_tip,
        func.getKeybindName(options.enable_handleTerrainTool_Key, options.enable_handleTerrainTool_ModifierKeys))))

    ---@type UTextBlock
    local textBlock_materialIndex = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_material_index"))
    textBlock_materialIndex.Font.Size = optUI.onDeform_color.font_size
    textBlock_materialIndex.Font.FontObject = fontObj
    textBlock_materialIndex:SetText(FText(optUI.onDeform_color.txt.material_index))

    ---@type USpacer
    local spacer_material_index = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_material_index"))
    spacer_material_index:SetSize(optUI.onDeform_color.spacer_size)

    ---@type UEditableTextBox
    UI.materialIndex = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_material_index"))
    UI.materialIndex.WidgetStyle.Font.Size = optUI.onDeform_color.font_size
    UI.materialIndex.WidgetStyle.Font.FontObject = fontObj
    UI.materialIndex.SelectAllTextWhenFocused = true
    UI.materialIndex:SetIsReadOnly(true)

    horizontalBox_material_index:AddChildToHorizontalBox(textBlock_materialIndex)
    horizontalBox_material_index:AddChildToHorizontalBox(spacer_material_index)
    horizontalBox_material_index:AddChildToHorizontalBox(UI.materialIndex)
    --#endregion

    verticalBox:AddChildToVerticalBox(textBlock_title)
    verticalBox:AddChildToVerticalBox(horizontalBox_enable)
    verticalBox:AddChildToVerticalBox(horizontalBox_scale)
    verticalBox:AddChildToVerticalBox(horizontalBox_revertColor)
    verticalBox:AddChildToVerticalBox(horizontalBox_material_index)

    ---@type UTerrainToolCreativeMenu_C
    UI.menu = StaticConstructObject(
        StaticFindObject("/Game/UI/CreativeMode/TerrainToolCreativeMenu.TerrainToolCreativeMenu_C"), rootWidget,
        FName(prefix .. "TerrainToolCreativeMenu_C"))
    assert(UI.menu:IsValid(), "Unable to create TerrainToolCreativeMenu widget.")

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    local slot = UI.canvas:AddChildToCanvas(verticalBox)
    slot:SetAutoSize(true)

    UI.userWidget:SetAnchorsInViewport(optUI._generic.AnchorsInViewport2)
    UI.userWidget:SetAlignmentInViewport(optUI._generic.AlignmentInViewport2)
    UI.userWidget:SetPadding(optUI._generic.Padding2)
    UI.userWidget:SetVisibility(params.VISIBILITY)
    UI.userWidget:AddToViewport(optUI._generic.zOrder2)

    UI.canvas:AddChildToCanvas(UI.menu)
    UI.menu.ActiveColorImage.RenderTransformPivot = optUI.onDeform_color.ActiveColorImage_RenderTransformPivot
    UI.menu.ActiveColorImage.RenderTransform.Scale = optUI.onDeform_color.ActiveColorImage_RenderTransform_Scale
    verticalBox:AddChildToVerticalBox(UI.menu.ActiveColorImage)

    UI.menu.CreativeTerrainPlanetColorPicker.Padding = optUI.onDeform_color.CreativeTerrainPlanetColorPicker_Padding
    verticalBox:AddChildToVerticalBox(UI.menu.CreativeTerrainPlanetColorPicker)

    UI.menu:RemoveFromParent()

    log.debug("UI created (onDeform_color).")

    return true
end

local function showUI()
    if UICreated == true and UI.userWidget and UI.userWidget:IsValid() then
        UI.userWidget:SetVisibility(ESlateVisibility.Visible)
    else
        UICreated = createUI()
    end

    updateUI()

    UI.userWidget:SetVisibility(ESlateVisibility.Visible)

    updateParams()
end

local function hideUI()
    if UI.userWidget and UI.userWidget:IsValid() then
        UI.userWidget:SetVisibility(ESlateVisibility.Hidden)
    end
    updateParams()
end

function m.toggleUI()
    if UI.userWidget and UI.userWidget:IsValid() and UI.userWidget:GetVisibility() == ESlateVisibility.Visible then
        hideUI()
    else
        showUI()
    end
end

---@param self RemoteUnrealParam
---@param _deformParams RemoteUnrealParam
local function hook_AstroPlanet_OnDeformationComplete(self, _deformParams)
    local deformParams = _deformParams:get() ---@type FDeformationParamsT2

    ---@diagnostic disable-next-line: undefined-field
    if deformParams.Instigator:Get():IsA(
            "/Game/Components_Small/SmallDeform_TERRAIN_EXPERIMENTAL.SmallDeform_TERRAIN_EXPERIMENTAL_C") and
        (deformParams.Operation == EDeformType.Add or
            deformParams.Operation == EDeformType.Flatten or
            deformParams.Operation == EDeformType.FlattenAddOnly or
            deformParams.Operation == EDeformType.FlattenSubtractOnly or
            deformParams.Operation == EDeformType.PlatformSurface)
    then
        Controller:ClientDoDeformation({
            AutoCreateResourceEfficiency = 0,
            CreativeModeNoResourceCollection = false,
            DeltaTime = deformParams.DeltaTime,
            ForceRemoveDecorators = false,
            HardnessPenetration = 0,
            Instigator = nil,
            Intensity = deform.Intensity,
            Location = {
                X = deformParams.Location.X + PlanetCenter.X,
                Y = deformParams.Location.Y + PlanetCenter.Y,
                Z = deformParams.Location.Z + PlanetCenter.Z,
            },
            MaterialIndex = deform.MaterialIndex,
            Normal = { X = deformParams.Normal.X, Y = deformParams.Normal.Y, Z = deformParams.Normal.Z },
            Operation = deform.Operation,
            Scale = deformParams.Scale * params.SCALE,
            SequenceNumber = 0,
            Shape = 0,
            bEasyUnbury = false,
            bUseAlternatePolygonization = true
        })
    end
end

---@param callback function
local function registerHook_AstroPlanet_OnDeformationComplete(callback)
    if type(PreId_AstroPlanet_OnDeformationComplete) == "number" or type(PostId_AstroPlanet_OnDeformationComplete) == "number" then
        log.warn("AstroPlanet_OnDeformationComplete is already hooked.")
        return
    end
    PreId_AstroPlanet_OnDeformationComplete, PostId_AstroPlanet_OnDeformationComplete = RegisterHook(
        "/Script/Astro.AstroPlanet:OnDeformationComplete", callback)
end
local function unregisterHook_AstroPlanet_OnDeformationComplete()
    if type(PreId_AstroPlanet_OnDeformationComplete) == "number" and type(PostId_AstroPlanet_OnDeformationComplete) == "number" then
        UnregisterHook("/Script/Astro.AstroPlanet:OnDeformationComplete", PreId_AstroPlanet_OnDeformationComplete,
            PostId_AstroPlanet_OnDeformationComplete)
        PreId_AstroPlanet_OnDeformationComplete = nil
        PostId_AstroPlanet_OnDeformationComplete = nil
    end
end

local function manageHook()
    if UI.enableCheckBox.CheckedState == ECheckBoxState.Checked then
        if PreId_AstroPlanet_OnDeformationComplete == nil then
            registerHook_AstroPlanet_OnDeformationComplete(hook_AstroPlanet_OnDeformationComplete)
        end
    else
        unregisterHook_AstroPlanet_OnDeformationComplete()
    end
end

local function init()
    Controller = UEHelpers:GetPlayerController() ---@cast Controller APlayControllerInstance_C
    PlanetCenter = Controller:GetLocalSolarBody():GetCenter()
    if UI.userWidget:IsValid() == false or UICreated == false then
        UICreated = createUI()
        if UICreated == false then
            log.warn("Unable to create UI.")
            return
        end
        updateUI()
    end
end

RegisterHook("/Script/Astro.DeformTool:Activated", function()
    update()
    manageHook()
    updateParams()
end)

RegisterHook("/Script/Astro.DeformTool:Deactivated", function()
    manageHook()
    updateParams()
end)

---@param self UTerrainToolCreativeMenu_C
---@param SelectedColor FLinearColor
---@param SelectedColorIndex int32
---@param PaintType EPaintIndexType
function m.hook_TerrainToolCreativeMenu_OnColorAndTypePicked(self, SelectedColor, SelectedColorIndex, PaintType)
    MaterialIndexImage = SelectedColorIndex
    _G.MaterialIndexImage = SelectedColorIndex

    if UI.revertColorCheckBox:IsValid() and UI.revertColorCheckBox.CheckedState == ECheckBoxState.Unchecked then
        deform.MaterialIndex = SelectedColorIndex
    end

    if UI.materialIndex:IsValid() then
        UI.materialIndex:SetText(FText(tostring(SelectedColorIndex)))
    end
end

---@param self RemoteUnrealParam
---@param newPawn ADesignAstro_C
---@param firstInitialization boolean
function m.hook_PlayerController_ClientRestart(self, newPawn, firstInitialization)
    Controller = UEHelpers:GetPlayerController() ---@cast Controller APlayControllerInstance_C
    PlanetCenter = Controller:GetLocalSolarBody():GetCenter()
end

---@param self RemoteUnrealParam
function m.hook_Planet_Marker_HandlePlanetMarkerSelected(self)
    PlanetCenter = Controller:GetLocalSolarBody():GetCenter()

    UI.menu:Destruct()
    UI.menu:Construct()
end

function m.PlayerController_ClientReceiveLocalizedMessage(...)
    init()
end

--Manage "UE4SS Restart mods" or when the script is injected manually.
---@param firstInitialization boolean?
function m.onModRestartedOrStartedManually(firstInitialization)
    init()
end

params = func.loadParamsFile(paramsFile) ---@type TerrainToolMod__onDeform_color__PARAMS

return m
