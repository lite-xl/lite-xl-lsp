--
-- A list of servers for testing.
--
-- Can be used by doing a 'require "plugins.lsp.serverlist"'
-- on your user init.lua
--

local lsp = require "plugins.lsp"

lsp.add_server {
  name = "intelephense",
  language = "php",
  file_patterns = {"%.php$"},
  command = {
    "intelephense",
    "--stdio"
  },
  verbose = true
}

lsp.add_server {
  name = "css-languageserver",
  language = "css",
  file_patterns = {"%.css$"},
  command = {
    "css-languageserver",
    "--stdio"
  },
  verbose = true
}

lsp.add_server {
  name = "clangd",
  language = "c/cpp",
  file_patterns = {
    "%.c$", "%.h$", "%.inl$", "%.cpp$", "%.hpp$",
    "%.cc$", "%.C$", "%.cxx$", "%.c++$", "%.hh$",
    "%.H$", "%.hxx$", "%.h++$", "%.objc$", "%.objcpp$"
  },
  command = {
    "clangd",
    "-background-index"
  },
  verbose = true
}
