-- Store diagnostic messages received by an LSP.
-- @copyright Jefferson Gonzalez
-- @license MIT

local core = require "core"
local config = require "core.config"
local util = require "plugins.lsp.util"

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

-- Try to load lintplus plugin if available for diagnostics rendering
local lintplus_found, lintplus = nil, nil
if config.plugins.lintplus ~= false then
  lintplus_found, lintplus = pcall(require, "plugins.lintplus")
end
local lintplus_kinds = { "error", "warning", "info", "hint" }

---@class diagnostic.timer
---@field typed boolean
---@field routine integer

---List of linplus coroutines to delay messages population
---@type table<string,diagnostic.timer>
local lintplus_delays = {}

---Used to set proper diagnostic type on lintplus
---@type table<integer, string>
diagnostics.lintplus_kinds = lintplus_kinds

---@type boolean
diagnostics.lintplus_found = lintplus_found

---@param a diagnostics.message
---@param b diagnostics.message
local function sort_helper(a, b)
  return a.severity < b.severity
end

---Helper to catch some trange occurances where nil is given as filename
---@param filename string|nil
---@return string | nil
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

---@param doc core.doc
function diagnostics.lintplus_init_doc(doc)
  if lintplus_found then
    lintplus.init_doc(doc.filename, doc)
  end
end

---Remove registered diagnostics from lintplus for the given file or for
---all files if no filename is given.
---@param filename? string
function diagnostics.lintplus_clear_messages(filename)
  if lintplus_found then
    if filename then
      lintplus.clear_messages(filename)
    else
      for fname, _ in pairs(lintplus.messages) do
        lintplus.clear_messages(fname)
      end
    end
  end
end

function diagnostics.lintplus_populate(filename)
  if lintplus_found then
    diagnostics.lintplus_clear_messages(filename)

    if not filename then
      for _, diagnostic in ipairs(diagnostics.list) do
        local fname = core.normalize_to_project_dir(diagnostic.filename)
        for _, message in pairs(diagnostic.messages) do
          local line, col = util.toselection(message.range)
          local text = message.message
          local kind = lintplus_kinds[message.severity]

          lintplus.add_message(fname, line, col, kind, text)
        end
      end
    else
      local messages = diagnostics.get(filename)
      if messages then
        for _, message in pairs(messages) do
          local line, col = util.toselection(message.range)
          local text = message.message
          local kind = lintplus_kinds[message.severity]

          lintplus.add_message(
            core.normalize_to_project_dir(filename),
            line, col, kind, text
          )
        end
      end
    end
  end
end

function diagnostics.lintplus_populate_delayed(filename, user_typed)
  if lintplus_found then
    if not lintplus_delays[filename] then
      lintplus_delays[filename] = {
        typed = user_typed,
        routine = core.add_thread(function()
          local prev_time = system.get_time()
          while (prev_time + 1) > system.get_time() do
            if lintplus_delays[filename].typed then
              prev_time = system.get_time()
            end
            coroutine.yield(0)
          end
          diagnostics.lintplus_populate(filename)
          lintplus_delays[filename] = nil
        end)
      }
    else
      lintplus_delays[filename].typed = user_typed
    end
  end
end


return diagnostics
