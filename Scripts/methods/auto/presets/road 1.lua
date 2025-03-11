local UEHelpers = require("UEHelpers")
local sys = UEHelpers.GetKismetSystemLibrary()
local vec3 = Vec3
local rad = math.rad
local EDeformType = EDeformType

---@type Method__Auto__PRESET
return {
    doDeformation = function(p)
        local scale = 400

        -- Planets: SYLVA, DESOLO, CALIDOR, VESANIA, NOVUS, GLACIO, ATROX.
        -- Documentation: if then else | https://www.lua.org/pil/4.3.1.html
        local materialIndex = 128 -- default (gray white)
        if p.planetName == "SYLVA" then
            materialIndex = 16    -- green
        end

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

        local directionMult = scale + 100

        local loc = {
            X = hit.ImpactPoint.X + (direction.x * directionMult),
            Y = hit.ImpactPoint.Y + (direction.y * directionMult),
            Z = hit.ImpactPoint.Z + (direction.z * directionMult),
        }

        p.controller:ClientDoDeformation(
            {
                AutoCreateResourceEfficiency = 0,
                CreativeModeNoResourceCollection = false,
                DeltaTime = 0.03299999982118, -- ???
                ForceRemoveDecorators = false,
                HardnessPenetration = 10,     -- 0 (default) to 10
                Instigator = nil,
                Intensity = 5,
                Location = loc, ---@diagnostic disable-line: assign-type-mismatch
                MaterialIndex = materialIndex,
                Normal = { X = newNormal_vec3.x, Y = newNormal_vec3.y, Z = newNormal_vec3.z },
                Operation = EDeformType.Flatten,
                Scale = 400,
                SequenceNumber = 0,
                Shape = 0,
                bEasyUnbury = false,
                bUseAlternatePolygonization = true
            })
    end
}
