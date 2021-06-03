-- Store diagnostic messages received by an LSP.
-- @copyright Jefferson Gonzalez
-- @license MIT

local diagnostics = {}

diagnostics.list = {}

function diagnostics.get(filename)
  return diagnostics.list[filename]
end

function diagnostics.add(filename, messages)
  diagnostics.list[filename] = messages
end

function diagnostics.clear(filename)
  diagnostics.list[filename] = nil
end

return diagnostics
