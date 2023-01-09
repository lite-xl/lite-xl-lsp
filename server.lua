-- Class in charge of establishing communication with an LSP server and
-- managing requests, notifications and responses from both the server
-- and the client that is establishing the connection.
--
-- @copyright Jefferson Gonzalez
-- @license MIT
-- @inspiration: https://github.com/orbitalquark/textadept-lsp
--
-- LSP Documentation:
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-17

local json = require "plugins.lsp.json"
local util = require "plugins.lsp.util"
local Object = require "core.object"

---@alias lsp.server.callback fun(server: lsp.server, ...)
---@alias lsp.server.notificationcb fun(server: lsp.server, params: table)
---@alias lsp.server.responsecb fun(server: lsp.server, response: table, request?: lsp.server.request)

---@class lsp.server.request
---@field id integer
---@field method string
---@field data table|nil
---@field params table
---@field callback lsp.server.responsecb | nil
---@field overwritten boolean
---@field overwritten_callback lsp.server.responsecb | nil
---@field sending boolean
---@field raw_data string
---@field timestamp number
---@field times_sent integer

---LSP Server communication library.
---@class lsp.server : core.object
---@field public name string
---@field public language string
---@field public file_patterns table
---@field public current_request integer
---@field public init_options table
---@field public settings table | nil
---@field public event_listeners table
---@field public message_listeners table
---@field public request_listeners table
---@field public request_list lsp.server.request[]
---@field public response_list table
---@field public notification_list lsp.server.request[]
---@field public raw_list lsp.server.request[]
---@field public command table
---@field public write_fails integer
---@field public write_fails_before_shutdown integer
---@field public verbose boolean
---@field public initialized boolean
---@field public hitrate_list table
---@field public requests_per_second integer
---@field public requests_in_chunks boolean
---@field public proc process | nil
---@field public capabilities table
---@field public yield_on_reads boolean
---@field public running boolean
local Server = Object:extend()

---LSP Server constructor options
---@class lsp.server.options
---@field name string
---@field language string
---@field file_patterns table<integer, string>
---@field command table<integer, string>
---@field settings table
---@field init_options table
---@field requests_per_second number
---@field requests_in_chunks boolean
---@field incremental_changes boolean
---@field id_not_extension boolean
Server.options = {
  ---Name of the server
  name = "",
  ---Programming language identifier
  language = "",
  ---Patterns to match the language files
  file_patterns = {},
  ---Command to launch LSP server and optional arguments
  command = {},
  ---Optional table of settings to pass into the lsp
  ---Note that also having a settings.json or settings.lua in
  ---your workspace directory is supported
  settings = {},
  ---Optional table of initializationOptions for the LSP
  init_options = {},
  ---Set by default to 16 should only be modified if having issues with a server
  requests_per_second = 32,
  ---By default each request is written to the server stdin in chunks of
  ---10KB, if this gives issues set to false to write everything at once.
  requests_in_chunks = true,
  ---Some servers like bash language server support incremental changes
  ---which are more performant but don't advertise it, set to true to force
  ---incremental changes even if server doesn't advertise them.
  incremental_changes = false,
  ---True to debug the lsp client when developing it
  verbose = false,
  ---
  id_not_extension = false
}

---Default timeout when sending a request to lsp server.
---@type integer Time in seconds
Server.DEFAULT_TIMEOUT = 10

---The maximum amount of data to retrieve when reading from server.
---@type integer Amount of bytes
Server.BUFFER_SIZE = 1024 * 10

---LSP Docs: /#errorCodes
Server.error_code = {
  ParseError                      = -32700,
  InvalidRequest                  = -32600,
  MethodNotFound                  = -32601,
  InvalidParams                   = -32602,
  InternalError                   = -32603,
  jsonrpcReservedErrorRangeStart  = -32099,
  serverErrorStart                = -32099,
  ServerNotInitialized            = -32002,
  UnknownErrorCode                = -32001,
  jsonrpcReservedErrorRangeEnd    = -32000,
  serverErrorEnd                  = -32000,
  lspReservedErrorRangeStart      = -32899,
  ContentModified                 = -32801,
  RequestCancelled                = -32800,
  lspReservedErrorRangeEnd        = -32800,
}

---LSP Docs: /#completionTriggerKind
Server.completion_trigger_Kind = {
  Invoked = 1,
  TriggerCharacter = 2,
  TriggerForIncompleteCompletions = 3
}

---LSP Docs: /#diagnosticSeverity
Server.diagnostic_severity = {
  Error = 1,
  Warning = 2,
  Information = 3,
  Hint = 4
}

---LSP Docs: /#textDocumentSyncKind
Server.text_document_sync_kind = {
  None = 0,
  Full = 1,
  Incremental = 2
}

