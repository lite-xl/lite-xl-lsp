--
-- A list of servers.
--
-- Can be used by doing a 'local lspconfig = require "plugins.lsp.config"'
-- on your user init.lua, for more details check the README.md
--
-- Servers taken from:
-- https://github.com/prabirshrestha/vim-lsp/wiki/Servers
-- https://github.com/mattn/vim-lsp-settings/tree/master/settings
--

local lsp = require "plugins.lsp"

local function merge(a, b)
  local t = {}
  if a then
    for k, v in pairs(a) do
      if type(v) == "table" then
        t[k] = merge(t[k], v)
      else
        t[k] = v
      end
    end
  end
  if b then
    for k, v in pairs(b) do
      if type(v) == "table" then
        t[k] = merge(t[k], v)
      else
        t[k] = v
      end
    end
  end
  return t
end

---Options that can be passed to a LSP server to overwrite the defaults.
---@class lsp.config.options
---
---Name of server.
---@field name string
---Main language, eg: C.
---@field language string
---File types that are supported by this server.
---@field file_patterns string[]
---LSP command and optional arguments.
---@field command string[]
---Optional table of settings to pass into the lsp
---Note that also having a settings.json or settings.lua in
---your workspace directory with a table of settings is supported.
---@field settings table<string,any>
---Optional table of initializationOptions for the LSP.
---@field init_options table<string,any>
---Set by default to 16 should only be modified if having issues with a server.
---@field requests_per_second integer
---By default each request is written to the server stdin in chunks of 10KB,
---if this gives issues set to false to write everything at once.
---@field requests_in_chunks boolean
---Some servers like bash language server support incremental changes
---which are more performant but don't advertise it, set to true to force
---incremental changes even if server doesn't advertise them.
---@field incremental_changes boolean
---Set to true to debug the lsp client when developing it
---@field verbose boolean

---@class lsp.config.server
---Register the lsp server for usage.
---@field setup fun(options?:lsp.config.options)
---Get the default lsp server options.
---@field get_options fun():lsp.config.options

---Helper to register a language server.
---@param options lsp.config.options
---@return lsp.config.server
local function add_lsp(options)
  return {
    setup = function(user_options)
      local merged_options = merge(options, user_options)
      lsp.add_server(merged_options)
    end,
    get_options = function()
      return options
    end
  }
end

---List of predefined language servers that can be easily enabled at runtime.
---@class lsp.config
local lspconfig = {}

---# bash-language-server
--- __Status__: Works
--- __Site__: https://github.com/bash-lsp/bash-language-server
--- __Installation__: `npm i -g bash-language-server`
--- __Note__: also install `shellcheck` for linting
lspconfig.bashls = add_lsp {
  name = "bash-language-server",
  language = "shell",
  file_patterns = { "%.sh$" },
  command = { "bash-language-server", "start" },
  incremental_changes = true,
  verbose = false
}

---# ccls
--- __Status__: Works
--- __Site__: https://github.com/MaskRay/ccls/
--- __Installation__: https://github.com/MaskRay/ccls/wiki
lspconfig.ccls = add_lsp {
  name = "ccls",
  language = "c/cpp",
  file_patterns = {
    "%.c$", "%.h$", "%.inl$", "%.cpp$", "%.hpp$",
    "%.cc$", "%.C$", "%.cxx$", "%.c++$", "%.hh$",
    "%.H$", "%.hxx$", "%.h++$", "%.objc$", "%.objcpp$"
  },
  command = { "ccls" },
  verbose = false
}

