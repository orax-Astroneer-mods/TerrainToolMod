---@meta _

---@class (exact) TerrainToolMod_Method
---@field params table
---@field hook_DeformTool_HandleTerrainTool fun(self: RemoteUnrealParam, controller: RemoteUnrealParam, toolHit: RemoteUnrealParam, clickResult: RemoteUnrealParam, startedInteraction: RemoteUnrealParam, endedInteraction: RemoteUnrealParam, isUsingTool: RemoteUnrealParam, justActivated: RemoteUnrealParam, canUse): boolean
---@field hook_DeformTool_Deactivated fun(self: RemoteUnrealParam)?
---@field onLoad fun(FirstInit: boolean?)? -- True when the mod has just been loaded.
---@field onUnload fun()?
---@field onEnable fun()?
---@field onDisable fun()?
---@field onUpdate fun()?
---@field onClientRestart fun(self: RemoteUnrealParam, NewPawn: RemoteUnrealParam)?

---@class TerrainToolMod_Main_PARAMS
---@field METHOD string

---@class TerrainToolMod_Debug
---@field staticMeshActorClassShortName string
---@field staticMeshActorClassName string
---@field staticMeshActorClass UClass?
---@field material UMaterialInterface?
---@field mesh UStaticMesh?
---@field scale FVector
---@field meshClassName string
---@field matClassName string
