--
-- A list of servers.
--
-- Can be used by doing a 'require "plugins.lsp.serverlist"'
-- on your user init.lua
--
-- Servers taken from:
-- https://github.com/prabirshrestha/vim-lsp/wiki/Servers
-- https://github.com/mattn/vim-lsp-settings/tree/master/settings
--

local lsp = require "plugins.lsp"

-- bash-language-server
-- Status: Works but performs really badly
--         set 'requests_per_second' to 2-4 if too slow
-- Site: https://github.com/bash-lsp/bash-language-server
-- Installation: npm i -g bash-language-server
lsp.add_server {
  name = "bash-language-server",
  language = "shell",
  file_patterns = { "%.sh$" },
  command = { "bash-language-server", "start" },
  verbose = false
}

-- clangd
-- Status: Works
-- Site: https://clangd.llvm.org/
-- Installation: install the clang software package on your system
lsp.add_server {
  name = "clangd",
  language = "c/cpp",
  file_patterns = {
    "%.c$", "%.h$", "%.inl$", "%.cpp$", "%.hpp$",
    "%.cc$", "%.C$", "%.cxx$", "%.c++$", "%.hh$",
    "%.H$", "%.hxx$", "%.h++$", "%.objc$", "%.objcpp$"
  },
  command = { "clangd", "-background-index" },
  verbose = false
}

-- Clojure
-- Status: Untested
-- Site: https://clojure-lsp.github.io/
-- Installation: https://clojure-lsp.github.io/clojure-lsp/installation/
lsp.add_server {
  name = "clojure-lsp",
  language = "clojure",
  file_patterns = { "%.clj$", "%.cljs$", "%.clc$", "%.edn$" },
  command = { "clojure-lsp" },
  verbose = false
}

-- css-languageserver
-- Status: Requires snippets support for completion to work which isn't implemented
-- Site: https://github.com/vscode-langservers/vscode-css-languageserver-bin
-- Installation: npm install -g vscode-css-languageserver-bin
lsp.add_server {
  name = "css-languageserver",
  language = "css",
  file_patterns = {"%.css$", "%.less$", "%.sass$"},
  command = { "css-languageserver", "--stdio" },
  verbose = false
}

-- Dockerfile
-- Status: Untested
-- Site: https://github.com/rcjsuen/dockerfile-language-server-nodejs
-- Installation: npm install -g dockerfile-language-server-nodejs
lsp.add_server {
  name = "docker-langserver",
  language = "dockerfile",
  file_patterns = { "Dockerfile$" },
  command = { "docker-langserver", "--stdio" },
  verbose = false
}

-- Flow - JavaScript
-- Status: Untested
-- Site: https://flow.org/
-- Installation: npm install -g flow-bin
lsp.add_server {
  name = "flow",
  language = "javascript",
  file_patterns = { "%.js$", "%.jsx$" },
  command = { "flow", "lsp" },
  verbose = false
}

-- gopls
-- Status: Untested
-- Site: https://pkg.go.dev/golang.org/x/tools/gopls
-- Installation: go get -u golang.org/x/tools/gopls
lsp.add_server {
  name = "gopls",
  language = "go",
  file_patterns = { "%.go$" },
  command = { "gopls" },
  verbose = false
}

-- groovy-language-server
-- Status: Untested
-- Site: https://github.com/prominic/groovy-language-server
-- Installation:
--    mkdir ~/lsp
--    cd ~/lsp
--    git clone https://github.com/prominic/groovy-language-server.git
--    cd ~/lsp/groovy-language-server
--    ./gradlew build
lsp.add_server {
  name = "groovy-language-server",
  language = "groovy",
  file_patterns = { "%.groovy$", "%.gvy$", "%.gy$", "%.gsh$" },
  -- command = { "java", "-jar", "/path/to/groovy-language-server-all.jar" },
  command = { "groovy-language-server" },
  verbose = false
}

-- haskell-language-server
-- Status: Untested
-- Site: https://github.com/haskell/haskell-language-server
-- Installation: ghcup install hls
-- or https://github.com/haskell/haskell-language-server#installation
lsp.add_server {
  name = "haskell-language-server",
  language = "haskell",
  file_patterns = { "%.hs$", "%.lhs$" },
  command = { 'haskell-language-server-wrapper', '--lsp' },
  verbose = false
}

-- vscode-html-languageserver
-- Status: Untested
-- Site: https://github.com/vscode-langservers/vscode-html-languageserver-bin
-- Installation: npm install --global vscode-html-languageserver-bin
lsp.add_server {
  name = "html-languageserver",
  language = "html",
  file_patterns = { "%.html$" },
  command = { 'html-languageserver', '--stdio' },
  verbose = false
}

