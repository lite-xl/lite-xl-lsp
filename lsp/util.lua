-- @copyright Jefferson Gonzalez
-- @license MIT
-- Some functions adapted from: https://github.com/orbitalquark/textadept-lsp

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

-- Returns the start and end buffer positions for the given LSP Range.
-- @param range LSP Range.
function util.tobufferrange(range)
  local s = buffer:position_from_line(range.start.line + 1) + range.start.character + 1
  local e = buffer:position_from_line(range['end'].line + 1) + range['end'].character + 1
  return s, e
end

function util.jsonprettify(json)
  return json
  --return json:gsub("{", "{\n"):gsub("}", "\n}"):gsub(",", ",\n")
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
