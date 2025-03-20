---@meta _

---@class (exact) Method
---@field params table
---@field handleTerrainTool_hook fun(self: RemoteUnrealParam, controller: RemoteUnrealParam, toolHit: RemoteUnrealParam, clickResult: RemoteUnrealParam, startedInteraction: RemoteUnrealParam, endedInteraction: RemoteUnrealParam, isUsingTool: RemoteUnrealParam, justActivated: RemoteUnrealParam, canUse): boolean
---@field onLoad fun(init: boolean?)? -- True when the mod has just been loaded.
---@field onUnload fun()?
---@field onEnable fun()?
---@field onDisable fun()?
---@field onUpdate fun()? -- On F2 pressed twice.
---@field onClientRestart fun(self: RemoteUnrealParam, NewPawn: RemoteUnrealParam)?

---@class TerrainToolMod_Main_PARAMS
---@field METHOD string
