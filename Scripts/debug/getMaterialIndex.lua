RegisterHook("/Script/Astro.AstroPlanet:OnDeformationComplete",
    function(self, params)
        params = params:get() ---@cast params FDeformationParamsT2
        print("Material index = " .. params.MaterialIndex .. "\n")
    end)
