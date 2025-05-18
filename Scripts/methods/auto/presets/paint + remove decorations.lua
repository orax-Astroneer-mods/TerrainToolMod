--[[
    How to get a "material index" (color)?

    Open the "paint" method (shortcut "5" by default) and click on a color to see its material index.
]]

local UEHelpers = require("UEHelpers")
local sys = UEHelpers.GetKismetSystemLibrary()
local vec3 = Vec3
local rad = math.rad

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

---@type Method__Auto__PRESET
return {
    doDeformation = function(p)
        local scale = 1000
        local scale_paint = 300

        -- Planets: SYLVA, DESOLO, CALIDOR, VESANIA, NOVUS, GLACIO, ATROX.
        -- Documentation: if then else | https://www.lua.org/pil/4.3.1.html
        -- material index 128 = default (gray white)
        local materialIndex = 128
        if p.planetName == "SYLVA" then
            materialIndex = 16 -- green on Sylva
        elseif p.planetName == "Aeoluz" then
            materialIndex = 0
        end

        local endLoc = {
            X = p.characterLocation.X - p.up.X * 500,
            Y = p.characterLocation.Y - p.up.Y * 500,
            Z = p.characterLocation.Z - p.up.Z * 500
        }

        ---@diagnostic disable-next-line: missing-fields
        local hit = {} ---@type FHitResult
        local result = sys:LineTraceSingleForObjects(p.world,
            p.characterLocation, endLoc, { 6 }, false, {}, 0, hit, true, {}, {}, 0) ---@diagnostic disable-line: missing-fields
        if not result then return end

        local controller = p.controller
        local location = {
            X = p.floor.X,
            Y = p.floor.Y,
            Z = p.floor.Z,
        }

        controller:ClientDoDeformation(
            {
                AutoCreateResourceEfficiency = 0,
                CreativeModeNoResourceCollection = false,
                DeltaTime = 0.03299999982118, -- ???
                ForceRemoveDecorators = false,
                HardnessPenetration = 10,     -- 0 (default) to 10
                Instigator = nil,
                Intensity = 0,
                Location = location,
                MaterialIndex = -1,
                Normal = { X = hit.Normal.X, Y = hit.Normal.Y, Z = hit.Normal.Z },
                Operation = EDeformType.Subtract,
                Scale = scale,
                SequenceNumber = 0,
                Shape = 0,
                bEasyUnbury = false,
                bUseAlternatePolygonization = true
            })

        controller:ClientDoDeformation(
            {
                AutoCreateResourceEfficiency = 0,
                CreativeModeNoResourceCollection = false,
                DeltaTime = 0.03299999982118, -- ???
                ForceRemoveDecorators = false,
                HardnessPenetration = 10,     -- 0 (default) to 10
                Instigator = nil,
                Intensity = 0,
                Location = location,
                MaterialIndex = materialIndex,
                Normal = { X = hit.Normal.X, Y = hit.Normal.Y, Z = hit.Normal.Z },
                Operation = EDeformType.ColorPaint,
                Scale = scale_paint,
                SequenceNumber = 0,
                Shape = 0,
                bEasyUnbury = false,
                bUseAlternatePolygonization = true
            })
    end
}
