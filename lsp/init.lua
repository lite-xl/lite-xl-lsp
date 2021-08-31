-- mod-version:2 -- lite-xl 2.00
--
-- LSP client for lite-xl
-- @copyright Jefferson Gonzalez
-- @license MIT
--
-- Note: Annotations syntax documentation which is supported by
-- https://github.com/sumneko/lua-language-server can be read here:
-- https://emmylua.github.io/annotation.html

-- TODO Change the code to make it possible to use more than one LSP server
-- for a single file if possible and needed, for eg:
--   One lsp may not support goto definition but another one registered
--   for the current document filetype may do.

local core = require "core"
local common = require "core.common"
local config = require "core.config"
local command = require "core.command"
local style = require "core.style"
local Doc = require "core.doc"
local translate = require "core.doc.translate"
local keymap = require "core.keymap"
local RootView = require "core.rootview"
local DocView = require "core.docview"
local StatusView = require "core.statusview"
local autocomplete = require "plugins.autocomplete"

local Json = require "plugins.lsp.json"
local Server = require "plugins.lsp.server"
local Util = require "plugins.lsp.util"
local Diagnostics = require "plugins.lsp.diagnostics"
local SymbolResults = require "plugins.lsp.symbolresults"
local listbox = require "plugins.lsp.listbox"

-- Try to load lintplus plugin if available for diagnostics rendering
local lintplus = nil
if pcall(require, "plugins.lintplus") then
  lintplus = require "plugins.lintplus"
end

--
-- Plugin settings
--

---Configuration options for the LSP plugin.
config.plugins.lsp = {
  ---Set to a file path to log all json
  ---@type string
  log_file = "",

  ---Setting to true prettyfies json for more readability on the log
  ---but this setting will impact performance so only enable it when
  ---in need of easy to read json output when developing the plugin.
  ---@type boolean
  prettify_json = false,

  ---Show diagnostic messages
  ---@type boolean
  show_diagnostics = true,

  ---Stop servers that aren't needed by any of the open files
  ---@type boolean
  stop_unneeded_servers = true,

  ---Send a server stderr output to lite log
  ---@type boolean
  log_server_stderr = false,

  ---Force verbosity off even if a server is configured with verbosity on
  ---@type boolean
  force_verbosity_off = false
}

--
-- Main plugin functionality
--
local lsp = {}

---List of registered servers
lsp.servers = {}

---List of running servers
lsp.servers_running = {}

---Flag that indicates if last autocomplete request was a trigger
---to prevent requesting another autocompletion request until the
---autocomplete box is hidden since some lsp servers loose context
---and return wrong results (eg: lua-language-server)
---@type boolean
lsp.in_trigger = false

---Used to set proper diagnostic type on lintplus
---@type table<integer, string>
local diagnostic_kinds = { "error", "warning", "info", "hint" }

--
-- Private functions
--

---Generate an lsp location object
---@param doc Doc
---@param line integer
---@param col integer
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

---Recursive function to generate a list of symbols ready
---to use for the lsp.request_document_symbols() action.
---@param list table<integer, table>
---@param parent string
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

---Check if active view is a DocView and return it
---@return DocView|nil
local function get_active_view()
  if getmetatable(core.active_view) == DocView then
    return core.active_view
  end
  return nil
end

---Generates a code preview of a location
---@param location table
local function get_location_preview(location)
  local line1, col1 = Util.toselection(
    location.range or location.targetRange
  )
  local filename = core.normalize_to_project_dir(
    Util.tofilename(location.uri or location.targetUri)
  )

  local file = io.open(Util.tofilename(
    location.uri or location.targetUri
  ))

  local preview = ""

  -- sometimes the lsp can send the location of a definition where the
  -- doc comments should be written but if no docs are written the line
  -- is empty and subsequent line is the one we are interested in.
  local line_count = 1
  for line in file:lines() do
    if line_count >= line1 then
      preview = line:gsub("^%s+", "")
        :gsub("%s+$", "")

      if preview ~= "" then
        break
      else
        -- change also the location table
        if location.range then
          location.range.start.line = location.range.start.line + 1
          location.range['end'].line = location.range['end'].line + 1
        elseif location.targetRange then
          location.targetRange.start.line = location.targetRange.start.line + 1
          location.targetRange['end'].line = location.targetRange['end'].line + 1
        end
      end
    end
    line_count = line_count + 1
  end

  local position = filename .. ":" .. tostring(line1) .. ":" .. tostring(col1)

  return preview, position
end

---Generate a list ready to use for the lsp.request_references() action.
---@param locations table
local function get_references_lists(locations)
  local references, reference_names = {}, {}

  for _, location in pairs(locations) do
    local preview, position = get_location_preview(location)
    local name = preview .. "||" .. position
    table.insert(reference_names, name)
    references[name] = location
  end

  return references, reference_names
end