---LSP Docs: /#completionItemKind
Server.completion_item_kind = {
  'Text', 'Method', 'Function', 'Constructor', 'Field', 'Variable', 'Class',
  'Interface', 'Module', 'Property', 'Unit', 'Value', 'Enum', 'Keyword',
  'Snippet', 'Color', 'File', 'Reference', 'Folder', 'EnumMember',
  'Constant', 'Struct', 'Event', 'Operator', 'TypeParameter'
}

---LSP Docs: /#symbolKind
Server.symbol_kind = {
  'File', 'Module', 'Namespace', 'Package', 'Class', 'Method', 'Property',
  'Field', 'Constructor', 'Enum', 'Interface', 'Function', 'Variable',
  'Constant', 'String', 'Number', 'Boolean', 'Array', 'Object', 'Key',
  'Null', 'EnumMember', 'Struct', 'Event', 'Operator', 'TypeParameter'
}

---LSP Docs: /#messageType
---@enum
Server.message_type = {
	Error = 1,
	Warning = 2,
	Info = 3,
	Log = 4
}

---@class lsp.server.requestoptions
---@field params table<string,any>
---@field data table @Optional data appended to request.
---@field callback lsp.server.responsecb @Default callback executed when a response is received.
---@field overwrite boolean @Substitute same previous request with new one if not sent.
---@field overwritten_callback lsp.server.responsecb @Executed in place of original response callback if the request should have been overwritten but was already sent.
---@field raw_data string @Request body used when sending a raw request.

---Get a completion kind label from its id or empty string if not found.
---@param id integer
---@return string
function Server.get_completion_item_kind(id)
  return Server.completion_item_kind[id] or ""
end

---Get list of completion kinds.
---@return table
function Server.get_completion_items_kind_list()
  local list = {}
  for i = 1, #Server.completion_item_kind do
    if i ~= 15 then --Disable snippets
      table.insert(list, i)
    end
  end

  return list
end

---Get a symbol kind label from its id or empty string if not found.
---@param id integer
---@return string
function Server.get_symbol_kind(id)
  return Server.symbol_kind[id] or ""
end

---Get list of symbol kinds.
---@return table
function Server.get_symbols_kind_list()
  local list = {}
  for i = 1, #Server.symbol_kind do
    list[i] = i
  end

  return list
end

---Instantiates a new LSP server.
---@param options table
function Server:new(options)
  Server.super.new(self)

  self.name = options.name
  self.language = options.language
  self.id_not_extension = options.id_not_extension or false
  self.file_patterns = options.file_patterns
  self.current_request = 0
  self.init_options = options.init_options or {}
  self.settings = options.settings or nil
  self.event_listeners = {}
  self.message_listeners = {}
  self.request_listeners = {}
  self.request_list = {}
  self.response_list = {}
  self.notification_list = {}
  self.raw_list = {}
  self.command = options.command
  self.write_fails = 0
  self.fake_snippets = options.fake_snippets or false
  -- TODO: We may need to lower this but tests so far show that some servers
  -- may actually fail to write many of the request sent to it if it is
  -- indexing the workspace source code or other heavy tasks.
  self.write_fails_before_shutdown = 60
  self.verbose = options.verbose or false
  self.last_restart = system.get_time()
  self.initialized = false
  self.hitrate_list = {}
  self.requests_per_second = options.requests_per_second or 16
  self.requests_in_chunks = type(options.requests_in_chunks) == "nil" and
    true or options.requests_in_chunks

  self.proc = process.start(
    options.command, {
      stderr = process.REDIRECT_PIPE
    }
  )
  self.capabilities = nil
  self.yield_on_reads = false
  self.incremental_changes = options.incremental_changes or false
end