---# clangd
--- __Status__: Works
--- __Site__: https://clangd.llvm.org/
--- __Installation__: install the clang software package on your system
--- __Note__: See https://clangd.llvm.org/installation.html#project-setup
lspconfig.clangd = add_lsp {
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

---# Clojure
--- __Status__: Untested
--- __Site__: https://clojure-lsp.github.io/
--- __Installation__: https://clojure-lsp.github.io/clojure-lsp/installation/
lspconfig.clojure_lsp = add_lsp {
  name = "clojure-lsp",
  language = "clojure",
  file_patterns = { "%.clj$", "%.cljs$", "%.clc$", "%.edn$" },
  command = { "clojure-lsp" },
  verbose = false
}

---# css-languageserver
--- __Status__: Requires snippets support for completion to work which isn't implemented
--- __Site__: https://github.com/vscode-langservers/vscode-css-languageserver-bin
--- __Installation__: `npm install -g vscode-css-languageserver-bin`
lspconfig.cssls = add_lsp {
  name = "css-languageserver",
  language = "css",
  file_patterns = { "%.css$", "%.less$", "%.sass$" },
  command = { "css-languageserver", "--stdio" },
  fake_snippets = true,
  verbose = false
}

---# dartls
--- __Status__: Untested
--- __Site__: https://github.com/dart-lang/sdk
--- __Installation__: Provided in dart sdk
lspconfig.dartls = add_lsp {
  name = "dart",
  language = "dart",
  file_patterns = { "%.dart$" },
  command = { "dart", "language-server", "--protocol=lsp" },
  verbose = false
}

---# Dockerfile
--- __Status__: Untested
--- __Site__: https://github.com/rcjsuen/dockerfile-language-server-nodejs
--- __Installation__: `npm install -g dockerfile-language-server-nodejs`
lspconfig.dockerls = add_lsp {
  name = "docker-langserver",
  language = "dockerfile",
  file_patterns = { "Dockerfile$" },
  command = { "docker-langserver", "--stdio" },
  verbose = false
}

---# Deno
--- __Status__: Works
--- __Site__: https://deno.land/manual/advanced/language_server
--- __Installation__: Provided in Deno runtime
lspconfig.deno = add_lsp {
  name = "deno",
  language = "typescript",
  file_patterns = { "%.ts$", "%.tsx$" },
  command = { 'deno', 'lsp' },
  id_not_extension = true,
  verbose = false,
  settings = {
    deno = {
      enable = true,
      unstable = true,
      config = "./deno.json",
      importMap = "./import_map.json",
      lint = true,
      codeLens  = {
        implementations = true,
        references = true,
        test = true,
        referencesAllFunctions = true
      },
      suggest = {
        names = true,
        paths = true,
        completeFunctionCalls = true,
        imports = {
          autoDiscover = true,
        },
        autoImports = true
      }
    }
  }
}

---# Flow - JavaScript
--- __Status__: Untested
--- __Site__: https://flow.org/
--- __Installation__: `npm install -g flow-bin`
lspconfig.flow = add_lsp {
  name = "flow",
  language = "javascript",
  file_patterns = { "%.js$", "%.jsx$" },
  command = { "flow", "lsp" },
  verbose = false
}

---# gopls
--- __Status__: Works
--- __Site__: https://pkg.go.dev/golang.org/x/tools/gopls
--- __Installation__: `go get -u golang.org/x/tools/gopls`
lspconfig.gopls = add_lsp {
  name = "gopls",
  language = "go",
  file_patterns = { "%.go$" },
  command = { "gopls" },
  verbose = false
}

---# groovy-language-server
--- __Status__: Untested
--- __Site__: https://github.com/prominic/groovy-language-server
--- __Installation__:
--- ```sh
--- mkdir ~/lsp
--- cd ~/lsp
--- git clone https://github.com/prominic/groovy-language-server.git
--- cd ~/lsp/groovy-language-server
--- ./gradlew build
--- ```
lspconfig.groovyls = add_lsp {
  name = "groovy-language-server",
  language = "groovy",
  file_patterns = { "%.groovy$", "%.gvy$", "%.gy$", "%.gsh$" },
  -- command = { "java", "-jar", "/path/to/groovy-language-server-all.jar" },
  command = { "groovy-language-server" },
  verbose = false
}

---# haskell-language-server
--- __Status__: Untested
--- __Site__: https://github.com/haskell/haskell-language-server
--- __Installation__: `ghcup install hls`
--- or https://github.com/haskell/haskell-language-server#installation
lspconfig.hls = add_lsp {
  name = "haskell-language-server",
  language = "haskell",
  file_patterns = { "%.hs$", "%.lhs$" },
  command = { 'haskell-language-server-wrapper', '--lsp' },
  verbose = false
}

---# vscode-html-languageserver
--- __Status__: Untested
--- __Site__: https://github.com/vscode-langservers/vscode-html-languageserver-bin
--- __Installation__: `npm install --global vscode-html-languageserver-bin`
lspconfig.html = add_lsp {
  name = "html-languageserver",
  language = "html",
  file_patterns = { "%.html$" },
  command = { 'html-languageserver', '--stdio' },
  verbose = false
}

---# intelephense
--- __Status__: Works
--- __Site__: https://github.com/bmewburn/intelephense-docs
--- __Installation__: `npm -g install intelephense`
--- __Note__: Set your license and storage by passing the init_options as follows:
--- ```lua
--- init_options = { licenceKey = "...", storagePath = "/some/path"}
--- ```
lspconfig.intelephense = add_lsp {
  name = "intelephense",
  language = "php",
  file_patterns = { "%.php$" },
  command = { "intelephense", "--stdio" },
  verbose = false
}

---# vscode-json-languageserver
--- __Status__: Untested
--- __Site__: https://www.npmjs.com/package/vscode-json-languageserver
--- __Installation__: `npm install -g vscode-json-languageserver`
lspconfig.jsonls = add_lsp {
  name = "vscode-json-languageserver",
  language = "json",
  file_patterns = { "%.json$", "%.jsonc$" },
  command = { 'vscode-json-languageserver', '--stdio' },
  verbose = false
}

---# kotlin-language-server
--- __Status__: Untested
--- __Site__: https://github.com/fwcd/kotlin-language-server
--- __Installation__: https://github.com/fwcd/kotlin-language-server/releases
lspconfig.kotlin_language_server = add_lsp {
  name = "kotlin-language-server",
  language = "kotlin",
  file_patterns = { "%.kt$", "%.kts$", "%.ktm$" },
  command = { 'kotlin-language-server' },
  verbose = false
}

---# nil
--- __Status__:       Works
--- __Site__:         https://github.com/oxalica/nil
--- __Installation__: cargo install --git https://github.com/oxalica/nil nil
--- __Note__:         nix >= 2.4 needs to be installed
lspconfig.nillsp = add_lsp {
  name = "nil",
  language = "nix",
  file_patterns = { "%.nix$" },
  command = { "nil" },
  verbose = false
}

---# nimlsp
--- __Status__: Works
--- __Site__: https://github.com/PMunch/nimlsp
--- __Installation__: `nimble install nimlsp`
lspconfig.nimlsp = add_lsp {
  name = "nimlsp",
  language = "Nim",
  file_patterns = { "%.nim$" },
  command = { "nimlsp" },
  requests_per_second = 25,
  requests_in_chunks = true,
  incremental_changes = false,
  verbose = false
}

---# ocaml-lsp
--- __Status__: Reported working on https://github.com/jgmdev/lite-xl-lsp/issues/17
--- __Site__: https://github.com/ocaml/ocaml-lsp
--- __Installation__: https://github.com/ocaml/ocaml-lsp#installation
lspconfig.ocaml_lsp = add_lsp {
  name = "ocaml-lsp",
  language = "ocaml",
  file_patterns = { "%.ml$", "%.mli$" },
  command = { "ocamllsp" },
  id_not_extension = true,
  verbose = false
}

---# omnisharp
--- __Status__: Works but, freeze on large projects (https://github.com/ppy/osu.git)
--- __Site__: https://github.com/OmniSharp/omnisharp-roslyn
--- __Installation__: See official website for instructions
lspconfig.omnisharp = add_lsp {
  name = "omnisharp",
  language = "c#",
  file_patterns = { "%.cs$" },
  command = { "omnisharp", "-lsp" },
  verbose = false
}

--# pyright
--- __Status__: Works
--- __Site__: https://github.com/microsoft/pyright
--- __Installation__: `pip install pyright`  or `npm install -g pyright`
lspconfig.pyright = add_lsp {
  name = "pyright",
  language = "python",
  file_patterns = { "%.py$" },
  command = { "pyright-langserver",  "--stdio" },
  verbose = false
}

---# python-language-server
--- __Status__: Works (deprecated in favor of python-lsp-server)
--- __Site__: https://github.com/palantir/python-language-server
--- __Installation__: `pip install python-language-server`
--- __Note__: Also don't forget to install any additional optional dependencies
--- for additional features (see official site for details).
lspconfig.pyls = add_lsp {
  name = "pyls",
  language = "python",
  file_patterns = { "%.py$" },
  command = { 'pyls' },
  verbose = false
}

---# svelte-language-server
--- __Status__: Works
--- __Site__: https://github.com/sveltejs/language-tools/tree/master/packages/language-server
--- __Installation__: `npm install -g svelte-language-server`
--- __Note__: Also don't forget to install any additional optional dependencies
--- for additional features (see official site for details).
lspconfig.sveltels = add_lsp {
  name = "sveltels",
  language = "svelte",
  file_patterns = { "%.svelte$" },
  command = { 'svelteserver', '--stdio' },
  verbose = false
}

---# python-lsp-server
--- __Status__: Works
--- __Site__: https://github.com/python-lsp/python-lsp-server
--- __Installation__: `pip install python-lsp-server`
--- __Note__: Also don't forget to install any additional optional dependencies
--- for additional features (see official site for details).
lspconfig.pylsp = add_lsp {
  name = "pylsp",
  language = "python",
  file_patterns = { "%.py$" },
  command = { 'pylsp' },
  verbose = false
}

---# Rust Language Server
--- __Status__: Works
--- __Site__: https://github.com/rust-lang/rls
--- __Installation__: Install rust on your system
lspconfig.rls = add_lsp {
  name = "rust-language-server",
  language = "rust",
  file_patterns = { "%.rs$" },
  command = { 'rls' },
  verbose = false
}

---# Rust Analyzer
--- __Status__: Works
--- __Site__: https://rust-analyzer.github.io/
--- __Installation__: See official website for instructions
lspconfig.rust_analyzer = add_lsp {
  name = "rust-analyzer",
  language = "rust",
  file_patterns = { "%.rs$" },
  command = { 'rust-analyzer' },
  verbose = false
}

---# Solargraph
--- __Status__: Untested
--- __Site__: https://github.com/castwide/solargraph
--- __Installation__: `gem install solargraph`
lspconfig.solargraph = add_lsp {
  name = "solargraph",
  language = "ruby",
  file_patterns = { "%.rb$" },
  command = { 'solargraph', 'stdio' },
  verbose = false
}

---# sql-language-server
--- __Status__: Untested
--- __Site__: https://github.com/joe-re/sql-language-server
--- __Installation__: `npm i -g sql-language-server`
lspconfig.sqlls = add_lsp {
  name = "sql-language-server",
  language = "sql",
  file_patterns = { "%.sql$" },
  command = { 'sql-language-server', 'up', '--method', 'stdio' },
  verbose = false
}

---# lua-language-server
--- __Status__: Works
--- __Site__: https://github.com/sumneko/lua-language-server
--- __Installation__: https://github.com/sumneko/lua-language-server/wiki/Build-and-Run-(Standalone)
lspconfig.sumneko_lua = add_lsp {
  name = "lua-language-server",
  language = "lua",
  file_patterns = { "%.lua$" },
  command = { 'lua-language-server' },
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
        library = {
          DATADIR
        },
        maxPreload = 2000,
        preloadFileSize = 1000
      },
      telemetry = {
        enable = false
      }
    }
  }
}

