---@meta _

---@class (exact) TerrainToolMod_Method
---@field params table
---@field hook_DeformTool_HandleTerrainTool fun(self: RemoteUnrealParam, controller: RemoteUnrealParam, toolHit: RemoteUnrealParam, clickResult: RemoteUnrealParam, startedInteraction: RemoteUnrealParam, endedInteraction: RemoteUnrealParam, isUsingTool: RemoteUnrealParam, justActivated: RemoteUnrealParam, canUse): boolean
---@field hook_DeformTool_Deactivated fun(self: RemoteUnrealParam)?
---@field hook_TerrainToolCreativeMenu_OnColorAndTypePicked fun(self: UTerrainToolCreativeMenu_C, SelectedColor: FLinearColor, SelectedColorIndex: int32, PaintType: EPaintIndexType)?
---@field onLoad fun()?
---@field onUnload fun()?
---@field onUpdate fun()?
---@field onClientRestart fun(self: RemoteUnrealParam, newPawn: ADesignAstro_C, firstInitialization: boolean)?
---@field onModRestartedOrStartedManually fun(firstInitialization: boolean)?
---@field hook_Planet_Marker_HandlePlanetMarkerSelected fun(self: RemoteUnrealParam)?
---@field PlayerController_ClientReceiveLocalizedMessage fun(...)?

---@class TerrainToolMod_Main_PARAMS
---@field LATEST_METHOD string

---@class TerrainToolMod_Debug
---@field material UObject|UMaterialInterface
---@field matClassName string
---@field mesh UObject|UStaticMesh
---@field meshClassName string
---@field scale FVector
---@field staticMeshActorClass UObject|UClass
---@field staticMeshActorClassShortName string
---@field staticMeshActorClassName string
