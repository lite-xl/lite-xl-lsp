-- Store diagnostic messages received by an LSP.
-- @copyright Jefferson Gonzalez
-- @license MIT

local diagnostics = {}

diagnostics.list = {}
diagnostics.count = 0

function diagnostics.get(filename)
  return diagnostics.list[filename]
end

function diagnostics.add(filename, messages)
  if not diagnostics.list[filename] then
    diagnostics.count = diagnostics.count + 1
  end
  diagnostics.list[filename] = messages
end

function diagnostics.clear(filename)
  if diagnostics.list[filename] then
    diagnostics.list[filename] = nil
    diagnostics.count = diagnostics.count - 1
  end
end

function diagnostics.get_messages_count(filename)
  if diagnostics.list[filename] then
    return #diagnostics.list[filename]
  end

  return 0
end

return diagnostics
