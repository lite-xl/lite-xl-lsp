-- @copyright Jefferson Gonzalez
-- @license MIT
-- Inspiration: https://github.com/orbitalquark/textadept-lsp

local json = require "plugins.lsp.json"
local util = require "plugins.lsp.util"

local server = {
  DEFAULT_TIMEOUT = 10
}

server.error_code = {
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

server.completion_trigger_Kind = {
	Invoked = 1,
	TriggerCharacter = 2,
	TriggerForIncompleteCompletions = 3
}

server.diagnostic_severity = {
  Error = 1,
  Warning = 2,
  Information = 3,
  Hint = 4
}

server.text_document_sync_kind = {
  None = 0,
  Full = 1,
  Incremental = 2
}

function server.new(options)
  local srv = setmetatable(
    {
      name = options.name,
      language = options.language,
      file_patterns = options.file_patterns,
      current_request = 0,
      init_options = options.init_options or {},
      settings = options.settings or nil,
      event_listeners = {},
      message_listeners = {},
      request_listeners = {},
      request_list = {},
      response_list = {},
      notification_list = {},
      command = options.command,
      restarts = options.restarts or 3,
      restart_retries = 0,
      write_fails = 0,
      write_fails_before_restart = 10,
      verbose = options.verbose or false,
      initialized = false
    },
    {__index = server}
  )

  srv.proc = process.new()
  srv.proc:start(options.command)

  return srv
end

function server.get_completion_items_kind(id)
  local kinds = {
    'Text', 'Method', 'Function', 'Constructor', 'Field', 'Variable', 'Class',
    'Interface', 'Module', 'Property', 'Unit', 'Value', 'Enum', 'Keyword',
    'Snippet', 'Color', 'File', 'Reference', 'Folder', 'EnumMember',
    'Constant', 'Struct', 'Event', 'Operator', 'TypeParameter'
  }

  if id then
    return kinds[id]
  end

  local list = {}
  for i = 1, #kinds do
    list[i] = i
  end

  return list
end

function server.get_symbols_kind(id)
  local kinds = {
    'File', 'Module', 'Namespace', 'Package', 'Class', 'Method', 'Property',
    'Field', 'Constructor', 'Enum', 'Interface', 'Function', 'Variable',
    'Constant', 'String', 'Number', 'Boolean', 'Array', 'Object', 'Key',
    'Null', 'EnumMember', 'Struct', 'Event', 'Operator', 'TypeParameter'
  }

  if id then
    return kinds[id]
  end

  local list = {}
  for i = 1, #kinds do
    list[i] = i
  end

  return list
end

function server:initialize(path, editor_name, editor_version)
  local root_uri = "";
  if PLATFORM ~= "Windows" then
    root_uri = 'file://' .. path
  else
    root_uri = 'file:///' .. path:gsub('\\', '/')
  end

  self.path = path or ""
  self.editor_name = editor_name or "unknwon"
  self.editor_version = editor_version or "0.1"

  self:push_request(
    'initialize',
    {
      processId = nil,
      clientInfo = {
        name = editor_name or "unknwon",
        version = editor_version or "0.1"
      },
      -- TODO: locale
      rootPath = path,
      rootUri = root_uri,
      workspaceFolders = {
        {uri = root_uri, name = util.getpathname(path)}
      },
      initializationOptions = self.init_options,
      capabilities = {
        -- workspace = nil, -- workspaces are not supported at all
        textDocument = {
          synchronization = {
            -- willSave = true,
            -- willSaveWaitUntil = true,
            didSave = true
          },
          completion = {
            -- dynamicRegistration = false, -- not supported
            completionItem = {
              -- Snippets are required by css-languageserver
              -- snippetSupport = true, -- ${1:foo} format not supported
              -- commitCharactersSupport = true,
              documentationFormat = {'plaintext'},
              -- deprecatedSupport = false, -- simple autocompletion list
              preselectSupport = true
              -- tagSupport = {valueSet = {}},
              -- insertReplaceSupport = true,
              -- resolveSupport = {properties = {}},
              -- insertTextModeSupport = {valueSet = {}}
            },
            completionItemKind = {valueSet = server.get_completion_items_kind()}
            -- contextSupport = true
          },
          hover = {
            -- dynamicRegistration = false, -- not supported
            contentFormat = {'plaintext'}
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
            symbolKind = {valueSet = server.get_symbols_kind()}
            -- hierarchicalDocumentSymbolSupport = true,
            -- tagSupport = {valueSet = {}},
            -- labelSupport = true
          }
          -- formatting = {dynamicRegistration = false}, -- not supported
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
        }
        -- window = {
        --  workDoneProgress = true,
        --  showMessage = {},
        --  showDocument = {}
        -- },
        -- general = {
        --  regularExpressions = {},
        --  markdown = {}
        -- },
        -- experimental = nil
      }
    },
    function(self, response)
      if self.verbose then
        self:log(
          "Processing initialization response '%s'",
          util.jsonprettify(json.encode(response))
        )
      end
      local result = response.result
      if result then
        self.capabilities = result.capabilities
        self.info = result.serverInfo

        if self.info then
          self:log(
            'Connected to %s %s',
            self.info.name,
            self.info.version or '(unknown version)'
          )
        end

        self:notify('initialized') -- required by protocol
        self:send_event_signal("initialized", self, result)

        self.initialized = true;
      end
    end
  )
end

function server:add_event_listener(event_name, callback)
  if self.verbose then
    self:log(
      "Listening for event '%s'",
      event_name
    )
  end

  self.event_listeners[event_name] = callback
end

function server:send_event_signal(event_name, ...)
  if self.event_listeners[event_name] then
    self.event_listeners[event_name](self, ...)
  else
    self:on_event(event_name, ...)
  end
end

function server:on_event(event_name, ...)
  if self.verbose then
    self:log("Received event '%s'", event_name)
  end
end

--- Send a message to the server that doesn't needs a response.
function server:notify(method, params)
  local message = {
    jsonrpc = '2.0',
    method = method,
    params = params or {}
  }

  local data = json.encode(message)

  if self.verbose then
    self:log("Sending notification: %s", util.jsonprettify(data))
  end

  local written = self:write_request(data)

  if not written and self.verbose then
    self:log("Could not send notification: %s", util.jsonprettify(data))
  end
end

function server:respond(id, result)
  local message = {
    jsonrpc = '2.0',
    id = id,
    result = result
  }

  local data = json.encode(message)

  if self.verbose then
    self:log("Responding: %s", util.jsonprettify(data))
  end

  local written = self:write_request(data)

  if not written and self.verbose then
    self:log("Could not send response: %s", util.jsonprettify(data))
  end
end

function server:respond_error(id, error_message, error_code)
  local message = {
    jsonrpc = '2.0',
    id = id,
    error = {
      code = error_code or server.error_code.MethodNotFound,
      message = error_message
    }
  }

  local data = json.encode(message)

  if self.verbose then
    self:log("Responding error: %s", util.jsonprettify(data))
  end

  local written = self:write_request(data)

  if not written and self.verbose then
    self:log("Could not send response: %s", util.jsonprettify(data))
  end
end

--- Sends the pushed notifications.
function server:process_notifications()
  -- only process when initialized
  if not self.initialized then
    return
  end
  for index, request in pairs(self.notification_list) do
    local message = {
      jsonrpc = '2.0',
      method = request.method,
      params = request.params or {}
    }

    local data = json.encode(message)

    if self.verbose then
        self:log("Sending notification '%s'", util.jsonprettify(data))
    end

    local written = self:write_request(data, 0)

    if self.verbose then
      if not written or written < 0 then
        self:log(
          "Failed sending notification '%s' - '%s'",
          request.method,
          util.jsonprettify(data)
        )
      end
    end

    if written and written > 0 then
      table.remove(self.notification_list, index)
    end
  end
end

--- Sends one of the pushed request, this function should be called on a
-- loop for non blocking interaction.
function server:process_requests()
  for id, request in pairs(self.request_list) do
    if not request.sent then
      -- only process when initialized or the initialize request
      -- which should be the first one.
      if not self.initialized and id ~= 1 then
        return
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
            "Sent request '%s' - '%s'",
            request.method,
            util.jsonprettify(data)
          )
        else
          self:log(
            "Failed sending request '%s' - '%s'",
            request.method,
            util.jsonprettify(data)
          )
        end
      end

      if written and written > 0 then
        self.request_list[id].sent = true
        return request
      end
    end
  end