---Apply an lsp textEdit to a document if possible.
---@param doc Doc
---@param text_edit table
---@return boolean True on success
local function apply_edit(doc, text_edit)
  local range = nil

  if text_edit.range then
    range = text_edit.range
  elseif text_edit.insert then
    range = text_edit.insert
  elseif text_edit.replace then
    range = text_edit.replace
  end

  if not range then return false end

  local line1, col1, line2, col2 = Util.toselection(range)
  local text = text_edit.newText
  local current_text = ""

  if lsp.in_trigger then
    local cline2, ccol2 = doc:get_selection()
    local cline1, ccol1 = doc:position_offset(line2, col2, translate.start_of_word)
    current_text = doc:get_text(cline1, ccol1, cline2, ccol2)
  end

  doc:remove(line1, col1, line2, col2+#current_text)
  doc:insert(line1, col1, text_edit.newText)
  doc:set_selection(line2, col2+#text, line2, col2+#text)
  lsp.update_document(doc)

  return true
end

---Callback given to autocomplete plugin which is executed once for each
---element of the autocomplete box which is hovered with the idea of providing
---better description of the selected element by requesting the LSP server for
---detailed information/documentation.
---@param index integer
---@param item table
local function autocomplete_onhover(index, item)
  local completion_item = item.data.completion_item

  if item.data.server.verbose then
    item.data.server:log(
      "Resolve item: %s", Util.jsonprettify(Json.encode(completion_item))
    )
  end

  -- Only send resolve request if data field (which should contain
  -- the item id) is available.
  if completion_item.data then
    item.data.server:push_request(
      'completionItem/resolve',
      completion_item,
      function(server, response)
        if response.result then
          local symbol = response.result
          if symbol.detail and #item.desc <= 0 then
            item.desc = symbol.detail
          end
          if symbol.documentation then
            if #item.desc > 0 then
              item.desc = item.desc .. "\n\n"
            end
            if
              type(symbol.documentation) == "table"
              and
              symbol.documentation.value
            then
              item.desc = item.desc .. symbol.documentation.value
              if
                symbol.documentation.kind
                and
                symbol.documentation.kind == "markdown"
              then
                item.desc = Util.strip_markdown(item.desc)
              end
            else
              item.desc = item.desc .. symbol.documentation
            end
          end
          item.desc = item.desc:gsub("[%s\n]+$", "")
            :gsub("^[%s\n]+", "")
            :gsub("\n\n\n+", "\n\n")
          if server.verbose then
            server:log(
              "Resolve response: %s", Util.jsonprettify(Json.encode(symbol))
            )
          end
        elseif server.verbose then
          server:log("Resolve returned empty response")
        end
      end
    )
  end
end

---Callback that handles insertion of an autocompletion item that has
---the information of insertion
---@param index integer
---@param item table
local function autocomplete_onselect(index, item)
  local completion = item.data.completion_item
  if completion.textEdit then
    local av = get_active_view()
    local edit_applied = apply_edit(av.doc, completion.textEdit)
    if edit_applied then
      lsp.update_document(av.doc)
      -- Retrigger code completion if last char is a trigger
      -- this is useful for example with clangd when autocompleting
      -- a #include, if user types < a list of paths will appear
      -- when selecting a path that ends with / as <AL/ the
      -- autocompletion will be retriggered to show a list of
      -- header files that belong to that directory.
      lsp.in_trigger = false
      local line, col = av.doc:get_selection()
      local char = av.doc:get_char(line, col-1)
      if char:match("%p") then
        lsp.request_completion(
          av.doc,
          line,
          col,
          true
        )
      end
    end
    return edit_applied
  end
  return false
end

--
-- Public functions
--

---Open a document location returned by LSP
---@param location table
function lsp.goto_location(location)
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

lsp.get_location_preview = get_location_preview

---Register an LSP server to be launched on demand
---@param options table
function lsp.add_server(options)
  local required_fields = {
    "name", "language", "file_patterns", "command"
  }

  for _, field in pairs(required_fields) do
    if not options[field] then
      core.error(
        "[LSP] You need to provide a '%s' field for the server.",
        field
      )
      return false
    end
  end

  if #options.command <= 0 then
    core.error("[LSP] Provide a command table list with the lsp command.")
    return false
  end

  if config.plugins.lsp.force_verbosity_off then
    options.verbose = false
  end

  lsp.servers[options.name] = options

  return true
end

---Get valid running lsp servers for a given filename
---@param filename string
---@param initialized boolean
---@return table active_servers
function lsp.get_active_servers(filename, initialized)
  local servers = {}
  for name, server in pairs(lsp.servers) do
    if common.match_pattern(filename, server.file_patterns) then
      if lsp.servers_running[name] then
        local add_server = true
        if
          initialized
          and
          (
            not lsp.servers_running[name].initialized
            or
            not lsp.servers_running[name].capabilities
          )
        then
          add_server = false
        end
        if add_server then
          table.insert(servers, name)
        end
      end
    end
  end
  return servers
end

-- Used on lsp.get_workspace_settings()
local cached_workspace_settings = {}
local cached_workspace_settings_timestamp = 0

---Get table of configuration settings in the following way:
---1. Scan the USERDIR for settings.lua or settings.json (in that order)
---2. Merge server.settings
---4. Scan workspace if set also for settings.lua/json and merge them or
---3. Scan server.path also for settings.lua/json and merge them
---Note: settings are cached for 5 seconds for faster retrieval
---      on repetitive calls to this function.
---@param server Server
---@param workspace? string
---@return table
function lsp.get_workspace_settings(server, workspace)
  -- Search settings on the following directories, subsequent settings
  -- overwrite the previous ones
  local paths = { USERDIR }
  local cached_index = USERDIR
  local settings = {}

  if not workspace and server.path then
    table.insert(paths, server.path)
    cached_index = cached_index .. tostring(server.path)
  elseif workspace then
    table.insert(paths, workspace)
    cached_index = cached_index .. tostring(workspace)
  end

  if
    cached_workspace_settings_timestamp > os.time()
    and
    cached_workspace_settings[cached_index]
  then
    return cached_workspace_settings[cached_index]
  else
    local position = 1
    for _, path in pairs(paths) do
      if path then
        local settings_new = nil
        path = path:gsub("\\+$", ""):gsub("/+$", "")
        if Util.file_exists(path .. "/settings.lua") then
          local settings_lua = require(path .. "/settings.lua")
          if type(settings_lua) == "table" then
            settings_new = settings_lua
          end
        elseif Util.file_exists(path .. "/settings.json") then
          local file = io.open(path .. "/settings.json", "r")
          local settings_json = file:read("*a")
          settings_new = Json.decode(settings_json)
        end

        -- overwrite global settings by those specified in the server if any
        if position == 1 and server.settings then
          if settings_new then
            Util.table_merge(settings_new, server.settings)
          else
            settings_new = server.settings
          end
        end

        -- overwrite previous settings with new ones
        if settings_new then
          Util.table_merge(settings, settings_new)
        end
      end

      position = position + 1
    end

    -- store settings on cache for 5 seconds for fast repeated calls
    cached_workspace_settings[cached_index] = settings
    cached_workspace_settings_timestamp = os.time() + 5
  end

  return settings
end

-- TODO Update workspace folders of already running lsp servers if required
--- Start all applicable lsp servers for a given file.
--- @param filename string
--- @param project_directory string
function lsp.start_server(filename, project_directory)
  local server_started = false
  local server_registered = false
  local servers_not_found = {}
  for name, server in pairs(lsp.servers) do
    if common.match_pattern(filename, server.file_patterns) then
      server_registered = true
      if lsp.servers_running[name] then
        server_started = true
      end

      local command_exists = false
      if Util.command_exists(server.command[1]) then
        command_exists = true
      else
        table.insert(servers_not_found, name)
      end

      if not lsp.servers_running[name] and command_exists then
        core.log("[LSP] starting " .. name)
        local client = Server(server)

        lsp.servers_running[name] = client

        -- We overwrite the default log function to log messages on lite
        function client:log(message, ...)
          core.log_quiet(
            "[LSP/%s]: " .. message .. "\n",
            self.name,
            ...
          )
        end

        function client:on_shutdown()
          core.log(
            "[LSP]: %s was shutdown, revise your configuration",
            self.name
          )
          lsp.servers_running = Util.table_remove_key(
            lsp.servers_running,
            self.name
          )
        end

        -- Respond to workspace/configuration request
        client:add_request_listener(
          "workspace/configuration",
          function(server, request)
            local settings_default = lsp.get_workspace_settings(server)

            local settings_list = {}
            for _, item in pairs(request.params.items) do
              local value = nil
              -- No workspace was specified so we return from default settings
              if not item.scopeUri then
                value = Util.table_get_field(settings_default, item.section)
              -- A workspace was specified so we return from that workspace
              else
                local settings_workspace = lsp.get_workspace_settings(
                  server, Util.tofilename(item.scopeUri)
                )
                value = Util.table_get_field(settings_workspace, item.section)
              end

              if not value then
                server:log("Asking for '%s' config but not set", item.section)
              else
                server:log("Asking for '%s' config", item.section)
              end

              table.insert(settings_list, value or Json.null)
            end
            server:push_response(request.method, request.id, settings_list)
          end
        )

        -- Display server messages on lite UI
        client:add_message_listener(
          "window/logMessage",
          function(server, params)
            if core.log then
              log(server, "%s", params.message)
              coroutine.yield(3)
            end
          end
        )

        -- Display server messages on lite UI
        client:add_message_listener(
          "textDocument/publishDiagnostics",
          function(server, params)
            local filename = Util.tofilename(params.uri)

            local filename_rel = common.normalize_path(filename)
            if not common.path_belongs_to(filename_rel, core.project_dir) then
              if server.verbose then
                log(
                  server,
                  "Diagnostics for non project file '%s' ignored",
                  filename
                )
              end
              return
            end

            if server.vebose then
              core.log_quiet(
                "["..server.name.."] %d diagnostics for:  %s",
                filename,
                params.diagnostics and #params.diagnostics or 0
              )
            end

            if params.diagnostics and #params.diagnostics > 0 then
              Diagnostics.add(filename, params.diagnostics)

              if
                config.plugins.lsp.show_diagnostics
                and
                lintplus and lintplus.add_message
              then
                lintplus.clear_messages(filename)

                for _, diagnostic in pairs(params.diagnostics) do
                  local line, col = Util.toselection(diagnostic.range)
                  local message = diagnostic.message
                  local kind = diagnostic_kinds[diagnostic.severity]

                  lintplus.add_message(filename, line, col, kind, message)
                end
              end
            else
              Diagnostics.clear(filename)
              if
                config.plugins.lsp.show_diagnostics
                and
                lintplus and lintplus.add_message
              then
                lintplus.clear_messages(filename)
              end
            end
          end
        )

        -- Send settings table after initialization if available.
        client:add_event_listener("initialized", function(server)
          if config.plugins.lsp.force_verbosity_off then
            core.log_quiet("["..server.name.."] " .. "Initialized")
          else
            log(server, "Initialized")
          end
          local settings = lsp.get_workspace_settings(server)
          if not Util.table_empty(settings) then
            server:push_request(
              "workspace/didChangeConfiguration",
              {settings = settings},
              function(server, response)
                if server.verbose then
                  server:log(
                    "'workspace/didChangeConfiguration' response:\n%s",
                    Util.jsonprettify(Json.encode(response))
                  )
                end
              end
            )
          end

          -- Send open document request if needed
          for _, docu in ipairs(core.docs) do
            if docu.filename then
              if common.match_pattern(docu.filename, server.file_patterns) then
                lsp.open_document(docu)
              end
            end
          end
        end)

        -- Start the server initialization process
        client:initialize(project_directory, "Lite XL", VERSION)
      end
    end
  end

  if server_registered and not server_started then
    for _, server in pairs(servers_not_found) do
      core.error(
        "[LSP] servers registered but not installed: %s",
        table.concat(servers_not_found, ", ")
      )
    end
  end
end

--- Send notification to applicable LSP servers that a document was opened
function lsp.open_document(doc)
  lsp.start_server(doc.filename, core.project_dir)

  local active_servers = lsp.get_active_servers(doc.filename, true)

  if #active_servers > 0 then
    doc.disable_symbols = true -- disable symbol parsing on autocomplete plugin
    for _, name in pairs(active_servers) do
      local server = lsp.servers_running[name]
      if
        server.capabilities.textDocumentSync
        and
        (
          server.capabilities.textDocumentSync
          ==
          Server.text_document_sync_kind.Incremental
          or
          server.capabilities.textDocumentSync
          ==
          Server.text_document_sync_kind.Full
          or
          (
            type(server.capabilities.textDocumentSync) == "table"
            and
            server.capabilities.textDocumentSync.openClose
          )
        )
      then
        local file_info = system.get_file_info(
          system.absolute_path(doc.filename)
        )
        if file_info.size / 1024 <= 100 then
          -- file is in the range of 100kb so push the notification as usual.
          server:push_notification(
            'textDocument/didOpen',
            {
              textDocument = {
                uri = Util.touri(system.absolute_path(doc.filename)),
                languageId = Util.file_extension(doc.filename),
                version = doc.clean_change_id,
                text = doc:get_text(1, 1, #doc.lines, #doc.lines[#doc.lines])
              }
            },
            function() doc.lsp_open = true end
          )
        else
          -- file seems too big and json encoder is too slow, plus sending a
          -- huge file without yielding would stall the ui
          local text = doc
            :get_text(1, 1, #doc.lines, #doc.lines[#doc.lines])
            :gsub('\\', '\\\\'):gsub("\n", "\\n"):gsub("\r", "\\r")
            :gsub("\t", "\\t"):gsub('"', '\\"'):gsub('\b', '\\b')
            :gsub('\f', '\\f')

          server:push_raw(
            '{'
            .. '"jsonrpc": "2.0",'
            .. '"method": "textDocument/didOpen",'
            .. '"params": {'
            .. '"textDocument": {'
            .. '"uri": "'..Util.touri(system.absolute_path(doc.filename))..'",'
            .. '"languageId": "'..Util.file_extension(doc.filename)..'",'
            .. '"version": '..doc.clean_change_id..','
            .. '"text": "'..text..'"'
            .. '}'
            .. '} '
            .. '}',
            function(server)
              doc.lsp_open = true
              log(server, "Big file '%s' ready for completion!", doc.filename)
            end
          )

          log(server, "Processing big file '%s'...", doc.filename)
        end
      else
        doc.lsp_open = true
      end
    end
  end
end

--- Send notification to applicable LSP servers that a document was saved
function lsp.save_document(doc)
  if not doc.lsp_open then return end

  local active_servers = lsp.get_active_servers(doc.filename, true)
  if #active_servers > 0 then
    for _, name in pairs(active_servers) do
      local server = lsp.servers_running[name]
      if
        server.capabilities.textDocumentSync
        and
        type(server.capabilities.textDocumentSync) == "table"
        and
        server.capabilities.textDocumentSync.save
      then
        -- Send document content only if required by lsp server
        if
          type(server.capabilities.textDocumentSync.save) == "table"
          and
          server.capabilities.textDocumentSync.save.includeText
        then
          -- If save should include file content then raw is faster for
          -- huge files that would take too much to encode.
          local text = doc
            :get_text(1, 1, #doc.lines, #doc.lines[#doc.lines])
            :gsub('\\', '\\\\'):gsub("\n", "\\n"):gsub("\r", "\\r")
            :gsub("\t", "\\t"):gsub('"', '\\"'):gsub('\b', '\\b')
            :gsub('\f', '\\f')

          server:push_raw(
            '{'
            .. '"jsonrpc": "2.0",'
            .. '"method": "textDocument/didSave",'
            .. '"params": {'
            .. '"textDocument": {'
            .. '"uri": "'..Util.touri(system.absolute_path(doc.filename))..'"'
            .. '},'
            .. '"text": "'..text..'"'
            .. '} '
            .. '}'
          )
        else
          server:push_notification(
            'textDocument/didSave',
            {
              textDocument = {
                uri = Util.touri(system.absolute_path(doc.filename))
              }
            }
          )
        end
      end
    end
  end
end

--- Send notification to applicable LSP servers that a document was closed
function lsp.close_document(doc)
  if not doc.lsp_open then return end

  local active_servers = lsp.get_active_servers(doc.filename, true)
  if #active_servers > 0 then
    for _, name in pairs(active_servers) do
      local server = lsp.servers_running[name]
      if
        server.capabilities.textDocumentSync
        and
        type(server.capabilities.textDocumentSync) == "table"
        and
        server.capabilities.textDocumentSync.openClose
      then
        server:push_notification(
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
end

--- Send document updates to applicable running LSP servers.
function lsp.update_document(doc)
  if not doc.lsp_open or not doc.lsp_changes or #doc.lsp_changes <= 0 then
    return
  end

  for _, name in pairs(lsp.get_active_servers(doc.filename, true)) do
    local server = lsp.servers_running[name]
    if
      server.capabilities.textDocumentSync
      and
      (
        (
          type(server.capabilities.textDocumentSync) == "table"
          and
          server.capabilities.textDocumentSync.change
          and
          server.capabilities.textDocumentSync.change
          ~=
          Server.text_document_sync_kind.None
        )
        or
        server.capabilities.textDocumentSync
        ~=
        Server.text_document_sync_kind.None
      )
      and
      server:can_push() -- ensure we don't loose incremental changes
    then
      local sync_kind = Server.text_document_sync_kind.Incremental

      if
        type(server.capabilities.textDocumentSync) == "table"
        and
        server.capabilities.textDocumentSync.change
      then
        sync_kind = server.capabilities.textDocumentSync.change
      elseif server.capabilities.textDocumentSync then
        sync_kind = server.capabilities.textDocumentSync
      end

      if
        sync_kind == Server.text_document_sync_kind.Full
        and
        not server.incremental_changes
      then
        -- If sync should be done by sending full file content then lets do
        -- it raw which is faster for big files.
        local text = doc
          :get_text(1, 1, #doc.lines, #doc.lines[#doc.lines])
          :gsub('\\', '\\\\'):gsub("\n", "\\n"):gsub("\r", "\\r")
          :gsub("\t", "\\t"):gsub('"', '\\"'):gsub('\b', '\\b')
          :gsub('\f', '\\f')

        server:push_raw(
          '{'
          .. '"jsonrpc": "2.0",'
          .. '"method": "textDocument/didChange",'
          .. '"params": {'
          .. '"textDocument": {'
          .. '"uri": "'..Util.touri(system.absolute_path(doc.filename))..'",'
          .. '"version": '..doc.lsp_version
          .. '},'
          .. '"contentChanges": {'
          .. '"text": "'..text..'"'
          .. "}"
          .. '} '
          .. '}'
        )
      else
        lsp.servers_running[name]:push_notification(
          'textDocument/didChange',
          {
            textDocument = {
              uri = Util.touri(system.absolute_path(doc.filename)),
              version = doc.lsp_version,
            },
            contentChanges = doc.lsp_changes
          }
        )
      end
      doc.lsp_changes = {}
    end
  end
end

--- Enable or disable diagnostic messages
function lsp.toggle_diagnostics()
  config.plugins.lsp.show_diagnostics = not config.plugins.lsp.show_diagnostics

  if not config.plugins.lsp.show_diagnostics and lintplus then
    for name, message in pairs(lintplus.messages) do
      lintplus.clear_messages(name)
    end
    core.log("[LSP] Diagnostics disabled")
  else
    local av = get_active_view()
    if av and av.doc and av.doc.filename then
      local filename = system.absolute_path(av.doc.filename)
      local diagnostics = Diagnostics.get(filename)
      if diagnostics then
        for _, diagnostic in pairs(diagnostics) do
          local line, col = Util.toselection(diagnostic.range)
          local message = diagnostic.message
          local kind = diagnostic_kinds[diagnostic.severity]

          lintplus.add_message(filename, line, col, kind, message)
        end
      end
    end
    core.log("[LSP] Diagnostics enabled")
  end
end

--- Send to applicable LSP servers a request for code completion
function lsp.request_completion(doc, line, col, forced)
  if lsp.in_trigger or not doc.lsp_open then
    return
  end

  for _, name in pairs(lsp.get_active_servers(doc.filename, true)) do
    local server = lsp.servers_running[name]
    if server.capabilities.completionProvider then
      local capabilities = lsp.servers_running[name].capabilities
      local char = doc:get_char(line, col-1)
      local trigger_char = false

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
        trigger_char = true;
      end

      if
        not trigger_char
        and
        not autocomplete.can_complete()
        and
        not forced
      then
        core.redraw = true
        return false
      end

      server:push_request(
        'textDocument/completion',
        request,
        function(server, response)
          if server.verbose then
            server:log(
              "Completion response received."
            )
          end

          if not response.result then
            return
          end

          local result = response.result
          local complete_result = true
          if result.isIncomplete then
            if server.verbose then
              core.log_quiet(
                "["..server.name.."] " .. "Completion list incomplete"
              )
            end
            complete_result = false
          end

          if not result.items or #result.items <= 0 then
            -- Workaround for some lsp servers that don't return results
            -- in the items property but instead on the results it self
            if #result > 0 then
              local items = result
              result = {items = items}
            else
              return
            end
          end

          local symbols = {
            name = lsp.servers_running[name].name,
            files = lsp.servers_running[name].file_patterns,
            items = {}
          }

          local symbol_count = 1
          for _, symbol in ipairs(result.items) do
            local label = symbol.label
              or (
                symbol.textEdit
                and symbol.textEdit.newText
                or symbol.insertText
              )

            local info = server.get_completion_items_kind(symbol.kind) or ""

            local desc = symbol.detail or ""

            -- TODO: maybe we should give priority to insertText above
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
            end

            if desc ~= "" then
              desc = desc .. "\n"
            end

            if
              type(symbol.documentation) == "table"
              and
              symbol.documentation.value
            then
              desc = desc .. "\n" .. symbol.documentation.value
              if
                symbol.documentation.kind
                and
                symbol.documentation.kind == "markdown"
              then
                desc = Util.strip_markdown(desc)
              end
            elseif symbol.documentation then
              desc = desc .. "\n" .. symbol.documentation
            end

            desc = desc:gsub("[%s\n]+$", "")
              :gsub("\n\n\n+", "\n\n")

            symbols.items[label] = {
              info = info,
              desc = desc,
              data = {
                server = server, completion_item = symbol
              },
              onselect = autocomplete_onselect
            }

            if
              server.capabilities.completionProvider.resolveProvider
              and
              not symbol.documentation
            then
              symbols.items[label].onhover = autocomplete_onhover
            end

            if (symbol_count % 10) == 0 then
              coroutine.yield()
            end
            symbol_count = symbol_count + 1
          end

          if trigger_char and complete_result then
            lsp.in_trigger = true
            autocomplete.complete(symbols, function()
              lsp.in_trigger = false
            end)
          else
            autocomplete.complete(symbols)
          end
        end
      )
    end
  end
end

--- Send to applicable LSP servers a request for info about a function
--- signatures and display them on a tooltip.
function lsp.request_signature(doc, line, col, forced, fallback)
  if not doc.lsp_open then return end

  local char = doc:get_char(line, col-1)
  for _, name in pairs(lsp.get_active_servers(doc.filename, true)) do
    local server = lsp.servers_running[name]
    if
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
            autocomplete.close()
            listbox.show_text(text:gsub("[%s\n]+$", ""))
          elseif fallback then
            fallback(doc, line, col)
          end
        end
      )
      break
    elseif fallback then
      fallback(doc, line, col)
    end
  end
end

--- Sends a request to applicable LSP servers for information about the
--- symbol where the cursor is placed and shows it on a tooltip.
function lsp.request_hover(doc, line, col)
  if not doc.lsp_open then return end

  for _, name in pairs(lsp.get_active_servers(doc.filename, true)) do
    local server = lsp.servers_running[name]
    if server.capabilities.hoverProvider then
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
              listbox.show_text(text:gsub("^[\n%s]+", ""):gsub("[\n%s]+$", ""))
            end
          end
        end
      )
      break
    end
  end
end

--- Sends a request to applicable LSP servers for a symbol references
function lsp.request_references(doc, line, col)
  if not doc.lsp_open then return end

  for _, name in pairs(lsp.get_active_servers(doc.filename, true)) do
    local server = lsp.servers_running[name]
    if server.capabilities.hoverProvider then
      local request_params = get_buffer_position_params(doc, line, col)
      request_params.context = {includeDeclaration = true}
      server:push_request(
        'textDocument/references',
        request_params,
        function(server, response)
          if response.result and #response.result > 0 then
            local references, reference_names = get_references_lists(response.result)
            core.command_view:enter("Filter References",
              function(text, item)
                if item then
                  local reference = references[item.name]
                    lsp.goto_location(reference)
                end
              end,
              function(text)
                local res = common.fuzzy_match(reference_names, text)
                for i, name in ipairs(res) do
                  local reference_info = Util.split(name, "||")
                  res[i] = {
                    text = reference_info[1],
                    info = reference_info[2],
                    name = name
                  }
                end
                return res
              end
            )
          else
            log(server, "No references found.")
          end
        end
      )
      break
    end
    break
  end
end

---Sends a request to applicable LSP servers to retrieve the
---hierarchy of calls for the given function under the cursor.
function lsp.request_call_hierarchy(doc, line, col)
  if not doc.lsp_open then return end

  for _, name in pairs(lsp.get_active_servers(doc.filename, true)) do
    local server = lsp.servers_running[name]
    if server.capabilities.callHierarchyProvider then
      server:push_request(
        'textDocument/prepareCallHierarchy',
        get_buffer_position_params(doc, line, col),
        function(server, response)
          if response.result and #response.result > 0 then
            -- TODO: Finish implement call hierarchy funcitonality
          end
        end
      )
      return
    end
  end

  core.log("[LSP] Call hierarchy not supported.")
end

---Sends a request to applicable LSP servers to rename a symbol.
---@param doc Doc
---@param line integer
---@param col integer
---@param new_name string
function lsp.request_symbol_rename(doc, line, col, new_name)
  if not doc.lsp_open then return end

  local servers_found = false
  for _, name in pairs(lsp.get_active_servers(doc.filename, true)) do
    servers_found = true
    local server = lsp.servers_running[name]
    if server.capabilities.renameProvider then
      local request_params = get_buffer_position_params(doc, line, col)
      request_params.newName = new_name
      server:push_request(
        'textDocument/rename',
        request_params,
        function(server, response)
          if response.result and #response.result.changes then
            for file_uri, changes in pairs(response.result.changes) do
              core.log(file_uri .. " " .. #changes)
              -- TODO: Finish implement textDocument/rename
            end
          end
          core.log("%s", Json.prettify(Json.encode(response)))
        end
      )
      return
    end
  end

  if not servers_found then
    core.log("[LSP] " .. "No server ready or running")
  else
    core.log("[LSP] " .. "Symbols rename not supported")
  end
end

---Sends a request to applicable LSP servers to search for symbol on workspace.
---@param doc Doc
---@param symbol string
function lsp.request_workspace_symbol(doc, symbol)
  if not doc.lsp_open then return end

  for _, name in pairs(lsp.get_active_servers(doc.filename, true)) do
    local server = lsp.servers_running[name]
    if server.capabilities.workspaceSymbolProvider then
      local rs = SymbolResults(symbol)
      core.root_view:get_active_node_default():add_view(rs)
      server:push_request(
        'workspace/symbol',
        {
          query = symbol,
          -- TODO: implement status notifications but seems not supported
          -- by tested lsp servers so far.
          -- workDoneToken = "some-identifier",
          -- partialResultToken = "some-other-identifier"
        },
        function(server, response)
          if response.result and #response.result > 0 then
            for index, result in ipairs(response.result) do
              rs:add_result(result)
              if index % 20 == 0 then
                coroutine.yield()
                rs.list:resize_to_parent()
              end
            end
            rs.list:resize_to_parent()
          end
          rs:stop_searching()
        end
      )
      break
    end
    break
  end
end

--- Request a list of symbols for the given document for easy document
-- navigation and displays them using core.command_view:enter()
function lsp.request_document_symbols(doc)
  if not doc.lsp_open then return end

  local servers_found = false
  local symbols_retrieved = false
  for _, name in pairs(lsp.get_active_servers(doc.filename, true)) do
    servers_found = true
    local server = lsp.servers_running[name]
    if server.capabilities.documentSymbolProvider then
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
                    lsp.goto_location(symbol)
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

function lsp.view_document_diagnostics(doc)
  local diagnostics = Diagnostics.get(system.absolute_path(doc.filename))
  if not diagnostics or #diagnostics <= 0 then
    core.log("[LSP] %s", "No diagnostic messages found.")
    return
  end

  local diagnostic_labels = { "Error", "Warning", "Info", "Hint" }

  local indexes, captions = {}, {}
  for index, diagnostic in pairs(diagnostics) do
    local line1, col1 = Util.toselection(diagnostic.range)
    local label = diagnostic_labels[diagnostic.severity]
      .. ": " .. diagnostic.message .. " "
      .. tostring(line1) .. ":" .. tostring(col1)
    captions[index] = label
    indexes[label] = index
  end

  core.command_view:enter("Filter Diagnostics",
    function(text, item)
      if item then
        local diagnostic = diagnostics[item.index]
        local line1, col1 = Util.toselection(diagnostic.range)
        doc:set_selection(line1, col1, line1, col1)
      end
    end,
    function(text)
      local res = common.fuzzy_match(captions, text)
      for i, name in ipairs(res) do
        local diagnostic = diagnostics[indexes[name]]
        local line1, col1 = Util.toselection(diagnostic.range)
        res[i] = {
          text = diagnostic_kinds[diagnostic.severity]
            .. ": " .. diagnostic.message,
          info = tostring(line1) .. ":" .. tostring(col1),
          index = indexes[name]
        }
      end
      return res
    end
  )
end

function lsp.view_all_diagnostics()
  if Diagnostics.count <= 0 then
    core.log("[LSP] %s", "No diagnostic messages found.")
    return
  end

  local captions = {}
  for name, _ in pairs(Diagnostics.list) do
    table.insert(captions, core.normalize_to_project_dir(name))
  end

  core.command_view:enter("Filter Files",
    function(text, item)
      if item then
        core.root_view:open_doc(
          core.open_doc(
            common.home_expand(
              text
            )
          )
        )
      end
    end,
    function(text)
      local res = common.fuzzy_match(captions, text, true)
      for i, name in ipairs(res) do
        local diagnostics = Diagnostics.get_messages_count(
          system.absolute_path(name)
        )
        res[i] = {
          text = name,
          info = "Messages: " .. diagnostics
        }
      end
      return res
    end
  )
end

--- Jumps to the definition or implementation of the symbol where the cursor
-- is placed if the LSP server supports it
function lsp.goto_symbol(doc, line, col, implementation)
  if not doc.lsp_open then return end

  for _, name in pairs(lsp.get_active_servers(doc.filename, true)) do
    local server = lsp.servers_running[name]

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

    -- Send document updates first
    lsp.update_document(doc)

    server:push_request(
      "textDocument/" .. method,
      get_buffer_position_params(doc, line, col),
      function(server, response)
        local location = response.result

        if not location or not location.uri and #location == 0 then
          log(server, "No %s found", method)
          return
        end

        if not location.uri and #location > 1 then
          listbox.clear()
          for _, loc in pairs(location) do
            local preview, position = get_location_preview(loc)
            listbox.append {
              text = preview,
              info = position,
              location = loc
            }
          end
          listbox.show_list(nil, function(doc, item)
            lsp.goto_location(item.location)
          end)
        else
          if not location.uri then
            location = location[1]
          end
          lsp.goto_location(location)
        end
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
    local servers_running = false
    for _,server in pairs(lsp.servers_running) do
      -- Send raw data to server which is usually big and slow in a
      -- non blocking way by creating a coroutine just for it.
      if #server.raw_list > 0 then
        local raw_send = coroutine.create(function()
          server:process_raw()
        end)
        coroutine.resume(raw_send)
        while coroutine.status(raw_send) ~= "dead" do
          server:process_errors(config.plugins.lsp.log_server_stderr)
          server:process_responses()
          server:process_client_responses()
          coroutine.yield(0)
          coroutine.resume(raw_send)
        end
      end

      -- less yielding for lowerfps setups
      if config.fps <= 30 then
        server:process_notifications()
        server:process_requests()
        server:process_responses()
        server:process_client_responses()
      else
        server:process_notifications()
        coroutine.yield()
        server:process_requests()
        coroutine.yield()
        server:process_responses()
        server:process_client_responses()
        coroutine.yield()
      end

      server:process_errors(config.plugins.lsp.log_server_stderr)

      servers_running = true
    end

    if servers_running then
      coroutine.yield(0.01)
    else
      coroutine.yield(2)
    end
  end
end)

--
-- Events patching
--
local doc_load = Doc.load
local doc_save = Doc.save
local doc_undo = Doc.undo
local doc_redo = Doc.redo
local doc_on_close = Doc.on_close
local doc_raw_insert = Doc.raw_insert
local doc_raw_remove = Doc.raw_remove
local root_view_on_text_input = RootView.on_text_input
local status_view_get_items = StatusView.get_items

function Doc:load(...)
  local res = doc_load(self, ...)
  -- skip new files
  if self.filename then
    if lintplus then
      lintplus.init_doc(self.filename, self)
    end
    core.add_thread(function()
      lsp.open_document(self)
    end)
  end
  return res
end

function Doc:save(...)
  local old_filename = self.filename
  local res = doc_save(self, ...)
  if old_filename ~= self.filename then
    -- seems to be a new document so we send open notification
    if lintplus then
      lintplus.init_doc(self.filename, self)
    end
    core.add_thread(function()
      lsp.open_document(self)
    end)
  else
    core.add_thread(function()
      lsp.update_document(self)
      lsp.save_document(self)
    end)
  end
  return res
end

function Doc:undo(...)
  doc_undo(self, ...)

  -- skip new files
  if not self.filename then return end

  local av = get_active_view()
  if av and av.doc then
    -- Send update to lsp servers
    lsp.update_document(av.doc)
  end
end

function Doc:redo(...)
  doc_redo(self, ...)

  -- skip new files
  if not self.filename then return end

  local av = get_active_view()
  if av then
    -- Send update to lsp servers
    lsp.update_document(av.doc)
  end
end

function Doc:on_close()
  doc_on_close(self)

  -- skip new files
  if not self.filename then return end
  core.add_thread(function()
    lsp.close_document(self)
  end)

  if not config.plugins.lsp.stop_unneeded_servers then
    return
  end

  -- Check if any running lsp servers is not needed anymore and stop it
  for name, server in pairs(lsp.servers_running) do
    local doc_found = false
    for _, docu in ipairs(core.docs) do
      if docu.filename then
        if common.match_pattern(docu.filename, server.file_patterns) then
          doc_found = true
          break
        end
      end
    end

    if not doc_found then
      server:exit()
      core.log("[LSP] stopped %s", name)
      lsp.servers_running = Util.table_remove_key(lsp.servers_running, name)
    end
  end
end

local function add_change(self, text, line1, col1, line2, col2)
  if not self.lsp_changes then
    self.lsp_changes = {}
    self.lsp_version = 0
  end

  local change = { range = {}, text = text}
  change.range["start"] = {line = line1-1, character = col1-1}
  change.range["end"] = {line = line2-1, character = col2-1}

  table.insert(self.lsp_changes, change)

  -- TODO: this should not be needed but changing documents rapidly causes this
  if type(self.lsp_version) ~= 'nil' then
    self.lsp_version = self.lsp_version + 1
  else
    self.lsp_version = 1
  end
end

function Doc:raw_insert(line, col, text, undo_stack, time)
  doc_raw_insert(self, line, col, text, undo_stack, time)

  -- skip new files
  if not self.filename then return end

  add_change(self, text, line, col, line, col)
end

function Doc:raw_remove(line1, col1, line2, col2, undo_stack, time)
  doc_raw_remove(self, line1, col1, line2, col2, undo_stack, time)

  -- skip new files
  if not self.filename then return end

  add_change(self, "", line1, col1, line2, col2)
end

function RootView:on_text_input(...)
  root_view_on_text_input(self, ...)

  local av = get_active_view()

  if av and av.doc and av.doc.filename then
    local line1, col1, line2, col2 = av.doc:get_selection()

    -- Send update to lsp servers
    lsp.update_document(av.doc)

    if line1 == line2 and col1 == col2 then
      -- First try to display a function signatures and if not possible
      -- do normal code autocomplete
      lsp.request_signature(
        av.doc,
        line1,
        col1,
        false,
        lsp.request_completion
      )
    end
  end
end

function StatusView:get_items()
  local left, right = status_view_get_items(self)

  local av = get_active_view()
  if av and av.doc and av.doc.filename then
    local filename = system.absolute_path(av.doc.filename)
    local diagnostics = Diagnostics.get(filename)

    if diagnostics and #diagnostics > 0 then
      local t = {
        style.syntax["string"],
        style.icon_font, "!",
        style.font, " " .. tostring(#diagnostics),
        style.dim,
        self.separator2,
      }
      for i, item in ipairs(t) do
        table.insert(right, i, item)
      end
    end
  end
  return left, right
end

--
-- Commands
--
command.add("core.docview", {
  ["lsp:complete"] = function()
    local av = core.active_view
    if av and av.doc and av.doc.filename then
      local doc = core.active_view.doc
      local line1, col1, line2, col2 = doc:get_selection()
      if line1 == line2 and col1 == col2 then
        lsp.request_completion(doc, line1, col1, true)
      end
    end
  end,

  ["lsp:goto-definition"] = function()
    local av = core.active_view
    if av and av.doc and av.doc.filename then
      local doc = core.active_view.doc
      local line1, col1, line2 = doc:get_selection()
      if line1 == line2 then
        lsp.goto_symbol(doc, line1, col1)
      end
    end
  end,

  ["lsp:goto-implementation"] = function()
    local av = core.active_view
    if av and av.doc and av.doc.filename then
      local doc = core.active_view.doc
      local line1, col1, line2 = doc:get_selection()
      if line1 == line2 then
        lsp.goto_symbol(doc, line1, col1, true)
      end
    end
  end,

  ["lsp:show-signature"] = function()
    local av = core.active_view
    if av and av.doc and av.doc.filename then
      local doc = core.active_view.doc
      local line1, col1, line2, col2 = doc:get_selection()
      if line1 == line2 and col1 == col2 then
        lsp.request_signature(doc, line1, col1, true)
      end
    end
  end,

  ["lsp:show-symbol-info"] = function()
    local av = core.active_view
    if av and av.doc and av.doc.filename then
      local doc = core.active_view.doc
      local line1, col1, line2 = doc:get_selection()
      if line1 == line2 then
        lsp.request_hover(doc, line1, col1)
      end
    end
  end,

  ["lsp:view-call-hierarchy"] = function()
    local av = core.active_view
    if av and av.doc and av.doc.filename then
      local doc = core.active_view.doc
      local line1, col1, line2 = doc:get_selection()
      if line1 == line2 then
        lsp.request_call_hierarchy(doc, line1, col1)
      end
    end
  end,

  ["lsp:view-document-symbols"] = function()
    if core.active_view and core.active_view.doc then
      local doc = core.active_view.doc
      if doc and doc.filename then
        lsp.request_document_symbols(doc)
      end
    end
  end,

  ["lsp:view-document-diagnostics"] = function()
    if core.active_view and core.active_view.doc then
      local doc = core.active_view.doc
      if doc and doc.filename then
        lsp.view_document_diagnostics(doc)
      end
    end
  end,

  ["lsp:view-all-diagnostics"] = function()
    if core.active_view and core.active_view.doc then
        lsp.view_all_diagnostics()
    end
  end,

  ["lsp:rename-symbol"] = function()
    local doc = nil
    local symbol = ""
    if core.active_view and core.active_view.doc then
      doc = core.active_view.doc
      symbol = core.active_view.doc:get_text(core.active_view.doc:get_selection())
    else
      return
    end
    local line1, col1, line2 = doc:get_selection()
    if #symbol > 0 and line1 == line2 then
      core.command_view:set_text(symbol)
      core.command_view:enter("New Symbol Name", function(new_name)
        lsp.request_symbol_rename(doc, line1, col1, new_name)
      end, nil)
    else
      core.log("Please select a symbol on the document to rename.")
    end
  end,

  ["lsp:find-workspace-symbol"] = function()
    local doc = nil
    local symbol = ""
    if core.active_view and core.active_view.doc then
      doc = core.active_view.doc
      symbol = core.active_view.doc:get_text(core.active_view.doc:get_selection())
    else
      return
    end
    core.command_view:set_text(symbol)
    core.command_view:enter("Find Workspace Symbol", function(query)
      lsp.request_workspace_symbol(doc, query)
    end, nil)
  end,

  ["lsp:find-references"] = function()
    local doc = core.active_view.doc
    if doc then
      local line1, col1, line2 = doc:get_selection()
      if line1 == line2 then
        lsp.request_references(doc, line1, col1)
      end
    end
  end,

  ["lsp:toggle-diagnostics"] = function()
    if type(lintplus) == "nil" then
      core.error("[LSP] Please install lintplus for diagnostics rendering.")
      return
    end
    lsp.toggle_diagnostics()
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
  ["alt+s"]             = "lsp:view-document-symbols",
  ["alt+shift+s"]       = "lsp:find-workspace-symbol",
  ["alt+f"]             = "lsp:find-references",
  ["alt+e"]             = "lsp:view-document-diagnostics",
  ["ctrl+alt+e"]        = "lsp:view-all-diagnostics",
  ["alt+shift+e"]       = "lsp:toggle-diagnostics",
  ["alt+c"]             = "lsp:view-call-hierarchy",
  ["alt+r"]             = "lsp:rename-symbol",
}

--
-- Register context menu items
--
local function lsp_predicate(_, _, also_in_symbol)
  if
    get_active_view()
    and
    core.active_view.doc
    and
    core.active_view.doc.filename
  then
    local doc = core.active_view.doc

    if #lsp.get_active_servers(doc.filename, true) < 1 then
      return false
    elseif not also_in_symbol then
      return true
    end

    -- Make sure the cursor is place near a document symbol (word)
    local linem, colm = doc:get_selection()
    local linel, coll = doc:position_offset(linem, colm, translate.start_of_word)
    local liner, colr = doc:position_offset(linem, colm, translate.end_of_word)

    local word_left = doc:get_text(linel, coll, linem, colm)
    local word_right = doc:get_text(linem, colm, liner, colr)

    if #word_left > 0 or #word_right > 0 then
      return true
    end
  end
  return false
end

local function lsp_predicate_symbols()
  return lsp_predicate(nil, nil, true)
end

local found, menu = pcall(require, "plugins.contextmenu")
if found then
  menu:register(lsp_predicate_symbols, {
    menu.DIVIDER,
    { text = "Show Symbol Info",       command = "lsp:show-symbol-info" },
    { text = "Goto Definition",        command = "lsp:goto-definition" },
    { text = "Goto Implementation",    command = "lsp:goto-implementation" },
    { text = "Find References",        command = "lsp:find-references" }
  })

  menu:register(lsp_predicate, {
    menu.DIVIDER,
    { text = "Document Symbols",       command = "lsp:view-document-symbols" },
    { text = "Document Diagnostics",   command = "lsp:view-document-diagnostics" },
    { text = "Toggle Diagnostics",     command = "lsp:toggle-diagnostics" }
  })
end

return lsp
