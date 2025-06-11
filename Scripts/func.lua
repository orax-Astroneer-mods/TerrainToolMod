local utils = require("Scripts.lib.lua-mods-libs.utils")

local format, floor, sqrt = string.format, math.floor, math.sqrt

local m = {}

---@param filename string
---@return boolean
---@return integer
function m.isFileExists(filename)
    local file = io.open(filename, "r")
    if file ~= nil then
        local size = file:seek("end")
        io.close(file)
        return true, size
    else
        return false, 0
    end
end

---@param t table
---@param fmt string
function m.tableToString(t, fmt)
    local str = "{"
    for key, value in pairs(t) do
        str = str .. format("[\"%s\"]=" .. fmt .. ",", key, value)
    end
    str = str .. "}"

    return str
end

---@param name string
---@param directory string
---@param checkFile? boolean
---@return string
function m.getParamsFileByName(name, directory, checkFile)
    local function check(file, exampleFile)
        local f1 = loadfile(file)
        if f1 == nil then
            -- cannot load file
            return false
        end

        local params = f1()
        local ex = dofile(exampleFile)

        -- check if keys exist in the example file
        for key, value in pairs(params) do
            if ex[key] == nil then
                -- this key does not exist in the example file
                print(format("WARN: The key %q in the %s.lua file is unknown. You should delete it.", key, name))
                break
            end
        end
    end

    local file = format([[%s\%s.lua]], directory, name)

    if checkFile == true then
        local exampleFile = format([[%s\%s.example.lua]], directory, name)
        local _, fileSize = m.isFileExists(file)
        if fileSize == 0 or check(file, exampleFile) == false then
            local cmd = format([[copy /Y "%s" "%s"]], exampleFile, file)
            print("Copy example params to params.lua. Execute command: " .. cmd .. "\n")
            os.execute(cmd)
        end
    end

    return file
end

---@param sourceFile string
---@param checkFile? boolean
---@param method? string
---@return string
function m.getParamsFile(sourceFile, checkFile, method)
    local function check(file, exampleFile)
        local f1 = loadfile(file)
        if f1 == nil then
            -- cannot load file
            return false
        end

        local params = f1()
        local ex = dofile(exampleFile)

        -- check if keys exist in the example file
        for key, value in pairs(params) do
            if ex[key] == nil then
                -- this key does not exist in the example file
                print(format("WARN: The key %q in the params.lua file is unknown. You should delete it.", key))
                break
            end
        end
    end

    local methodDirectory
    if method == nil or method == "" then
        -- current directory
        methodDirectory = sourceFile:gsub("\\", "/"):match("@?(.+/[Ss]cripts/methods/[^/]+)")
    else
        methodDirectory = sourceFile:gsub("\\", "/"):match("@?(.+/[Ss]cripts/methods/)") .. method
    end ---@cast methodDirectory string

    local file = methodDirectory .. "\\params.lua"

    if checkFile == true then
        local exampleFile = methodDirectory .. "\\params.example.lua"
        local _, fileSize = m.isFileExists(file)
        if fileSize == 0 or check(file, exampleFile) == false then
            local cmd = format([[copy /Y "%s" "%s"]], exampleFile, file)
            print("Copy example params to params.lua. Execute command: " .. cmd .. "\n")
            os.execute(cmd)
        end
    end

    return file
end

---@param paramsFile string
---@param checkFile? boolean
---@return table
function m.loadParamsFile(paramsFile, checkFile)
    local params = dofile(paramsFile)
    assert(type(params) == "table", format("\nInvalid parameters file: %q.", paramsFile))

    if checkFile == true then
        -- load example file and set defaults if needed
        local exampleParamsFile = paramsFile:gsub("params.lua", "params.example.lua")
        local exParams = dofile(exampleParamsFile)
        assert(type(exParams) == "table", format("\nInvalid parameters file: %q.", exampleParamsFile))
        for key, defaultValue in pairs(exParams) do
            if params[key] == nil then
                params[key] = defaultValue
            end
        end

        local i, str = 0, ""
        for key, value in pairs(params) do
            str = str .. format("%s=%s\n", key, value)
            i = i + 1
        end

        if i == 0 then
            print(format("WARN: No parameters were loaded from the file %q.", paramsFile))
        end
    end

    return params
