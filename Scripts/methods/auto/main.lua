local methodName = "auto"

local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local vec3 = Vec3
local insert = table.insert
local format = string.format
local rad, mathHuge = math.rad, math.huge

local writeParamsFile = function() end

local Presets, PresetNamesList = {}, {}
local CurrentPreset ---@type Method__Auto__PRESET
local CurrentPresetName = "" ---@type string

-- load PARAMS global table
local paramsFile = func.getParamsFile()
local params = func.loadParamsFile(paramsFile) ---@type Method__Auto__PARAMS

local utils = require("lib.lua-mods-libs.utils")

local currentModDirectory = debug.getinfo(1, "S").source:match("@?(.+\\Mods\\[^\\]+)")

local World = UEHelpers:GetWorld()
local PlanetCenter = { X = 0, Y = 0, Z = 0 } ---@type FVector
local PlanetName = ""
local DesignAstro ---@type UObject|ADesignAstro_C
local Capsule = { halfHeight = 0, radius = 0 } ---@type Method__Auto__Capsule

local UI = {}
local options = OPTIONS
local optUI = OPTIONS_UI
local Angle = 0
local ExpectedAngle = mathHuge
local MainLoop = {
    enabled = false,
    stopping = true
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

---@type ESlateVisibility
local ESlateVisibility = {
    Visible = 0,
    Collapsed = 1,
    Hidden = 2,
    HitTestInvisible = 3,
    SelfHitTestInvisible = 4,
    ESlateVisibility_MAX = 5
}

local function setAngle(angle)
    Angle = angle
    UI.angle:SetText(FText(tostring(angle)))
end

local function setExpectedAngle(angle)
    ExpectedAngle = angle
    UI.expected_angle:SetText(FText(tostring(angle)))
end

---@return Method__Auto__PRESET[]
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

---@return UObject|ADesignAstro_C
local function getDesignAstro()
    local designAstro = UEHelpers:GetPlayer() ---@cast designAstro ADesignAstro_C
    if not designAstro:IsValid() then
        return CreateInvalidObject()
    end

    return designAstro
end

local function updateGameVariables()
    World = UEHelpers:GetWorld()
    local designAstro = getDesignAstro()

    if designAstro:IsValid() then ---@cast designAstro ADesignAstro_C
        DesignAstro = designAstro
        PlanetCenter = designAstro:GetLocalSolarBody():GetCenter()
        PlanetName = designAstro:GetLocalSolarBody().Name:ToString()

        local capsule = designAstro:K2_GetRootComponent() ---@cast capsule UCapsuleComponent
        Capsule.halfHeight = capsule:GetScaledCapsuleHalfHeight()
        Capsule.radius = capsule:GetScaledCapsuleRadius()
    end
end

local function updateUI()
    setAngle(0)
    setExpectedAngle(mathHuge)
    UI.loop_delay:SetText(FText(tostring(params.LOOP_DELAY)))

    local presets, presetNamesList = loadAllPresets()

    -- set semi-global variables
    Presets, PresetNamesList = presets, presetNamesList

    UI.comboBox_presets:ClearOptions()

    -- add presets to ComboBox
    for _, preset in ipairs(PresetNamesList) do
        UI.comboBox_presets:AddOption(preset)
    end
    -- select last selected preset
    ---@diagnostic disable-next-line: param-type-mismatch
    if params.LAST_PRESET and params.LAST_PRESET ~= "" and UI.comboBox_presets:FindOptionIndex(params.LAST_PRESET) ~= -1 then
        ---@diagnostic disable-next-line: param-type-mismatch
        UI.comboBox_presets:SetSelectedOption(params.LAST_PRESET)
    else
        UI.comboBox_presets:SetSelectedIndex(0)
        params.LAST_PRESET = UI.comboBox_presets:GetOptionAtIndex(0):ToString()
    end

    -- set semi-global variables
    CurrentPresetName = params.LAST_PRESET
    CurrentPreset = Presets[CurrentPresetName]
end

local function startMainLoop()
    MainLoop.stopping = false

    if MainLoop.enabled then
        log.debug("Main loop already enabled.")
        return
    end

    LoopAsync(params.LOOP_DELAY or 250, function()
        -- The angle will not change if the character is not holding the Terrain tool or moving.
        if DesignAstro:IsValid() and (DesignAstro.HoldingTool == false or DesignAstro.CurrentSpeed == 0) then
            return false
        end

        if ExpectedAngle == mathHuge then
            return MainLoop.stopping
        end
        if Angle < ExpectedAngle then
            setAngle(Angle + 1)
        elseif Angle > ExpectedAngle then
            setAngle(Angle - 1)
        elseif Angle == ExpectedAngle then
            setExpectedAngle(mathHuge)
        end

        return MainLoop.stopping
    end)
end

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createUI()
    local prefix = "TerrainMod_auto_"

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
    textBlock_title.Font.Size = optUI.auto.font_size
    textBlock_title.Font.FontObject = fontObj
    textBlock_title:SetText(FText(optUI.auto.txt.title))
    textBlock_title:SetToolTipText(FText(optUI.auto.txt.description_tip))

    --#region loop delay
    ---@type UHorizontalBox
    local horizontalBox_loop_delay = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_loop_delay"))

    ---@type UTextBlock
    local textBlock_loop_delay = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_loop_delay"))
    textBlock_loop_delay.Font.Size = optUI.auto.font_size
    textBlock_loop_delay.Font.FontObject = fontObj
    textBlock_loop_delay:SetText(FText(optUI.auto.txt.loop_delay))
    textBlock_loop_delay:SetToolTipText(FText(optUI.auto.txt.loop_delay_tip))

    ---@type USpacer
    local spacer_loop_delay = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_loop_delay"))
    spacer_loop_delay:SetSize(optUI.auto.spacer_size)

    ---@type UEditableTextBox
    UI.loop_delay = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_loop_delay"))
    UI.loop_delay.WidgetStyle.Font.Size = optUI.auto.font_size
    UI.loop_delay.WidgetStyle.Font.FontObject = fontObj

    horizontalBox_loop_delay:AddChildToHorizontalBox(textBlock_loop_delay)
    horizontalBox_loop_delay:AddChildToHorizontalBox(spacer_loop_delay)
    horizontalBox_loop_delay:AddChildToHorizontalBox(UI.loop_delay)
    --#endregion

    --#region angle
    ---@type UHorizontalBox
    local horizontalBox_angle = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_angle"))
    horizontalBox_angle:SetToolTipText(FText(format(optUI.auto.txt.angle_tip,
        func.getKeybindName(options.enable_handleTerrainTool_Key, options.enable_handleTerrainTool_ModifierKeys))))

    ---@type UTextBlock
    local textBlock_angle = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_angle"))
    textBlock_angle.Font.Size = optUI.auto.font_size
    textBlock_angle.Font.FontObject = fontObj
    textBlock_angle:SetText(FText(optUI.auto.txt.angle))

    ---@type USpacer
    local spacer_angle = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_angle"))
    spacer_angle:SetSize(optUI.auto.spacer_size)

    ---@type UEditableTextBox
    UI.angle = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_angle"))
    UI.angle.WidgetStyle.Font.Size = optUI.auto.font_size
    UI.angle.WidgetStyle.Font.FontObject = fontObj

    horizontalBox_angle:AddChildToHorizontalBox(textBlock_angle)
    horizontalBox_angle:AddChildToHorizontalBox(spacer_angle)
    horizontalBox_angle:AddChildToHorizontalBox(UI.angle)
    --#endregion

    --#region expected angle
    ---@type UHorizontalBox
    local horizontalBox_expected_angle = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_expected_angle"))
    horizontalBox_expected_angle:SetToolTipText(FText(optUI.auto.txt.expected_angle_tip))

    ---@type UTextBlock
    local textBlock_expected_angle = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_expected_angle"))
    textBlock_expected_angle.Font.Size = optUI.auto.font_size
    textBlock_expected_angle.Font.FontObject = fontObj
    textBlock_expected_angle:SetText(FText(optUI.auto.txt.expected_angle))

    ---@type USpacer
    local spacer_expected_angle = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_expected_angle"))
    spacer_expected_angle:SetSize(optUI.auto.spacer_size)

    ---@type UEditableTextBox
    UI.expected_angle = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_expected_angle"))
    UI.expected_angle.WidgetStyle.Font.Size = optUI.auto.font_size
    UI.expected_angle.WidgetStyle.Font.FontObject = fontObj

    horizontalBox_expected_angle:AddChildToHorizontalBox(textBlock_expected_angle)
    horizontalBox_expected_angle:AddChildToHorizontalBox(spacer_expected_angle)
    horizontalBox_expected_angle:AddChildToHorizontalBox(UI.expected_angle)
    --#endregion

    --#region presets
    ---@type UComboBoxString
    UI.comboBox_presets = StaticConstructObject(StaticFindObject("/Script/UMG.ComboBoxString"), verticalBox,
        FName("ComboBox_presets")) ---@type UComboBoxString
    UI.comboBox_presets.Font.FontObject = fontObj
    UI.comboBox_presets:SetToolTipText(FText(format(optUI.auto.txt.presetsComboBox_tip,
        func.getKeybindName(options.enable_handleTerrainTool_Key, options.enable_handleTerrainTool_ModifierKeys))))
    --#endregion

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    local slot = UI.canvas:AddChildToCanvas(verticalBox)
    slot:SetAutoSize(true)

    verticalBox:AddChildToVerticalBox(textBlock_title)
    verticalBox:AddChildToVerticalBox(horizontalBox_loop_delay)
    verticalBox:AddChildToVerticalBox(horizontalBox_angle)
    verticalBox:AddChildToVerticalBox(horizontalBox_expected_angle)
    verticalBox:AddChildToVerticalBox(UI.comboBox_presets)

    UI.userWidget:SetPositionInViewport(optUI.auto.positionInViewport, true)
    UI.userWidget:AddToViewport(optUI.auto.zOrder)
    UI.userWidget:SetVisibility(ESlateVisibility.Visible)

    writeParamsFile()

    log.debug("UI created (auto).")

    return true
end

local function showUI()
    startMainLoop()

    if UI.userWidget and UI.userWidget:IsValid() then
        UI.userWidget:SetVisibility(ESlateVisibility.Visible)
    else
        createUI()
    end

    updateUI()
end

local function hideUI()
    MainLoop.stopping = true

    if UI.userWidget and UI.userWidget:IsValid() then
        UI.userWidget:SetVisibility(ESlateVisibility.Hidden)
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
    controller = controller:get()
    justActivated = justActivated:get()

    ---@cast controller APlayController
    -- ---@cast toolHit FHitResult
    -- ---@cast clickResult FClickResult
    -- ---@cast startedInteraction boolean
    -- ---@cast endedInteraction boolean
    -- ---@cast isUsingTool boolean
    ---@cast justActivated boolean
    -- ---@cast canUse boolean

    if justActivated == true then
        World = UEHelpers:GetWorld()

        -- select preset from UI
        CurrentPresetName = UI.comboBox_presets:GetSelectedOption():ToString()
        if CurrentPresetName == "" then
            log.warn("No preset found.")
            return
        end
        CurrentPreset = Presets[CurrentPresetName]

        if params.LAST_PRESET ~= CurrentPresetName then
            params.LAST_PRESET = CurrentPresetName
            writeParamsFile()
        end

        -- get angle from UI
        Angle = tonumber(UI.angle:GetText():ToString()) or 0

        -- get selected angle from UI
        ExpectedAngle = tonumber(UI.expected_angle:GetText():ToString()) or mathHuge

        -- Planet center is (0, 0, 0) for SYLVA.
        PlanetCenter = controller:GetLocalSolarBody():GetCenter()
        PlanetName = controller:GetLocalSolarBody().Name:ToString()

        ---@diagnostic disable-next-line: cast-local-type
        DesignAstro = controller:GetAstroCharacter() ---@cast DesignAstro ADesignAstro_C

        log.debug(format("Angle: %.16g", Angle))
    end

    if controller:WasInputKeyJustPressed({ KeyName = FName(options.auto__decrease_angle_KeyName) }) then
        if controller:IsInputKeyDown({ KeyName = FName(options.auto__increase_or_decrease_expected_angle_KeyName) }) then
            if ExpectedAngle == mathHuge then
                setExpectedAngle(Angle - 5)
            else
                setExpectedAngle(ExpectedAngle - 5)
            end
        else
            setAngle(Angle - 1)
            log.debug(format("Angle: %.16g", Angle))
        end
    elseif controller:WasInputKeyJustPressed({ KeyName = FName(options.auto__increase_angle_KeyName) }) then
        if controller:IsInputKeyDown({ KeyName = FName(options.auto__increase_or_decrease_expected_angle_KeyName) }) then
            if ExpectedAngle == mathHuge then
                setExpectedAngle(Angle + 5)
            else
                setExpectedAngle(ExpectedAngle + 5)
            end
        else
            setAngle(Angle + 1)
            log.debug(format("Angle: %.16g", Angle))
        end
    elseif controller:WasInputKeyJustPressed({ KeyName = FName(options.auto__set_angle_to_expectedAngle_KeyName) }) and
        controller:IsInputKeyDown({ KeyName = FName(options.auto__increase_or_decrease_expected_angle_KeyName) }) then
        if ExpectedAngle ~= nil and ExpectedAngle ~= mathHuge then
            setAngle(ExpectedAngle)
        end
    elseif controller:WasInputKeyJustPressed({ KeyName = FName(options.auto__set_angle_to_value1_KeyName) }) then
        setExpectedAngle(45)
    elseif controller:WasInputKeyJustPressed({ KeyName = FName(options.auto__set_angle_to_value2_KeyName) }) then
        setExpectedAngle(-45)
    elseif controller:WasInputKeyJustPressed({ KeyName = FName(options.auto__set_angle_to_zero_KeyName) }) then
        setExpectedAngle(0)
    elseif controller:WasInputKeyJustPressed({ KeyName = FName(options.auto__set_angle_from_slope_KeyName) }) then
        local sign = controller:IsInputKeyDown({ KeyName = FName(options.auto__set_angle_from_slope_Modifier_KeyName) }) and
            -1 or 1

        toolHit = toolHit:get() ---@cast toolHit FHitResult
        local relativeLocation = vec3.new(
            toolHit.Location.X - PlanetCenter.X,
            toolHit.Location.Y - PlanetCenter.Y,
            toolHit.Location.Z - PlanetCenter.Z)

        local angle = math.deg(vec3.angle_to(
            relativeLocation,
            vec3.new(toolHit.Normal.X, toolHit.Normal.Y, toolHit.Normal.Z))) * sign
        log.debug(format("Angle under cursor: %.16g", angle))
        setExpectedAngle(func.roundToBase(angle, 1))
    end

    -- does the character move?
    if DesignAstro.CurrentSpeed == 0 then
        return
    end

    local loc = DesignAstro:K2_GetActorLocation()
    local fw = DesignAstro:GetActorForwardVector()
    local right = DesignAstro:GetActorRightVector()
    local up = DesignAstro:GetActorUpVector()

    local floor = {
        X = loc.X - (up.X * Capsule.halfHeight),
        Y = loc.Y - (up.Y * Capsule.halfHeight),
        Z = loc.Z - (up.Z * Capsule.halfHeight)
    }
    local relativeFloor = {
        X = floor.X - PlanetCenter.X,
        Y = floor.Y - PlanetCenter.Y,
        Z = floor.Z - PlanetCenter.Z
    }

    local altitude = func.getVectorLen(relativeFloor)

    ---@type Method__Auto__PRESET_DeformationParams
    local parameters = {
        angle = Angle,
        altitude = altitude,
        capsule = Capsule,
        character = DesignAstro,
        characterLocation = loc,
        controller = controller,
        floor = floor,
        forward = fw,
        justActivated = justActivated,
        planetCenter = PlanetCenter,
        planetName = PlanetName, -- SYLVA, DESOLO, CALIDOR, VESANIA, NOVUS, GLACIO, ATROX
        relativeFloor = relativeFloor,
        right = right,
        up = up,
        world = World
    }

    CurrentPreset.doDeformation(parameters)
end

writeParamsFile = function()
    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    if params.LAST_PRESET == nil then params.LAST_PRESET = "" end
    if params.LOOP_DELAY == nil then params.LOOP_DELAY = 250 end

    file:write(format(
        [[return {
LAST_PRESET="%s",
LOOP_DELAY=%d
}]], params.LAST_PRESET, params.LOOP_DELAY))

    file:close()
end

local function init()
    updateGameVariables()
end

---@type Method__Auto
return {
    params = params,
    handleTerrainTool_hook = handleTerrainTool_hook,
    writeParamsFile = writeParamsFile,
    onEnable = function()
        updateGameVariables()
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
    onClientRestart = init,
    onUpdate = function()
        updateGameVariables()
        updateUI()
    end
}
