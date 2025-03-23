RegisterHook("/Script/Astro.AstroPlanet:OnDeformationComplete",
    function(self, params)
        params = params:get() ---@cast params FDeformationParamsT2
        print(params.AutoCreateResourceEfficiency,
            params.CreativeModeNoResourceCollection,
            params.DeltaTime,
            params.ForceRemoveDecorators,
            params.HardnessPenetration,
            params.Instigator,
            string.format("%.16g", params.Intensity),
            params.Location.X,
            params.Location.Y,
            params.Location.Z,
            params.MaterialIndex,
            params.Normal.X,
            params.Normal.Y,
            params.Normal.Z,
            params.Operation,
            params.Scale,
            params.SequenceNumber,
            params.Shape,
            params.bEasyUnbury,
            params.bUseAlternatePolygonization
        )
    end)
