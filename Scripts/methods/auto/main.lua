local UEHelpers = require("UEHelpers")
local func = require("func")

local methodName = "auto"

local log = Log
local vec3 = Vec3
local insert = table.insert
local format = string.format
local rad = math.rad

local writeParamsFile = function() end

local Presets, PresetNamesList = {}, {}
local CurrentPreset ---@type Method__Auto__PRESET
local CurrentPresetName = "" ---@type string

-- load PARAMS global table
local paramsFile = func.getParamsFile()
local params = func.loadParamsFile(paramsFile) ---@type Method__Auto__PARAMS

local sys = UEHelpers.GetKismetSystemLibrary()

local utils = require("lib.lua-mods-libs.utils")

local currentModDirectory = debug.getinfo(1, "S").source:match("@?(.+\\Mods\\[^\\]+)")

local UI = {}

local World = UEHelpers:GetWorld()
local PlanetCenter = { X = 0, Y = 0, Z = 0 } ---@type FVector
local PlanetName = ""
local Angle = 0
local Capsule = { halfHeight = 0, radius = 0 } ---@type Method__Auto__Capsule

local pi2 = math.pi * 2

local EDeformType = EDeformType

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

local ExpectedAngle = math.huge

LoopAsync(250, function()
    if ExpectedAngle == math.huge then
        return false
    end
    log.info(format("Expected angle: %.16g. Current: %.16g", ExpectedAngle, Angle))
    if Angle < ExpectedAngle then
        Angle = Angle + 1
    elseif Angle > ExpectedAngle then
        Angle = Angle - 1
    elseif Angle == ExpectedAngle then
        ExpectedAngle = math.huge
    end
    return false
end)

-- Enum /Script/UMG.ESlateVisibility
local ESlateVisibility = {
    Visible = 0,
    Collapsed = 1,
    Hidden = 2,
    HitTestInvisible = 3,
    SelfHitTestInvisible = 4,
    ESlateVisibility_MAX = 5
}

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

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createUI()
    local prefix = "TerrainMod_"

    local gameInstance = UEHelpers.GetGameInstance()
    if not gameInstance:IsValid() then
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

    ---@type UVerticalBox
    local verticalBox = StaticConstructObject(StaticFindObject("/Script/UMG.VerticalBox"),
        UI.userWidget.WidgetTree.RootWidget, FName(prefix .. "VerticalBox"))

    ---@type UComboBoxString
    UI.comboBox1 = StaticConstructObject(StaticFindObject("/Script/UMG.ComboBoxString"), verticalBox,
        FName("ComboBox1")) ---@type UComboBoxString

    -- add presets to ComboBox
    for _, preset in ipairs(PresetNamesList) do
        UI.comboBox1:AddOption(preset)
    end
    -- select last selected preset
    if params.LAST_PRESET and params.LAST_PRESET ~= "" and UI.comboBox1:FindOptionIndex(params.LAST_PRESET) ~= -1 then
        UI.comboBox1:SetSelectedOption(params.LAST_PRESET)
    else
        UI.comboBox1:SetSelectedIndex(0)
        params.LAST_PRESET = UI.comboBox1:GetOptionAtIndex(0):ToString()
    end

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    UI.canvas:AddChildToCanvas(verticalBox)
    verticalBox:AddChildToVerticalBox(UI.comboBox1)

    UI.userWidget:SetPositionInViewport({ X = 0, Y = 0 }, true)
    UI.userWidget:AddToViewport(100)
    UI.userWidget:SetVisibility(ESlateVisibility.Visible)

    writeParamsFile()

    log.debug("UI created.")

    return true
end

local function showUI()
    if UI.userWidget and UI.userWidget:IsValid() then
        UI.userWidget:AddToViewport(100)
        UI.userWidget:SetVisibility(ESlateVisibility.Visible)
    else
        createUI()
    end
end

