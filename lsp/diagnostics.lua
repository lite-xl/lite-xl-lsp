-- Store diagnostic messages received by an LSP.
-- @copyright Jefferson Gonzalez
-- @license MIT

local diagnostics = {}

diagnostics.list = {}

function diagnostics.get(filename)
  for _, diagnostic in pairs(diagnostics.list) do
    if diagnostic.file == filename then
      return diagnostic
    end
  end

  return nil
end

function diagnostics.add(filename, messages)
  local current_messages = diagnostics.get(filename)

  if not current_messages then
    table.insert(
      diagnostics.list,
      {file = filename, messages = messages}
    )
  else
    current_messages.messages = messages
  end
end

function diagnostics.clear(filename)
  for index, diagnostic in ipairs(diagnostics.list) do
    if diagnostic.file == filename then
      table.remove(diagnostics.list, index)
    end
  end
end

return diagnostics