-- vscode-json-languageserver
-- Status: Untested
-- Site: https://www.npmjs.com/package/vscode-json-languageserver
-- Installation: npm install -g vscode-json-languageserver
lsp.add_server {
  name = "vscode-json-languageserver",
  language = "json",
  file_patterns = { "%.json$", "%.jsonc$" },
  command = { 'vscode-json-languageserver', '--stdio' },
  verbose = false
}

-- sql-language-server
-- Status: Untested
-- Site: https://github.com/joe-re/sql-language-server
-- Installation: npm i -g sql-language-server
lsp.add_server {
  name = "sql-language-server",
  language = "sql",
  file_patterns = { "%.sql$" },
  command = { 'sql-language-server', 'up', '--method', 'stdio' },
  verbose = false
}

-- typescript-language-server
-- Status: Untested
-- Site: https://github.com/theia-ide/typescript-language-server
-- Installation: npm install -g typescript typescript-language-server
lsp.add_server {
  name = "typescript-language-server",
  language = "javascript",
  file_patterns = { "%.js$", "%.cjs$", "%.mjs$" },
  command = { 'typescript-language-server', '--stdio' },
  verbose = false
}

-- kotlin-language-server
-- Status: Untested
-- Site: https://github.com/fwcd/kotlin-language-server
-- Installation: https://github.com/fwcd/kotlin-language-server/releases
lsp.add_server {
  name = "kotlin-language-server",
  language = "kotlin",
  file_patterns = { "%.kt$", "%.kts$", "%.ktm$" },
  command = { 'kotlin-language-server' },
  verbose = false
}

-- intelephense
-- Status: Works
-- Site: https://github.com/bmewburn/intelephense-docs
-- Installation: npm -g install intelephense
-- Note: Set your license and storage by passing the init_options as follows:
--       init_options = { licenceKey = "...", storagePath = "/some/path"}
lsp.add_server {
  name = "intelephense",
  language = "php",
  file_patterns = {"%.php$"},
  command = { "intelephense", "--stdio" },
  verbose = false
}

-- python-language-server
-- Status: Untested
-- Site: https://github.com/palantir/python-language-server
-- Installation: pip install python-language-server
lsp.add_server {
  name = "pyls",
  language = "python",
  file_patterns = { "%.py$" },
  command = { 'pyls' },
  verbose = false
}

-- Solargraph
-- Status: Untested
-- Site: https://github.com/castwide/solargraph
-- Installation: gem install solargraph
lsp.add_server {
  name = "solargraph",
  language = "ruby",
  file_patterns = { "%.rb$" },
  command = { 'solargraph', 'stdio' },
  verbose = false
}

-- Rust Language Server
-- Status: Untested
-- Site: https://github.com/rust-lang/rls
-- Installation: Install rust on your system
lsp.add_server {
  name = "rust-language-server",
  language = "rust",
  file_patterns = { "%.rs$" },
  command = { 'rls' },
  verbose = false
}

-- lua-language-server
-- Status: Works
-- Site: https://github.com/sumneko/lua-language-server
-- Installation: https://github.com/sumneko/lua-language-server/wiki/Build-and-Run-(Standalone)
lsp.add_server {
  name = "lua-language-server",
  language = "lua",
  file_patterns = {"%.lua$"},
  command = {
    "/path/to/lua-language-server/bin/Linux/lua-language-server",
    "-E",
    "/path/to/lua-language-server/main.lua"
  },
  verbose = false,
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
      },
      telemetry = {
        enable = true
      }
    }
  }
}

-- vlang-vls
-- Status: Initializes but doesn't responds to completion requests
--         at least it helped improve lit-xl-lsp requests mechanism
-- Site: https://github.com/vlang/vls
-- Installation:
--  git clone https://github.com/vlang/vls.git vls && cd vls/
--  v -prod cmd/vls
--  mv cmd/vls vlang-vls
lsp.add_server {
  name = "vlang-vls",
  language = "v",
  file_patterns = { "%.v$" },
  command = { 'vlang-vls' },
  verbose = false
}

-- vim-language-server
-- Status: Untested
-- Site: https://github.com/iamcco/vim-language-server
-- Installation: npm install -g vim-language-server
lsp.add_server {
  name = "vim-language-server",
  language = "vim",
  file_patterns = { "%.vim$" },
  command = { 'vim-language-server', '--stdio' },
  verbose = false
}

-- yaml-language-server
-- Status: Untested
-- Site: https://github.com/redhat-developer/yaml-language-server
-- Installation: Install rust on your system
lsp.add_server {
  name = "yaml-language-server",
  language = "yaml",
  file_patterns = { "%.yml$", "%.yaml$" },
  command = { 'yaml-language-server', '--stdio' },
  verbose = false
}