local function hideUI()
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

        -- select preset
        CurrentPresetName = UI.comboBox1:GetSelectedOption():ToString()
        if CurrentPresetName == "" then
            log.warn("No preset found.")
            return
        end
        CurrentPreset = Presets[CurrentPresetName]
        params.LAST_PRESET = CurrentPresetName
        writeParamsFile()

        -- Planet center is (0, 0, 0) for SYLVA.
        PlanetCenter = controller:GetLocalSolarBody():GetCenter()

        PlanetName = controller:GetLocalSolarBody().Name:ToString()

        log.info(format("Angle: %.16g", Angle))
    end

    if controller:WasInputKeyJustReleased({ KeyName = FName("End") }) then
        if controller:IsInputKeyDown({ KeyName = FName("LeftAlt") }) then
            if ExpectedAngle == math.huge then
                ExpectedAngle = Angle - 5
            else
                ExpectedAngle = ExpectedAngle - 5
            end
        else
            Angle = Angle - 1
            log.info(format("Angle: %.16g", Angle))
        end
    elseif controller:WasInputKeyJustReleased({ KeyName = FName("Home") }) then
        if controller:IsInputKeyDown({ KeyName = FName("LeftAlt") }) then
            if ExpectedAngle == math.huge then
                ExpectedAngle = Angle + 5
            else
                ExpectedAngle = ExpectedAngle + 5
            end
        else
            Angle = Angle + 1
            log.info(format("Angle: %.16g", Angle))
        end
    elseif controller:WasInputKeyJustReleased({ KeyName = FName("PageUp") }) then
        ExpectedAngle = 45
    elseif controller:WasInputKeyJustReleased({ KeyName = FName("PageDown") }) then
        ExpectedAngle = -45
    elseif controller:WasInputKeyJustReleased({ KeyName = FName("Delete") }) then
        ExpectedAngle = 0
    elseif controller:WasInputKeyJustReleased({ KeyName = FName("Insert") }) then
        toolHit = toolHit:get() ---@cast toolHit FHitResult
        local relativeLocation = vec3.new(
            toolHit.Location.X - PlanetCenter.X,
            toolHit.Location.Y - PlanetCenter.Y,
            toolHit.Location.Z - PlanetCenter.Z)

        local angle = math.deg(vec3.angle_to(
            relativeLocation,
            vec3.new(toolHit.Normal.X, toolHit.Normal.Y, toolHit.Normal.Z)))
        log.info(format("Angle under cursor: %.16g", angle))
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local designAstro = controller:GetAstroCharacter() ---@type ADesignAstro_C

    -- if  designAstro.ControlInputVector.X == 0 and designAstro.ControlInputVector.Y == 0 and designAstro.ControlInputVector.Z == 0 then
    if designAstro.CurrentSpeed == 0 then
        return
    end

    local loc = designAstro:K2_GetActorLocation()
    local fw = designAstro:GetActorForwardVector()
    local right = designAstro:GetActorRightVector()
    local up = designAstro:GetActorUpVector()

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
        character = designAstro,
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

    file:write(format(
        [[return {
LAST_PRESET="%s"
}]], params.LAST_PRESET))

    file:close()
end

---@return string
local function getInfo()
    return ""
end

---@param firstInit? boolean
local function init(firstInit)
    ---@diagnostic disable-next-line: assign-type-mismatch
    AstroPlayStatics = StaticFindObject("/Script/Astro.Default__AstroPlayStatics") ---@type UAstroPlayStatics

    local designAstro = UEHelpers:GetPlayer() ---@cast designAstro ADesignAstro_C
    if not designAstro:IsValid() then
        return
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local capsule = designAstro:K2_GetRootComponent() ---@type UCapsuleComponent
    Capsule.halfHeight = capsule:GetScaledCapsuleHalfHeight()
    Capsule.radius = capsule:GetScaledCapsuleRadius()

    if not firstInit then
        showUI()
    end
end

Presets, PresetNamesList = loadAllPresets()

---@type Method__Auto
return {
    params = params,
    handleTerrainTool_hook = handleTerrainTool_hook,
    writeParamsFile = writeParamsFile,
    getInfo = getInfo,
    onLoad = init,
    onUnload = hideUI,
    onEnable = showUI,
    onDisable = hideUI,
    onClientRestart = init
}
