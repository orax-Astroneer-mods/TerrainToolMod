--[[
Terrain colors
  https://astroneer.fandom.com/wiki/Terrain_Analyzer#Terrain_colors
]]

local methodName = "paint"

local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local format = string.format

local CurrentFile = debug.getinfo(1, "S").source

-- load PARAMS global table
local paramsFile = func.getParamsFile(CurrentFile, true)
local params = func.loadParamsFile(paramsFile, true) ---@type Method__Paint__PARAMS

local options = OPTIONS
local optUI = OPTIONS_UI
local UI = {}
local MaterialIndexImage = 0

---@type ESlateVisibility
local ESlateVisibility = {
    Visible = 0,
    Collapsed = 1,
    Hidden = 2,
    HitTestInvisible = 3,
    SelfHitTestInvisible = 4,
    ESlateVisibility_MAX = 5
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

---@type EPaintIndexType
local EPaintIndexType = {
    SpencerPalette = 0,
    PlanetPalette = 1,
    SpecialPalette = 2,
    Invalid = 3,
    EPaintIndexType_MAX = 4,
}

local function writeParamsFile()
    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    if params.SCALE == nil then params.SCALE = 2.0 end

    file:write(format(
        [[return {
SCALE=%.16g,
}]],
        params.SCALE
    ))

    file:close()
end

local function updateParams()
    local updateRequired = false

    local scale = tonumber(UI.scale:GetText():ToString())
    if scale == nil then
        scale = params.SCALE
    end
    if scale ~= params.SCALE then
        params.SCALE = scale
        updateRequired = true
    end

    if updateRequired then
        writeParamsFile()
    end
end

local function updateUI()
    params = func.loadParamsFile(paramsFile) ---@type Method__Paint__PARAMS

    if UI.scale:IsValid() then
        UI.scale:SetText(FText(tostring(params.SCALE)))
    end

    if UI.materialIndex:IsValid() then
        UI.materialIndex:SetText(FText(tostring(_G.MaterialIndexImage)))
    end
end

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createUI()
    local prefix = "TerrainMod_paint_"

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
    textBlock_title.Font.Size = optUI.paint.font_size
    textBlock_title.Font.FontObject = fontObj
    textBlock_title:SetText(FText(optUI.paint.txt.title))
    textBlock_title:SetToolTipText(FText(optUI.paint.txt.description_tip))

    --#region scale
    ---@type UHorizontalBox
    local horizontalBox_scale = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_scale"))
    horizontalBox_scale:SetToolTipText(FText(optUI.paint.txt.scale_tip))

    ---@type UTextBlock
    local textBlock_scale = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_scale"))
    textBlock_scale.Font.Size = optUI.paint.font_size
    textBlock_scale.Font.FontObject = fontObj
    textBlock_scale:SetText(FText(optUI.paint.txt.scale))

    ---@type USpacer
    local spacer_scale = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_scale"))
    spacer_scale:SetSize(optUI.paint.spacer_size)

    ---@type UEditableTextBox
    UI.scale = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_scale"))
    UI.scale.WidgetStyle.Font.Size = optUI.paint.font_size
    UI.scale.WidgetStyle.Font.FontObject = fontObj
    UI.scale.SelectAllTextWhenFocused = true

    horizontalBox_scale:AddChildToHorizontalBox(textBlock_scale)
    horizontalBox_scale:AddChildToHorizontalBox(spacer_scale)
    horizontalBox_scale:AddChildToHorizontalBox(UI.scale)
    --#endregion

    --#region material index
    ---@type UHorizontalBox
    local horizontalBox_material_index = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_material_index"))
    horizontalBox_material_index:SetToolTipText(FText(format(optUI.paint.txt.material_index_tip,
        func.getKeybindName(options.enable_handleTerrainTool_Key, options.enable_handleTerrainTool_ModifierKeys))))

    ---@type UTextBlock
    local textBlock_materialIndex = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_material_index"))
    textBlock_materialIndex.Font.Size = optUI.paint.font_size
    textBlock_materialIndex.Font.FontObject = fontObj
    textBlock_materialIndex:SetText(FText(optUI.paint.txt.material_index))

    ---@type USpacer
    local spacer_material_index = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_material_index"))
    spacer_material_index:SetSize(optUI.paint.spacer_size)

    ---@type UEditableTextBox
    UI.materialIndex = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_material_index"))
    UI.materialIndex.WidgetStyle.Font.Size = optUI.paint.font_size
    UI.materialIndex.WidgetStyle.Font.FontObject = fontObj
    UI.materialIndex.SelectAllTextWhenFocused = true
    UI.materialIndex:SetIsReadOnly(true)

    horizontalBox_material_index:AddChildToHorizontalBox(textBlock_materialIndex)
    horizontalBox_material_index:AddChildToHorizontalBox(spacer_material_index)
    horizontalBox_material_index:AddChildToHorizontalBox(UI.materialIndex)
    --#endregion

    ---@type UTerrainToolCreativeMenu_C
    UI.menu = StaticConstructObject(
        StaticFindObject("/Game/UI/CreativeMode/TerrainToolCreativeMenu.TerrainToolCreativeMenu_C"), UI.userWidget,
        FName(prefix .. "TerrainToolCreativeMenu_C"))
    assert(UI.menu:IsValid(), "Unable to create TerrainToolCreativeMenu widget.")

    verticalBox:AddChildToVerticalBox(textBlock_title)
    verticalBox:AddChildToVerticalBox(horizontalBox_scale)
    verticalBox:AddChildToVerticalBox(horizontalBox_material_index)

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    local slot = UI.canvas:AddChildToCanvas(verticalBox)
    slot:SetAutoSize(true)

    UI.userWidget:SetAnchorsInViewport(optUI._generic.AnchorsInViewport)
    UI.userWidget:SetAlignmentInViewport(optUI._generic.AlignmentInViewport)
    UI.userWidget:SetPadding(optUI._generic.Padding)
    UI.userWidget:AddToViewport(optUI._generic.zOrder)
    UI.userWidget:SetVisibility(ESlateVisibility.Visible)

    UI.canvas:AddChildToCanvas(UI.menu)
    UI.menu.ActiveColorImage.RenderTransformPivot = optUI.paint.ActiveColorImage_RenderTransformPivot
    UI.menu.ActiveColorImage.RenderTransform.Scale = optUI.paint.ActiveColorImage_RenderTransform_Scale
    verticalBox:AddChildToVerticalBox(UI.menu.ActiveColorImage)

    UI.menu.CreativeTerrainPlanetColorPicker.Padding = optUI.paint.CreativeTerrainPlanetColorPicker_Padding
    verticalBox:AddChildToVerticalBox(UI.menu.CreativeTerrainPlanetColorPicker)

    UI.menu:RemoveFromParent()

    log.debug("UI created (paint).")

    return true
end

local function showUI()
    if UI.userWidget and UI.userWidget:IsValid() then
        UI.userWidget:SetVisibility(ESlateVisibility.Visible)
    else
        createUI()
    end

    updateUI()
end

local function hideUI()
    if UI.userWidget and UI.userWidget:IsValid() then
        UI.userWidget:SetVisibility(ESlateVisibility.Hidden)
    end
    updateParams()
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
    local deformTool = _self:get() ---@type ASmallDeform_TERRAIN_EXPERIMENTAL_C

    if _justActivated:get() == true then
        -- change current mode to ColorPaint
        deformTool.Operation = EDeformType.ColorPaint

        MaterialIndexImage = _G.MaterialIndexImage

        updateParams()
    end

    if _isUsingTool:get() == false then
        return
    end

    local controller = _controller:get() ---@type APlayController
    local toolHit = _toolHit:get() ---@type FHitResult

    if deformTool.Operation == EDeformType.ColorPaint then
        _isUsingTool:set(false)
    else
        return
    end

    controller:ClientDoDeformation({
        AutoCreateResourceEfficiency = 0,
        CreativeModeNoResourceCollection = false,
        DeltaTime = 0.03299999982118, -- ???
        ForceRemoveDecorators = false,
        HardnessPenetration = 0,
        Instigator = nil,
        Intensity = 0,
        Location = { X = toolHit.Location.X, Y = toolHit.Location.Y, Z = toolHit.Location.Z },
        MaterialIndex = MaterialIndexImage,
        Normal = { X = toolHit.Normal.X, Y = toolHit.Normal.Y, Z = toolHit.Normal.Z },
        Operation = EDeformType.ColorPaint,
        Scale = deformTool.BaseBrushIndicatorScale * deformTool.BaseBrushDeformationScale * params.SCALE,
        SequenceNumber = 0,
        Shape = 0,
        bEasyUnbury = false,
        bUseAlternatePolygonization = true
    })
end

---@param self UTerrainToolCreativeMenu_C
---@param SelectedColor FLinearColor
---@param SelectedColorIndex int32
---@param PaintType EPaintIndexType
local function hook_TerrainToolCreativeMenu_OnColorAndTypePicked(self, SelectedColor, SelectedColorIndex, PaintType)
    MaterialIndexImage = SelectedColorIndex

    if UI.materialIndex:IsValid() then
        UI.materialIndex:SetText(FText(tostring(SelectedColorIndex)))
    end
end

---@param self RemoteUnrealParam
local function hook_Planet_Marker_HandlePlanetMarkerSelected(self)
    UI.menu:Destruct()
    UI.menu:Construct()
end

local function isUIFocused()
    if not UI.userWidget or not UI.userWidget:IsValid() then
        return false
    end
    if not UI.menu or not UI.menu:IsValid() then
        return false
    end

    return UI.userWidget:HasFocusedDescendants() or UI.menu:HasFocusedDescendants()
end

---@type Method__Paint
return {
    params = params,
    hook_DeformTool_HandleTerrainTool = hook_HandleTerrainTool,
    hook_TerrainToolCreativeMenu_OnColorAndTypePicked = hook_TerrainToolCreativeMenu_OnColorAndTypePicked,
    hook_Planet_Marker_HandlePlanetMarkerSelected = hook_Planet_Marker_HandlePlanetMarkerSelected,
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