end

---@param key Key
---@param modifierKeys? ModifierKey[]
function m.getKeybindName(key, modifierKeys)
    local modifierKeysList = ""

    if type(modifierKeys) == "table" then
        for _, keyValue in ipairs(modifierKeys) do
            for k, v in pairs(ModifierKey) do
                if keyValue == v then
                    modifierKeysList = modifierKeysList .. k .. "+"
                end
            end
        end
    end

    for k, v in pairs(Key) do
        if key == v then
            return modifierKeysList .. k
        end
    end

    return ""
end

---Get nearest multiple of base.
---@param a number
---@param base number
---@return number
function m.roundToBase(a, base)
    return floor(a / base + 0.5) * base
end

--- Get the length of a vector.
---@param u FVector
---@return number len
function m.getVectorLen(u)
    return sqrt(u.X * u.X + u.Y * u.Y + u.Z * u.Z)
end

---@param HitResult FHitResult
---@return AActor
function m.getActorFromHitResult(HitResult)
    if UnrealVersion:IsBelow(5, 0) then
        return HitResult.Actor:Get() ---@diagnostic disable-line: undefined-field
    elseif UnrealVersion:IsBelow(5, 4) then
        return HitResult.HitObjectHandle.Actor:Get() ---@diagnostic disable-line: undefined-field
    else
        return HitResult.HitObjectHandle.ReferenceObject:Get() ---@diagnostic disable-line: undefined-field
    end
end

function m.FVector(x, y, z)
    return { X = x, Y = y, Z = z }
end

function m.fvectorToUserData(v)
    return { X = v.X, Y = v.Y, Z = v.Z }
end

function m.vec3ToFVector(v)
    return { X = v.x, Y = v.y, Z = v.z }
end

---@param world UWorld
---@param staticMeshActorClass UClass
---@param mesh UStaticMesh
---@param material UMaterialInterface
---@param location FVector
---@param rotation FRotator?
---@param scale FVector?
---@param color FLinearColor?
---@return UObject|AStaticMeshActor
function m.spawnDebugObject(world, staticMeshActorClass, mesh, material, location, rotation, scale, color)
    if not world:IsValid() or not staticMeshActorClass:IsValid() or not mesh:IsValid() or not material:IsValid() then
        return CreateInvalidObject()
    end

    rotation = rotation or { Pitch = 0, Roll = 0, Yaw = 0 }
    scale = scale or { X = 1, Y = 1, Z = 1 }
    color = color or { R = 1.0, G = 1.0, B = 1.0, A = 1.0 }

    ---@diagnostic disable-next-line: undefined-field
    local staticMeshActor = world:SpawnActor(staticMeshActorClass, m.fvectorToUserData(location),
        rotation) ---@cast staticMeshActor AStaticMeshActor
    assert(staticMeshActor:IsValid())

    staticMeshActor:SetActorScale3D(scale)
    staticMeshActor.StaticMeshComponent.StaticMesh = mesh

    local matInstance = staticMeshActor.StaticMeshComponent:CreateDynamicMaterialInstance(0, material, FName(0))
    matInstance:SetVectorParameterValue(FName("Color"), color)

    return staticMeshActor
end

---Set that the mod is started in a shared variable.
function m.setModStarted()
    ModRef:SetSharedVariable(utils.mod.name, true)
end

---Return true if the mod has been restarted.
function m.isModRestarted()
    return ModRef:GetSharedVariable(utils.mod.name)
end

