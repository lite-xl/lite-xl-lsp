-- mod-version:1 lite-xl 1.16
--
-- LSP client for lite-xl
-- @copyright Jefferson Gonzalez
-- @license MIT

-- TODO Change the code to make it possible to use more than one LSP server
-- for a single file if possible and needed, for eg:
--   One lsp may not support goto definition but another one registered
--   for the current document filetype may do.

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

-- Setting to true breaks json for more readability on the log
config.lsp.prettify_json = false

--
-- Main plugin functionality
--
local lsp = {}

lsp.servers = {}
lsp.servers_running = {}

--
-- Private functions
--
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

--- Recursive function to generate a list of symbols ready
-- to use for the lsp.request_document_symbols() action.
local function get_symbol_lists(list, parent)
  local symbols = {}
  local symbol_names = {}
  parent = parent or ""
  parent = #parent > 0 and (parent .. "/") or parent

  for _, symbol in pairs(list) do
    -- Include symbol kind to be able to filter by it
    local symbol_name = parent
      .. symbol.name
      .. "||" .. Server.get_symbols_kind(symbol.kind)

    table.insert(symbol_names, symbol_name)

    symbols[symbol_name] = { kind = symbol.kind }

    if symbol.location then
      symbols[symbol_name].location = symbol.location
    else
      if symbol.range then
        symbols[symbol_name].range = symbol.range
      end
      if symbol.uri then
        symbols[symbol_name].uri = symbol.uri
      end
    end

    if symbol.children and #symbol.children > 0 then
      local child_symbols, child_names = get_symbol_lists(
        symbol.children, parent .. symbol.name
      )

      for _, name in pairs(child_names) do
        table.insert(symbol_names, name)
        symbols[name] = child_symbols[name]
      end
    end
  end

  return symbols, symbol_names
end

local function log(server, message, ...)
  core.log("["..server.name.."] " .. message, ...)
end

local function get_active_view()
  if getmetatable(core.active_view) == DocView then
    return core.active_view
  end
  return nil
end

--
-- Public functions
--

--- Register an LSP server to be launched on demand
function lsp.add_server(server)
  lsp.servers[server.name] = server
end

--- Get valid running lsp servers for a given filename
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

--- Start all applicable lsp servers for a given file.
-- TODO Update workspace folders of already running lsp servers if required
-- TODO figure a way to check if the server command exists before trying to
-- execute it and if not exists warn the user
function lsp.start_server(filename, project_directory)
  for name, server in pairs(lsp.servers) do
    if matches_any(filename, server.file_patterns) then
      if not lsp.servers_running[name] then
        core.log("[LSP] starting " .. name)
        local client = Server.new(server)

        lsp.servers_running[name] = client

        -- We overwrite the default log function to log messages on lite
        function client:log(message, ...)
          core.log_quiet(
            "[LSP/%s]: " .. message .. "\n",
            self.name,
            ...
          )
        end

        -- Respond to workspace/configuration request with:
        -- 1. settings table if given to server,
        -- 2. or content of settings.json if exits,
        -- 3. or table returned on settings.lua if exists
        -- 4. or finally respond with method not found
        client:add_request_listener("workspace/configuration", function(server, request)
          local settings = nil
          local project_path = server.path .. PATHSEP
          if type(server.settings) == "table" then
            settings = server.settings
          elseif Util.file_exists(project_path .. "settings.json") then
            local file = io.open(project_path .. "settings.json", "r")
            local settings_json = file:read("*a")
            settings_json = Json.decode(settings_json)
            if settings_json then
              settings = settings_json
            end
          elseif Util.file_exists(project_path .. "settings.lua") then
            local settings_lua = require(project_path .. "settings.lua")
            if type(settings_lua) == "table" then
              settings = settings_lua
            end
          end

          if settings then
            server:push_response(request.method, request.id, settings)
          else
            server:push_response(
              request.method,
              request.id,
              nil,
              {
                code = server.error_code.MethodNotFound,
                message = "Method not found"
              }
            )
          end
        end)

        -- Display server messages on lite UI
        client:add_message_listener("window/logMessage", function(server, params)
          if core.log then
            core.log("["..server.name.."] " .. params.message)
            coroutine.yield(3)
          end
        end)

        -- Send settings table after initialization if available.
        -- TODO Apply same logic as on 'workspace/configuration' request
        -- Setup some autocompletion triggers if possible
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

              -- Don't include signature trigger characters as part of code
              -- auto completion to prevent issues with some lsp servers
              -- like lua-language-server
              local signature_chars = {}
              if
                server.capabilities.signatureHelpProvider
                and
                server.capabilities.signatureHelpProvider.triggerCharacters
                and
                #server.capabilities.signatureHelpProvider.triggerCharacters > 0
              then
                signature_chars = server.capabilities
                  .signatureHelpProvider.triggerCharacters
              end

              -- Filter autocomplete trigger characters as workaround
              -- for lua-language-server
              local chars = {}
              for _, char in
                pairs(server.capabilities.completionProvider.triggerCharacters)
              do
                if
                  char == ":" -- workaround for intelephense adding this in signatures :S
                  or
                  (
                    char:match("%p")
                    and
                    not Util.intable(char, signature_chars)
                  )
                then
                  table.insert(chars, char)
                end
              end

              autocomplete.add_trigger {
                name = server.language,
                file_patterns = server.file_patterns,
                characters = chars
              }
            end
          end
        end)

        -- Start the server initialization process
        client:initialize(project_directory, "Lite XL", VERSION)
      end
    end
  end
end

--- Send notification to applicable LSP servers that a document was opened
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

--- Send notification to applicable LSP servers that a document was saved
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

--- Send notification to applicable LSP servers that a document was closed
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

