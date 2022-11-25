-- A configurable listbox that can be used as tooltip, selection box and
-- selection box with fuzzy search, this may change in the future.
--
-- @note This code is a readaptation of autocomplete plugin from rxi :)
--
-- TODO implement select box with fuzzy search

local core = require "core"
local common = require "core.common"
local command = require "core.command"
local style = require "core.style"
local keymap = require "core.keymap"
local util = require "plugins.lsp.util"
local RootView = require "core.rootview"
local DocView = require "core.docview"

---@class lsp.listbox.item
---@field text string
---@field info string
---@field on_draw fun(item:lsp.listbox.item, x:number, y:number, calc_only?:boolean):number

---@alias lsp.listbox.callback fun(doc: core.doc, item: lsp.listbox.item)

---@class lsp.listbox.signature_param
---@field label string

---@class lsp.listbox.signature
---@field label string
---@field activeParameter? integer
---@field activeSignature? integer
---@field parameters lsp.listbox.signature_param[]

---@class lsp.listbox.signature_list
---@field activeParameter? integer
---@field activeSignature? integer
---@field signatures lsp.listbox.signature[]

---@class lsp.listbox.position
---@field line integer
---@field col integer

---@class lsp.listbox
local listbox = {}

---@class lsp.listbox.settings
---@field items lsp.listbox.item[]
---@field shown_items lsp.listbox.item[]
---@field selected_item_idx integer
---@field show_items_count boolean
---@field max_height integer
---@field active_view core.docview | nil
---@field line integer | nil
---@field col integer | nil
---@field last_line integer | nil
---@field last_col integer | nil
---@field callback lsp.listbox.callback | nil
---@field is_list boolean
---@field has_fuzzy_search boolean
---@field above_text boolean
local settings = {
  items = {},
  shown_items = {},
  selected_item_idx = 1,
  show_items_count = false,
  max_height = 6,
  active_view = nil,
  line = nil,
  col = nil,
  last_line = nil,
  last_col = nil,
  callback = nil,
  is_list = false,
  has_fuzzy_search = false,
  above_text = false,
}

local mt = { __tostring = function(t) return t.text end }

--------------------------------------------------------------------------------
-- Private functions
--------------------------------------------------------------------------------

---@return core.docview | nil
local function get_active_view()
  if getmetatable(core.active_view) == DocView then
    return core.active_view
  end
end

---@param active_view core.docview
---@return number x
---@return number y
---@return number width
---@return number height
local function get_suggestions_rect(active_view)
  if #settings.shown_items == 0 then
    listbox.hide()
    return 0, 0, 0, 0
  end

  local line, col
  if settings.line then
    line, col = settings.line, settings.col
  else
    line, col = active_view.doc:get_selection()
  end

  -- Validate line against current view because there can be cases
  -- when user rapidly switches between tabs causing the deferred draw
  -- to be called late and the current document view already changed.
  if line > #active_view.doc.lines then
    listbox.hide()
    return 0, 0, 0, 0
  end

  local x, y = active_view:get_line_screen_position(line)

  -- This function causes tokenizer to fail if given line is greater than
  -- the amount of lines the document holds, so validation above is needed.
  x = x + active_view:get_col_x_offset(line, col)

  local padding_x = style.padding.x
  local padding_y = style.padding.y

  if settings.above_text and line > 1 then
    y = y - active_view:get_line_height() - style.padding.y
  else
    y = y + active_view:get_line_height() + style.padding.y
  end

  local font = settings.is_list and active_view:get_font() or style.font
  local text_height = font:get_height()

  local max_width = 0
  for _, item in ipairs(settings.shown_items) do
    local w = 0
    if item.on_draw then
      w = item.on_draw(item, 0, 0, true)
    else
      w = font:get_width(item.text)
      if item.info then
        w = w + style.font:get_width(item.info) + style.padding.x
      end
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

  local height = max_items * (text_height + (padding_y/4)) + (padding_y*2)
  local width = max_width + padding_x * 2

  x = x - padding_x
  y = y - padding_y

  local win_w = system.get_window_size()
  if (width/win_w*100) >= 85 and (width+style.padding.x*4) < win_w then
    x = win_w - width - style.padding.x*2
  elseif width > (win_w - x) then
    x = x - (width - (win_w - x))
    if x < 0 then
      x = 0
    end
  end

  return x, y, width, height
end