---Starts the LSP server process, any listeners should be registered before
---calling this method and this method should be called before any pushes.
---@param workspace string
---@param editor_name? string
---@param editor_version? string
function Server:initialize(workspace, editor_name, editor_version)
  local root_uri = util.touri(workspace);

  self.running = false
  self.path = workspace or ""
  self.editor_name = editor_name or "unknown"
  self.editor_version = editor_version or "0.1"

  self:push_request('initialize', {
    params = {
      processId = system["get_process_id"] and system.get_process_id() or nil,
      clientInfo = {
        name = editor_name or "unknown",
        version = editor_version or "0.1"
      },
      -- TODO: locale
      rootPath = workspace,
      rootUri = root_uri,
      workspaceFolders = {
        {uri = root_uri, name = util.getpathname(workspace)}
      },
      initializationOptions = self.init_options,
      capabilities = {
        workspace = {
          configuration = true -- 'workspace/configuration' requests
        },
        textDocument = {
          synchronization = {
            -- willSave = true,
            -- willSaveWaitUntil = true,
            didSave = true,
            -- dynamicRegistration = false -- not supported
          },
          completion = {
            -- dynamicRegistration = false, -- not supported
            completionItem = {
              -- Snippets are required by css-languageserver
              snippetSupport = self.fake_snippets, -- ${1:foo} format not supported
              -- commitCharactersSupport = true,
              documentationFormat = {'plaintext'},
              -- deprecatedSupport = false, -- simple autocompletion list
              -- preselectSupport = true
              -- tagSupport = {valueSet = {}},
              insertReplaceSupport = true,
              resolveSupport = {properties = {'documentation', 'detail'}},
              -- insertTextModeSupport = {valueSet = {}}
            },
            completionItemKind = {
              valueSet = Server.get_completion_items_kind_list()
            }
            -- contextSupport = true
          },
          hover = {
            -- dynamicRegistration = false, -- not supported
            contentFormat = {'markdown', 'plaintext'}
          },
          signatureHelp = {
            -- dynamicRegistration = false, -- not supported
            signatureInformation = {
              documentationFormat = {'plaintext'}
              -- parameterInformation = {labelOffsetSupport = true},
              -- activeParameterSupport = true
            }
            -- contextSupport = true
          },
          -- references = {dynamicRegistration = false}, -- not supported
          -- documentHighlight = {dynamicRegistration = false}, -- not supported
          documentSymbol = {
            -- dynamicRegistration = false, -- not supported
            symbolKind = {valueSet = Server.get_symbols_kind_list()}
            -- hierarchicalDocumentSymbolSupport = true,
            -- tagSupport = {valueSet = {}},
            -- labelSupport = true
          },
          -- diagnostic = {
          --   dynamicRegistration = true,
          --   relatedDocumentSupport = false
          -- },
          -- formatting = {dynamicRegistration = false},-- not supported
          -- rangeFormatting = {dynamicRegistration = false}, -- not supported
          -- onTypeFormatting = {dynamicRegistration = false}, -- not supported
          -- declaration = {
          --  dynamicRegistration = false, -- not supported
          --  linkSupport = true
          -- }
          -- definition = {
          --  dynamicRegistration = false, -- not supported
          --  linkSupport = true
          -- },
          -- typeDefinition = {
          --  dynamicRegistration = false, -- not supported
          --  linkSupport = true
          -- },
          -- implementation = {
          --  dynamicRegistration = false, -- not supported
          --  linkSupport = true
          -- },
          -- codeAction = {
          --  dynamicRegistration = false, -- not supported
          --  codeActionLiteralSupport = {valueSet = {}},
          --  isPreferredSupport = true,
          --  disabledSupport = true,
          --  dataSupport = true,
          --  resolveSupport = {properties = {}},
          --  honorsChangeAnnotations = true
          -- },
          -- codeLens = {dynamicRegistration = false}, -- not supported
          -- documentLink = {
          --  dynamicRegistration = false, -- not supported
          --  tooltipSupport = true
          -- },
          -- colorProvider = {dynamicRegistration = false}, -- not supported
          -- rename = {
          --  dynamicRegistration = false, -- not supported
          --  prepareSupport = false
          -- },
          -- publishDiagnostics = {
          -- relatedInformation = true,
          --  tagSupport = {valueSet = {}},
          --  versionSupport = true,
          --  codeDescriptionSupport = true,
          --  dataSupport = true
          -- },
          -- foldingRange = {
          --  dynamicRegistration = false, -- not supported
          --  rangeLimit = ?,
          --  lineFoldingOnly = true
          -- },
          -- selectionRange = {dynamicRegistration = false}, -- not supported
          -- linkedEditingRange = {dynamicRegistration = false}, -- not supported
          -- callHierarchy = {dynamicRegistration = false}, -- not supported
          -- semanticTokens = {
          --  dynamicRegistration = false, -- not supported
          --  requests = {},
          --  tokenTypes = {},
          --  tokenModifiers = {},
          --  formats = {},
          --  overlappingTokenSupport = true,
          --  multilineTokenSupport = true
          -- },
          -- moniker = {dynamicRegistration = false} -- not supported
        },
        window = {
         -- workDoneProgress = true,
         -- showMessage = {},
         showDocument = { support = true }
        },
        -- general = {
        --  regularExpressions = {},
        --  markdown = {}
        -- },
        -- experimental = nil
      }
    },
    callback = function(server, response)
      if server.verbose then
        server:log(
          "Processing initialization response:\n%s",
          util.jsonprettify(json.encode(response))
        )
      end
      local result = response.result
      if result then
        server.capabilities = result.capabilities
        server.info = result.serverInfo

        if server.info then
          server:log(
            'Connected to %s %s',
            server.info.name,
            server.info.version or '(unknown version)'
          )
        end

        server:notify('initialized') -- required by protocol

        -- We wait a few seconds to prevent initialization issues
        coroutine.yield(3)
        server.initialized = true;
        server:send_event_signal("initialized", server, result)
      end
    end
  })
