---@meta _

---@class (exact) Mod_Config
---@field LOG_LEVEL _LogLevel The logging level.
---@field MIN_LEVEL_OF_FATAL_ERROR _LogLevel The minimum logging level for fatal errors.
---@field OPTIONS_FILES string The list of options files.
---@field FORCE_REAPPLY_ON_MOD_RESTART boolean Reapply changes when you restart the mod?
__CONFIG = {} -- Global configuration.

---@type Mod_Logger
---@diagnostic disable-next-line: missing-fields
__LOGGER = {}

---@class (exact) Mod_ModInfo
---@field name string The name of the mod.
---@field file string
---@field currentDirectory string
---@field modsDirectory string

---@class (exact) Mod_Options
---@field items Mod_Options_Item[]
---@field default Mod_Options_Item Default parameters.
---@field file string This field is set automatically.
---@field path string This field is set automatically.
---@field loader? fun(func: function): any

---@class (exact) Mod_Options_Item
---@field id string This field is set automatically.
---@field n number This field is set automatically.
---@field enabled boolean Is this item enabled?
---@field className string The class name.
---@field shortClassName string The short class name.
---@field filters table<integer, fun(instance: UObject, item: Mod_Options_Item): boolean>
---@field instances fun(): UObject[] The list of the instances found.
---@field minNumberOfInstancesToFind number Minimum number of instances to find.
---@field target string | fun(instance: UObject, ...: any): UObject The target instance.
---@field targetVars table<string, any> The list of target variables.
---@field epsilon number Epsilon is used to determine whether two numbers are almost equal in the following calculation: `math.abs(x - y) < epsilon.`
---@field pre table<integer, fun(instance: UObject, property: string, value: any, item: Mod_Options_Item): any> The list of functions that are called before the property value changes.
---@field post table<integer, fun(instance: UObject, property: string, value: any, item: Mod_Options_Item): any> The list of functions that are called after the property value changes.
---@field updateNewObjects boolean Will new object instances be updated/patched?
---@field reapplyOnModRestart boolean Reapply changes when you restart the mod?
---@field logLevel _LogLevel|false The logging level.
---@field logLevelForFatalError _LogLevel|false The minimum logging level for fatal errors.
---@field [integer] table Indexed tables that contain property values.

---@class Mod_Logger
local logger = {}
---@param ... any
function logger.trace(value, ...) end

---@param ... any
function logger.debug(value, ...) end

---@param ... any
function logger.info(value, ...) end

---@param ... any
function logger.warn(value, ...) end

---@param ... any
function logger.error(value, ...) end

---@param ... any
function logger.fatal(value, ...) end

---@param newLevel? _LogLevel
---@param newLevelForFatalError? _LogLevel
function logger.setLevel(newLevel, newLevelForFatalError) end

--------------------------------------------------------------------------------
--#region Fixes things from UE4SS Types.lua

---@class LocalObject

---@class FName : LocalObject
FName = {}
--Returns the string for this FName.
---@return string
function FName.ToString() end

--#endregion
