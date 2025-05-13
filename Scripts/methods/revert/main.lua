local MethodName = "revert"

local UEHelpers = require("UEHelpers")
local func = require("func")

local log = Log
local format = string.format
local floor, sqrt = math.floor, math.sqrt

local CurrentFile = debug.getinfo(1, "S").source

-- load PARAMS global table
local paramsFile = func.getParamsFile(CurrentFile, true)
local params = func.loadParamsFile(paramsFile, true) ---@type Method__Revert__PARAMS

local options = OPTIONS
local optUI = OPTIONS_UI
local UI = {}

-- Smallest positive subnormal number
-- https://en.wikipedia.org/wiki/Single-precision_floating-point_format#Notable_single-precision_cases
local SmallestNumber = 2 ^ -149

local IsDebugSphereCreated = false
local RevertOffset = 0
local Altitude
local FreezeAltitude = false

---@type TerrainToolMod__Revert_Debug
local dbg = {
    staticMeshActorClassShortName = "StaticMeshActor",
    staticMeshActorClassName = "/Script/Engine.StaticMeshActor",
    staticMeshActorClass = CreateInvalidObject(),
    material = CreateInvalidObject(),
    materialWireframe = CreateInvalidObject(),
    mesh = CreateInvalidObject(),
    --[[ Cone, Cube, Cylinder, Plane, Sphere ]]
    meshClassName = "/Engine/BasicShapes/Sphere.Sphere",
    --[[
        Open FModel, go in Engine > Content > EngineDebugMaterials

        "/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial"
        "/Engine/EngineDebugMaterials/WireframeMaterial.WireframeMaterial" -- Params: Color (wireframe, emissive).
        "/Engine/EngineDebugMaterials/DebugMeshMaterial.DebugMeshMaterial" -- Params: Color (emissive).
        "/Engine/EngineDebugMaterials/DebugEditorMaterial.DebugEditorMaterial" -- Params: Color, Desaturation, Opacity (emissive).
        "/Engine/EngineDebugMaterials/M_SimpleTranslucent.M_SimpleTranslucent" -- Params: Color (translucent).
        "/Engine/EngineMaterials/EmissiveTexturedMaterial.EmissiveTexturedMaterial" -- Params: Texture.
        "/Engine/EngineMaterials/WorldGridMaterial.WorldGridMaterial" -- Params: None.
        ]]
    matClassName = "/Engine/EngineDebugMaterials/M_SimpleTranslucent.M_SimpleTranslucent",
    matWireframeClassName = "/Engine/EngineDebugMaterials/WireframeMaterial.WireframeMaterial",
    scale = { X = 0, Y = 0, Z = 0 },
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

local function loadDebugAssets()
    ---@diagnostic disable: assign-type-mismatch
    if dbg.material:IsValid() == false then
        dbg.material = StaticFindObject(dbg.matClassName)
    end

    if dbg.materialWireframe:IsValid() == false then
        dbg.materialWireframe = StaticFindObject(dbg.matWireframeClassName)
    end

    if dbg.mesh:IsValid() == false then
        dbg.mesh = StaticFindObject(dbg.meshClassName)
    end

    if dbg.staticMeshActorClass:IsValid() == false then
        dbg.staticMeshActorClass = StaticFindObject(dbg.staticMeshActorClassName)
    end
    ---@diagnostic enable: assign-type-mismatch

    if dbg.material:IsValid() == false then
        LoadAsset(dbg.matClassName)
        dbg.material = StaticFindObject(dbg.matClassName)
    end

    if dbg.materialWireframe:IsValid() == false then
        LoadAsset(dbg.matWireframeClassName)
        dbg.materialWireframe = StaticFindObject(dbg.matWireframeClassName)
    end

    if dbg.mesh:IsValid() == false then
        LoadAsset(dbg.meshClassName)
        dbg.mesh = StaticFindObject(dbg.meshClassName)
    end
end

--#region DebugSphere

---@class TerrainToolMod_Revert_DebugSphere
local DebugSphere = {
    actor = CreateInvalidObject(), ---@type UObject|AStaticMeshActor
}

function DebugSphere.create()
    if DebugSphere.actor:IsValid() == false or DebugSphere.actor.bActorIsBeingDestroyed == true then
        ExecuteInGameThread(function()
            loadDebugAssets()

            -- get normal or wireframe material
            local material = params.WIREFRAME == true and dbg.materialWireframe or dbg.material

            -- create the sphere
            ---@diagnostic disable: param-type-mismatch
            DebugSphere.actor = func.spawnDebugObject(UEHelpers:GetWorld(),
                dbg.staticMeshActorClass, dbg.mesh, material,
                { X = 0, Y = 0, Z = 0 },
                nil,
                { X = 0, Y = 0, Z = 0 },
                { R = params.R, G = params.G, B = params.B, A = params.A })
            ---@diagnostic enable: param-type-mismatch

            if DebugSphere.actor:IsValid() then
                DebugSphere.actor:SetMobility(2)
                DebugSphere.actor:SetActorEnableCollision(false)
                DebugSphere.setScale(params.SCALE)
                IsDebugSphereCreated = true
            else
                log.warn("Debug sphere is invalid.")
            end
        end)
    end
end

function DebugSphere.destroy()
    if DebugSphere.actor:IsValid() and DebugSphere.actor.bActorIsBeingDestroyed == false then
        IsDebugSphereCreated = false

        DebugSphere.actor:K2_DestroyActor()
    end
end

function DebugSphere.setScale(scale)
    if DebugSphere.actor:IsValid() then
        local bounds = DebugSphere.actor.StaticMeshComponent.StaticMesh:GetBounds()

        local newScale = {
            X = scale / bounds.BoxExtent.X,
            Y = scale / bounds.BoxExtent.Y,
            Z = scale / bounds.BoxExtent.Z
        }
        DebugSphere.actor:SetActorScale3D(newScale)
    end
end

--#endregion

local function writeParamsFile()
    local file = io.open(paramsFile, "w+")

    assert(file, format("\nUnable to open the params file %q.", paramsFile))

    if params.DEBUG == nil then params.DEBUG = true end
    if params.INTENSITY == nil then params.INTENSITY = 5.0 end
    if params.REVERT_COLOR_ONLY == nil then params.REVERT_COLOR_ONLY = false end
    if params.REVERT_ONCE == nil then params.REVERT_ONCE = false end
    if params.SCALE == nil then params.SCALE = 2000.0 end
    if params.WIREFRAME == nil then params.WIREFRAME = false end
    if params.R == nil then params.R = 1 end
    if params.G == nil then params.G = 0 end
    if params.B == nil then params.B = 0 end
    if params.A == nil then params.A = 0.5 end

    file:write(format(
        [[---@type Method__Revert__PARAMS
return {
DEBUG=%s,
INTENSITY=%.16g,
REVERT_COLOR_ONLY=%s,
REVERT_ONCE=%s,
SCALE=%.16g,
WIREFRAME=%s,
R=%.16g,
G=%.16g,
B=%.16g,
A=%.16g
}]],
        params.DEBUG,
        params.INTENSITY,
        params.REVERT_COLOR_ONLY,
        params.REVERT_ONCE,
        params.SCALE,
        params.WIREFRAME,
        params.R,
        params.G,
        params.B,
        params.A
    ))

    file:close()
end

local function updateParams()
    local updateRequired = false

    local intensity = tonumber(UI.intensity.Text:ToString())
    if intensity == nil then
        intensity = params.INTENSITY
    end
    if intensity ~= params.INTENSITY then
        params.INTENSITY = intensity
        updateRequired = true
    end

    local revertOnce = UI.revertOnceCheckBox.CheckedState == ECheckBoxState.Checked
    if params.REVERT_ONCE ~= revertOnce then
        params.REVERT_ONCE = revertOnce
        updateRequired = true
    end

    local revertColorOnly = UI.revertColorOnlyCheckBox.CheckedState == ECheckBoxState.Checked
    if params.REVERT_COLOR_ONLY ~= revertColorOnly then
        params.REVERT_COLOR_ONLY = revertColorOnly
        updateRequired = true
    end

    local debug = UI.debugCheckBox.CheckedState == ECheckBoxState.Checked
    if params.DEBUG ~= debug then
        params.DEBUG = debug
        updateRequired = true
    end

    local wireframe = UI.wireframeCheckBox.CheckedState == ECheckBoxState.Checked
    if params.WIREFRAME ~= wireframe then
        params.WIREFRAME = wireframe
        updateRequired = true
    end

    -- RED
    local r = tonumber(UI.r.Text:ToString())
    if r == nil then
        r = params.R
    end
    if r ~= params.R then
        params.R = r
        updateRequired = true
    end

    -- GREEN
    local g = tonumber(UI.g.Text:ToString())
    if g == nil then
        g = params.G
    end
    if g ~= params.G then
        params.G = g
        updateRequired = true
    end

    -- BLUE
    local b = tonumber(UI.b.Text:ToString())
    if b == nil then
        b = params.B
    end
    if b ~= params.B then
        params.B = b
        updateRequired = true
    end

    -- ALPHA
    local a = tonumber(UI.a.Text:ToString())
    if a == nil then
        a = params.A
    end
    if a ~= params.A then
        params.A = a
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

    if updateRequired then
        writeParamsFile()
    end
end

local function updateUI()
    params = func.loadParamsFile(paramsFile) ---@type Method__Revert__PARAMS

    UI.intensity:SetText(FText(tostring(params.INTENSITY)))
    UI.scale:SetText(FText(tostring(params.SCALE)))
    UI.revertOnceCheckBox:SetCheckedState(params.REVERT_ONCE == true and ECheckBoxState.Checked or
        ECheckBoxState.Unchecked)
    UI.revertColorOnlyCheckBox:SetCheckedState(params.REVERT_COLOR_ONLY == true and ECheckBoxState.Checked or
        ECheckBoxState.Unchecked)
    UI.debugCheckBox:SetCheckedState(params.DEBUG == true and ECheckBoxState.Checked or
        ECheckBoxState.Unchecked)
    UI.wireframeCheckBox:SetCheckedState(params.WIREFRAME == true and ECheckBoxState.Checked or
        ECheckBoxState.Unchecked)
    UI.r:SetText(FText(tostring(params.R)))
    UI.g:SetText(FText(tostring(params.G)))
    UI.b:SetText(FText(tostring(params.B)))
    UI.a:SetText(FText(tostring(params.A)))
    UI.offset:SetText(FText("0"))
end

-- Sources:
--   https://github.com/MichaelK-UnderscoreUnderscore/PseudoregaliaSavestates/blob/main/Scripts/Utils.lua
--   https://github.com/massclown/HalfSwordTrainerMod-playtest/blob/main/HalfSwordTrainerMod/scripts/main.lua
local function createUI()
    local prefix = "TerrainMod_revert_"

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
    textBlock_title.Font.Size = optUI.revert.font_size
    textBlock_title.Font.FontObject = fontObj
    textBlock_title:SetText(FText(optUI.revert.txt.title))
    textBlock_title:SetToolTipText(FText(optUI.revert.txt.description_tip))

    --#region scale
    ---@type UHorizontalBox
    local horizontalBox_scale = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_scale"))
    horizontalBox_scale:SetToolTipText(FText(optUI.revert.txt.scale_tip))

    ---@type UTextBlock
    local textBlock_scale = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_scale"))
    textBlock_scale.Font.Size = optUI.revert.font_size
    textBlock_scale.Font.FontObject = fontObj
    textBlock_scale:SetText(FText(optUI.revert.txt.scale))

    ---@type USpacer
    local spacer_scale = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_scale"))
    spacer_scale:SetSize(optUI.revert.spacer_size)

    ---@type UEditableTextBox
    UI.scale = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_scale"))
    UI.scale.WidgetStyle.Font.Size = optUI.revert.font_size
    UI.scale.WidgetStyle.Font.FontObject = fontObj
    UI.scale.SelectAllTextWhenFocused = true

    horizontalBox_scale:AddChildToHorizontalBox(textBlock_scale)
    horizontalBox_scale:AddChildToHorizontalBox(spacer_scale)
    horizontalBox_scale:AddChildToHorizontalBox(UI.scale)
    --#endregion

    --#region intensity
    ---@type UHorizontalBox
    local horizontalBox_intensity = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_intensity"))
    horizontalBox_intensity:SetToolTipText(FText(optUI.revert.txt.intensity_tip))

    ---@type UTextBlock
    local textBlock_intensity = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_intensity"))
    textBlock_intensity.Font.Size = optUI.revert.font_size
    textBlock_intensity.Font.FontObject = fontObj
    textBlock_intensity:SetText(FText(optUI.revert.txt.intensity))

    ---@type USpacer
    local spacer_intensity = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_intensity"))
    spacer_intensity:SetSize(optUI.revert.spacer_size)

    ---@type UEditableTextBox
    UI.intensity = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_intensity"))
    UI.intensity.WidgetStyle.Font.Size = optUI.revert.font_size
    UI.intensity.WidgetStyle.Font.FontObject = fontObj
    UI.intensity.SelectAllTextWhenFocused = true

    horizontalBox_intensity:AddChildToHorizontalBox(textBlock_intensity)
    horizontalBox_intensity:AddChildToHorizontalBox(spacer_intensity)
    horizontalBox_intensity:AddChildToHorizontalBox(UI.intensity)
    --#endregion

    --#region revertOnce
    ---@type UHorizontalBox
    local horizontalBox_revertOnce = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_revertOnce"))
    horizontalBox_revertOnce:SetToolTipText(FText(optUI.revert.txt.revertOnce_tip))

    ---@type UTextBlock
    local textBlock_revertOnce = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_revertOnce"))
    textBlock_revertOnce.Font.Size = optUI.revert.font_size
    textBlock_revertOnce.Font.FontObject = fontObj
    textBlock_revertOnce:SetText(FText(optUI.revert.txt.revertOnce))

    ---@type USpacer
    local spacer_revertOnce = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_revertOnce"))
    spacer_revertOnce:SetSize(optUI.revert.spacer_size)

    ---@type UCheckBox
    UI.revertOnceCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_revertOnce"))

    horizontalBox_revertOnce:AddChildToHorizontalBox(textBlock_revertOnce)
    horizontalBox_revertOnce:AddChildToHorizontalBox(spacer_revertOnce)
    horizontalBox_revertOnce:AddChildToHorizontalBox(UI.revertOnceCheckBox)
    --#endregion

    --#region revertColorOnly
    ---@type UHorizontalBox
    local horizontalBox_revertColorOnly = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_revertColorOnly"))
    horizontalBox_revertColorOnly:SetToolTipText(FText(optUI.revert.txt.revertColorOnly_tip))

    ---@type UTextBlock
    local textBlock_revertColorOnly = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_revertColorOnly"))
    textBlock_revertColorOnly.Font.Size = optUI.revert.font_size
    textBlock_revertColorOnly.Font.FontObject = fontObj
    textBlock_revertColorOnly:SetText(FText(optUI.revert.txt.revertColorOnly))

    ---@type USpacer
    local spacer_revertColorOnly = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_revertColorOnly"))
    spacer_revertColorOnly:SetSize(optUI.revert.spacer_size)

    ---@type UCheckBox
    UI.revertColorOnlyCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_revertColorOnly"))

    horizontalBox_revertColorOnly:AddChildToHorizontalBox(textBlock_revertColorOnly)
    horizontalBox_revertColorOnly:AddChildToHorizontalBox(spacer_revertColorOnly)
    horizontalBox_revertColorOnly:AddChildToHorizontalBox(UI.revertColorOnlyCheckBox)
    --#endregion

    --#region Offset (up/down)
    ---@type UHorizontalBox
    local horizontalBox_offset = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_offset"))
    local sp = "   "
    local nl = "\n"
    local v1_offset_p = format("(+ %d)", options.revert_offset_location_value)
    local v1_offset_m = format("(- %d)", options.revert_offset_location_value)
    local v2_offset_p = format("(+ %d)", options.revert_offset_location_value_with_modifier)
    local v2_offset_m = format("(- %d)", options.revert_offset_location_value_with_modifier)
    local helpText_offset =
        optUI.revert.txt.keybinds ..
        options.revert_offset_location_down_text ..
        sp .. options.revert_offset_location_down_KeyName .. v1_offset_m .. nl ..
        options.revert_offset_location_up_text ..
        sp .. options.revert_offset_location_up_KeyName .. v1_offset_p .. nl ..
        options.revert_offset_location_down_text ..
        sp ..
        options.revert_offset_location_down_KeyName ..
        "+" .. options.revert_offset_location_modifier_KeyName .. v2_offset_m .. nl ..
        options.revert_offset_location_up_text ..
        sp ..
        options.revert_offset_location_up_KeyName ..
        "+" .. options.revert_offset_location_modifier_KeyName .. v2_offset_p
    horizontalBox_offset:SetToolTipText(FText(optUI.revert.txt.offset_tip .. "\n" .. helpText_offset))

    ---@type UTextBlock
    local textBlock_offset = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_offset"))
    textBlock_offset.Font.Size = optUI.revert.font_size
    textBlock_offset.Font.FontObject = fontObj
    textBlock_offset:SetText(FText(optUI.revert.txt.offset))

    ---@type USpacer
    local spacer_offset = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_offset"))
    spacer_offset:SetSize(optUI.revert.spacer_size)

    ---@type UEditableTextBox
    UI.offset = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_offset"))
    UI.offset.WidgetStyle.Font.Size = optUI.revert.font_size
    UI.offset.WidgetStyle.Font.FontObject = fontObj
    UI.offset.SelectAllTextWhenFocused = true

    horizontalBox_offset:AddChildToHorizontalBox(textBlock_offset)
    horizontalBox_offset:AddChildToHorizontalBox(spacer_offset)
    horizontalBox_offset:AddChildToHorizontalBox(UI.offset)
    --#endregion

    --#region altitude
    ---@type UHorizontalBox
    local horizontalBox_altitude = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_altitude"))
    horizontalBox_altitude:SetToolTipText(FText(optUI.revert.txt.altitude_tip))

    ---@type UTextBlock
    local textBlock_altitude = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_altitude"))
    textBlock_altitude.Font.Size = optUI.revert.font_size
    textBlock_altitude.Font.FontObject = fontObj
    textBlock_altitude:SetText(FText(optUI.revert.txt.altitude))

    ---@type USpacer
    local spacer_altitude = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_altitude"))
    spacer_altitude:SetSize(optUI.revert.spacer_size)

    ---@type UEditableTextBox
    UI.altitude = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_altitude"))
    UI.altitude.WidgetStyle.Font.Size = optUI.revert.font_size
    UI.altitude.WidgetStyle.Font.FontObject = fontObj
    UI.altitude.SelectAllTextWhenFocused = true

    horizontalBox_altitude:AddChildToHorizontalBox(textBlock_altitude)
    horizontalBox_altitude:AddChildToHorizontalBox(spacer_altitude)
    horizontalBox_altitude:AddChildToHorizontalBox(UI.altitude)
    --#endregion

    --#region freeze altitude
    ---@type UHorizontalBox
    local horizontalBox_freezeAltitude = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_freezeAltitude"))
    horizontalBox_freezeAltitude:SetToolTipText(FText(optUI.revert.txt.freezeAltitude_tip))

    ---@type UTextBlock
    local textBlock_freezeAltitude = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_freezeAltitude"))
    textBlock_freezeAltitude.Font.Size = optUI.revert.font_size
    textBlock_freezeAltitude.Font.FontObject = fontObj
    textBlock_freezeAltitude:SetText(FText(optUI.revert.txt.freezeAltitude))

    ---@type USpacer
    local spacer_freezeAltitude = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_freezeAltitude"))
    spacer_freezeAltitude:SetSize(optUI.revert.spacer_size)

    ---@type UCheckBox
    UI.freezeAltitudeCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_freezeAltitude"))

    horizontalBox_freezeAltitude:AddChildToHorizontalBox(textBlock_freezeAltitude)
    horizontalBox_freezeAltitude:AddChildToHorizontalBox(spacer_freezeAltitude)
    horizontalBox_freezeAltitude:AddChildToHorizontalBox(UI.freezeAltitudeCheckBox)
    --#endregion

    --#region debug
    ---@type UHorizontalBox
    local horizontalBox_debug = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_debug"))
    horizontalBox_debug:SetToolTipText(FText(optUI.revert.txt.debug_tip))

    ---@type UTextBlock
    local textBlock_debug = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_debug"))
    textBlock_debug.Font.Size = optUI.revert.font_size
    textBlock_debug.Font.FontObject = fontObj
    textBlock_debug:SetText(FText(optUI.revert.txt.debug))

    ---@type USpacer
    local spacer_debug = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_debug"))
    spacer_debug:SetSize(optUI.revert.spacer_size)

    ---@type UCheckBox
    UI.debugCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_debug"))

    horizontalBox_debug:AddChildToHorizontalBox(textBlock_debug)
    horizontalBox_debug:AddChildToHorizontalBox(spacer_debug)
    horizontalBox_debug:AddChildToHorizontalBox(UI.debugCheckBox)
    --#endregion

    --#region wireframe
    ---@type UHorizontalBox
    local horizontalBox_wireframe = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_wireframe"))
    horizontalBox_wireframe:SetToolTipText(FText(optUI.revert.txt.wireframe_tip))

    ---@type UTextBlock
    local textBlock_wireframe = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_wireframe"))
    textBlock_wireframe.Font.Size = optUI.revert.font_size
    textBlock_wireframe.Font.FontObject = fontObj
    textBlock_wireframe:SetText(FText(optUI.revert.txt.wireframe))

    ---@type USpacer
    local spacer_wireframe = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_wireframe"))
    spacer_wireframe:SetSize(optUI.revert.spacer_size)

    ---@type UCheckBox
    UI.wireframeCheckBox = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_wireframe"))

    horizontalBox_wireframe:AddChildToHorizontalBox(textBlock_wireframe)
    horizontalBox_wireframe:AddChildToHorizontalBox(spacer_wireframe)
    horizontalBox_wireframe:AddChildToHorizontalBox(UI.wireframeCheckBox)
    --#endregion

    --#region rgba
    ---@type UHorizontalBox
    local horizontalBox_rgba = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_rgba"))
    horizontalBox_rgba:SetToolTipText(FText(optUI.revert.txt.rgba_tip))

    ---@type UTextBlock
    local textBlock_r = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_r"))
    textBlock_r.Font.Size = optUI.revert.font_size
    textBlock_r.Font.FontObject = fontObj
    textBlock_r:SetText(FText(optUI.revert.txt.rgba))

    ---@type USpacer
    local spacer_1 = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_1"))
    spacer_1:SetSize(optUI.revert.spacer_size)

    -- RED
    ---@type UEditableTextBox
    UI.r = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_r"))
    UI.r.WidgetStyle.Font.Size = optUI.revert.font_size
    UI.r.WidgetStyle.Font.FontObject = fontObj
    UI.r.SelectAllTextWhenFocused = true
    horizontalBox_rgba:AddChildToHorizontalBox(textBlock_r)
    horizontalBox_rgba:AddChildToHorizontalBox(spacer_1)
    horizontalBox_rgba:AddChildToHorizontalBox(UI.r)

    -- GREEN
    ---@type USpacer
    local spacer_2 = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_2"))
    spacer_2:SetSize(optUI.revert.spacer_size2)
    ---@type UEditableTextBox
    UI.g = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_g"))
    UI.g.WidgetStyle.Font.Size = optUI.revert.font_size
    UI.g.WidgetStyle.Font.FontObject = fontObj
    UI.g.SelectAllTextWhenFocused = true
    horizontalBox_rgba:AddChildToHorizontalBox(spacer_2)
    horizontalBox_rgba:AddChildToHorizontalBox(UI.g)

    -- BLUE
    ---@type USpacer
    local spacer_3 = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_3"))
    spacer_3:SetSize(optUI.revert.spacer_size2)
    ---@type UEditableTextBox
    UI.b = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_b"))
    UI.b.WidgetStyle.Font.Size = optUI.revert.font_size
    UI.b.WidgetStyle.Font.FontObject = fontObj
    UI.b.SelectAllTextWhenFocused = true
    horizontalBox_rgba:AddChildToHorizontalBox(spacer_3)
    horizontalBox_rgba:AddChildToHorizontalBox(UI.b)

    -- ALPHA
    ---@type USpacer
    local spacer_4 = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_4"))
    spacer_4:SetSize(optUI.revert.spacer_size2)
    ---@type UEditableTextBox
    UI.a = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_a"))
    UI.a.WidgetStyle.Font.Size = optUI.revert.font_size
    UI.a.WidgetStyle.Font.FontObject = fontObj
    UI.a.SelectAllTextWhenFocused = true
    horizontalBox_rgba:AddChildToHorizontalBox(spacer_4)
    horizontalBox_rgba:AddChildToHorizontalBox(UI.a)
    --#endregion

    verticalBox:AddChildToVerticalBox(textBlock_title)
    verticalBox:AddChildToVerticalBox(horizontalBox_scale)
    verticalBox:AddChildToVerticalBox(horizontalBox_intensity)
    verticalBox:AddChildToVerticalBox(horizontalBox_revertOnce)
    verticalBox:AddChildToVerticalBox(horizontalBox_revertColorOnly)
    verticalBox:AddChildToVerticalBox(horizontalBox_offset)
    verticalBox:AddChildToVerticalBox(horizontalBox_altitude)
    verticalBox:AddChildToVerticalBox(horizontalBox_freezeAltitude)
    verticalBox:AddChildToVerticalBox(horizontalBox_debug)
    verticalBox:AddChildToVerticalBox(horizontalBox_wireframe)
    verticalBox:AddChildToVerticalBox(horizontalBox_rgba)

    local slot = UI.canvas:AddChildToCanvas(verticalBox)
    slot:SetAutoSize(true)

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    UI.userWidget:SetAnchorsInViewport(optUI._generic.AnchorsInViewport)
    UI.userWidget:SetAlignmentInViewport(optUI._generic.AlignmentInViewport)
    UI.userWidget:SetPadding(optUI._generic.Padding)
    UI.userWidget:AddToViewport(optUI._generic.zOrder)
    UI.userWidget:SetVisibility(ESlateVisibility.Visible)

    log.debug(format("UI created (%s).", MethodName))
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
    DebugSphere.destroy()

    updateParams()
end

local function round(num, numDecimalPlaces)
    local mult = 10 ^ (numDecimalPlaces or 4)
    return floor(num * mult + 0.5) / mult
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
    local controller = _controller:get() ---@type APlayController
    local toolHit = _toolHit:get() ---@type FHitResult

    local homeBody = controller.HomeBody
    local rootComponent = homeBody.RootComponent
    local planetCenter = rootComponent.RelativeLocation
    local relativeLocation = {
        X = toolHit.Location.X - planetCenter.X,
        Y = toolHit.Location.Y - planetCenter.Y,
        Z = toolHit.Location.Z - planetCenter.Z
    }
    local currentAltitude = sqrt(
        relativeLocation.X ^ 2 +
        relativeLocation.Y ^ 2 +
        relativeLocation.Z ^ 2)
    local up = {
        X = relativeLocation.X / currentAltitude,
        Y = relativeLocation.Y / currentAltitude,
        Z = relativeLocation.Z / currentAltitude
    }

    local location = toolHit.Location

    if _justActivated:get() == true then
        deformTool.Operation = EDeformType.RevertModifications
        updateParams()

        if params.DEBUG == true then
            DebugSphere.create()
        end

        -- altitude
        FreezeAltitude = UI.freezeAltitudeCheckBox.CheckedState == ECheckBoxState.Checked and true or false
        if FreezeAltitude then
            Altitude = tonumber(UI.altitude.Text:ToString())
            if Altitude == nil then
                FreezeAltitude = false
                UI.freezeAltitudeCheckBox:SetCheckedState(ECheckBoxState.Unchecked)
            end
        else
            UI.altitude:SetText(FText(tostring(round(currentAltitude, 2))))
            Altitude = currentAltitude
        end

        local offset = tonumber(UI.offset.Text:ToString())
        if offset ~= nil then
            RevertOffset = offset
        end
    end

    if deformTool.Operation ~= EDeformType.RevertModifications then
        if IsDebugSphereCreated == true then
            DebugSphere.destroy()
        end

        return
    end

    -- https://michaeljcole.github.io/wiki.unrealengine.com/List_of_Key/Gamepad_Input_Names/
    if controller:WasInputKeyJustPressed({ KeyName = FName(options.revert_offset_location_down_KeyName) }) then
        if controller:IsInputKeyDown({ KeyName = FName(options.revert_offset_location_modifier_KeyName) }) then
            RevertOffset = RevertOffset - options.revert_offset_location_value_with_modifier
        else
            RevertOffset = RevertOffset - options.revert_offset_location_value
        end

        UI.offset:SetText(FText(tostring(RevertOffset)))
    elseif controller:WasInputKeyJustPressed({ KeyName = FName(options.revert_offset_location_up_KeyName) }) then
        if controller:IsInputKeyDown({ KeyName = FName(options.revert_offset_location_modifier_KeyName) }) then
            RevertOffset = RevertOffset + options.revert_offset_location_value_with_modifier
        else
            RevertOffset = RevertOffset + options.revert_offset_location_value
        end

        UI.offset:SetText(FText(tostring(RevertOffset)))
    end

    if FreezeAltitude then
        -- altitude will be modified
        location = {
            X = (relativeLocation.X / currentAltitude) * Altitude + (location.X - relativeLocation.X),
            Y = (relativeLocation.Y / currentAltitude) * Altitude + (location.Y - relativeLocation.Y),
            Z = (relativeLocation.Z / currentAltitude) * Altitude + (location.Z - relativeLocation.Z)
        }
    end

    location = {
        X = location.X + up.X * RevertOffset,
        Y = location.Y + up.Y * RevertOffset,
        Z = location.Z + up.Z * RevertOffset
    }

    if IsDebugSphereCreated == true and DebugSphere.actor:IsValid() and DebugSphere.actor.bActorIsBeingDestroyed == false then
        DebugSphere.actor:K2_SetActorLocationAndRotation(
            location,
            controller:GetCameraRotation(),
            false, {}, true) ---@diagnostic disable-line: missing-fields
    end

    if _isUsingTool:get() == false then
        return
    end

    if deformTool.Operation == EDeformType.RevertModifications then
        _isUsingTool:set(false)

        if params.REVERT_ONCE == true and _startedInteraction:get() == false then
            return
        end
    else
        return
    end

    local intensity = params.REVERT_COLOR_ONLY == true and SmallestNumber or params.INTENSITY

    controller:ClientDoDeformation({
        AutoCreateResourceEfficiency = 0,
        CreativeModeNoResourceCollection = false,
        DeltaTime = 0.1, -- ???
        ForceRemoveDecorators = false,
        HardnessPenetration = 0,
        Instigator = nil,
        Intensity = intensity,
        Location = { X = location.X, Y = location.Y, Z = location.Z },
        MaterialIndex = 0,
        Normal = { X = toolHit.Normal.X, Y = toolHit.Normal.Y, Z = toolHit.Normal.Z },
        Operation = EDeformType.RevertModifications,
        Scale = params.SCALE,
        SequenceNumber = 0,
        Shape = 0,
        bEasyUnbury = false,
        bUseAlternatePolygonization = true
    })
end

local function hook_Deactivated()
    DebugSphere.destroy()
end

local function isUIFocused()
    if not UI.userWidget or not UI.userWidget:IsValid() then
        return false
    end

    return UI.userWidget:HasFocusedDescendants()
end

---@type Method__Revert
return {
    params = params,
    hook_DeformTool_HandleTerrainTool = hook_HandleTerrainTool,
    hook_DeformTool_Deactivated = hook_Deactivated,
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