--- Callback given to autocomplete plugin which is executed once for each
-- element of the autocomplete box which is selected with the idea of providing
-- better description of the selected element by requesting an LSP server for
-- detailed information.
function lsp.request_item_resolve(index, item)
  local completion_item = item.data.completion_item
  item.data.server:push_request(
    'completionItem/resolve',
    completion_item,
    function(server, response)
      if response.result then
        local symbol = response.result
        -- TODO overwrite the item.desc to show documentation of
        -- symbol if available, but nothing seems to be returned
        -- by tested LSP's, maybe some missing initialization option?
      end
    end
  )
end

--- Send to applicable LSP servers a request for code completion
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
      local capabilities = lsp.servers_running[name].capabilities
      local char = doc:get_char(line, col-1)
      local signature_char = false

      if
        capabilities.signatureHelpProvider
        and
        capabilities.signatureHelpProvider.triggerCharacters
        and
        #capabilities.signatureHelpProvider.triggerCharacters > 0
        and
        Util.intable(char, capabilities.signatureHelpProvider.triggerCharacters)
        and
        char ~= ":" -- work around for some lang servers (intelephense)
      then
        signature_char = true
      end

      -- don't request code completion if input character was a signature
      -- trigger character because some bad behaved language servers like
      -- lua-language-server return a lot of garbage
      if not signature_char and char ~= ")" then
        local request = get_buffer_position_params(doc, line, col)

        -- without providing context some language servers like the
        -- lua-language-server behave poorly and return garbage.
        if
          capabilities.completionProvider.triggerCharacters
          and
          #capabilities.completionProvider.triggerCharacters > 0
          and
          char:match("%p")
          and
          Util.intable(char, capabilities.completionProvider.triggerCharacters)
        then
          request.context = {
            triggerKind = Server.completion_trigger_Kind.TriggerCharacter,
            triggerCharacter = char
          }
        end

        lsp.servers_running[name]:push_request(
          'textDocument/completion',
          request,
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
end

--- Send to applicable LSP servers a request for info about a function
-- signatures and display them on a tooltip.
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

--- Sends a request to applicable LSP servers for information about the
-- symbol where the cursor is placed and shows it on a tooltip.
function lsp.request_hover(doc, line, col)
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

--- Request a list of symbols for the given document for easy document
-- navigation and displays them using core.command_view:enter()
function lsp.request_document_symbols(doc)
  local servers_found = false
  local symbols_retrieved = false
  for index, name in pairs(lsp.get_active_servers(doc.filename)) do
    servers_found = true
    local server = lsp.servers_running[name]
    if server.capabilities and server.capabilities.documentSymbolProvider then
      log(server, "Retrieving document symbols...")
      server:push_request(
        'textDocument/documentSymbol',
        {
          textDocument = {
            uri = Util.touri(system.absolute_path(doc.filename)),
          }
        },
        function(server, response)
          if response.result and response.result and #response.result > 0 then
            local symbols, symbol_names = get_symbol_lists(response.result)
            core.command_view:enter("Find Symbol",
              function(text, item)
                if item then
                  local symbol = symbols[item.name]
                  -- The lsp may return a location object with range
                  -- and uri inside of it or just range as part of
                  -- the symbol it self.
                  symbol = symbol.location and symbol.location or symbol
                  if not symbol.uri then
                    local line1, col1 = Util.toselection(symbol.range)
                    doc:set_selection(line1, col1, line1, col1)
                  else
                    core.root_view:open_doc(
                      core.open_doc(
                        common.home_expand(Util.tofilename(symbol.uri))
                      )
                    )
                    local line1, col1 = Util.toselection(symbol.range)
                    core.active_view.doc:set_selection(line1, col1, line1, col1)
                  end
                end
              end,
              function(text)
                local res = common.fuzzy_match(symbol_names, text)
                for i, name in ipairs(res) do
                  res[i] = {
                    text = Util.split(name, "||")[1],
                    info = Server.get_symbols_kind(symbols[name].kind),
                    name = name
                  }
                end
                return res
              end
            )
          end
        end
      )
      symbols_retrieved = true
      break
    end
  end

  if not servers_found then
    core.log("[LSP] " .. "No server running")
  elseif not symbols_retrieved then
    core.log("[LSP] " .. "Document symbols not supported")
  end
end

--- Jumps to the definition or implementation of the symbol where the cursor
-- is placed if the LSP server supports it
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
            common.home_expand(
              Util.tofilename(location.uri or location.targetUri)
            )
          )
        )
        local line1, col1 = Util.toselection(
          location.range or location.targetRange
        )
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
      server:process_client_responses()
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
      -- TODO this should be moved to another function that checks
      -- if current character should trigger a signature and if no signature
      -- was returned then trigger regular code completion. This may fix
      -- issues with some lsp servers and make the requests sequence better.
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

  ["lsp:show-symbol-info"] = function()
    local doc = core.active_view.doc
    if doc then
      local line1, col1, line2, col2 = doc:get_selection()
      if line1 == line2 and col1 == col2 then
        lsp.request_hover(doc, line1, col1)
      end
    end
  end,

  ["lsp:view-document-symbols"] = function()
    local doc = core.active_view.doc
    if doc then
      lsp.request_document_symbols(doc)
    end
  end,
})

--
-- Default Keybindings
--
keymap.add {
  ["ctrl+space"]        = "lsp:complete",
  ["ctrl+shift+space"]  = "lsp:show-signature",
  ["alt+a"]             = "lsp:show-symbol-info",
  ["alt+d"]             = "lsp:goto-definition",
  ["alt+shift+d"]       = "lsp:goto-implementation",
  ["alt+f"]             = "lsp:view-document-symbols",
}

return lsp
