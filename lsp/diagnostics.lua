-- Store diagnostic messages received by an LSP.
-- @copyright Jefferson Gonzalez
-- @license MIT

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
---|>'diagnostics.ERROR'
---| 'diagnostics.WARNING'
---| 'diagnostics.INFO'
---| 'diagnostics.HINT'

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
---@field tags diagnostics.tag[]
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

---Get the diagnostics associated to a file.
---@param filename string
---@param severity? diagnostics.severity_code
---@return diagnostics.message[] | nil
function diagnostics.get(filename, severity)
  if not severity then return diagnostics.list[filename] end

  local results = {}
  for _, message in ipairs(diagnostics.list) do
    if message.severity == severity then table.insert(results, message) end
  end

  return #results > 0 and results | nil
end

---Adds a new list of diagnostics associated to a file replacing previous one.
---@param filename string
---@param messages diagnostics.message[]
function diagnostics.add(filename, messages)
  table.sort(messages, sort_helper)
  if not diagnostics.list[filename] then
    diagnostics.count = diagnostics.count + 1
  end
  diagnostics.list[filename] = messages
end

---Removes all diagnostics associated to a file.
---@param filename string
function diagnostics.clear(filename)
  if diagnostics.list[filename] then
    diagnostics.list[filename] = nil
    diagnostics.count = diagnostics.count - 1
  end
end

---Get the amount of diagnostics associated to a file.
---@param filename string
---@param severity? diagnostics.severity_code
function diagnostics.get_messages_count(filename, severity)
  if diagnostics.list[filename] then
    if not severity then return #diagnostics.list[filename] end

    local count = 0
    for _, message in ipairs(diagnostics.list) do
      if message.severity == severity then count = count + 1 end
    end
    return count
  end

  return 0
end


return diagnostics