end

---Register an event listener.
---@param event_name string
---@param callback lsp.server.callback
function Server:add_event_listener(event_name, callback)
  if self.verbose then
    self:log(
      "Listening for event '%s'",
      event_name
    )
  end

  self.event_listeners[event_name] = callback
end

function Server:send_event_signal(event_name, ...)
  if self.event_listeners[event_name] then
    self.event_listeners[event_name](self, ...)
  else
    self:on_event(event_name)
  end
end

function Server:on_event(event_name)
  if self.verbose then
    self:log("Received event '%s'", event_name)
  end
end

---Send a message to the server that doesn't needs a response.
---@param method string
---@param params? table
function Server:notify(method, params)
  local message = {
    jsonrpc = '2.0',
    method = method,
    params = params or {}
  }

  local data = json.encode(message)

  if self.verbose then
    self:log("Sending notification:\n%s", util.jsonprettify(data))
  end

  local written = self:write_request(data)

  if not written and self.verbose then
    self:log("Could not send notification.")
  end
end

---Reply to a server request.
---@param id integer
---@param result table
function Server:respond(id, result)
  local message = {
    jsonrpc = '2.0',
    id = id,
    result = result
  }

  local data = json.encode(message)

  if self.verbose then
    self:log("Responding to '%d':\n%s", id, util.jsonprettify(data))
  end

  local written = self:write_request(data)

  if not written and self.verbose then
    self:log("Could not send response.")
  end
end

---Respond to a an unknown server request with a method not found error code.
---@param id integer
---@param error_message string
---@param error_code integer
function Server:respond_error(id, error_message, error_code)
  local message = {
    jsonrpc = '2.0',
    id = id,
    error = {
      code = error_code or Server.error_code.MethodNotFound,
      message = error_message
    }
  }

  local data = json.encode(message)

  if self.verbose then
    self:log("Responding error to '%d':\n%s", id, util.jsonprettify(data))
  end

  local written = self:write_request(data)

  if not written and self.verbose then
    self:log("Could not send response.")
  end
end

---Sends one of the queued notifications.
function Server:process_notifications()
  if not self.initialized then return end

  for index, request in ipairs(self.notification_list) do
    local message = {
      jsonrpc = '2.0',
      method = request.method,
      params = request.params or {}
    }

    local data = json.encode(message)

    if self.verbose then
        self:log(
          "Sending notification '%s':\n%s",
          request.method,
          util.jsonprettify(data)
        )
    end

    local written = self:write_request(data, 0)

    if self.verbose then
      if not written or written < 0 then
        self:log(
          "Failed sending notification '%s'",
          request.method
        )
      end
    end

    if written and written > 0 then
      if request.callback then
        request.callback(self)
      end
      table.remove(self.notification_list, index)
      self.write_fails = 0
      return request
    else
      self:shutdown_if_needed()
      return
    end
  end
end

---Sends one of the queued client requests.
function Server:process_requests()
  local remove_request = nil
  for index, request in ipairs(self.request_list) do
    if request.timestamp < os.time() then
      -- only process when initialized or the initialize request
      -- which should be the first one.
      if not self.initialized and request.id ~= 1 then
        return nil
      end

      local message = {
        jsonrpc = '2.0',
        id = request.id,
        method = request.method,
        params = request.params or {}
      }

      local data = json.encode(message)

      local written = self:write_request(data, 0)

      if self.verbose then
        if written and written > 0 then
          self:log(
            "Sent request '%s':\n%s",
            request.method,
            util.jsonprettify(data)
          )
        else
          self:log(
            "Failed sending request '%s':\n%s",
            request.method,
            util.jsonprettify(data)
          )
        end
      end

      if written and written > 0 then
        local time = 1
        if request.id == 1 then
          time = 10 -- give initialize enough time to respond
        end
        request.timestamp = os.time() + time

        self.write_fails = 0

        -- if request has been sent more than 2 times remove them
        request.times_sent = request.times_sent + 1
        if
          request.times_sent > 1
          and
          request.id ~= 1 -- Initialize request may take some time
        then
          remove_request = index
          break
        else
          return request
        end
      else
        request.timestamp = os.time() + 1
        self:shutdown_if_needed()
        return nil
      end
    end
  end

  if remove_request then
    table.remove(self.request_list, remove_request)
    if self.verbose then
      self:log("Request '%s' expired without response", remove_request)
    end
  end

  return nil
end

