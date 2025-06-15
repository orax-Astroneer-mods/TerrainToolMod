---@type Mod_Options_Item
local DEFAULT_OPTIONS_ITEM = {
  id = "",
  n = 0,
  enabled = true,
  className = "",
  shortClassName = "",
  filters = {},
  instances = function() return {} end,
  minNumberOfInstancesToFind = 0,
  target = "",
  targetVars = {},
  epsilon = 0.01,
  pre = {},
  post = {},
  updateNewObjects = true,
  reapplyOnModRestart = false,
  logLevel = false,
  logLevelForFatalError = false,
}

---@type Mod_Config
local DEFAULT_CONFIG = {
  OPTIONS_FILES = "options.lua",
  FORCE_REAPPLY_ON_MOD_RESTART = false,
  LOG_LEVEL = "WARN",
  MIN_LEVEL_OF_FATAL_ERROR = "ERROR"
}

local string, pairs, ipairs, type = string, pairs, ipairs, type

local M = {}
M.table = {}

---@return Mod_ModInfo
---@nodiscard
function M.getModInfo(info)
  if not info then
    info = debug.getinfo(2, "S")
  end

  local source = info.source:gsub("\\", "/")

  ---@type Mod_ModInfo
  return {
    name = source:match("@?.+/Mods/([^/]+)"),
    file = source:sub(2),
    currentDirectory = source:match("@?(.+)/"),
    currentModDirectory = source:match("@?(.+/Mods/[^/]+)"),
    modsDirectory = source:match("@?(.+/Mods)/")
  }
end

---@param list table
---@param value any
---@return boolean
---@nodiscard
function M.table.includes(list, value)
  for _, v in ipairs(list) do
    if v == value then
      return true
    end
  end

  return false
end

