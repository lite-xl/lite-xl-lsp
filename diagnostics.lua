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
---@field filename string
---@field range diagnostics.position
---@field severity diagnostics.severity_code | integer
---@field code integer | string
---@field codeDescription diagnostics.code_description
---@field source string
---@field message string
---@field tags diagnostics.tag_code[]
---@field relatedInformation diagnostics.related_information
diagnostics.message = {}

---A diagnostic item.
---@class diagnostics.item
---@field filename string
---@field messages diagnostics.message[]
diagnostics.message = {}

---@type table<integer, diagnostics.item>
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
  return core.project_absolute_path(filename)
end

---Get the position of diagnostics associated to a file.
---@param filename string
---@return integer | nil
function diagnostics.get_index(filename)
  filename = get_absolute_path(filename)
  if not filename then return nil end
  for index, diagnostic in ipairs(diagnostics.list) do
    if diagnostic.filename == filename then
      return index
    end
  end
  return nil
end

---Get the diagnostics associated to a file.
---@param filename string
---@param severity? diagnostics.severity_code | integer
---@return diagnostics.message[] | nil
function diagnostics.get(filename, severity)
  filename = get_absolute_path(filename)
  if not filename then return nil end
  for _, diagnostic in ipairs(diagnostics.list) do
    if diagnostic.filename == filename then
      if not severity then return diagnostic.messages end

      local results = {}
      for _, message in ipairs(diagnostic.messages) do
        if message.severity == severity then table.insert(results, message) end
      end

      return #results > 0 and results or nil
    end
  end
  return nil
end

---Adds a new list of diagnostics associated to a file replacing previous one.
---@param filename string
---@param messages diagnostics.message[]
---@return boolean
function diagnostics.add(filename, messages)
  local index = diagnostics.get_index(filename)

  filename = get_absolute_path(filename)
  if not filename then return false end

  table.sort(messages, sort_helper)

  if not index then
    diagnostics.count = diagnostics.count + 1
    table.insert(diagnostics.list, {
      filename = filename, messages = messages
    })
  else
    diagnostics.list[index].messages = messages
  end

  return true
end

---Removes all diagnostics associated to a file.
---@param filename string
function diagnostics.clear(filename)
  local index = diagnostics.get_index(filename)

  if index then
    table.remove(diagnostics.list, index)
    diagnostics.count = diagnostics.count - 1
  end
end

---Get the amount of diagnostics associated to a file.
---@param filename string
---@param severity? diagnostics.severity_code | integer
function diagnostics.get_messages_count(filename, severity)
  local index = diagnostics.get_index(filename)

  if not index then return 0 end

  if not severity then return #diagnostics.list[index].messages end

  local count = 0
  for _, message in ipairs(diagnostics.list[index].messages) do
    if message.severity == severity then count = count + 1 end
  end

  return count
end


return diagnostics
