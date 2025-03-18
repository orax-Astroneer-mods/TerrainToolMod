--[[
    How to get a "material index" (color)?

    Open the "paint" method (shortcut "5" by default) and click on a color to see its material index.
]]

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
        local normal = p.character:GetActorUpVector()

        -- Planets: SYLVA, DESOLO, CALIDOR, VESANIA, NOVUS, GLACIO, ATROX.
        local materialIndex = 128 -- default (gray white)
        if p.planetName == "SYLVA" then
            materialIndex = 1
        elseif p.planetName == "DESOLO" then
            materialIndex = 0
        elseif p.planetName == "CALIDOR" then
            materialIndex = 3
        elseif p.planetName == "VESANIA" then
            materialIndex = 0
        elseif p.planetName == "NOVUS" then
            materialIndex = 0
        elseif p.planetName == "GLACIO" then
            materialIndex = 0
        elseif p.planetName == "ATROX" then
            materialIndex = 0
        end

        p.controller:ClientDoDeformation(
            {
                AutoCreateResourceEfficiency = 0,
                CreativeModeNoResourceCollection = false,
                DeltaTime = 0.03299999982118, -- ???
                ForceRemoveDecorators = false,
                HardnessPenetration = 0,
                Instigator = nil,
                Intensity = 0,
                Location = { X = p.floor.X, Y = p.floor.Y, Z = p.floor.Z },
                MaterialIndex = materialIndex,
                Normal = { X = normal.X, Y = normal.Y, Z = normal.Z },
                Operation = EDeformType.ColorPaint,
                Scale = 500,
                SequenceNumber = 0,
                Shape = 0,
                bEasyUnbury = false,
                bUseAlternatePolygonization = true
            })
    end
}
