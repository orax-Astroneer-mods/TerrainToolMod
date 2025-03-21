--[[
Terrain colors
  https://astroneer.fandom.com/wiki/Terrain_Analyzer#Terrain_colors
]]

local methodName = "paint"

local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local format = string.format

-- load PARAMS global table
local paramsFile = func.getParamsFile()
local params = func.loadParamsFile(paramsFile) ---@type Method__Paint__PARAMS

local FirstInit = true
local options = OPTIONS
local optUI = OPTIONS_UI
local UI = {}
local materialIndexImage = 0

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
    if params.MATERIAL_INDEX == nil then params.MATERIAL_INDEX = 0 end

    file:write(format(
        [[return {
    MATERIAL_INDEX=%d,
    SCALE=%.16g,
    }]], params.MATERIAL_INDEX, params.SCALE))

    file:close()
end

local function updateParamsFile()
    local updateRequired = false

    local materialIndex = tonumber(UI.materialIndex:GetText():ToString())
    if materialIndex == nil then
        materialIndex = params.MATERIAL_INDEX
        UI.materialIndex:SetText(FText(tostring(materialIndex)))
    end
    if materialIndex ~= params.MATERIAL_INDEX then
        params.MATERIAL_INDEX = materialIndex
        updateRequired = true
    end

    local scale = tonumber(UI.scale:GetText():ToString())
    if scale == nil then
        scale = params.SCALE
        UI.scale:SetText(FText(tostring(scale)))
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
    params = func.loadParamsFile(paramsFile)

    updateParamsFile()

    if materialIndexImage ~= params.MATERIAL_INDEX then
        log.debug("Update active material index image.")
        UI.menu:OnColorAndTypePicked({ R = 0, G = 0, B = 0, A = 0 }, params.MATERIAL_INDEX, EPaintIndexType
            .PlanetPalette)
    end
end

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createUI()
    local prefix = "TerrainMod_paint_"

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
    UI.scale:SetText(FText(tostring(params.SCALE)))

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
    local slot_menu = UI.canvas:AddChildToCanvas(UI.menu)
    slot:SetAutoSize(true)

    UI.userWidget:SetPositionInViewport(optUI.paint.positionInViewport, true)
    UI.userWidget:AddToViewport(optUI.paint.zOrder)
    UI.userWidget:SetVisibility(ESlateVisibility.Visible)

    UI.menu.TerrainToolCreativeQuitButton:RemoveFromParent()
    UI.menu.FakeTabBarButtonBG:RemoveFromParent()
    UI.menu.FakeTabBarSeparator:RemoveFromParent()
    UI.menu.ToolStrengthSlider:RemoveFromParent()
    UI.menu.ToolSizeSlider:RemoveFromParent()
    UI.menu.ToolRangeSlider:RemoveFromParent()
    UI.menu.IgnoreHardnessCheckbox:RemoveFromParent()
    UI.menu.ActiveColorText:RemoveFromParent()
    UI.menu.CreativeTerrainColorPicker:RemoveFromParent()
    UI.menu.CreativeTerrainSpecialColorPicker:RemoveFromParent()
    UI.menu.ClickOutOfMenuButton:RemoveFromParent()
    UI.menu.Image_0:RemoveFromParent()
    UI.menu.MenuBackingButton:RemoveFromParent()
    UI.menu.TerrainToolCreativeQuitButton:RemoveFromParent()

    slot_menu:SetAutoSize(true)
    slot_menu:SetPosition(optUI.paint.creativeMenu_position)
    UI.menu.ActiveColorImage:SetRenderTranslation(optUI.paint.activeColorImage_translation)
    UI.menu.CreativeTerrainPlanetColorPicker:SetPadding(optUI.paint.colorPicker_padding)

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
    updateParamsFile()
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
    local deformTool = self:get() ---@type ASmallDeform_TERRAIN_EXPERIMENTAL_C

    if justActivated:get() == true then
        deformTool.Operation = EDeformType.ColorPaint

        updateUI()
    end

    if isUsingTool:get() == false then
        return
    end

    controller = controller:get() ---@cast controller APlayController
    toolHit = toolHit:get() ---@cast toolHit FHitResult

    if deformTool.Operation == EDeformType.ColorPaint then
        isUsingTool:set(false)
    elseif deformTool.Operation == EDeformType.Subtract or
        deformTool.Operation == EDeformType.ColorPick or
        deformTool.Operation == EDeformType.Crater or
        deformTool.Operation == EDeformType.RevertModifications then
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
        MaterialIndex = params.MATERIAL_INDEX,
        Normal = { X = toolHit.Normal.X, Y = toolHit.Normal.Y, Z = toolHit.Normal.Z },
        Operation = EDeformType.ColorPaint,
        Scale = deformTool.BaseBrushIndicatorScale * deformTool.BaseBrushDeformationScale * params.SCALE,
        SequenceNumber = 0,
        Shape = 0,
        bEasyUnbury = false,
        bUseAlternatePolygonization = true
    })
end

local function init()
    if FirstInit == true then
        RegisterHook("/Game/UI/CreativeMode/TerrainToolCreativeMenu.TerrainToolCreativeMenu_C:OnColorAndTypePicked",
            function(self, SelectedColor, SelectedColorIndex, PaintType)
                SelectedColor = SelectedColor:get()
                SelectedColorIndex = SelectedColorIndex:get()
                PaintType = PaintType:get()

                ---@cast SelectedColor FLinearColor
                ---@cast SelectedColorIndex int32
                ---@cast PaintType EPaintIndexType

                if PaintType == EPaintIndexType.PlanetPalette then
                    if params.MATERIAL_INDEX ~= SelectedColorIndex then
                        params.MATERIAL_INDEX = SelectedColorIndex
                    end
                    UI.materialIndex:SetText(FText(tostring(SelectedColorIndex)))
                end

                materialIndexImage = SelectedColorIndex
            end)
    end

    FirstInit = false
end

---@type Method__Paint
return {
    params = params,
    handleTerrainTool_hook = handleTerrainTool_hook,
    writeParamsFile = writeParamsFile,
    onEnable = function()
        init()
        showUI()
    end,
    onDisable = function()
        hideUI()
    end,
    onLoad = function()
        init()
        showUI()
    end,
    onUnload = function()
        hideUI()
    end,
    onUpdate = function()
        updateUI()
    end,
    onClientRestart = init,
}
