local MethodName = "auto"

local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local vec3 = Vec3
local format = string.format
local mathHuge = math.huge

local Presets, PresetNamesList = {}, {}
local CurrentPreset ---@type Method__Auto__PRESET
local CurrentPresetName = "" ---@type string

local CurrentFile = debug.getinfo(1, "S").source

-- load PARAMS global table
local paramsFile = func.getParamsFile(CurrentFile, true)
local params = func.loadParamsFile(paramsFile, true) ---@type Method__Auto__PARAMS

local utils = require("lib.lua-mods-libs.utils")

local currentModDirectory = debug.getinfo(1, "S").source:gsub("\\", "/"):match("@?(.+)/[Ss]cripts/")

local World = UEHelpers:GetWorld()
local PlanetCenter = { X = 0, Y = 0, Z = 0 } ---@type FVector
local PlanetName = ""
local DesignAstro ---@type UObject|ADesignAstro_C
local Capsule = { halfHeight = 0, radius = 0 } ---@type Method__Auto__Capsule
local MaxSpeed = math.huge
local SlideStartSpeedThreshold = math.huge

local UI = {}
local options = OPTIONS
local optUI = OPTIONS_UI
local Angle = 0
local ExpectedAngle = mathHuge
local MainLoops = {}

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

---@type ECheckBoxState
local ECheckBoxState = {
    Unchecked    = 0,
    Checked      = 1,
    Undetermined = 2,
}

local function setAngle(angle)
    Angle = angle
    UI.angle:SetText(FText(tostring(angle)))

    if angle == ExpectedAngle then
        UI.expected_angle:SetText(FText(tostring(mathHuge)))
    end
end

local function setExpectedAngle(angle)
    ExpectedAngle = angle
    UI.expected_angle:SetText(FText(tostring(angle)))
end

---@return Method__Auto__PRESET[]
---@return table
local function loadAllPresets()
    ---@type string[]
    local fileList = utils.getFileList(currentModDirectory .. "/Scripts/methods/" .. MethodName .. "/presets/",
        ".lua")
    local presets = {}
    local presetNamesList = {}

    for index, file in ipairs(fileList) do
        local presetName = file:gsub("\\", "/"):match("([^/]+)[.]lua$")
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

local function writeParamsFile()
    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    if params.LATEST_PRESET == nil then params.LATEST_PRESET = "" end
    if params.LOOP_DELAY == nil then params.LOOP_DELAY = 250 end
    if params.SPEED_LIMIT == nil then params.SPEED_LIMIT = 1360.0 end
    if params.NO_SLIDING == nil then params.NO_SLIDING = false end

    file:write(format(
        [[---@type Method__Auto__PARAMS
return {
LATEST_PRESET="%s",
LOOP_DELAY=%d,
SPEED_LIMIT=%.16g,
NO_SLIDING=%s
}]],
        params.LATEST_PRESET,
        params.LOOP_DELAY,
        params.SPEED_LIMIT,
        params.NO_SLIDING
    ))

    file:close()
end