---Read the lsp server stdout, parse any responses, requests or
---notifications and properly dispatch signals to any listeners.
function Server:process_responses()
  local responses = self:read_responses(0)

  if type(responses) == "table" then
    for _, response in pairs(responses) do
      if self.verbose then
        self:log(
          "Processing Response:\n%s",
          util.jsonprettify(json.encode(response))
        )
      end
      if not response.id then
        -- A notification, event or generic message was received
        self:send_message_signal(response)
      elseif
        response.result
        or
        (not response.params and not response.method)
      then
        -- An actual request response was received
        self:send_response_signal(response)
      else
        -- The server is making a request
        self:send_request_signal(response)
      end
    end
  end

  return responses
end

---Sends all queued client responses to server.
function Server:process_client_responses()
  if not self.initialized then return end

  ::send_responses::
  for index, response in ipairs(self.response_list) do
    local message = {
      jsonrpc = '2.0',
      id = response.id
    }

    if response.result then
      message.result = response.result
    else
      message.error = response.error
    end

    local data = json.encode(message)

    if self.verbose then
        self:log("Sending client response:\n%s", util.jsonprettify(data))
    end

    local written = self:write_request(data, 0)

    if self.verbose then
      if not written or written < 0 then
        self:log(
          "Failed sending client response '%s'",
          response.id
        )
      end
    end

    if written and written > 0 then
      self.write_fails = 0
      table.remove(self.response_list, index)
      -- restart loop after removing from table to prevent issues
      goto send_responses
    else
      self:shutdown_if_needed()
      return
    end
  end
end

---Should be called periodically to prevent the server from stalling
---because of not flushing the stderr (especially true of clangd).
---@param log_errors boolean
function Server:process_errors(log_errors)
  local errors = self:read_errors(0)

  if #errors > 0 and log_errors then
    self:log("Error: \n'%s'", errors)
  end

  return errors
end

---Send one of the queued chunks of raw data to lsp server which are
---usually huge, like the textDocument/didOpen notification.
function Server:process_raw()
  if not self.initialized then return end

  -- Wait until everything else is processed to prevent initialization issues
  if
    #self.notification_list > 0
    or
    #self.request_list > 0
    or
    #self.response_list > 0
  then
    return
  end

  if not self.proc:running() then
    self.raw_list = {}
    return
  end

  local sent = false
  for index, raw in ipairs(self.raw_list) do
    raw.sending = true
    local written = 0
    -- first send the header
    while written <= 0 do
      written = self.proc:write(string.format(
        'Content-Length: %d\r\n\r\n',
        #raw.raw_data + 2 -- last \r\n
      ))
    end

    if self.verbose then
      self:log("Raw header written")
    end

    -- send content in chunks
    local chunks = 10 * 1024
    raw.raw_data = raw.raw_data .. "\r\n"

    while #raw.raw_data > 0 do
      local wrote = 0

      if #raw.raw_data > chunks then
        while wrote <= 0 do
          wrote = self.proc:write(raw.raw_data:sub(1, chunks))
        end
        raw.raw_data = raw.raw_data:sub(chunks+1)
      else
        while wrote <= 0 do
          wrote = self.proc:write(raw.raw_data)
        end
        raw.raw_data = ""
      end

      self.write_fails = 0

      coroutine.yield()
    end

    if self.verbose then
      self:log("Raw content written")
    end

    if raw.callback then
      raw.callback(self, raw)
    end

    table.remove(self.raw_list, index)
    sent = true
    break
  end
  if sent then collectgarbage("collect") end
end

---Help controls the amount of requests sent to the lsp server per second
---which prevents overloading it and causing a pipe hang.
---@param type string
---@return boolean true if max hitrate was reached
function Server:hitrate_reached(type)
  if not self.hitrate_list[type] then
    self.hitrate_list[type] = {
      count = 1,
      timestamp = os.time() + 1
    }
  elseif self.hitrate_list[type].timestamp > os.time() then
    if self.hitrate_list[type].count >= self.requests_per_second then
      return true
    end
    self.hitrate_list[type].count = self.hitrate_list[type].count + 1
  else
    self.hitrate_list[type].timestamp = os.time() + 1
    self.hitrate_list[type].count = 1
  end
  return false
end

---Check if it is possible to queue a new request of any kind except
---raw ones. This is useful to delay a request and not loose it in case
---the lsp reached maximum amount of hit rate per second.
function Server:can_push()
  local type = "request"
  if not self.hitrate_list[type] then
    return self.initialized
  elseif self.hitrate_list[type].timestamp > os.time() then
    if self.hitrate_list[type].count >= self.requests_per_second then
      return false
    end
  end
  return self.initialized
end

-- Notifications that should bypass the hitrate limit
local notifications_whitelist = {
  "textDocument/didOpen",
  "textDocument/didSave",
  "textDocument/didClose"
}

