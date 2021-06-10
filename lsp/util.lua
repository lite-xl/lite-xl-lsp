-- @copyright Jefferson Gonzalez
-- @license MIT
-- Some functions adapted from: https://github.com/orbitalquark/textadept-lsp

local config = require "core.config"

local util = {}

--- Split a string by the given delimeter
-- @tparam string s The string to split
-- @tparam string delimeter Delimeter without lua patterns
-- @tparam string delimeter_pattern Optional delimeter with lua patterns
-- @treturn table List of results
function util.split(s, delimeter, delimeter_pattern)
  if not delimeter_pattern then
    delimeter_pattern = delimeter
  end

  local result = {};
  for match in (s..delimeter):gmatch("(.-)"..delimeter_pattern) do
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

-- Converts a document range returned by lsp to a valid document selection.
-- @param range LSP Range.
function util.toselection(range)
  local line1 = range.start.line + 1
  local col1 = range.start.character + 1
  local line2 = range['end'].line + 1
  local col2 = range['end'].character + 1

  return line1, col1, line2, col2
end

--- Implemented some json prettifier but not a parser so
-- don't expect it to give you parsing errors :D
-- @tparam string text the json string
-- @tparam integer indent_width The amount of spaces per indentation
local function prettify_json(text, indent_width)
  local out = ""
  indent_width = indent_width or 2

  local indent_level = 0
  local reading_literal = false
  local previous_was_escape = false
  local inside_string = false
  local in_value = false
  local last_was_bracket = false
  local string_char = ""
  local last_char = ""

  local function indent(text, level)
    return string.rep(" ", level * indent_width) .. text
  end

  for char in text:gmatch(".") do
    if (char == "{" or char == "[") and not inside_string then
      if not in_value or last_was_bracket then
        out = out .. indent(char, indent_level) .. "\n"
      else
        out = out .. char .. "\n"
      end
      last_was_bracket = true
      in_value = false
      indent_level = indent_level + 1
    elseif (char == '"' or char == "'") and not inside_string then
      inside_string = true
      string_char = char
      if not in_value then
        out = out .. indent(char, indent_level)
      else
        out = out .. char
      end
    elseif inside_string then
      local pe_set = false
      if char == "\\" and previous_was_escape then
        previous_was_escape = false
      elseif char == "\\" then
        previous_was_escape = true
        pe_set = true
      end
      out = out .. char
      if char == string_char and not previous_was_escape then
        inside_string = false
      elseif previous_was_escape and not pe_set then
        previous_was_escape = false
      end
    elseif char == ":" then
      in_value = true
      last_was_bracket = false
      out = out .. char .. " "
    elseif char == "," then
      in_value = false
      reading_literal = false
      out = out .. char .. "\n"
    elseif char == "}" or char == "]" then
      indent_level = indent_level - 1
      if
        (char == "}" and last_char == "{")
        or
        (char == "]" and last_char == "[")
      then
        out = out:gsub("%s*\n$", "") .. char
      else
        out = out .. "\n" .. indent(char, indent_level)
      end
    elseif not char:match("%s") and not reading_literal then
      reading_literal = true
      if not in_value or last_was_bracket then
        out = out .. indent(char, indent_level)
        last_was_bracket = false
      else
        out = out .. char
      end
    elseif not char:match("%s") then
      out = out .. char
    end

    if not char:match("%s") then
      last_char = char
    end
  end

  return out
end

function util.jsonprettify(json)
  if config.lsp.prettify_json then
    json = prettify_json(json)
  end

  if config.lsp.log_file and #config.lsp.log_file > 0 then
    local log = io.open(config.lsp.log_file, "a+")
    log:write("Output: \n" .. tostring(json) .. "\n\n")
    log:close()
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

function util.command_exists(command)
  local path_list = {}

  if util.file_exists(command) then
    return true
  end

  if PLATFORM ~= "Windows" then
    path_list = util.split(os.getenv("PATH"), ":")
  else
    path_list = util.split(os.getenv("PATH"), ";")
  end

  for _, path in pairs(path_list) do
    if util.file_exists(path .. PATHSEP .. command) then
      return true
    end
  end

  return false
end

function util.table_remove_key(table_object, key_name)
  local new_table = {}
  for key, data in pairs(table_object) do
    if key ~= key_name then
      new_table[key] = data
    end
  end

  return new_table
end

--- Get a table specific field or nil if not found.
-- @tparam table t The table we are going to search for the field.
-- @tparam string fieldset A field spec in the format "parent[.child][.subchild]"
--         eg: "myProp.subProp.subSubProp"
-- @return The value of the given field or nil if not found.
function util.table_get_field(t, fieldset)
  local fields = util.split(fieldset, ".", "%.")
  local field = fields[1]
  local value = nil

  if field and #fields > 1 and t[field] then
    local sub_fields = table.concat(fields, ".", 2)
    value = util.table_get_field(t[field], sub_fields)
  elseif field and #fields > 0 and t[field] then
    value = t[field]
  end

  return value
end

--- Merge the content of table2 into table1.
-- Solution found here: https://stackoverflow.com/a/1283608
-- @tparam table t1
-- @tparam table t2
function util.table_merge(t1, t2)
  for k,v in pairs(t2) do
    if type(v) == "table" then
      if type(t1[k] or false) == "table" then
        util.table_merge(t1[k] or {}, t2[k] or {})
      else
        t1[k] = v
      end
    else
      t1[k] = v
    end
  end
end

function util.table_empty(t)
  local found = false
  for _, value in pairs(t) do
    found = true
    break
  end
  return not found
end


return util