local function updateParams()
    local updateRequired = false

    -- select preset from the UI
    local currentPresetName = UI.comboBox_presets.SelectedOption:ToString()
    if currentPresetName == "" then
        UI.comboBox_presets:SetSelectedIndex(0)
        currentPresetName = UI.comboBox_presets.SelectedOption:ToString()
    end
    if currentPresetName ~= params.LATEST_PRESET then
        params.LATEST_PRESET = currentPresetName
        updateRequired = true
    end

    -- get loop delay from the UI
    local loopDelay = tonumber(UI.loop_delay:GetText():ToString())
    if loopDelay == nil then
        loopDelay = params.LOOP_DELAY
        UI.loop_delay:SetText(FText(tostring(loopDelay)))
    end
    if loopDelay ~= params.LOOP_DELAY then
        params.LOOP_DELAY = loopDelay
        updateRequired = true
    end

    -- get speed limit from the UI
    local speedLimit = tonumber(UI.speed_limit:GetText():ToString())
    if speedLimit == nil then
        speedLimit = params.SPEED_LIMIT
        UI.speed_limit:SetText(FText(tostring(speedLimit)))
    end
    speedLimit = math.min(1360, speedLimit) -- 1360.0 = game default
    if speedLimit ~= params.SPEED_LIMIT then
        params.SPEED_LIMIT = speedLimit
        updateRequired = true
    end

    -- get no sliding CheckBox state
    local noSliding = UI.noSlidingCheckBox.CheckedState == ECheckBoxState.Checked
    if params.NO_SLIDING ~= noSliding then
        params.NO_SLIDING = noSliding
        updateRequired = true
    end

    if updateRequired then
        writeParamsFile()
    end
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
    params = func.loadParamsFile(paramsFile) ---@type Method__Auto__PARAMS

    setAngle(0)
    setExpectedAngle(mathHuge)
    if UI.loop_delay:IsValid() then
        UI.loop_delay:SetText(FText(tostring(params.LOOP_DELAY)))
    end

    if UI.speed_limit:IsValid() then
        params.SPEED_LIMIT = math.min(1360, params.SPEED_LIMIT) -- 1360.0 = game default
        UI.speed_limit:SetText(FText(tostring(params.SPEED_LIMIT)))
    end

    if UI.noSlidingCheckBox:IsValid() then
        UI.noSlidingCheckBox:SetCheckedState(params.NO_SLIDING == true and
            ECheckBoxState.Checked or ECheckBoxState.Unchecked)
    end

    local presets, presetNamesList = loadAllPresets()

    -- set semi-global variables
    Presets, PresetNamesList = presets, presetNamesList

    if UI.comboBox_presets:IsValid() then
        UI.comboBox_presets:ClearOptions()

        -- add presets to ComboBox
        for _, preset in ipairs(PresetNamesList) do
            UI.comboBox_presets:AddOption(preset)
        end
        -- select latest selected preset
        ---@diagnostic disable-next-line: param-type-mismatch
        if params.LATEST_PRESET and params.LATEST_PRESET ~= "" and UI.comboBox_presets:FindOptionIndex(params.LATEST_PRESET) ~= -1 then
            ---@diagnostic disable-next-line: param-type-mismatch
            UI.comboBox_presets:SetSelectedOption(params.LATEST_PRESET)
        else
            UI.comboBox_presets:SetSelectedIndex(0)
            params.LATEST_PRESET = UI.comboBox_presets:GetOptionAtIndex(0):ToString()
        end
    end

    -- set semi-global variables
    CurrentPresetName = params.LATEST_PRESET
    CurrentPreset = Presets[CurrentPresetName]
end

local function stopAllMainLoops()
    for i = 1, #MainLoops, 1 do
        MainLoops[i] = true
    end
end

local function startMainLoop()
    stopAllMainLoops()

    if not DesignAstro:IsValid() then
        return
    end

    table.insert(MainLoops, false)
    local loopIndex = #MainLoops

    LoopAsync(params.LOOP_DELAY or 250, function()
        -- The angle will not change if the character is not holding the Terrain tool or moving,
        -- or if the loop must stop.
        if MainLoops[loopIndex] == false and DesignAstro.HoldingTool == true and DesignAstro.CurrentSpeed > 0 then
            if ExpectedAngle == mathHuge then
                return MainLoops[loopIndex]
            end
            if Angle < ExpectedAngle then
                setAngle(Angle + 1)
            elseif Angle > ExpectedAngle then
                setAngle(Angle - 1)
            elseif Angle == ExpectedAngle then
                setExpectedAngle(mathHuge)
            end
        end

        return MainLoops[loopIndex]
    end)
