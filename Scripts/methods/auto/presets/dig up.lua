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

--[[

    params.AutoCreateResourceEfficiency, 0.0
    params.CreativeModeNoResourceCollection,   true
    params.1/30,  0.032999999821186
    params.ForceRemoveDecorators,  false
    params.HardnessPenetration,     0
    params.Instigator,    FWeakObjectPtr: 000002A270F12F08
    string.format("%.16g", params.Intensity),   12.5
    params.Location.X,
    params.Location.Y,
    params.Location.Z,
    params.MaterialIndex, -1
    params.Normal.X,
    params.Normal.Y,
    params.Normal.Z,
    params.Operation, 0
    params.Scale,    385.0
    params.SequenceNumber, 0
    params.Shape, 0
    params.bEasyUnbury, false
    params.bUseAlternatePolygonization true

]]
---@type Method__Auto__PRESET
return {
    doDeformation = function(p)
        local scale = 1000

        local relativeFloor = vec3.new(
            p.floor.X - p.planetCenter.X,
            p.floor.Y - p.planetCenter.Y,
            p.floor.Z - p.planetCenter.Z)

        local right_vec3 = vec3.new(p.right.X, p.right.Y, p.right.Z)
        local newNormal_vec3 = vec3.normalize(vec3.rotate(relativeFloor, rad(p.angle), right_vec3))

        local endLoc = {
            X = p.characterLocation.X - p.up.X * scale,
            Y = p.characterLocation.Y - p.up.Y * scale,
            Z = p.characterLocation.Z - p.up.Z * scale
        }

        ---@diagnostic disable-next-line: missing-fields
        local hit = {} ---@type FHitResult
        local result = sys:LineTraceSingleForObjects(p.world,
            p.characterLocation, endLoc, { 6 }, false, {}, 0, hit, true, {}, {}, 0) ---@diagnostic disable-line: missing-fields
        if not result then return end

        local directionMult = scale / 2

        local loc = {
            X = hit.ImpactPoint.X + (p.up.X * directionMult),
            Y = hit.ImpactPoint.Y + (p.up.Y * directionMult),
            Z = hit.ImpactPoint.Z + (p.up.Z * directionMult),
        }

        p.controller:ClientDoDeformation(
            {
                AutoCreateResourceEfficiency = 0,
                CreativeModeNoResourceCollection = false,
                DeltaTime = 1 / 30,
                ForceRemoveDecorators = false,
                HardnessPenetration = 10, -- 0 (default) to 10
                Instigator = nil,
                Intensity = 5,
                Location = loc, ---@diagnostic disable-line: assign-type-mismatch
                MaterialIndex = -1,
                Normal = { X = newNormal_vec3.x, Y = newNormal_vec3.y, Z = newNormal_vec3.z },
                Operation = EDeformType.Subtract,
                Scale = scale,
                SequenceNumber = 0,
                Shape = 0,
                bEasyUnbury = false,
                bForceUnburyWithNoDeformationEvent = false,
                bUseAlternatePolygonization = false,
            })
    end
}
