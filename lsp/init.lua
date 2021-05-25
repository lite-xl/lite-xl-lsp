-- mod-version:1 lite-xl 1.16
--
-- LSP client for lite-xl
-- @copyright Jefferson Gonzalez
-- @license MIT

local core = require "core"
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

        client:initialize(
          project_directory,
          "Lite XL",
          "0.16.0"
        )
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

function lsp.request_completion(doc, line, col)
  --if autocomplete.is_open() then
  --  return
  --end

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

          local info = symbol.detail
            or server.get_completion_items_kind(symbol.kind)
            or ""

          symbols.items[label] = info
        end

        autocomplete.complete(symbols)
      end
    )
  end
end

function lsp.request_hover(filename, position)
  table.insert(lsp.documents, filename)
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

      coroutine.yield()

      server:process_responses()
    end

    -- wait for next scan (config.project_scan_rate
    coroutine.yield()
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
local root_view_on_text_input = RootView.on_text_input

Doc.load = function(self, ...)
  local res = doc_load(self, ...)
  core.add_thread(function()
    lsp.open_document(self)
  end)
  return res
end

RootView.on_text_input = function(...)
  root_view_on_text_input(...)

  local av = get_active_view()

  if av then
    local line1, col1, line2, col2 = av.doc:get_selection()

    if line1 == line2 and col1 == col2 then
      lsp.request_completion(av.doc, line1, col1)
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
})

--
-- Default Keybindings
--
keymap.add {
  ["ctrl+space"]    = "lsp:complete",
}

return lsp
