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

lsp.add_server {
  name = "lua-language-server",
  language = "lua",
  file_patterns = {"%.lua$"},
  command = {
    "/path/to/lua-language-server/bin/Linux/lua-language-server",
    "-E",
    "/path/to/lua-language-server/main.lua"
  },
  verbose = true,
  settings = {
    Lua = {
      completion = {
        enable = true,
        keywordSnippet = "Disable"
      },
      develop = {
        enable = false,
        debuggerPor = 11412,
        debuggerWait = false
      },
      diagnostics = {
        enable = true,
      },
      hover = {
        enable = true,
        viewNumber = true,
        viewString = true,
        viewStringMax = 1000
      },
      runtime = {
        version = 'Lua 5.4',
        path = {
          "?.lua",
          "?/init.lua",
          "?/?.lua",
          "/usr/share/5.4/?.lua",
          "/usr/share/lua/5.4/?/init.lua"
        }
      },
      signatureHelp = {
        enable = true
      },
      workspace = {
        maxPreload = 2000,
        preloadFileSize = 1000
      }
    }
  }
}
