-- Some functions adapted from: https://github.com/orbitalquark/textadept-lsp
-- and others added as needed.
--
-- @copyright Jefferson Gonzalez
-- @license MIT

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local json = require "plugins.lsp.json"

local util = {}

---Check if the given file is currently opened on the editor.
---@param abs_filename string
function util.doc_is_open(abs_filename)
  -- Normalize path format to the one used by normal docs
  abs_filename = common.normalize_path(abs_filename) or abs_filename
  for _, doc in ipairs(core.docs) do
    ---@cast doc core.doc
    if doc.abs_filename == abs_filename then
      return true;
    end
  end
  return false
end

---Converts a utf-8 column position into the equivalent utf-16 position.
---@param doc core.doc
---@param line integer
---@param column integer
---@return integer col_position
function util.doc_utf8_to_utf16(doc, line, column)
  local ltext = doc.lines[line]
  local ltext_len = ltext and #ltext or 0
  local ltext_ulen = ltext and utf8extra.len(ltext) or 0
  column = common.clamp(column, 1, ltext_len > 0 and ltext_len or 1)
  -- no need for conversion so return column as is
  if ltext_len == ltext_ulen then return column end
  if column > 1 then
    local col = 1
    for pos, code in utf8extra.next, ltext do
      if pos >= column then
        return col
      end
      -- Codepoints that high are encoded using surrogate pairs
      if code < 0x010000 then
        col = col + 1
      else
        col = col + 2
      end
    end
    return col
  end
  return column
end

---Converts a utf-16 column position into the equivalent utf-8 position.
---@param doc core.doc
---@param line integer
---@param column integer
---@return integer col_position
function util.doc_utf16_to_utf8(doc, line, column)
  local ltext = doc.lines[line]
  local ltext_len = ltext and #ltext or 0
  local ltext_ulen = ltext and utf8extra.len(ltext) or 0
  column = common.clamp(column, 1, ltext_len > 0 and ltext_len or 1)
  -- no need for conversion so return column as is
  if ltext_len == ltext_ulen then return column end
  if column > 1 then
    local col = 1
    local utf8_pos = 1
    for pos, code in utf8extra.next, ltext do
      if col >= column then
        return pos
      end
      utf8_pos = pos
      -- Codepoints that high are encoded using surrogate pairs
      if code < 0x010000 then
        col = col + 1
      else
        col = col + 2
      end
    end
    return utf8_pos
  end
  return column
end

---Split a string by the given delimeter
---@param s string The string to split
---@param delimeter string Delimeter without lua patterns
---@param delimeter_pattern? string Optional delimeter with lua patterns
---@return table
---@return boolean ends_with_delimiter
function util.split(s, delimeter, delimeter_pattern)
  if not delimeter_pattern then
    delimeter_pattern = delimeter
  end

  local last_idx = 1
  local result = {}
  for match_idx, afer_match_idx in s:gmatch("()"..delimeter_pattern.."()") do
    table.insert(result, string.sub(s, last_idx, match_idx - 1))
    last_idx = afer_match_idx
  end
  if last_idx > #s then
    return result, true
  else
    table.insert(result, string.sub(s, last_idx))
    return result, false
  end
end

