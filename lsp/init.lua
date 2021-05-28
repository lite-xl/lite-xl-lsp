-- mod-version:1 lite-xl 1.16
--
-- LSP client for lite-xl
-- @copyright Jefferson Gonzalez
-- @license MIT

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local command = require "core.command"
local Doc = require "core.doc"
local keymap = require "core.keymap"
local translate = require "core.doc.translate"
local RootView = require "core.rootview"
local DocView = require "core.docview"

local Json = require "plugins.lsp.json"
local Server = require "plugins.lsp.server"
local Util = require "plugins.lsp.util"
local autocomplete = require "plugins.autocomplete"
local listbox = require "plugins.lsp.listbox"

--
-- Plugin settings
--
config.lsp = {}

-- Set to a file to log all json
config.lsp.log_file = ""

-- Set to true break json for more readability on the log
config.lsp.prettify_json = false

--
-- Main plugin functionality
--
local lsp = {}

lsp.servers = {}
lsp.servers_running = {}

local function matches_any(filename, patterns)
  for _, ptn in ipairs(patterns) do
    if filename:find(ptn) then
      return true
    end
  end
end

local function get_buffer_position_params(doc, line, col)
  return {
    textDocument = {
      uri = Util.touri(system.absolute_path(doc.filename)),
    },
    position = {
      line = line - 1,
      character = col - 1
    }
  }
end

local function log(server, message, ...)
  core.log("["..server.name.."] " .. message, ...)
end

function lsp.add_server(server)
  lsp.servers[server.name] = server
end

function lsp.get_active_servers(filename)
  local servers = {}
  for name, server in pairs(lsp.servers) do
    if matches_any(filename, server.file_patterns) then
      if lsp.servers_running[name] then
        table.insert(servers, name)
      end
    end
  end
  return servers
end

function lsp.start_server(filename, project_directory)
  for name, server in pairs(lsp.servers) do
    if matches_any(filename, server.file_patterns) then
      if not lsp.servers_running[name] then
        core.log("[LSP] starting " .. name)
        local client = Server.new(server)

        lsp.servers_running[name] = client

        -- we overwrite the default log function
        function client:log(message, ...)
          core.log_quiet(
            "[LSP/%s]: " .. message .. "\n",
            self.name,
            ...
          )
        end

        client:add_message_listener("window/logMessage", function(server, params)
          if core.log then
            core.log("["..server.name.."] " .. params.message)
            coroutine.yield(3)
          end
        end)

        client:add_event_listener("initialized", function(server, ...)
          core.log("["..server.name.."] " .. "Initialized")
          if server.settings then
            server:push_request(
              "workspace/didChangeConfiguration",
              {settings = server.settings},
              function(server, response)
                if server.verbose then
                  server:log(
                    "Completion response: %s",
                    Util.jsonprettify(Json.encode(response))
                  )
                end
              end
            )
          end
          if server.capabilities then
            if
              server.capabilities.completionProvider
              and
              server.capabilities.completionProvider.triggerCharacters
            then
              if server.verbose then
                server:log(
                  "Adding triggers for '%s' - %s",
                  server.language,
                  table.concat(
                    server.capabilities
                      .completionProvider.triggerCharacters,
                    ", "
                  )
                )
              end
              autocomplete.add_trigger {
                name = server.language,
                file_patterns = server.file_patterns,
                characters = server.capabilities
                  .completionProvider.triggerCharacters
              }
            end
          end
        end)

        client:initialize(project_directory, "Lite XL", VERSION)
      end
    end
  end
end