---# typescript-language-server
--- __Status__: Untested
--- __Site__: https://github.com/typescript-language-server/typescript-language-server
--- __Installation__: `npm install -g typescript-language-server typescript`
lspconfig.tsserver = add_lsp {
  name = "typescript-language-server",
  language = "javascript",
  file_patterns = { "%.jsx?$", "%.cjs$", "%.mjs$", "%.tsx?$" },
  command = { 'typescript-language-server', '--stdio' },
  verbose = false
}

---# vim-language-server
--- __Status__: Untested
--- __Site__: https://github.com/iamcco/vim-language-server
--- __Installation__: `npm install -g vim-language-server`
lspconfig.vimls = add_lsp {
  name = "vim-language-server",
  language = "vim",
  file_patterns = { "%.vim$" },
  command = { 'vim-language-server', '--stdio' },
  verbose = false
}

---# vlang-vls
--- __Status__: Initializes but doesn't responds to completion requests
--- at least it helped improve lit-xl-lsp requests mechanism
--- __Site__: https://github.com/vlang/vls
--- __Installation__:
--- ```sh
--- git clone https://github.com/vlang/vls.git vls && cd vls/
--- v -prod cmd/vls
--- mv cmd/vls vlang-vls
--- ```
lspconfig.vls = add_lsp {
  name = "vlang-vls",
  language = "v",
  file_patterns = { "%.v$" },
  command = { 'vlang-vls' },
  verbose = false
}

---# yaml-language-server
--- __Status__: Untested
--- __Site__: https://github.com/redhat-developer/yaml-language-server
--- __Installation__: See official website for instructions
lspconfig.yamlls = add_lsp {
  name = "yaml-language-server",
  language = "yaml",
  file_patterns = { "%.yml$", "%.yaml$" },
  command = { 'yaml-language-server', '--stdio' },
  verbose = false
}

---# Zig Language Server
--- __Status__: Untested
--- __Site__: https://github.com/zigtools/zls
--- __Installation__: See official website for instructions
lspconfig.zls = add_lsp {
  name = "zls",
  language = "zig",
  file_patterns = { "%.zig$" },
  command = { 'zls' },
  verbose = false
}


return lspconfig
