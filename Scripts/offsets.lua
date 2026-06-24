--[[
Offsets for the custom properties registered with RegisterCustomProperty.

The value stored in 'UNKNOWN_DATA_OFFSET' corresponds to the "Unknown unreflected data"
entry visible in UE4SS Live View for SmallDeform_TERRAIN_EXPERIMENTAL_C.

Example:
    0x80C  RepBrushState
    0x840  Unknown unreflected data

The offsets above are examples only and may change after a game update.

All custom offsets below are relative to the start of the
"Unknown unreflected data" block (0x840 in the example above).

If the game is updated, verify this offset again in Live View, as the
position of the unreflected data block may change.
]]

---@class TerrainToolMod_VectorOffsets
---@field X integer
---@field Y integer
---@field Z integer

---@class TerrainToolMod_Offsets
---@field Deform_Normal1 TerrainToolMod_VectorOffsets
---@field Deform_Normal2 TerrainToolMod_VectorOffsets
---@field Deform_Location1 TerrainToolMod_VectorOffsets
---@field Deform_Location2 TerrainToolMod_VectorOffsets
---@field Deform_Location3 TerrainToolMod_VectorOffsets

---@type TerrainToolMod_Offsets
---@diagnostic disable-next-line: missing-fields
local offsets = {}

local UNKNOWN_DATA_OFFSET <const> = 0x840
local enableDebug = false

---@param baseName string
---@param baseOffset integer
local function setOffsets(baseName, baseOffset)
    assert(type(baseName) == "string")
    assert(math.type(baseOffset) == "integer")

    local x = UNKNOWN_DATA_OFFSET + baseOffset

    ---@type TerrainToolMod_VectorOffsets
    local vector = {
        X = x,
        Y = x + 4,
        Z = x + 8,
    }

    offsets[baseName] = vector

    if enableDebug then
        print(string.format("[TerrainTool] %s offsets:", baseName))
        print(string.format("  X: 0x%X", vector.X))
        print(string.format("  Y: 0x%X", vector.Y))
        print(string.format("  Z: 0x%X", vector.Z))
    end
end

-- Define all custom property offsets here.
setOffsets("Deform_Normal1", 0x10)
setOffsets("Deform_Normal2", 0xA4)
setOffsets("Deform_Location1", 0x1C)
setOffsets("Deform_Location2", 0x98)
setOffsets("Deform_Location3", 0xB0)

return offsets
