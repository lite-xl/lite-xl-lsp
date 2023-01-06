--
-- SymbolResults Widget/View.
-- @copyright Jefferson Gonzalez
-- @license MIT
--

local style = require "core.style"
local Widget = require "libraries.widget"
local Label = require "libraries.widget.label"
local Line = require "libraries.widget.line"
local ListBox = require "libraries.widget.listbox"
local Server = require "plugins.lsp.server"

local Lsp = {}

---@class lsp.symbolresults : widget
---@field public searching boolean
---@field public symbol string
---@field private title widget.label
---@field private line widget.line
---@field private list_container widget
---@field private list widget.listbox
local SymbolResults = Widget:extend()

function SymbolResults:new(symbol)
  SymbolResults.super.new(self)

  Lsp = require "plugins.lsp"

  self.name = "Symbols Search"
  self.defer_draw = false

  self.searching = true
  self.symbol = symbol or ""
  self.title = Label(self, "Searching symbols for: " .. symbol)
  self.line = Line(self, 2, style.padding.x)

  self.list_container = Widget(self)
  self.list_container.border.width = 0
  self.list_container:set_size(200, 200)

  self.list = ListBox(self.list_container)
  self.list.border.width = 0

  self.list:enable_expand(true)
  self.list:add_column("Num.")
  self.list:add_column("Symbol")
  self.list:add_column("Kind")
  self.list:add_column("Location")

  local list_on_row_click = self.list.on_row_click
  self.list.on_row_click = function(this, idx, data)
    list_on_row_click(this, idx, data)
    self:on_selected(idx, data)
  end

  self.num = 1

  self.border.width = 0
  self:set_size(200, 200)
  self:show()
end

function SymbolResults:add_result(result)
  local preview, position = Lsp.get_location_preview(result.location)
  local container_name = result.containerName and
    result.containerName .. "\n" or ""

  local row = {
    tostring(self.num),
    ListBox.COLEND,
    style.syntax.keyword, container_name .. result.name,
    ListBox.COLEND,
    style.syntax.literal, Server.get_symbol_kind(result.kind),
    ListBox.COLEND,
    style.text, position, ListBox.NEWLINE, style.accent, preview
  }

  self.num = self.num + 1

  self.list:add_row(row, result)
end

function SymbolResults:stop_searching()
  self.searching = false
end

function SymbolResults:on_selected(idx, data)
  Lsp.goto_location(data.location)
end

function SymbolResults:update()
  if not SymbolResults.super.update(self) then return end
  -- update the positions and sizes
  self.background_color = style.background
  self.title:set_position(style.padding.x, style.padding.y)
  if not self.searching or #self.list.rows > 0 then
    local label = "Finished: "
    if self.searching then
      label = "Searching: "
    end
    self.title:set_label(
      label
        .. #self.list.rows
        .. " results found for "
        .. '"'
        .. self.symbol
        .. '"'
    )
  end
  self.line:set_position(0, self.title:get_bottom() + 10)
  self.list_container:set_position(style.padding.x, self.line:get_bottom() + 10)
  self.list_container:set_size(
    self.size.x - (style.padding.x * 2),
    self.size.y - self.line:get_bottom()
  )
end


return SymbolResults

