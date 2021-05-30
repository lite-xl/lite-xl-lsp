-- mod-version:1 -- lite-xl 1.16
-- @copyright Jefferson Gonzalez
-- @license MIT
-- A configurable listbox that can be used as tooltip, selection box and
-- selection box with fuzzy search, this may change in the future.
--
-- TODO implement select box with fuzzy search

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local command = require "core.command"
local style = require "core.style"
local keymap = require "core.keymap"
local translate = require "core.doc.translate"
local RootView = require "core.rootview"
local DocView = require "core.docview"

local listbox = {}

local settings = {
  items = {},
  shown_items = {},
  selected_item_idx = 1,
  show_items_count = false,
  max_height = 6,
  last_line = nil,
  last_col = nil,
  callback = nil,
  is_list = false,
  has_fuzzy_search = false,
  above_text = false,
}

local mt = { __tostring = function(t) return t.text end }

--
-- Private functions
--
local function get_active_view()
  if getmetatable(core.active_view) == DocView then
    return core.active_view
  end
end

local function get_suggestions_rect(active_view)
  if #settings.shown_items == 0 then
    return 0, 0, 0, 0
  end

  local line, col = active_view.doc:get_selection()

  local x, y = active_view:get_line_screen_position(line)
  x = x + active_view:get_col_x_offset(line, col)

  if settings.above_text and line > 1 then
    y = y - active_view:get_line_height() - style.padding.y
  else
    y = y + active_view:get_line_height() + style.padding.y
  end

  local font = settings.is_list and active_view:get_font() or style.font
  local text_height = font:get_height()

  local max_width = 0
  for _, item in ipairs(settings.shown_items) do
    local w = settings.is_list and
      font:get_width(item.text) or style.font:get_width(item.text)
    if item.info then
      w = w + style.font:get_width(item.info) + style.padding.x
    end
    max_width = math.max(max_width, w)
  end

  local max_items = #settings.shown_items
  if settings.is_list and max_items > settings.max_height then
    max_items = settings.max_height
  end

  -- additional line to display total items
  if settings.show_items_count then
    max_items = max_items + 1
  end

  if max_width < 150 then
    max_width = 150
  end

  local height = 0
  if not settings.is_list then
    height = max_items * (text_height) + style.padding.y
  else
    height = max_items * (text_height + style.padding.y) + style.padding.y
  end

  return
    x - style.padding.x,
    y - style.padding.y,
    max_width + style.padding.x * 2,
    height
end