end

function server:process_responses()
  local responses = self:read_responses(0)

  if type(responses) == "table" then
    for i, response in pairs(responses) do
      if self.verbose then
        self:log("Response '%s'", util.jsonprettify(json.encode(response)))
      end
      if not response.id then
        -- A notification, event or generic message was received
        self:send_message_signal(response)
      elseif response.result then
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

--- Sends the pushed client responses to server.
function server:process_client_responses()
  -- only process when server initialized
  if not self.initialized then
    return
  end

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
        self:log("Sending client response '%s'", util.jsonprettify(data))
    end

    local written = self:write_request(data, 0)

    if self.verbose then
      if not written or written < 0 then
        self:log(
          "Failed sending client response '%s' - '%s'",
          response.id,
          util.jsonprettify(data)
        )
      end
    end

    if written and written > 0 then
      table.remove(self.response_list, index)
    end
  end
end

--- Along with process_requests() and process_responses() this one should
-- be called to prevent the server from stalling because of not flushing
-- the stderr.
function server:process_errors()
  local errors = self:read_errors(0)

  if errors then
    self:log("Error: \n'%s'", errors)
  end

  return errors
end

function server:push_notification(method, params)
  if self.verbose then
    self:log(
      "Adding request '%s' - '%s'",
      method,
      util.jsonprettify(json.encode(params))
    )
  end

  -- Store the notification for later processing on responses_loop
  table.insert(self.notification_list, {
    method = method,
    params = params
  })