---@param instance UObject
---@param list table<number, string>
---@return boolean
---@return string
function M.inheritFromTheseClasses(instance, list)
  assert(#list > 0)

  for _, className in ipairs(list) do
    if instance:IsA(className) then
      return true, className
    end
  end

  return false, ""
end

---@param str string
---@param separator string
---@return table
---@nodiscard
function M.stringToTable(str, separator)
  local list = {}
  local i = 1
  local matches = string.gmatch(str, "[^" .. separator .. "]+")

  for s in matches do
    list[s] = i
    i = i + 1
  end

  return list
end

---@param list table
---@nodiscard
function M.flattenTable(list)
  local flatTable = {}

  for _, subTable in ipairs(list) do
    for k, v in pairs(subTable) do
      flatTable[k] = v
    end
  end

  return flatTable
end

---@return table
---@nodiscard
function M.getEnabledModsList()
  local enabledMods = {}

  for line in io.lines(M.mod.modsDirectory .. "/mods.txt") do
    line = string.gsub(line, ";.*", "")
    line = string.gsub(line, "%s", "")
    if line ~= "" then
      local modName, enabled = string.match(line, "([^:]+):(%d)")

      if enabled == "1" then
        enabledMods[modName] = true
      else
        enabledMods[modName] = false
      end
    end
  end

  local fileList = M.getFileList(M.mod.modsDirectory, "enabled.txt")

  for _, v in ipairs(fileList) do
    local modName = string.match(v, "Mods/([^/]+)/enabled%.txt")
    if modName ~= nil then
      enabledMods[modName] = true
    end
  end

  return enabledMods
end

---@param path string
---@return string
---@nodiscard
function M.getRelPathToModsDir(path)
  local relPath, _ = path:gsub("\\", "/"):gsub("@?.+/Mods/", "")

  return relPath
end

---@param object UObject
---@param options table
---@deprecated
function M.patch(object, options)
  for k, v in pairs(options) do
    object[k] = v

    local isEqual

    if type(object[k]) == "number" or type(v) == "number" then
      isEqual = M.isAlmostEqual(object[k], v)
    else
      isEqual = object[k] ~= v
    end

    if not isEqual then
      local msg = string.format("Unable to change variable value as expected: `%s.%s`.\n",
        ---@diagnostic disable-next-line: undefined-field
        object:GetFName():ToString(), k)
      msg = msg .. string.format("Actual: %s\n", object[k])
      msg = msg .. string.format("Expected: %s\n", v)
      msg = msg .. string.format("Object full name: %s\n", object:GetFullName())
      msg = msg .. M.getTraceback()

      M.warn(msg)
    end
  end
end

---@param x number|string|boolean
---@param y number|string|boolean
---@param epsilon number
---@return boolean
---@nodiscard
function M.checkEquality(x, y, epsilon)
  local isEqual = false

  if type(x) == "number" or type(y) == "number" then
    isEqual = M.isAlmostEqual(x, y, epsilon)
  else
    isEqual = x ~= y
  end

  return isEqual
end

-- Math symbol: ≈ (Unicode: U+2248 ALMOST EQUAL TO).
function M.isAlmostEqual(x, y, epsilon)
  if epsilon == nil then
    epsilon = 0.01
  end

  return math.abs(x - y) < epsilon
end

---@param x number
---@return number
---@nodiscard
function M.round(x)
  local power = 10 ^ 2
  return math.floor(x * power) / power
end

---@param file string
---@return string
---@nodiscard
function M.getOptionsFileFullPath(file)
  assert(type(file) == "string" and file ~= "",
    "Can't get the options file. type(file) is " .. type(file))

  return string.format("%s/%s/%s", M.mod.modsDirectory, M.mod.name, file)
end

---Set default parameters to each item.
---@param options Mod_Options
---@return Mod_Options
---@nodiscard
local function setDefaultOptions(options)
  -- set default value on each item
  for _, item in ipairs(options.items) do
    for optName, defaultValue in pairs(DEFAULT_OPTIONS_ITEM) do
      if item[optName] == nil then
        -- set the global default option if it exists
        if options.default[optName] ~= nil then
          item[optName] = options.default[optName]
        else
          item[optName] = defaultValue
        end
      end
    end
  end

  return options
end

---Check options.
---@param options Mod_Options
---@return string?
---@nodiscard
local function checkOptions(options)
  local errMessage
  local errors = {}

  -- check if the "items" option exists
  if options.items == nil then
    options.items = {}
    table.insert(errors, [[The "items" option is nil.]])
  end

  local msg = "%q is an invalid parameter. Location: "

  -- check each parameter in options.default
  for k, _ in pairs(options.default) do
    if type(k) ~= "number" and DEFAULT_OPTIONS_ITEM[k] == nil then
      table.insert(errors, string.format(msg .. [["default" table.]], k))
    end
  end

  -- check each parameter in options.items
  for index, item in ipairs(options.items) do
    for k, _ in pairs(item) do
      if type(k) ~= "number" and DEFAULT_OPTIONS_ITEM[k] == nil then
        table.insert(errors, string.format(msg .. [[item n°%i/%i ID %q.]],
          k, index, #options.items, item.id))
      end
    end
  end

  -- build errors messages
  msg = [[There are one or more %q in the options file "%s":]] .. "\n"
  if #errors > 0 then
    errMessage = string.format(msg, "errors", options.file)
    for errIndex, error in ipairs(errors) do
      errMessage = errMessage .. string.format("- (error %i/%i) %s\n", errIndex, #errors, error)
    end
  end

  return errMessage
end

---Load options from the options file.
---Items ID, file and path fields will be added in the options table.
---@param file string
---@return Mod_Options
---@return string?
---@return string?
---@nodiscard
function M.loadOptions(file)
  local path = M.getOptionsFileFullPath(file)
  local options = dofile(path) ---@type Mod_Options

  options.default = options.default or {}

  -- add file and path fields, we do not have to add them manually
  options.file = file
  options.path = path

  local warn, err = checkOptions(options)
  options = setDefaultOptions(options)

  return options, warn, err
end

---@param str string
---@return table
---@nodiscard
function M.parseConfigOptionsFiles(str)
  local list = {}

  -- remove extra spaces
  str = string.gsub(str, "%s*%|%s*", "|")
  str = string.gsub(str, "^%s*", "")
  str = string.gsub(str, "%s*$", "")

  for file in string.gmatch(str, "[^|]+") do
    table.insert(list, file)
  end

  return list
end

---@param configTable Mod_Config
---@param configFile string
---@return Mod_Config
---@nodiscard
function M.mergeConfig(configTable, configFile)
  assert(type(configTable) == "table",
    "The variable 'configTable' is not a table. Type is: %s " .. type(configTable))

  local config = dofile(configFile)

  if config == nil or type(config) ~= "table" then
    return configTable
  end

  for k, v in pairs(config) do
    configTable[k] = v
  end

  return configTable
end

---@param directory string
---@param filter string
---@return table
---@nodiscard
function M.getFileList(directory, filter)
  local fileList = {}

  local handle = io.popen(string.format('dir "%s" /B /S', directory))
  if handle then
    for fileName in handle:lines() do
      fileName = fileName:gsub("\\", "/")
      if fileName:match(filter) then
        table.insert(fileList, fileName)
      end
    end
    handle:close()
  end

  return fileList
end

---@param filename string
---@return boolean
---@nodiscard
function M.isFileExists(filename)
  local file = io.open(filename, "r")
  if file ~= nil then
    io.close(file)
    return true
  else
    return false
  end
end

---@param list table
function M.printTable(list)
  local str = "{\n"

  for k, v in pairs(list) do
    str = string.format("%s%s: %s\n", str, k, v)
  end

  str = str .. "}\n"

  print(str)
end

---@deprecated
function M.__LINE__()
  return debug.getinfo(2, 'l').currentline
end

---@deprecated
function M.__NAME__()
  return debug.getinfo(2, "n").name
end

---@param msg? string
---@return string
---@nodiscard
function M.getTraceback(msg)
  return debug.traceback(msg, 2)
end

---@param fileName? string
---@return Mod_Config
---@nodiscard
function M.loadConfig(fileName)
  fileName = fileName or "config.lua"

  local config = DEFAULT_CONFIG

  -- load config.lua if exists
  local configFromFile = {}
  local path = M.mod.currentDirectory .. "/" .. fileName
  if M.isFileExists(path) then
    configFromFile = dofile(path)
  end

  local obtainedFrom = {}
  local sources = { "file (" .. fileName .. ")", "shared_variable", "env", "default_config" }

  -- override default configuration values ​​if other values ​​exist
  -- priority: config.lua > GetSharedVariable(key) > getenv(key > DEFAULT_CONFIG)
  for k, _ in pairs(config) do
    local t = { configFromFile[k], ModRef:GetSharedVariable(k), os.getenv(k), config[k] }

    for index, value in pairs(t) do
      if value ~= nil then
        config[k] = value
        obtainedFrom[k] = sources[index] -- useful for logging

        goto continue
      end
    end

    assert(config[k] ~= nil)

    ::continue::
  end

  -- logging
  local str = ""
  for k, v in pairs(config) do
    str = (string.format([[%s=%s from %s]], k, v, obtainedFrom[k])) .. "; " .. str
  end
  print(str)

  return config
end

M.mod = M.getModInfo(debug.getinfo(3, "S"))

return M
