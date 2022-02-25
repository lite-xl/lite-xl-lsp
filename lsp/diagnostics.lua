-- Store diagnostic messages received by an LSP.
-- @copyright Jefferson Gonzalez
-- @license MIT

local core = require "core"

local diagnostics = {}

---@class diagnostics.position
---@field line integer
---@field character integer
diagnostics.position = {}

---@class diagnostics.range
---@field start diagnostics.position
---@field end diagnostics.position
diagnostics.range = {}

---@class diagnostics.severity
---@field ERROR integer
---@field WARNING integer
---@field INFO integer
---@field HINT integer
diagnostics.severity = {
  ERROR = 1,
  WARNING = 2,
  INFO = 3,
  HINT = 4
}

---@alias diagnostics.severity_code
---|>'diagnostics.severity.ERROR'
---| 'diagnostics.severity.WARNING'
---| 'diagnostics.severity.INFO'
---| 'diagnostics.severity.HINT'

---@class diagnostics.code_description
---@field href string
diagnostics.code_description = {}

---@class diagnostics.tag
---@field UNNECESSARY integer
---@field DEPRECATED integer
diagnostics.tag = {
  UNNECESSARY = 1,
  DEPRECATED = 2
}

---@alias diagnostics.tag_code
---|>'diagnostics.tag.UNNECESSARY'
---| 'diagnostics.tag.DEPRECATED'

---@class diagnostics.location
---@field uri string
---@field range diagnostics.range
diagnostics.location = {}

---@class diagnostics.related_information
---@field location diagnostics.location
---@field message string
diagnostics.related_information = {}

---A diagnostic message.
---@class diagnostics.message
---@field range diagnostics.position
---@field severity diagnostics.severity_code | integer
---@field code integer | string
---@field codeDescription diagnostics.code_description
---@field source string
---@field message string
---@field tags diagnostics.tag_code[]
---@field relatedInformation diagnostics.related_information
diagnostics.message = {}

---@type table<string, diagnostics.message>
diagnostics.list = {}

---@type integer
diagnostics.count = 0

---@param a diagnostics.message
---@param b diagnostics.message
local function sort_helper(a, b)
  return a.severity < b.severity
end

---Helper to catch some trange occurances where nil is given as filename
---@param filename string
local function get_absolute_path(filename)
  if not filename then
    core.error(
      "[LSP Diagnostics]: nil filename given",
      tostring(filename)
    )
    return nil
  end
  local absolute_filename = system.absolute_path(filename)
  if not absolute_filename then
    core.error(
      "[LSP Diagnostics]: error on absolute conversion of '%s'",
      tostring(filename)
    )
    return filename
  end
  return absolute_filename
end

---Get the diagnostics associated to a file.
---@param filename string
---@param severity? diagnostics.severity_code | integer
---@return diagnostics.message[] | nil
function diagnostics.get(filename, severity)
  filename = get_absolute_path(filename)
  if not filename then return nil end
  if not severity then return diagnostics.list[filename] end
  if not diagnostics.list[filename] then return nil end

  local results = {}
  for _, message in ipairs(diagnostics.list[filename]) do
    if message.severity == severity then table.insert(results, message) end
  end

  return #results > 0 and results or nil
end

---Adds a new list of diagnostics associated to a file replacing previous one.
---@param filename string
---@param messages diagnostics.message[]
---@return boolean
function diagnostics.add(filename, messages)
  filename = get_absolute_path(filename)
  if not filename then return false end
  table.sort(messages, sort_helper)
  if not diagnostics.list[filename] then
    diagnostics.count = diagnostics.count + 1
  end
  diagnostics.list[filename] = messages
  return true
end

---Removes all diagnostics associated to a file.
---@param filename string
function diagnostics.clear(filename)
  filename = get_absolute_path(filename)
  if not filename then return end
  if diagnostics.list[filename] then
    diagnostics.list[filename] = nil
    diagnostics.count = diagnostics.count - 1
  end
end

---Get the amount of diagnostics associated to a file.
---@param filename string
---@param severity? diagnostics.severity_code | integer
function diagnostics.get_messages_count(filename, severity)
  filename = get_absolute_path(filename)
  if not filename then return 0 end
  if diagnostics.list[filename] then
    if not severity then return #diagnostics.list[filename] end

    local count = 0
    for _, message in ipairs(diagnostics.list[filename]) do
      if message.severity == severity then count = count + 1 end
    end
    return count
  end

  return 0
end


return diagnostics