function m.createPaintUI(rootWidget, prefix, options, optUI, fontObj)
    ---@diagnostic disable: param-type-mismatch, assign-type-mismatch

    local UI = {}

    --#region paint
    ---@type UHorizontalBox
    local horizontalBox_paint = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_paint"))
    horizontalBox_paint:SetToolTipText(FText(format(optUI["*"].txt.paint_tip,
        m.getKeybindName(options.set_paint_method_Key, options.set_paint_method_ModifierKeys))))

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

    ---@type USpacer
    local spacer_paint2 = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_paint2"))
    spacer_paint2:SetSize(optUI.tangent.spacer_size2)

    ---@type UCheckBox
    UI.paintCheckBox2 = StaticConstructObject(StaticFindObject("/Script/UMG.CheckBox"),
        rootWidget, FName(prefix .. "CheckBox_paint2"))

    ---@type USpacer
    local spacer_paint3 = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_paint3"))
    spacer_paint3:SetSize(optUI.tangent.spacer_size)

    ---@type UTextBlock
    local textBlock_paint2 = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_paint2"))
    textBlock_paint2.Font.Size = optUI.tangent.font_size
    textBlock_paint2.Font.FontObject = fontObj
    textBlock_paint2:SetText(FText(optUI.tangent.txt.paintOriginal))

    horizontalBox_paint:AddChildToHorizontalBox(textBlock_paint)
    horizontalBox_paint:AddChildToHorizontalBox(spacer_paint)
    horizontalBox_paint:AddChildToHorizontalBox(UI.paintCheckBox)
    horizontalBox_paint:AddChildToHorizontalBox(spacer_paint2)
    horizontalBox_paint:AddChildToHorizontalBox(textBlock_paint2)
    horizontalBox_paint:AddChildToHorizontalBox(spacer_paint3)
    horizontalBox_paint:AddChildToHorizontalBox(UI.paintCheckBox2)
    --#endregion

    --#region paint scale
    ---@type UHorizontalBox
    local horizontalBox_paint_scale = StaticConstructObject(StaticFindObject("/Script/UMG.HorizontalBox"),
        rootWidget, FName(prefix .. "HorizontalBox_paint_scale"))
    horizontalBox_paint_scale:SetToolTipText(FText(optUI["*"].txt.paint_scale_tip))

    ---@type UTextBlock
    local textBlock_paint_scale = StaticConstructObject(StaticFindObject("/Script/UMG.TextBlock"),
        rootWidget, FName(prefix .. "TextBlock_paint_scale"))
    textBlock_paint_scale.Font.Size = optUI.tangent.font_size
    textBlock_paint_scale.Font.FontObject = fontObj
    textBlock_paint_scale:SetText(FText(optUI.tangent.txt.paint_scale))

    ---@type USpacer
    local spacer_paint_scale = StaticConstructObject(StaticFindObject("/Script/UMG.Spacer"),
        rootWidget, FName(prefix .. "Spacer_paint_scale"))
    spacer_paint_scale:SetSize(optUI.tangent.spacer_size)

    ---@type UEditableTextBox
    UI.paint_scale = StaticConstructObject(StaticFindObject("/Script/UMG.EditableTextBox"),
        rootWidget, FName(prefix .. "EditableTextBox_paint_scale"))
    UI.paint_scale.WidgetStyle.Font.Size = optUI.tangent.font_size
    UI.paint_scale.WidgetStyle.Font.FontObject = fontObj

    horizontalBox_paint_scale:AddChildToHorizontalBox(textBlock_paint_scale)
    horizontalBox_paint_scale:AddChildToHorizontalBox(spacer_paint_scale)
    horizontalBox_paint_scale:AddChildToHorizontalBox(UI.paint_scale)
    --#endregion

    ---@diagnostic enable: param-type-mismatch, assign-type-mismatch

    return horizontalBox_paint, horizontalBox_paint_scale, UI.paintCheckBox, UI.paintCheckBox2, UI.paint_scale
end

---Sort a table.
---Source: https://www.lua.org/pil/19.3.html
---@param t table
---@param f function?
function m.pairsByKeys(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n) end
    table.sort(a, f)
    local i = 0             -- iterator variable
    local iter = function() -- iterator function
        i = i + 1
        if a[i] == nil then
            return nil
        else
            return a[i], t[a[i]]
        end
    end
    return iter
end

return m
