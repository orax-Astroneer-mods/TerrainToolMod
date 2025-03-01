local floor, sqrt = math.floor, math.sqrt

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

function m.getParamsFile()
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
                print(string.format("WARN: The key %q in the params.lua file is unknown. You should delete it.", key))
                break
            end
        end
    end

    local currentDirectory = debug.getinfo(2, "S").source:match([[@?(.+\Mods\[^\\]+\Scripts\methods\[^\]+)]])
    local file = currentDirectory .. "\\params.lua"
    local exampleFile = currentDirectory .. "\\params.example.lua"

    local _, fileSize = m.isFileExists(file)
    if fileSize == 0 or check(file, exampleFile) == false then
        local cmd = string.format([[copy /Y "%s" "%s"]], exampleFile, file)
        print("Copy example params to params.lua. Execute command: " .. cmd .. "\n")
        os.execute(cmd)
    end

    return file
end

---@param paramsFile? string
---@return table
function m.loadParamsFile(paramsFile)
    paramsFile = paramsFile or m.getParamsFile()
    local params = dofile(paramsFile)
    assert(type(params) == "table", string.format("\nInvalid parameters file: %q.", paramsFile))

    -- load example file and set defaults if needed
    local exampleParamsFile = paramsFile:gsub("params.lua", "params.example.lua")
    local exParams = dofile(exampleParamsFile)
    assert(type(exParams) == "table", string.format("\nInvalid parameters file: %q.", exampleParamsFile))
    for key, defaultValue in pairs(exParams) do
        if params[key] == nil then
            params[key] = defaultValue
        end
    end

    local i, str = 0, ""
    for key, value in pairs(params) do
        str = str .. string.format("%s=%s\n", key, value)
        i = i + 1
    end

    if i > 0 then
        print(string.format("Loaded params (%d): \n%s", i, str))
    else
        print(string.format("WARN: No parameters were loaded from the file %q.", paramsFile))
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

return m
