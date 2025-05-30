--[[
    How to get a "material index" (color)?

    Open the "paint" method (shortcut "5" by default) and click on a color to see its material index.
]]

local UEHelpers = require("UEHelpers")
local sys = UEHelpers.GetKismetSystemLibrary()
local vec3 = Vec3
local rad, random = math.rad, math.random

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

-- Planets: SYLVA, DESOLO, CALIDOR, VESANIA, NOVUS, GLACIO, ATROX.

-- The color and number of materials vary depending on the planets.
-- For example, SYLVA have a palette of 17 colors.
-- To see these colors, open the Terrain Tool Menu in Creative mode.
local mat = 0
local mat2 = 0
local materials = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 }
local materials2 = { 2, 3 }

local i1 = 1
local n1 = 10

---@type Method__Auto__PRESET
return {
    doDeformation = function(p)
        if i1 < n1 then
            i1 = i1 + 1
        else
            n1 = random(10)
            i1 = 1
            mat = random(#materials)
        end

        mat2 = random(#materials2)


        local directionOffset = 0
        local scale = 2000
        local scale2 = 1000

        local relativeFloor = vec3.new(
            p.floor.X - p.planetCenter.X,
            p.floor.Y - p.planetCenter.Y,
            p.floor.Z - p.planetCenter.Z)

        local right_vec3 = vec3.new(p.right.X, p.right.Y, p.right.Z)
        local newNormal_vec3 = vec3.normalize(vec3.rotate(relativeFloor, rad(p.angle), right_vec3))
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

        local direction = vec3.normalize(vec3.rotate(
            vec3.new(p.forward.X, p.forward.Y, p.forward.Z),
            rad(p.angle),
            vec3.new(p.right.X, p.right.Y, p.right.Z)))

        local directionMult = scale + directionOffset

        local loc = {
            X = hit.ImpactPoint.X + (direction.x * directionMult),
            Y = hit.ImpactPoint.Y + (direction.y * directionMult),
            Z = hit.ImpactPoint.Z + (direction.z * directionMult),
        }

        local relativeLoc_vec3 = vec3.new(
            p.floor.X - p.planetCenter.X,
            p.floor.Y - p.planetCenter.Y,
            p.floor.Z - p.planetCenter.Z)

        local fw_vec3 = vec3.new(p.forward.X, p.forward.Y, p.forward.Z)

        local up = vec3.new(
            p.floor.X + newNormal_vec3.x * scale2,
            p.floor.Y + newNormal_vec3.y * scale2,
            p.floor.Z + newNormal_vec3.z * scale2)

        local leftDeform_loc = up - right_vec3 * (scale - 300)
        local leftDeform_normal = vec3.normalize(vec3.rotate(relativeLoc_vec3, rad(-90), fw_vec3))

        local rightDeform_loc = up + right_vec3 * (scale - 300)
        local rightDeform_normal = vec3.normalize(vec3.rotate(relativeLoc_vec3, rad(90), fw_vec3))

        p.controller:ClientDoDeformation(
            {
                AutoCreateResourceEfficiency = 0,
                CreativeModeNoResourceCollection = false,
                DeltaTime = 0.03299999982118, -- ???
                ForceRemoveDecorators = false,
                HardnessPenetration = 0,
                Instigator = nil,
                Intensity = 5,
                Location = loc, ---@diagnostic disable-line: assign-type-mismatch
                MaterialIndex = materials[mat],
                Normal = { X = newNormal_vec3.x, Y = newNormal_vec3.y, Z = newNormal_vec3.z },
                Operation = EDeformType.Flatten,
                Scale = scale,
                SequenceNumber = 0,
                Shape = 0,
                bEasyUnbury = false,
                bUseAlternatePolygonization = true
            })

        -- left
        p.controller:ClientDoDeformation(
            {
                AutoCreateResourceEfficiency = 0,
                CreativeModeNoResourceCollection = false,
                DeltaTime = 0.03299999982118, -- ???
                ForceRemoveDecorators = false,
                HardnessPenetration = 0,
                Instigator = nil,
                Intensity = 5,
                Location = { X = leftDeform_loc.x, Y = leftDeform_loc.y, Z = leftDeform_loc.z },
                MaterialIndex = materials2[mat2],
                Normal = { X = leftDeform_normal.x, Y = leftDeform_normal.y, Z = leftDeform_normal.z },
                Operation = EDeformType.Flatten,
                Scale = scale2,
                SequenceNumber = 0,
                Shape = 0,
                bEasyUnbury = false,
                bUseAlternatePolygonization = true
            })

        -- right
        p.controller:ClientDoDeformation(
            {
                AutoCreateResourceEfficiency = 0,
                CreativeModeNoResourceCollection = false,
                DeltaTime = 0.03299999982118, -- ???
                ForceRemoveDecorators = false,
                HardnessPenetration = 0,
                Instigator = nil,
                Intensity = 5,
                Location = { X = rightDeform_loc.x, Y = rightDeform_loc.y, Z = rightDeform_loc.z },
                MaterialIndex = materials2[mat2],
                Normal = { X = rightDeform_normal.x, Y = rightDeform_normal.y, Z = rightDeform_normal.z },
                Operation = EDeformType.Flatten,
                Scale = scale2,
                SequenceNumber = 0,
                Shape = 0,
                bEasyUnbury = false,
                bUseAlternatePolygonization = true
            })
    end
}
