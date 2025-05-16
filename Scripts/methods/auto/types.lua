---@class Method__Auto: TerrainToolMod_Method

---@class Method__Auto__PARAMS
---@field LATEST_PRESET string
---@field LOOP_DELAY integer
---@field SPEED_LIMIT float
---@field NO_SLIDING boolean

---@class Method__Auto__PRESET
---@field doDeformation fun(params: Method__Auto__PRESET_DeformationParams)

---@class Method__Auto__Capsule
---@field halfHeight float
---@field radius float

---@class Method__Auto__PRESET_DeformationParams
---@field altitude float
---@field angle float
---@field capsule Method__Auto__Capsule
---@field character UObject|ADesignAstro_C
---@field characterLocation FVector
---@field controller APlayController
---@field floor FVector
---@field forward FVector
---@field justActivated boolean
---@field planetCenter FVector
---@field planetName string
---@field relativeFloor FVector
---@field right FVector
---@field up FVector
---@field world UWorld