---Queue a new notification but ignores new ones if the hit rate was reached.
---@param method string
---@param options lsp.server.requestoptions
function Server:push_notification(method, options)
  assert(options.params, "please provide the parameters for the notification")

  if options.overwrite then
    for _, notification in ipairs(self.notification_list) do
      if notification.method == method then
        if self.verbose then
          self:log("Overwriting notification %s", tostring(method))
        end
        notification.params = options.params
        notification.callback = options.callback or nil
        notification.data = options.data or nil
        return
      end
    end
  end

  if
    method ~= "textDocument/didOpen"
    and
    self:hitrate_reached("request")
    and
    not util.intable(method, notifications_whitelist)
  then
    return
  end

  if self.verbose then
    self:log(
      "Pushing notification '%s':\n%s",
      method,
      util.jsonprettify(json.encode(options.params))
    )
  end

  -- Store the notification for later processing on responses_loop
  table.insert(self.notification_list, {
    method = method,
    params = options.params,
    callback = options.callback or nil,
    data = options.data or nil
  })
end

-- Requests that should bypass the hitrate limit
local requests_whitelist = {
  "completionItem/resolve"
}

---Queue a new request but ignores new ones if the hit rate was reached.
---@param method string
---@param options lsp.server.requestoptions
function Server:push_request(method, options)
  if not self.initialized and method ~= "initialize" then
    return
  end

  assert(options.params, "please provide the parameters for the request")

  if options.overwrite then
    for _, request in ipairs(self.request_list) do
      if request.method == method then
        if request.times_sent > 0 then
          request.overwritten = true
          break
        else
          request.params = options.params
          request.callback = options.callback or nil
          request.overwritten_callback = options.overwritten_callback or nil
          request.data = options.data or nil
          request.timestamp = 0
          if self.verbose then
            self:log("Overwriting request %s", tostring(method))
          end
          return
        end
      end
    end
  end

  if
    method ~= "initialize"
    and
    self:hitrate_reached("request")
    and
    not util.intable(method, requests_whitelist)
  then
    return
  end

  if self.verbose then
    self:log("Adding request %s", tostring(method))
  end

  -- Set the request id
  self.current_request = self.current_request + 1

  -- Store the request for later processing on responses_loop
  table.insert(self.request_list, {
    id = self.current_request,
    method = method,
    params = options.params,
    callback = options.callback or nil,
    overwritten_callback = options.overwritten_callback or nil,
    data = options.data or nil,
    timestamp = 0,
    times_sent = 0
  })
end

---Queue a client response to a server request which can be an error
---or a regular response, one of both. This may ignore new ones if
---the hit rate was reached.
---@param method string
---@param id integer
---@param result table|nil
---@param error table|nil
function Server:push_response(method, id, result, error)
  if self:hitrate_reached("request") then
    return
  end

  if self.verbose then
    self:log("Adding response %s to %s", tostring(id), tostring(method))
  end

  -- Store the response for later processing on loop
  local response = {
    id = id
  }
  if result then
    response.result = result
  else
    response.error = error
  end

  table.insert(self.response_list, response)
end

---Send raw json strings to server in cases where the json encoder
---would be too slow to convert a lua table into a json representation.
---@param name string A name to identify the request when overwriting.
---@param options lsp.server.requestoptions
function Server:push_raw(name, options)
  assert(options.raw_data, "please provide the raw_data for request")

  if options.overwrite then
    for _, request in ipairs(self.raw_list) do
      if request.method == name then
        if not request.sending then
          request.raw_data = options.raw_data
          request.callback = options.callback or nil
          request.data = options.data or nil
          if self.verbose then
            self:log("Overwriting raw request %s", tostring(name))
          end
          return
        end
        break
      end
    end
  end

  if self.verbose then
    self:log("Adding raw request %s", name)
  end

  -- Store the request for later processing on responses_loop
  table.insert(self.raw_list, {
    method = name,
    raw_data = options.raw_data,
    callback = options.callback or nil,
    data = options.data or nil
  })
end

---Retrieve a request and removes it from the internal requests list
---@param id integer
---@return lsp.server.request | nil
function Server:pop_request(id)
  for index, request in ipairs(self.request_list) do
    if request.id == id then
      table.remove(self.request_list, index)
      return request
    end
  end
  return nil
end