end

function server:push_request(method, params, callback)
  if self.verbose then
    self:log("Adding request %s", tostring(method))
  end

  -- Set the request id
  self.current_request = self.current_request + 1

  -- Store the request for later processing on responses_loop
  self.request_list[self.current_request] = {
    id = self.current_request,
    method = method,
    params = params,
    callback = callback or nil,
    sent = false
  }
end

--- Add a client response to a server request.
function server:push_response(method, id, result, error)
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

--- Retrieve a request and removes it from the internal requests list
-- @param id id of the request
-- @return The request table or nil of not found
function server:pop_request(id)
  local request = nil
  if self.request_list[id] then
    request = self.request_list[id]
    for i, element in ipairs(self.request_list) do
      if element.id == request.id then
        table.remove(self.request_list, i)
      end
    end
  end
  return request
end

--- Try to fetch a server response in a specific amount of time.
-- @param timeout Time in seconds, set to 0 to not wait for response
-- @return Response Table or false if failed
function server:read_responses(timeout)
  timeout = timeout or server.DEFAULT_TIMEOUT

  local max_time = os.time() + timeout
  if timeout == 0 then max_time = max_time + 1 end
  local output = nil
  while max_time > os.time() and output == nil do
    output = self.proc:read()
    if timeout == 0 then break end
  end

  local responses = {}

  local bytes = 0;
  if output ~= nil then
    -- Make sure we retrieve everything
    local more_output = ""
    while more_output ~= nil do
      more_output = self.proc:read()
      if more_output ~= nil then
        output = output .. more_output
      end
    end

    if output:find('^Content%-Length: %d+') then
      bytes = tonumber(output:match("%d+"))

      local header_content = util.split(output, "\r\n\r\n")

      -- in case the response sent both header and content or
      -- more than one response at the same time
      if #header_content > 1 and #header_content[2] >= bytes then
        -- retrieve rest of output
        local new_output = ""
        while new_output ~= nil do
          new_output = self.proc:read()
          if new_output ~= nil then
            output = output .. new_output
          end
        end

        -- iterate every output
        header_content = util.split(output, "\r\n\r\n")
        bytes = 0
        for index, content in pairs(header_content) do
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

        if self.verbose then
          self:log("Response header and content received at once.")
          self:log("Output %s", util.jsonprettify(output))
        end
      else
        -- read again to retrieve actual response content
        output = ""
        while #output < bytes do
          local chars = self.proc:read(bytes - #output)
          if chars then
            output = output .. chars
          end
        end

        table.insert(responses, output)

        if self.verbose then
          self:log("Response header and content received separately")
          self:log("Output %s", util.jsonprettify(output) .. "\n")

          -- TODO: Debug this having issues with some servers
          --local thefile = io.open("/home/user/.config/lite-xl/out.txt", "a+")
          --thefile:write("Output: \n" .. output .. "\n")
          --for _,value in pairs(responses) do
          --  thefile:write(value .. "\n")
          --end
          --thefile:close()
        end
      end
    elseif #output > 0 then
      if self.verbose then
        self:log("Output withuot header: %s", util.jsonprettify(output))
      end
    end
  end

  if #responses > 0 then
    local responses_copy = responses

    for index,data in pairs(responses_copy) do
      data = json.decode(data)
      if data ~= false then
        responses[index] = data
      else
        table.remove(responses, index)
        self:log("Response '%s'", util.jsonprettify(data))
        self:log("JSON Parser Error: %s", json.last_error())
      end
    end

    if #responses > 0 then
      return responses
    end
  elseif self.verbose and timeout > 0 then
    self:log("Could not read a response in %d seconds", timeout)
  end

  return false
end

--- Get messages thrown by the stderr
-- @param timeout Time in seconds, set to 0 to not wait for response
-- @return Response Table or false if failed
function server:read_errors(timeout)
  timeout = timeout or server.DEFAULT_TIMEOUT

  local max_time = os.time() + timeout
  if timeout == 0 then max_time = max_time + 1 end
  local output = nil
  while max_time > os.time() and output == nil do
    output = self.proc:read_errors()
    if timeout == 0 then break end
  end

  if timeout == 0 and output ~= nil then
    local new_output = ""
    while new_output ~= nil do
      new_output = self.proc:read_errors()
      if new_output ~= nil then
        output = output .. new_output
      end
    end
  end

  return output
end

--- Try to send a request to a server in a specific amount of time.
-- @param data Table or string with the json request
-- @param timeout Time in seconds, set to 0 to not wait for write
-- @return Amount of characters written or false if failed
function server:write_request(data, timeout)
  timeout = timeout or server.DEFAULT_TIMEOUT

  if type(data) == "table" then
    data = json.encode(data)
  end

  local max_time = os.time() + timeout

  if timeout == 0 then max_time = max_time + 1 end

  local written = 0
  while max_time > os.time() and written <= 0 do
    written = self.proc:write(string.format(
      'Content-Length: %d\r\n\r\n%s\r\n',
      #data + 2,
      data
    ))

    if timeout == 0 then break end
  end

  if written and written <= 0 then
    return false
  end

  return written
end

function server:log(message, ...)
  print (string.format("%s: " .. message .. "\n", self.name, ...))
end

--- Call an apropriate signal handler for a given response.
-- @param response A response object as generated by request.
function server:send_response_signal(response)
  local request = self:pop_request(response.id)
  if request and request.callback then
    request.callback(self, response)
  else
    self:on_response(response)
  end
end

--- Called for each response that doesn't has a signal handler.
-- @param response Table with data as received from server
function server:on_response(response)
  if self.verbose then
    self:log(
      "Recieved response '%s' with result '%s'",
      response.id,
      util.jsonprettify(json.encode(response))
    )
  end
end

--- Register a request handler
-- @param method The name of method, eg: "workspace/configuration"
-- @param callback A function with parameters (server, request)
function server:add_request_listener(method, callback)
  if self.verbose then
    self:log(
      "Registering listener for '%s' requests",
      method
    )
  end
  self.request_listeners[method] = callback
end

--- Call an apropriate signal handler for a given request.
-- @param request A request object sent by server.
function server:send_request_signal(request)
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

--- Called for each request that doesn't has a signal handler.
-- @param request Table with data as received from server
function server:on_request(request)
  if self.verbose then
    self:log(
      "Recieved request '%s' with data '%s'",
      request.method,
      util.jsonprettify(json.encode(request))
    )
  end

  self:push_response(
    request.method,
    request.id,
    nil,
    {
      code = server.error_code.MethodNotFound,
      message = "Method not found"
    }
  )
end

--- Register a specialized message or notification listener.
-- Notice that if no specialized listener is registered the
-- on_notification() method will be called instead.
-- @param method The name of method, eg: "window/logMessage"
-- @param callback A function with parameters (server, method, params)
function server:add_message_listener(method, callback)
  if self.verbose then
    self:log(
      "Registering listener for '%s' messages",
      method
    )
  end
  self.message_listeners[method] = callback
end

--- Call an apropriate signal handler for a given message or notification
-- @param message A message object as generated by request.
function server:send_message_signal(message)
  if self.message_listeners[message.method] then
    self.message_listeners[message.method](
      self, message.params
    )
  else
    self:on_message(message.method, message.params)
  end
end

--- Called for every message or notification without a signal handler.
-- @param method The name of method, eg: "window/logMessage"
-- @Param params Paremeters table as sent by the server
function server:on_message(method, params)
  if self.verbose then
    self:log(
      "Recieved notification '%s' with params '%s'",
      method,
      util.jsonprettify(json.encode(params))
    )
  end
end

--- Instructs the server to exit.
function server:exit()
  server:request('shutdown')
  server:notify('exit')
end

return server