---Get the extension component of a filename.
---@param filename string
---@return string
function util.file_extension(filename)
  local parts = util.split(filename, "%.")
  if #parts > 1 then
    return parts[#parts]:gsub("%%", "")
  end

  return filename
end

---Check if a file exists.
---@param file_path string
---@return boolean
function util.file_exists(file_path)
  local file = io.open(file_path, "r")
  if file ~= nil then
    file:close()
    return true
  end
 return false
end

---Converts the given LSP DocumentUri into a valid filename path.
---@param uri string LSP DocumentUri to convert into a filename.
---@return string
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

---Convert a file path to a LSP valid uri.
---@param file_path string
---@return string
function util.touri(file_path)
  if PLATFORM ~= "Windows" then
    file_path = 'file://' .. file_path
  else
    file_path = 'file:///' .. file_path:gsub('\\', '/')
  end

  return file_path
end

---Converts a document range returned by lsp to a valid document selection.
---@param range table LSP Range.
---@param doc? core.doc
---@return integer line1
---@return integer col1
---@return integer line2
---@return integer col2
function util.toselection(range, doc)
  local line1 = range.start.line + 1
  local col1 = range.start.character + 1
  local line2 = range['end'].line + 1
  local col2 = range['end'].character + 1

  if doc then
    col1 = util.doc_utf16_to_utf8(doc, line1, col1)
    col2 = util.doc_utf16_to_utf8(doc, line2, col2)
  end

  return line1, col1, line2, col2
end

---Opens the given location on a external application.
---@param location string
function util.open_external(location)
  local filelauncher = ""
  if PLATFORM == "Windows" then
    filelauncher = "start"
  elseif PLATFORM == "Mac OS X" then
    filelauncher = "open"
  else
    filelauncher = "xdg-open"
  end

  -- non-Windows platforms need the text quoted (%q)
  if PLATFORM ~= "Windows" then
    location = string.format("%q", location)
  end

  system.exec(filelauncher .. " " .. location)
end

---Prettify json output and logs it if config.lsp.log_file is set.
---@param code string
---@return string
function util.jsonprettify(code)
  if config.plugins.lsp.prettify_json then
    code = json.prettify(code)
  end

  if config.plugins.lsp.log_file and #config.plugins.lsp.log_file > 0 then
    local log = io.open(config.plugins.lsp.log_file, "a+")
    log:write("Output: \n" .. tostring(code) .. "\n\n")
    log:close()
  end

  return code
end

---Gets the last component of a path. For example:
---/my/path/to/somwhere would return somewhere.
---@param path string
---@return string
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

---Check if a value is on a table.
---@param value any
---@param table_array table
---@return boolean
function util.intable(value, table_array)
  for _, element in pairs(table_array) do
    if element == value then
      return true
    end
  end

  return false
end

---Remove by key from a table and returns a new
---table with element removed.
---@param table_object table
---@param key_name string|integer
---@return table
function util.table_remove_key(table_object, key_name)
  local new_table = {}
  for key, data in pairs(table_object) do
    if key ~= key_name then
      new_table[key] = data
    end
  end

  return new_table
end

---Get a table specific field or nil if not found.
---@param t table The table we are going to search for the field.
---@param fieldset string A field spec in the format
---"parent[.child][.subchild]" eg: "myProp.subProp.subSubProp"
---@return any|nil The value of the given field or nil if not found.
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

---Merge the content of the tables into a new one.
---Arguments from the later tables take precedence.
---Doesn't touch the original tables.
---`nil` arguments are ignored.
---@param ... table?
---@return table
function util.deep_merge(...)
  local t = {}
  local args = table.pack(...)
  for i=1,args.n do
    local other = args[i]
    if other then
      assert(type(other) == "table", string.format("Argument %d must be a table", i))
      for k, v in pairs(other) do
        if type(v) == "table" then
          if type(t[k]) == "table" then
            t[k] = util.deep_merge(t[k], v)
          else
            t[k] = util.deep_merge({}, v)
          end
        else
          t[k] = v
        end
      end
    end
  end
  return t
end

---Check if a table is really empty.
---@param t table
---@return boolean
function util.table_empty(t)
  return next(t) == nil
end

---Convert markdown to plain text.
---@param text string
---@return string
function util.strip_markdown(text)
  local clean_text = ""
  local prev_line = ""
  for match in (text.."\n"):gmatch("(.-)".."\n") do
    match = match .. "\n"

    -- strip markdown
    local new_line = match
      -- Block quotes
      :gsub("^>+(%s*)", "%1")
      -- headings
      :gsub("^(%s*)######%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)#####%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)####%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)####%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)###%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)##%s(.-)\n", "%1%2\n")
      :gsub("^(%s*)#%s(.-)\n", "%1%2\n")
      -- heading custom id
      :gsub("{#.-}", "")
      -- emoji
      :gsub(":[%w%-_]+:", "")
      -- bold and italic
      :gsub("%*%*%*(.-)%*%*%*", "%1")
      :gsub("___(.-)___", "%1")
      :gsub("%*%*_(.-)_%*%*", "%1")
      :gsub("__%*(.-)%*__", "%1")
      :gsub("___(.-)___", "%1")
      -- bold
      :gsub("%*%*(.-)%*%*", "%1")
      :gsub("__(.-)__", "%1")
      -- strikethrough
      :gsub("%-%-(.-)%-%-", "%1")
      -- italic
      :gsub("%*(.-)%*", "%1")
      :gsub("%s_(.-)_%s", "%1")
      :gsub("\\_(.-)\\_", "_%1_")
      :gsub("^_(.-)_", "%1")
      -- code
      :gsub("^%s*```(%w+)%s*\n", "")
      :gsub("^%s*```%s*\n", "")
      :gsub("``(.-)``", "%1")
      :gsub("`(.-)`", "%1")
      -- lines
      :gsub("^%-%-%-%-*%s*\n", "")
      :gsub("^%*%*%*%**%s*\n", "")
      -- reference links
      :gsub("^%[[^%^](.-)%]:.-\n", "")
      -- footnotes
      :gsub("^%[%^(.-)%]:%s+", "[%1]: ")
      :gsub("%[%^(.-)%]", "[%1]")
      -- Images
      :gsub("!%[(.-)%]%((.-)%)", "")
      -- links
      :gsub("%s<(.-)>%s", "%1")
      :gsub("%[(.-)%]%s*%[(.-)%]", "%1")
      :gsub("%[(.-)%]%((.-)%)", "%1: %2")
      -- remove escaped punctuations
      :gsub("\\(%p)", "%1")

    -- if paragraph put in same line
    local is_paragraph = false

    local prev_spaces = prev_line:match("^%g+")
    local prev_endings = prev_line:match("[ \t\r\n]+$")
    local new_spaces = new_line:match("^%g+")

    if prev_spaces and new_spaces then
      local new_lines = prev_endings ~= nil
        and prev_endings:gsub("[ \t\r]+", "") or ""

      if #new_lines == 1 then
        is_paragraph = true
        clean_text = clean_text:gsub("[%s\n]+$", "")
          .. " " .. new_line:gsub("^%s+", "")
      end
    end

    if not is_paragraph then
      clean_text = clean_text .. new_line
    end

    prev_line = new_line
  end
  return clean_text
end

---@param text string
---@param font renderer.font
---@param max_width number
function util.wrap_text(text, font, max_width)
  local lines = util.split(text, "\n")
  local wrapped_text = ""
  local longest_line = 0;
  for _, line in ipairs(lines) do
    local line_len = line:ulen() or 0
    if line_len > longest_line then
      longest_line = line_len
      local line_width = font:get_width(line)
      if line_width > max_width then
        local words = util.split(line, " ")
        local new_line = words[1] and words[1] or ""
        wrapped_text = wrapped_text .. new_line
        for w=2, #words do
          if font:get_width(new_line .. " " .. words[w]) <= max_width then
            new_line = new_line .. " " .. words[w]
            wrapped_text = wrapped_text .. " " .. words[w]
          else
            wrapped_text = wrapped_text .. "\n" .. words[w]
            new_line = words[w]
          end
        end
        wrapped_text = wrapped_text .. "\n"
      else
        wrapped_text = wrapped_text .. line .. "\n"
      end
    else
      wrapped_text = wrapped_text .. line .. "\n"
    end
  end

  wrapped_text = wrapped_text:gsub("\n\n\n\n?", "\n\n"):gsub("%s*$", "")

  return wrapped_text
end


return util