---@param av core.docview
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

  local padding_x = style.padding.x
  local padding_y = style.padding.y

  -- draw text
  local font = settings.is_list and av:get_font() or style.font
  local line_height = font:get_height() + (padding_y / 4)
  local y = ry + padding_y

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

    if item.on_draw then
      item.on_draw(item, rx + padding_x, y)
    else
      local color = (i == settings.selected_item_idx and settings.is_list) and
        style.accent or style.text

      common.draw_text(
        font, color, item.text, "left",
        rx + padding_x, y, rw, line_height
      )

      if item.info then
        color = (i == settings.selected_item_idx and settings.is_list) and
          style.text or style.dim

        common.draw_text(
          style.font, color, item.info, "right",
          rx, y, rw - padding_x, line_height
        )
      end
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
      rx + padding_x, y, rw, line_height
    )
    common.draw_text(
      style.font,
      style.accent,
      tostring(settings.selected_item_idx) .. "/" .. tostring(#settings.shown_items),
      "right",
      rx, y, rw - padding_x, line_height
    )
  end
end

---Set the document position where the listbox will be draw.
---@param position? lsp.listbox.position
local function set_position(position)
  if type(position) == "table" then
    settings.line = position.line
    settings.col = position.col
  else
    settings.line = nil
    settings.col = nil
  end
end

--------------------------------------------------------------------------------
-- Public functions
--------------------------------------------------------------------------------

---@param elements lsp.listbox.item[]
function listbox.add(elements)
  if type(elements) == "table" and #elements > 0 then
    local items = {}
    for _, element in pairs(elements) do
      table.insert(items, setmetatable(element, mt))
    end
    settings.items = items
  end
end

function listbox.clear()
  settings.items = {}
  settings.selected_item_idx = 1
  settings.shown_items = {}
  settings.line = nil
  settings.col = nil
end

---@param element lsp.listbox.item
function listbox.append(element)
  table.insert(settings.items, setmetatable(element, mt))
end

function listbox.hide()
  settings.active_view = nil
  settings.line = nil
  settings.col = nil
  settings.selected_item_idx = 1
  settings.shown_items = {}
end

---@param is_list? boolean
---@param position? lsp.listbox.position
function listbox.show(is_list, position)
  set_position(position)

  local active_view = get_active_view()
  if active_view then
    settings.active_view = active_view
    settings.last_line, settings.last_col = active_view.doc:get_selection()
    if settings.items and #settings.items > 0 then
      settings.is_list = is_list or false
      settings.shown_items = settings.items
    end
  end
end

---@param text string
---@param position? lsp.listbox.position
function listbox.show_text(text, position)
  if text and type("text") == "string" then
    local win_w = system.get_window_size() - style.padding.x * 6
    text = util.wrap_text(text, style.font, win_w)

    local items = {}
    for result in string.gmatch(text.."\n", "(.-)\n") do
      table.insert(items, {text = result})
    end
    listbox.add(items)
  end

  listbox.show(false, position)
end

---@param items lsp.listbox.item[]
---@param callback lsp.listbox.callback
---@param position? lsp.listbox.position
function listbox.show_list(items, callback, position)
  listbox.add(items)

  if callback then
    settings.callback = callback
  end

  listbox.show(true, position)
end

---@param signatures lsp.listbox.signature_list
---@param position? lsp.listbox.position
function listbox.show_signatures(signatures, position)
  local active_parameter = nil
  local active_signature = nil

  if signatures.activeParameter then
    active_parameter = signatures.activeParameter + 1
  end

  if signatures.activeSignature then
    active_signature = signatures.activeSignature + 1
  end

  local signatures_count = #signatures.signatures

  local items = {}
  for index, signature in ipairs(signatures.signatures) do
    table.insert(items, {
      text = signature.label,
      signature = signature,
      on_draw = function(item, x, y, calc_only)
        local width = 0
        local height = style.font:get_height()

        if item.signature.parameters then
          if signatures_count > 1 then
            if index == active_signature then
              width = style.font:get_width("> ")
            else
              width = style.font:get_width("> ")
              x = x + style.font:get_width("> ")
            end
          end

          width = width
            + style.font:get_width("(")
            + style.font:get_width(")")

          if not calc_only then
            if signatures_count > 1 and index == active_signature then
              x = renderer.draw_text(style.font, "> ", x, y, style.caret)
            end
            x = renderer.draw_text(style.font, "(", x, y, style.text)
          end

          local params_count = #item.signature.parameters
          for pindex, param in ipairs(item.signature.parameters) do
            local label = ""
            if type(param.label) == "table" then
              label = signature.label:sub(param.label[1]+1, param.label[2])
            else
              label = param.label
            end
            if label and pindex ~= params_count then
              label = label .. ", "
            end
            width = width + style.font:get_width(label)
            if not calc_only then
              local color = style.text
              if
                (
                  signature.activeParameter
                  and
                  (signature.activeParameter + 1) == pindex
                )
                or
                (index == active_signature and active_parameter == pindex)
              then
                color = style.accent
              end
              x = renderer.draw_text(
                style.font,
                label,
                x, y,
                color
              )
            end
          end

          if not calc_only then
            renderer.draw_text(style.font, ")", x, y, style.text)
          end
        else
          width = style.font:get_width(item.signature.label)
          if not calc_only then
            renderer.draw_text(
              style.font,
              item.signature.label,
              x, y,
              style.text
            )
          end
        end
        return width, width > 0 and height or 0
      end
    })
  end

  listbox.add(items)

  listbox.show(false, position)
end

function listbox.toggle_above(enable)
  if enable then
    settings.above_text = true
  else
    settings.above_text = false
  end
end

--------------------------------------------------------------------------------
-- Patch event logic into RootView
--------------------------------------------------------------------------------
local root_view_update = RootView.update
local root_view_draw = RootView.draw

RootView.update = function(...)
  root_view_update(...)

  if not settings.active_view then return end

  local active_view = get_active_view()
  if active_view then
    -- reset suggestions if caret was moved or not same active view
    local line, col = active_view.doc:get_selection()
    if
      settings.active_view ~= active_view
      or
      line ~= settings.last_line or col ~= settings.last_col
    then
      listbox.hide()
    end
  else
    listbox.hide()
  end
end

RootView.draw = function(...)
  root_view_draw(...)

  if not settings.active_view then return end

  local active_view = get_active_view()
  if
    active_view and settings.active_view == active_view
    and
    #settings.shown_items > 0
  then
    -- draw suggestions box after everything else
    core.root_view:defer_draw(draw_listbox, active_view)
  end
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------
local function predicate()
  local av = get_active_view()
  return av and settings.active_view and #settings.shown_items > 0, av
end

command.add(predicate, {
  ["listbox:select"] = function(av)
    ---@cast av core.docview
    if settings.is_list then
      local doc = av.doc
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

--------------------------------------------------------------------------------
-- Keymaps
--------------------------------------------------------------------------------
keymap.add {
  ["tab"]    = "listbox:select",
  ["up"]     = "listbox:previous",
  ["down"]   = "listbox:next",
  ["escape"] = "listbox:cancel",
}


return listbox
