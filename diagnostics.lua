-- Store diagnostic messages received by an LSP.
-- @copyright Jefferson Gonzalez
-- @license MIT

local core = require "core"
local config = require "core.config"
local util = require "plugins.lsp.util"
local Timer = require "plugins.lsp.timer"

---@class lsp.diagnostics
local diagnostics = {}

---@class lsp.diagnostics.position
---@field line integer
---@field character integer

---@class lsp.diagnostics.range
---@field start lsp.diagnostics.position
---@field end lsp.diagnostics.position

---@class lsp.diagnostics.severity
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

---@alias lsp.diagnostics.severity_code
---|>`diagnostics.severity.ERROR`
---| `diagnostics.severity.WARNING`
---| `diagnostics.severity.INFO`
---| `diagnostics.severity.HINT`

---@class lsp.diagnostics.code_description
---@field href string

---@class lsp.diagnostics.tag
---@field UNNECESSARY integer
---@field DEPRECATED integer
diagnostics.tag = {
  UNNECESSARY = 1,
  DEPRECATED = 2
}

---@alias lsp.diagnostics.tag_code
---|>`diagnostics.tag.UNNECESSARY`
---| `diagnostics.tag.DEPRECATED`

---@class lsp.diagnostics.location
---@field uri string
---@field range lsp.diagnostics.range

---@class lsp.diagnostics.related_information
---@field location lsp.diagnostics.location
---@field message string

---A diagnostic message.
---@class lsp.diagnostics.message
---@field filename string
---@field range lsp.diagnostics.position
---@field severity lsp.diagnostics.severity_code | integer
---@field code integer | string
---@field codeDescription lsp.diagnostics.code_description
---@field source string
---@field message string
---@field tags lsp.diagnostics.tag_code[]
---@field relatedInformation lsp.diagnostics.related_information

---A diagnostic item.
---@class lsp.diagnostics.item
---@field filename string
---@field messages lsp.diagnostics.message[]

---@type table<integer, lsp.diagnostics.item>
diagnostics.list = {}

---@type integer
diagnostics.count = 0

-- Try to load lintplus plugin if available for diagnostics rendering
local lintplus_found, lintplus = nil, nil
if config.plugins.lintplus ~= false then
  lintplus_found, lintplus = pcall(require, "plugins.lintplus")
end
local lintplus_kinds = { "error", "warning", "info", "hint" }

---List of linplus coroutines to delay messages population
---@type table<string,lsp.timer>
local lintplus_delays = {}

---Used to set proper diagnostic type on lintplus
---@type table<integer, string>
diagnostics.lintplus_kinds = lintplus_kinds

---@type boolean
diagnostics.lintplus_found = lintplus_found

---@param a lsp.diagnostics.message
---@param b lsp.diagnostics.message
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
  ---@cast filename +nil
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
---@param severity? lsp.diagnostics.severity_code | integer
---@return lsp.diagnostics.message[] | nil
function diagnostics.get(filename, severity)
  ---@cast filename +nil
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
---@param messages lsp.diagnostics.message[]
---@return boolean
function diagnostics.add(filename, messages)
  local index = diagnostics.get_index(filename)

  ---@cast filename +nil
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
---@param severity? lsp.diagnostics.severity_code | integer
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
---@param force boolean
function diagnostics.lintplus_clear_messages(filename, force)
  if lintplus_found then
    if
      not force and lintplus_delays[filename]
      and
      lintplus_delays[filename]:running()
    then
      return
    end
    if filename then
      lintplus.clear_messages(filename)
    else
      for fname, _ in pairs(lintplus.messages) do
        if lintplus_delays[fname] then
          lintplus_delays[fname]:stop()
          lintplus_delays[fname] = nil
        end
        lintplus.clear_messages(fname)
      end
    end
  end
end

---@param filename string
function diagnostics.lintplus_populate(filename)
  if lintplus_found then
    diagnostics.lintplus_clear_messages(filename, true)

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

---@param filename string
---@param user_typed boolean
function diagnostics.lintplus_populate_delayed(filename)
  if lintplus_found then
    if not lintplus_delays[filename] then
      lintplus_delays[filename] = Timer(
        config.plugins.lsp.diagnostics_delay or 500,
        true
      )
      lintplus_delays[filename].on_timer = function()
        diagnostics.lintplus_populate(filename)
        lintplus_delays[filename] = nil
      end
      lintplus_delays[filename]:start()
    else
      lintplus_delays[filename]:reset()
      lintplus_delays[filename]:start()
    end
  end
end


return diagnostics