function lsp.open_document(doc)
  lsp.start_server(doc.filename, core.project_dir)

  local active_servers = lsp.get_active_servers(doc.filename)

  if #active_servers > 0 then
    doc.disable_symbols = true

    for index, name in pairs(active_servers) do
      lsp.servers_running[name]:push_notification(
        'textDocument/didOpen',
        {
          textDocument = {
            uri = Util.touri(system.absolute_path(doc.filename)),
            languageId = Util.file_extension(doc.filename),
            version = doc.clean_change_id,
            text = doc:get_text(1, 1, #doc.lines, #doc.lines[#doc.lines])
          }
        }
      )
    end
  end
end

function lsp.save_document(doc)
  local active_servers = lsp.get_active_servers(doc.filename)
  if #active_servers > 0 then
    for index, name in pairs(active_servers) do
      lsp.servers_running[name]:push_notification(
        'textDocument/didSave',
        {
          textDocument = {
            uri = Util.touri(system.absolute_path(doc.filename)),
            languageId = Util.file_extension(doc.filename),
            version = doc.clean_change_id
          },
          includeText = true,
          text = doc:get_text(1, 1, #doc.lines, #doc.lines[#doc.lines])
        }
      )
    end
  end
end

function lsp.close_document(doc)
  local active_servers = lsp.get_active_servers(doc.filename)
  if #active_servers > 0 then
    for index, name in pairs(active_servers) do
      lsp.servers_running[name]:push_notification(
        'textDocument/didClose',
        {
          textDocument = {
            uri = Util.touri(system.absolute_path(doc.filename)),
            languageId = Util.file_extension(doc.filename),
            version = doc.clean_change_id
          }
        }
      )
    end
  end
end

function lsp.request_item_resolve(index, item)
  local completion_item = item.data.completion_item
  item.data.server:push_request(
    'completionItem/resolve',
    completion_item,
    function(server, response)
      if response.result then
        local symbol = response.result
        -- TODO overwrite the item.desc to show documentation of
        -- symbol is available but nothing seems to be returned,
        -- maybe some missing initialization option?
      end
    end
  )
end

function lsp.request_completion(doc, line, col)
  for index, name in pairs(lsp.get_active_servers(doc.filename)) do
    lsp.servers_running[name]:push_notification(
      'textDocument/didChange',
      {
        textDocument = {
          uri = Util.touri(system.absolute_path(doc.filename)),
          version = doc.clean_change_id,
        },
        contentChanges = {
          {
            text = doc:get_text(1, 1, #doc.lines, #doc.lines[#doc.lines])
          }
        },
        syncKind = 1
      }
    )

    if
      lsp.servers_running[name].capabilities
      and
      lsp.servers_running[name].capabilities.completionProvider
    then
      lsp.servers_running[name]:push_request(
        'textDocument/completion',
        get_buffer_position_params(doc, line, col),
        function(server, response)
          if server.verbose then
            server:log(
              "Completion response: %s",
              Util.jsonprettify(Json.encode(response))
            )
          end

          if not response.result then
            return
          end

          local result = response.result
          if result.isIncomplete then
            if server.verbose then
              core.log_quiet(
                "["..server.name.."] " .. "Completion list incomplete"
              )
            end
            return
          end

          local symbols = {
            name = lsp.servers_running[name].name,
            files = lsp.servers_running[name].file_patterns,
            items = {}
          }

          for _, symbol in ipairs(result.items) do
            local label = symbol.label
              or (
                symbol.textEdit
                and symbol.textEdit.newText
                or symbol.insertText
              )

            local info = server.get_completion_items_kind(symbol.kind) or ""

            local desc = symbol.detail or ""

            -- Fix some issues as with clangd
            if
              symbol.label and
              symbol.insertText and
              #symbol.label > #symbol.insertText
            then
              label = symbol.insertText
              if symbol.label ~= label then
                desc = symbol.label
              end
              if symbol.detail then
                desc = desc .. ": " .. symbol.detail
              end
              desc = desc .. "\n"
            end

            if symbol.documentation and symbol.documentation.value then
              desc = desc .. "\n" .. symbol.documentation.value
            end

            desc = desc:gsub("\n$", "")

            if server.capabilities.completionProvider.resolveProvider then
              symbols.items[label] = {
                info = info, desc = desc,
                data = {server = server, completion_item = symbol},
                cb = lsp.request_item_resolve
              }
            else
              symbols.items[label] = {info = info, desc = desc}
            end
          end

          autocomplete.complete(symbols)
        end
      )
    end
  end
end

function lsp.request_signature(doc, line, col, forced)
  local char = doc:get_char(line, col-1)
  for index, name in pairs(lsp.get_active_servers(doc.filename)) do
    local server = lsp.servers_running[name]
    if
      server.capabilities
      and
      server.capabilities.signatureHelpProvider
      and
      (
        forced
        or
        (
          server.capabilities.signatureHelpProvider.triggerCharacters
          and
          #server.capabilities.signatureHelpProvider.triggerCharacters > 0
          and
          Util.intable(
            char, server.capabilities.signatureHelpProvider.triggerCharacters
          )
        )
      )
    then
      server:push_request(
        'textDocument/signatureHelp',
        get_buffer_position_params(doc, line, col),
        function(server, response)
          if
            response.result
            and
            response.result.signatures
            and
            #response.result.signatures > 0
          then
            local active_parameter = response.result.activeParameter or 0
            local active_signature = response.result.activeSignature or 0
            local signatures = response.result.signatures
            local text = ""
            for index, signature in pairs(signatures) do
              text = text .. signature.label .. "\n"
            end
            listbox.show_text(text:gsub("\n$", ""))
          end
        end
      )
      break
    end
  end
end

function lsp.request_hover(doc, line, col)
  local char = doc:get_char(line, col-1)
  for index, name in pairs(lsp.get_active_servers(doc.filename)) do
    local server = lsp.servers_running[name]
    if server.capabilities and server.capabilities.hoverProvider then
      server:push_request(
        'textDocument/hover',
        get_buffer_position_params(doc, line, col),
        function(server, response)
          if response.result and response.result.contents then
            local content = response.result.contents
            local text = ""
            if type(content) == "table" then
              if content.value then
                text = content.value
              else
                for _, element in pairs(content) do
                  if type(element) == "string" then
                    text = text .. element
                  elseif type(element) == "table" and element.value then
                    text = text .. element.value
                  end
                end
              end
            else -- content should be a string
              text = content
            end
            if text and #text > 0 then
              listbox.show_text(text:gsub("\n+$", ""))
            end
          end
        end
      )
      break
    end
  end
end

function lsp.goto_symbol(doc, line, col, implementation)
  for index, name in pairs(lsp.get_active_servers(doc.filename)) do
    local server = lsp.servers_running[name]

    if not server.capabilities then
      return
    end

    local method = ""
    if not implementation then
      if server.capabilities.definitionProvider then
        method = method .. "definition"
      elseif server.capabilities.declarationProvider then
        method = method .. "declaration"
      elseif server.capabilities.typeDefinitionProvider then
        method = method .. "typeDefinition"
      else
        log(server, "Goto definition not supported")
        return
      end
    else
      if server.capabilities.implementationProvider then
        method = method .. "implementation"
      else
        log(server, "Goto implementation not supported")
        return
      end
    end

    server:push_request(
      "textDocument/" .. method,
      get_buffer_position_params(doc, line, col),
      function(server, response)
        local location = response.result

        if not location or not location.uri and #location == 0 then
          log(server, "No %s found", method)
          return
        end

        -- TODO display a box showing different definition points to go
        if not location.uri then
          if #location >= 1 then
            location = location[1]
          end
        end

        -- Open first matching result and goto the line
        core.root_view:open_doc(
          core.open_doc(
            common.home_expand(Util.tofilename(location.uri))
          )
        )
        local line1, col1 = Util.toselection(location.range)
        core.active_view.doc:set_selection(line1, col1, line1, col1)
      end
    )
  end
end

--
-- Thread to process server requests and responses
-- without blocking entirely the editor.
--
core.add_thread(function()
  while true do
    for name,server in pairs(lsp.servers_running) do
      server:process_notifications()
      server:process_requests()
      server:process_responses()
      server:process_errors()
    end

    if system.window_has_focus() then
      -- scan the fastest possible while not eating too much cpu
      coroutine.yield(0.01)
    else
      -- if window is unfocused lower the thread rate to lower cpu usage
      coroutine.yield(config.project_scan_rate)
    end
  end
end)

local function get_active_view()
  if getmetatable(core.active_view) == DocView then
    return core.active_view
  end
  return nil
end

--
-- Events patching
--
local doc_load = Doc.load
local doc_save = Doc.save
local root_view_on_text_input = RootView.on_text_input

Doc.load = function(self, ...)
  local res = doc_load(self, ...)
  core.add_thread(function()
    lsp.open_document(self)
  end)
  return res
end

Doc.save = function(self, ...)
  local res = doc_save(self, ...)
  core.add_thread(function()
    lsp.save_document(self)
  end)
  return res
end

core.add_close_hook(function(doc)
  core.add_thread(function()
    lsp.close_document(doc)
  end)
end)

RootView.on_text_input = function(...)
  root_view_on_text_input(...)

  local av = get_active_view()

  if av then
    local line1, col1, line2, col2 = av.doc:get_selection()

    if line1 == line2 and col1 == col2 then
      lsp.request_completion(av.doc, line1, col1)
      lsp.request_signature(av.doc, line1, col1)
    end
  end
end

--
-- Commands
--
command.add("core.docview", {
  ["lsp:complete"] = function()
    local doc = core.active_view.doc
    if doc then
      local line1, col1, line2, col2 = doc:get_selection()
      if line1 == line2 and col1 == col2 then
        lsp.request_completion(doc, line1, col1)
      end
    end
  end,

  ["lsp:goto-definition"] = function()
    local doc = core.active_view.doc
    if doc then
      local line1, col1, line2, col2 = doc:get_selection()
      if line1 == line2 and col1 == col2 then
        lsp.goto_symbol(doc, line1, col1)
      end
    end
  end,

  ["lsp:goto-implementation"] = function()
    local doc = core.active_view.doc
    if doc then
      local line1, col1, line2, col2 = doc:get_selection()
      if line1 == line2 and col1 == col2 then
        lsp.goto_symbol(doc, line1, col1, true)
      end
    end
  end,

  ["lsp:show-signature"] = function()
    local doc = core.active_view.doc
    if doc then
      local line1, col1, line2, col2 = doc:get_selection()
      if line1 == line2 and col1 == col2 then
        lsp.request_signature(doc, line1, col1, true)
      end
    end
  end,

  ["lsp:symbol-info"] = function()
    local doc = core.active_view.doc
    if doc then
      local line1, col1, line2, col2 = doc:get_selection()
      if line1 == line2 and col1 == col2 then
        lsp.request_hover(doc, line1, col1)
      end
    end
  end,
})

--
-- Default Keybindings
--
keymap.add {
  ["ctrl+space"]        = "lsp:complete",
  ["ctrl+shift+space"]  = "lsp:show-signature",
  ["alt+a"]             = "lsp:symbol-info",
  ["alt+d"]             = "lsp:goto-definition",
  ["alt+shift+d"]       = "lsp:goto-implementation",
}

return lsp