end

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createUI()
    local prefix = "TerrainMod_auto_"

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
    textBlock_title.Font.Size = optUI.auto.font_size
    textBlock_title.Font.FontObject = fontObj
    textBlock_title:SetText(FText(optUI.auto.txt.title))
    textBlock_title:SetToolTipText(FText(optUI.auto.txt.description_tip))

    --#region loop delay
    ---@type UHorizontalBox
    local horizontalBox_loop_delay = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_loop_delay"))

    ---@type UTextBlock
    UI.textBlock_loop_delay = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_loop_delay"))
    UI.textBlock_loop_delay.Font.Size = optUI.auto.font_size
    UI.textBlock_loop_delay.Font.FontObject = fontObj
    UI.textBlock_loop_delay:SetText(FText(optUI.auto.txt.loop_delay))
    UI.textBlock_loop_delay:SetToolTipText(FText(optUI.auto.txt.loop_delay_tip))

    ---@type USpacer
    local spacer_loop_delay = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_loop_delay"))
    spacer_loop_delay:SetSize(optUI.auto.spacer_size)

    ---@type UEditableTextBox
    UI.loop_delay = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_loop_delay"))
    UI.loop_delay.WidgetStyle.Font.Size = optUI.auto.font_size
    UI.loop_delay.WidgetStyle.Font.FontObject = fontObj
    UI.loop_delay.SelectAllTextWhenFocused = true

    horizontalBox_loop_delay:AddChildToHorizontalBox(UI.textBlock_loop_delay)
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
    UI.angle.SelectAllTextWhenFocused = true

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
    UI.expected_angle.SelectAllTextWhenFocused = true

    horizontalBox_expected_angle:AddChildToHorizontalBox(textBlock_expected_angle)
    horizontalBox_expected_angle:AddChildToHorizontalBox(spacer_expected_angle)
    horizontalBox_expected_angle:AddChildToHorizontalBox(UI.expected_angle)
    --#endregion

    --#region speed limit
    ---@type UHorizontalBox
    local horizontalBox_speed_limit = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_speed_limit"))
    horizontalBox_speed_limit:SetToolTipText(FText(optUI.auto.txt.speed_limit_tip))

    ---@type UTextBlock
    local textBlock_speed_limit = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_speed_limit"))
    textBlock_speed_limit.Font.Size = optUI.auto.font_size
    textBlock_speed_limit.Font.FontObject = fontObj
    textBlock_speed_limit:SetText(FText(optUI.auto.txt.speed_limit))

    ---@type USpacer
    local spacer_speed_limit = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_speed_limit"))
    spacer_speed_limit:SetSize(optUI.auto.spacer_size)

    ---@type UEditableTextBox
    UI.speed_limit = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_speed_limit"))
    UI.speed_limit.WidgetStyle.Font.Size = optUI.auto.font_size
    UI.speed_limit.WidgetStyle.Font.FontObject = fontObj
    UI.speed_limit.SelectAllTextWhenFocused = true

    horizontalBox_speed_limit:AddChildToHorizontalBox(textBlock_speed_limit)
    horizontalBox_speed_limit:AddChildToHorizontalBox(spacer_speed_limit)
    horizontalBox_speed_limit:AddChildToHorizontalBox(UI.speed_limit)
    --#endregion

    --#region no sliding
    ---@type UHorizontalBox
    local horizontalBox_no_sliding = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_no_sliding"))
    horizontalBox_no_sliding:SetToolTipText(FText(optUI.auto.txt.no_sliding_tip))

    ---@type UTextBlock
    local textBlock_no_sliding = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_no_sliding"))
    textBlock_no_sliding.Font.Size = optUI.auto.font_size
    textBlock_no_sliding.Font.FontObject = fontObj
    textBlock_no_sliding:SetText(FText(optUI.auto.txt.no_sliding))

    ---@type USpacer
    local spacer_no_sliding = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_no_sliding"))
    spacer_no_sliding:SetSize(optUI.auto.spacer_size)

    ---@type UCheckBox
    UI.noSlidingCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_no_sliding"))

    horizontalBox_no_sliding:AddChildToHorizontalBox(textBlock_no_sliding)
    horizontalBox_no_sliding:AddChildToHorizontalBox(spacer_no_sliding)
    horizontalBox_no_sliding:AddChildToHorizontalBox(UI.noSlidingCheckBox)
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
    verticalBox:AddChildToVerticalBox(horizontalBox_speed_limit)
    verticalBox:AddChildToVerticalBox(horizontalBox_no_sliding)
    verticalBox:AddChildToVerticalBox(UI.comboBox_presets)

    UI.userWidget:SetAnchorsInViewport(optUI._generic.AnchorsInViewport)
    UI.userWidget:SetAlignmentInViewport(optUI._generic.AlignmentInViewport)
    UI.userWidget:SetPadding(optUI._generic.Padding)
    UI.userWidget:AddToViewport(optUI._generic.zOrder)
    UI.userWidget:SetVisibility(ESlateVisibility.Visible)

    log.debug(format("UI created (%s).", MethodName))

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
    stopAllMainLoops()

    if UI.userWidget and UI.userWidget:IsValid() then
        UI.userWidget:SetVisibility(ESlateVisibility.Hidden)
    end

    -- restore game values
    local designAstro = getDesignAstro()
    if designAstro:IsValid() then
        local moveComp = designAstro.AstroMovementComponent
        if moveComp:IsValid() then
            if MaxSpeed ~= mathHuge then
                moveComp.MaxSpeed = MaxSpeed
            end
            if SlideStartSpeedThreshold ~= mathHuge then
                moveComp.SlideStartSpeedThreshold = SlideStartSpeedThreshold
            end
        end
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
    if CurrentPresetName == "" then
        return -- no preset found
    end

    local controller = _controller:get() ---@type APlayController
    local justActivated = _justActivated:get() ---@type boolean

    if justActivated == true then
        updateParams()

        startMainLoop()

        -- select preset from the UI
        CurrentPresetName = UI.comboBox_presets.SelectedOption:ToString()
        CurrentPreset = Presets[CurrentPresetName]

        -- Planet center is (0, 0, 0) for SYLVA.
        PlanetCenter = controller:GetLocalSolarBody():GetCenter()
        PlanetName = controller:GetLocalSolarBody().Name:ToString()

        World = UEHelpers:GetWorld()

        -- get angle from UI
        Angle = tonumber(UI.angle:GetText():ToString()) or 0

        -- get selected angle from UI
        ExpectedAngle = tonumber(UI.expected_angle:GetText():ToString()) or mathHuge

        DesignAstro = controller:GetAstroCharacter()
        if not DesignAstro:IsValid() then
            log.warn("DesignAstro is not valid.")
            return
        end ---@cast DesignAstro ADesignAstro_C

        -- get speed limit from UI
        local speedLimit = tonumber(UI.speed_limit:GetText():ToString())
        if speedLimit ~= nil and speedLimit > 0 then
            speedLimit = math.min(1360, speedLimit) -- 1360.0 = game default

            if MaxSpeed == mathHuge then
                -- save game value
                MaxSpeed = DesignAstro.AstroMovementComponent.MaxSpeed
            end

            DesignAstro.AstroMovementComponent.MaxSpeed = speedLimit
        end

        local noSliding = UI.noSlidingCheckBox.CheckedState == ECheckBoxState.Checked
        if noSliding then
            if SlideStartSpeedThreshold == mathHuge then
                -- save game value
                SlideStartSpeedThreshold = DesignAstro.AstroCharacterMovement.SlideStartSpeedThreshold
            end

            -- This very high number should disable sliding.
            DesignAstro.AstroCharacterMovement.SlideStartSpeedThreshold = 2 ^ 126
        end

        log.debug(format("Angle: %.16g", Angle))

        if CurrentPresetName == "" then
            log.warn("No preset found.")
            return
        end
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

        local toolHit = _toolHit:get() ---@type FHitResult
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

local function isUIFocused()
    if not UI.userWidget or not UI.userWidget:IsValid() then
        return false
    end

    return UI.userWidget:HasFocusedDescendants()
end

---@type Method__Auto
return {
    params = params,
    hook_DeformTool_HandleTerrainTool = hook_HandleTerrainTool,
    onLoad = function()
        updateGameVariables()
        showUI()
    end,
    onUnload = function()
        hideUI()
    end,
    onUpdate = function()
        updateGameVariables()
        updateUI()
    end,
    onClientRestart = function()
        updateGameVariables()
    end,
    isUIFocused = isUIFocused,
}