---Try to fetch a server rsponses, notifications or requests
---in a specific amount of time.
---@param timeout integer Time in seconds, set to 0 to not wait
---@return table[]|boolean Responses list or false if failed
function Server:read_responses(timeout)
  if not self.proc:running() then
    return false
  end

  timeout = timeout or Server.DEFAULT_TIMEOUT
  local inside_coroutine = self.yield_on_reads and coroutine.running() or false

  local max_time = os.time() + timeout
  if timeout == 0 then max_time = max_time + 1 end
  local output = ""
  while max_time > os.time() and output == "" do
    output = self.proc:read_stdout(Server.BUFFER_SIZE)
    if timeout == 0 then break end
    if output == "" and inside_coroutine then
      coroutine.yield()
    end
  end

  if output == nil then
    return false
  end

  local responses = {}
  local readmode = ""

  local bytes = 0;
  if output ~= "" then
    -- Make sure we retrieve everything
    local more_output = nil
    while more_output ~= "" do
      more_output = self.proc:read_stdout(Server.BUFFER_SIZE)
      if more_output ~= "" then
        if more_output == nil then
          break
        end
        output = output .. more_output
        if inside_coroutine then
          coroutine.yield()
        end
      end
    end

    if output:find('^Content%-Length: %d+\r\n') then
      bytes = tonumber(output:match("%d+"))

      local header_content = util.split(output, "\r\n\r\n")

      -- in case the response sent both header and content or
      -- more than one response at the same time
      if #header_content > 1 and #header_content[2] >= bytes then
        -- retrieve rest of output
        local new_output = nil
        while new_output ~= "" do
          new_output = self.proc:read_stdout(Server.BUFFER_SIZE)
          if new_output ~= "" then
            if new_output == nil then
              break
            end
            output = output .. new_output
            if inside_coroutine then
              coroutine.yield()
            end
          end
        end

        -- iterate every output
        header_content = util.split(output, "\r\n\r\n")
        bytes = 0
        for _, content in pairs(header_content) do
          if bytes == 0 and content:find('Content%-Length: %d+') then
            bytes =  tonumber(content:match("Content%-Length: (%d+)"))
          elseif bytes and #content >= bytes then
            local data = string.sub(content, 1, bytes)
            table.insert(responses, data)
            if content:find('Content%-Length: %d+') then
              bytes =  tonumber(content:match("Content%-Length: (%d+)"))
            else
              bytes = 0
            end
          end
        end

        readmode = "Response header and content received at once:\n"

        if self.verbose then
          self:log(
            readmode .. "%s",
            output
          )
        end
      else
        -- store partial content if available
        if #header_content > 1 and #header_content[2] > 0 then
          output = header_content[2]
        else
          output = ""
        end

        -- read again to retrieve full response content
        while #output < bytes do
          local chars = self.proc:read_stdout(bytes - #output)
          if #chars > 0 then
            output = output .. chars
          end
          if inside_coroutine then
            coroutine.yield()
          end
        end

        table.insert(responses, output)

        readmode = "Response header and content received separately:\n"

        if self.verbose then
          self:log(
            readmode .. "%s",
            output
          )
        end
      end
    elseif #output > 0 then
      if self.verbose then
        self:log("Output without header:\n%s", output)
      end
    end
  end

  if #responses > 0 then
    for index,data in pairs(responses) do
      data = json.decode(data)
      if data ~= false then
        responses[index] = data
      else
        responses[index] = nil
        self:log(
          "JSON Parser Error: %s\n%s\n%s",
          json.last_error(),
          readmode,
          output
        )
        return false
      end
    end

    if #responses > 0 then
      -- Reset write fails since server is sending responses
      self.write_fails = 0

      return responses
    end
  elseif self.verbose and timeout > 0 then
    self:log("Could not read a response in %d seconds", timeout)
  end

  return false
end

---Get messages thrown by the stderr pipe of the server.
---@param timeout integer Time in seconds, set to 0 to not wait
---@return string|nil
function Server:read_errors(timeout)
  timeout = timeout or Server.DEFAULT_TIMEOUT
  local inside_coroutine = self.yield_on_reads and coroutine.running() or false

  local max_time = os.time() + timeout
  if timeout == 0 then max_time = max_time + 1 end
  local output = ""
  while max_time > os.time() and output == "" do
    output = self.proc:read_stderr(Server.BUFFER_SIZE)
    if timeout == 0 then break end
    if output == "" and inside_coroutine then
      coroutine.yield()
    end
  end

  if timeout == 0 and output ~= "" then
    local new_output = nil
    while new_output ~= "" do
      new_output = self.proc:read_stderr(Server.BUFFER_SIZE)
      if new_output ~= "" then
        if new_output == nil then
          break
        end
        output = output .. new_output
        if inside_coroutine then
          coroutine.yield()
        end
      end
    end
  end

  return output or ""
end

---Try to send a request to a server in a specific amount of time.
---@param data table | string Table or string with the json request
---@param timeout? integer Time in seconds, set to 0 to not wait for write
---@return integer|boolean Amount of characters written or false if failed
function Server:write_request(data, timeout)
  if not self.proc:running() then
    return false
  end

  timeout = timeout or Server.DEFAULT_TIMEOUT

  if type(data) == "table" then
    data = json.encode(data)
  end

  local max_time = os.time() + timeout

  if timeout == 0 then max_time = max_time + 1 end
  local written = 0

  if not self.requests_in_chunks then
    while max_time > os.time() and written <= 0 do
      written = self.proc:write(string.format(
        'Content-Length: %d\r\n\r\n%s\r\n',
        #data + 2,
        data
      ))

      if timeout == 0 then break end
    end
  else
    -- first send the header
    while max_time > os.time() and written <= 0 do
      written = self.proc:write(string.format(
        'Content-Length: %d\r\n\r\n',
        #data + 2 -- last \r\n
      ))

      if timeout == 0 then break end
    end

    if written and written <= 0 then
      return false
    end

    -- send content in chunks
    local chunks = 10 * 1024
    data = data .. "\r\n"

    while #data > 0 do
      local wrote = 0

      if #data > chunks then
        wrote = self.proc:write(data:sub(1, chunks))
        data = data:sub(chunks+1)
      else
        wrote = self.proc:write(data)
        data = ""
      end

      if wrote > 0 then
        written = written + wrote
      else
        return false
      end
    end
  end

  if written and written <= 0 then
    return false
  end

  return written
end

function Server:log(message, ...)
  print (string.format("%s: " .. message .. "\n", self.name, ...))
end

---Call an apropriate signal handler for a given response.
---@param response table
function Server:send_response_signal(response)
  local request = self:pop_request(response.id)
  if request then
    if not request.overwritten and request.callback then
      request.callback(self, response, request)
    elseif request.overwritten and request.overwritten_callback then
      request.overwritten_callback(self, response, request)
    end
    return
  end
  self:on_response(response, request)
end

---Called for each response that doesn't has a signal handler.
---@param response table
---@param request lsp.server.request | nil
function Server:on_response(response, request)
  if self.verbose then
    self:log(
      "Recieved response '%s' with result:\n%s",
      response.id,
      util.jsonprettify(json.encode(response))
    )
  end
end

---Register a request handler.
---@param method string
---@param callback lsp.server.responsecb
function Server:add_request_listener(method, callback)
  if self.verbose then
    self:log(
      "Registering listener for '%s' requests",
      method
    )
  end
  self.request_listeners[method] = callback
end

---Call an apropriate signal handler for a given request.
---@param request table
function Server:send_request_signal(request)
  if not request.method then
    if self.verbose and request.id then
      self:log(
        "Received empty response for previous request '%s'",
        request.id
      )
    end
    return
  end

  if self.request_listeners[request.method] then
    self.request_listeners[request.method](
      self, request
    )
  else
    self:on_request(request)
  end
end

---Called for each request that doesn't has a signal handler.
---@param request table
function Server:on_request(request)
  if self.verbose then
    self:log(
      "Recieved request '%s' with data:\n%s",
      request.method,
      util.jsonprettify(json.encode(request))
    )
  end

  self:push_response(
    request.method,
    request.id,
    nil,
    {
      code = Server.error_code.MethodNotFound,
      message = "Method not found"
    }
  )
end

---Register a specialized message or notification listener.
---Notice that if no specialized listener is registered the
---on_notification() method will be called instead.
---@param method string
---@param callback lsp.server.notificationcb
function Server:add_message_listener(method, callback)
  if self.verbose then
    self:log(
      "Registering listener for '%s' messages",
      method
    )
  end
  self.message_listeners[method] = callback
end

---Call an apropriate signal handler for a given message or notification.
---@param message table
function Server:send_message_signal(message)
  if self.message_listeners[message.method] then
    self.message_listeners[message.method](
      self, message.params
    )
  else
    self:on_message(message.method, message.params)
  end
end

---Called for every message or notification without a signal handler.
---@param method string
---@Param params table
function Server:on_message(method, params)
  if self.verbose then
    self:log(
      "Recieved notification '%s' with params:\n%s",
      method,
      util.jsonprettify(json.encode(params))
    )
  end
end

---Kills the server process and deinitialize the server object state.
function Server:stop()
  self.initialized = false
  self.proc:kill()

  self.request_list = {}
  self.response_list = {}
  self.notification_list = {}
  self.raw_list = {}
  self.running = false
end

---Shut downs the server is not running or amount of write fails has
---reached its maximum allowed.
function Server:shutdown_if_needed()
  if
    self.write_fails >= self.write_fails_before_shutdown
    or
    not self.proc:running()
  then
    self:stop()
    self:on_shutdown()
    return
  end
  self.write_fails = self.write_fails + 1
end

---Can be overwritten to handle server shutdowns.
function Server:on_shutdown()
  self:log("The server was shutdown.")
end

---Sends a shutdown notification to lsp and then stop it.
function Server:exit()
  self.initialized = false

  -- Send shutdown request
  local message = {
    jsonrpc = '2.0',
    id = self.current_request + 1,
    method = "shutdown",
    params = {}
  }
  self:write_request(json.encode(message))

  -- send exit notification
  self:notify('exit')

  -- wait 1 second until it exits
  self.proc:wait(1000)

  self:stop()
end


return Server
