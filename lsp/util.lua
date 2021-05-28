-- @copyright Jefferson Gonzalez
-- @license MIT
-- Some functions adapted from: https://github.com/orbitalquark/textadept-lsp

local config = require "core.config"

local util = {}

function util.split(s, delimiter)
  local result = {};
  for match in (s..delimiter):gmatch("(.-)"..delimiter) do
    table.insert(result, match);
  end
  return result;
end

function util.file_extension(filename)
  local parts = util.split(filename, "%.")
  if #parts > 1 then
    return parts[#parts]:gsub("%%", "")
  end

  return filename
end

function util.file_exists(file_path)
  local file = io.open(file_path, "r")
  if file ~= nil then
    file:close()
    return true
  end
 return false
end

-- Converts the given LSP DocumentUri into a valid filename and returns it.
-- @param uri LSP DocumentUri to convert into a filename.
function util.tofilename(uri)
  local filename = ""
  if PLATFORM == "Windows" then
    filename = uri:gsub('^file:///', '')
  else
    filename = uri:gsub('^file://', '')
  end

  filename = filename:gsub(
    '%%(%x%x)',
    function(hex) return string.char(tonumber(hex, 16)) end
  )

  if PLATFORM == "Windows" then filename = filename:gsub('/', '\\') end

  return filename
end

function util.touri(filename)
  if PLATFORM ~= "Windows" then
    filename = 'file://' .. filename
  else
    filename = 'file:///' .. filename:gsub('\\', '/')
  end

  return filename
end

-- Converts a document range returned bu lsp to a valid document selection.
-- @param range LSP Range.
function util.toselection(range)
  local line1 = range.start.line + 1
  local col1 = range.start.character + 1
  local line2 = range['end'].line + 1
  local col2 = range['end'].character + 1

  return line1, col1, line2, col2
end

function util.jsonprettify(json)
  if config.lsp.log_file and #config.lsp.log_file > 0 then
    local log = io.open(config.lsp.log_file, "a+")
    log:write("Output: \n" .. tostring(json) .. "\n\n")
    log:close()
  end

  -- TODO implement/integrate something that really makes it prettier :)
  if config.lsp.prettify_json then
    return json:gsub("{", "{\n"):gsub("}", "\n}"):gsub(",", ",\n")
  end

  return json
end

--- Gets the last component of a path. For example:
-- /my/path/to/somwhere would return somewhere
function util.getpathname(path)
  local components = {}
  if PLATFORM == "Windows" then
    components = util.split(path, "\\")
  else
    components = util.split(path, "/")
  end

  if #components > 0 then
    return components[#components]
  end

  return path
end

function util.intable(value, table_array)
  for i, element in pairs(table_array) do
    if element == value then
      return true
    end
  end

  return false
end


return util