local function draw_listbox(av)
  if #settings.shown_items <= 0 then
    return
  end

  -- draw background rect
  local rx, ry, rw, rh = get_suggestions_rect(av)

  -- draw border
  if not settings.is_list then
    local border_width = 1
    renderer.draw_rect(
      rx - border_width,
      ry - border_width,
      rw + (border_width * 2),
      rh + (border_width * 2),
      style.divider
    )
  end

  renderer.draw_rect(rx, ry, rw, rh, style.background3)

  -- draw text
  local font = settings.is_list and av:get_font() or style.font
  local line_height = font:get_height()
  if settings.is_list then
    line_height = line_height + style.padding.y
  end
  local y = ry + style.padding.y / 2

  local max_height = settings.max_height

  local show_count = (
    #settings.shown_items <= max_height or not settings.is_list
    ) and
    #settings.shown_items or max_height

  local start_index = settings.selected_item_idx > max_height and
    (settings.selected_item_idx-(max_height-1)) or 1

  for i=start_index, start_index+show_count-1, 1 do
    if not settings.shown_items[i] then
      break
    end

    local item = settings.shown_items[i]

    local color = (i == settings.selected_item_idx and settings.is_list) and
      style.accent or style.text

    common.draw_text(
      settings.is_list and font or style.font,
      color, item.text, "left", rx + style.padding.x, y, rw, line_height
    )

    if item.info then
      color = (i == settings.selected_item_idx and settings.is_list) and
        style.text or style.dim

      common.draw_text(
        style.font, color, item.info, "right",
        rx, y, rw - style.padding.x, line_height
      )
    end
    y = y + line_height
  end

  if settings.show_items_count then
    renderer.draw_rect(rx, y, rw, 2, style.caret)
    renderer.draw_rect(rx, y+2, rw, line_height, style.background)
    common.draw_text(
      style.font,
      style.accent,
      "Items",
      "left",
      rx + style.padding.x, y, rw, line_height
    )
    common.draw_text(
      style.font,
      style.accent,
      tostring(settings.selected_item_idx) .. "/" .. tostring(#settings.shown_items),
      "right",
      rx, y, rw - style.padding.x, line_height
    )
  end
end

--
-- Public functions
--
function listbox.add(elements)
  local items = {}
  for _, element in pairs(elements) do
    table.insert(items, setmetatable(element, mt))
  end
  settings.items = items
end

function listbox.clear()
  settings.items = {}
  settings.selected_item_idx = 1
  settings.shown_items = {}
end

function listbox.append(element)
  table.insert(settings.items, setmetatable(element, mt))
end

function listbox.show_text(text)
  local active_view = get_active_view()
  settings.last_line, settings.last_col = active_view.doc:get_selection()

  if text then
    local items = {}
    for result in string.gmatch(text.."\n", "(.-)\n") do
      table.insert(items, {text = result})
    end
    listbox.add(items)
  end

  if settings.items and #settings.items > 0 then
    settings.is_list = false
    settings.shown_items = settings.items
  end
end

function listbox.show_list(items, callback)
  local active_view = get_active_view()
  settings.last_line, settings.last_col = active_view.doc:get_selection()

  if items and #items > 0 then
    listbox.add(items)
  end

  if callback then
    settings.callback = callback
  end

  if settings.items and #settings.items > 0 then
    settings.is_list = true
    settings.shown_items = settings.items
  end
end

function listbox.hide()
  settings.selected_item_idx = 1
  settings.shown_items = {}
end

function listbox.toggle_above(enable)
  if enable then
    settings.above_text = true
  else
    settings.above_text = false
  end
end


--
-- Patch event logic into RootView
--
local root_view_update = RootView.update
local root_view_draw = RootView.draw

RootView.update = function(...)
  root_view_update(...)

  local active_view = get_active_view()
  if active_view then
    -- reset suggestions if caret was moved
    local line, col = active_view.doc:get_selection()
    if line ~= settings.last_line or col ~= settings.last_col then
      listbox.hide()
    end
  end
end

RootView.draw = function(...)
  root_view_draw(...)

  local active_view = get_active_view()
  if active_view and #settings.shown_items > 0 then
    -- draw suggestions box after everything else
    core.root_view:defer_draw(draw_listbox, active_view)
  end
end

--
-- Commands
--
local function predicate()
  return get_active_view() and #settings.shown_items > 0
end

command.add(predicate, {
  ["listbox:select"] = function()
    if settings.is_list then
      local doc = core.active_view.doc
      local item = settings.shown_items[settings.selected_item_idx]

      if settings.callback then
        settings.callback(doc, item)
      end

      listbox.hide()
    end
  end,

  ["listbox:previous"] = function()
    if settings.is_list then
      settings.selected_item_idx = math.max(settings.selected_item_idx - 1, 1)
    else
      listbox.hide()
    end
  end,

  ["listbox:next"] = function()
    if settings.is_list then
      settings.selected_item_idx = math.min(
        settings.selected_item_idx + 1, #settings.shown_items
      )
    else
      listbox.hide()
    end
  end,

  ["listbox:cancel"] = function()
    listbox.hide()
  end,
})

--
-- Keymaps
--
keymap.add {
  ["tab"]    = "listbox:select",
  ["up"]     = "listbox:previous",
  ["down"]   = "listbox:next",
  ["escape"] = "listbox:cancel",
}


return listbox
