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
local util = require "plugins.lsp.util"
local config = require "core.config"
local snippets = pcall(require, "plugins.snippets") and config.plugins.lsp.snippets

---Options that can be passed to a LSP server to overwrite the defaults.
---@class lsp.config.options
---
---Name of server.
---@field name string
---Main language, eg: C.
---Can be a string or a table.
---If the table is empty, the file extension will be used instead.
---The table should be an array of tables containing `id` and `pattern`.
---The `pattern` will be matched with the file path.
---Will use the `id` of the first `pattern` that matches.
---If no pattern matches, the file extension will be used instead.
---@field language string | lsp.server.languagematch[]
---File types that are supported by this server.
---@field file_patterns string[]
---LSP command and optional arguments.
---@field command table<integer,string|table>
---On Windows, avoid running the LSP server with cmd.exe.
---@field windows_skip_cmd? boolean
---Enviroment variables to set for the server command.
---@field env? table<string, string>
---Seconds before closing the server when not needed anymore.
---@field quit_timeout? number
---Optional table of settings to pass into the LSP.
---Note that also having a settings.json or settings.lua in
---your workspace directory with a table of settings is supported.
---@field settings? table<string,any>
---Optional table of initializationOptions for the LSP.
---@field init_options? table<string,any>
---Optional table of capabilities that will be merged with our default one.
---@field custom_capabilities? table<string,any>
---Function called when the server has been started.
---@field on_start? fun(server: lsp.server)
---Set by default to 16 should only be modified if having issues with a server.
---@field requests_per_second? integer
---Some servers like bash language server support incremental changes
---which are more performant but don't advertise it, set to true to force
---incremental changes even if server doesn't advertise them.
---@field incremental_changes? boolean
---Set to true to debug the lsp client when developing it.
---@field verbose? boolean

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
      local merged_options = util.deep_merge(options, user_options)
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
  language = "shellscript",
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
  language = {
    { id = "c",   pattern = "%.[ch]$"     },
    { id = "cpp", pattern = "%.[ch]pp$"   },
    { id = "cpp", pattern = "%.[CH]$"     },
    { id = "cpp", pattern = "%.[ch]%+%+$" },
  },
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
  language = {
    { id = "c",   pattern = "%.[ch]$"     },
    { id = "cpp", pattern = "%.[ch]pp$"   },
    { id = "cpp", pattern = "%.[CH]$"     },
    { id = "cpp", pattern = "%.[ch]%+%+$" },
  },
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

---# Crystal
--- __Status__: Works
--- __Site__: https://github.com/elbywan/crystalline
--- __Installation__: 'paru -S crystalline-bin'
lspconfig.crystalline = add_lsp {
  name = "crystalline",
  language = "crystal",
  file_patterns = { "%.cr$" },
  command = { "crystalline", "--stdio" },
  verbose = false
}

---# vscode-css-languageserver
--- __Status__: Works
--- __Site__: https://github.com/vscode-langservers/vscode-css-languageserver-bin
--- __Installation__: `npm install -g vscode-css-languageserver-bin`
---                   or `pacman -S vscode-css-languageserver`
lspconfig.cssls = add_lsp {
  name = "css-languageserver",
  language = "css",
  file_patterns = { "%.css$", "%.less$", "%.sass$" },
  command = {
    {
      'vscode-css-languageserver',
      'vscode-css-language-server',
      'css-languageserver'
    },
    '--stdio'
  },
  fake_snippets = true,
  verbose = false
}

---# D
--- __Status__: Works
--- __Site__: https://github.com/Pure-D/serve-d
--- __Installation__: https://github.com/Pure-D/serve-d?tab=readme-ov-file#installation
lspconfig.serve_d = add_lsp {
  name = "serve_d",
  language = "d",
  file_patterns = { "%.di?$" },
  command = { "serve-d" },
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

---# Deno
--- __Status__: Works
--- __Site__: https://deno.land/manual/advanced/language_server
--- __Installation__: Provided in Deno runtime
lspconfig.deno = add_lsp {
  name = "deno",
  language = {
    { id = "javascript",      pattern = "%.js$"  },
    { id = "javascriptreact", pattern = "%.jsx$" },
    { id = "typescript",      pattern = "%.ts$"  },
    { id = "typescriptreact", pattern = "%.tsx$" },
  },
  file_patterns = { "%.[tj]s$", "%.[tj]sx$" },
  command = { 'deno', 'lsp' },
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
          hosts = {
            ["https://deno.land/"] = true,
            ["https://nest.land/"] = true,
            ["https://crux.land/"] = true
          }
        },
        autoImports = true
      }
    }
  }
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

---# Elixir
--- __Status__: Works
--- __Site__: https://github.com/elixir-lsp/elixir-ls
--- __Installation__: 'paru -S elixir-ls'
lspconfig.elixirls = add_lsp {
  name = "elixirls",
  language = "elixir",
  file_patterns = { "%.ex$", "%.exs$" },
  command = { "elixir-ls" },
  verbose = false
}

---# Elm
--- __Status__: Untested
--- __Site__: https://github.com/elm-tooling/elm-language-server
--- __Installation__: `paru -S elm-language-server`
lspconfig.elmls = add_lsp {
  name = "elmls",
  language = "elm",
  file_patterns = { "%.elm$" },
  command = { "elm-language-server" },
  verbose = false
}

---# Erlang
--- __Status__: Untested
--- __Site__: https://github.com/erlang-ls/erlang_ls
--- __Installation__: ?
lspconfig.erlangls = add_lsp {
  name = "erlangls",
  language = "erlang",
  file_patterns = { "%.erl$", "%.hrl$" },
  command = { 'Erlang', 'LS', '-t', 'stdio' },
  verbose = false
}

---# Fennel - fennel-ls
--- __Status__: Works
--- __Site__: https://git.sr.ht/~xerool/fennel-ls
--- __Installation__: https://git.sr.ht/~xerool/fennel-ls/tree/main/docs/manual.md#installation
lspconfig.fennells = add_lsp {
  name = "fennel-ls",
  language = "fennel",
  file_patterns = { "%.fnl$" },
  command = { "fennel-ls" },
  verbose = false
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

---# Fortran - fortls
--- __Status__: Works
--- __Site__: https://fortls.fortran-lang.org/index.html
--- __Installation__: `paru -S fortls`
lspconfig.fortls = add_lsp {
  name = "fortls",
  language = "fortran",
  file_patterns = { "%.f$", "%.f90$", "%.f95$", "%.F$" },
  command = { "fortls", "--notify_init" },
  verbose = false
}

---# Gleam
--- __Status__: Works (the gleam lsp itself acts kinda weird)
--- __Site__: https://gleam.run/
--- __Installation__: Included with the gleam compiler binary
lspconfig.gleam = add_lsp {
	name = "gleam",
	language = "gleam",
	file_patterns = { "%.gleam$" },
	command = { "gleam", "lsp" },
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
--- __Status__: Works
--- __Site__: https://github.com/vscode-langservers/vscode-html-languageserver-bin
--- __Installation__: `npm install --global vscode-html-languageserver-bin`
---                   or `pacman -S vscode-html-languageserver`
lspconfig.html = add_lsp {
  name = "html-languageserver",
  language = "html",
  file_patterns = { "%.html$" },
  command = {
    {
      'vscode-html-languageserver',
      'vscode-html-language-server',
      'html-languageserver'
    },
    '--stdio'
  },
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

---# java
--- __Status__: Works
--- __Site__: https://github.com/eclipse/eclipse.jdt.ls
lspconfig.jdtls = add_lsp {
  name = "jdtls",
  language = "java",
  file_patterns = { "%.java$" },
  command = { "jdtls" },
  verbose = false
}

---# Scala
--- __Status__: Works
--- __Site__: https://scalameta.org/metals/
--- __Installation__: `paru -S metals`
lspconfig.metals = add_lsp {
  name = "metals",
  language = "scala",
  file_patterns = { "%.scala$" },
  command = { "metals" },
  verbose = false
}

---# vscode-json-languageserver
--- __Status__: Works
--- __Site__: https://www.npmjs.com/package/vscode-json-languageserver
--- __Installation__: `npm install -g vscode-json-languageserver`
---                   or `pacman -S vscode-json-languageserver`
lspconfig.jsonls = add_lsp {
  name = "json-languageserver",
  language = "json",
  file_patterns = { "%.json$", "%.jsonc$" },
  command = {
    {
      'vscode-json-languageserver',
      'vscode-json-language-server',
      'json-languageserver',
    },
    '--stdio'
  },
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

---# XML
--- __Status__: Works
--- __Site__: https://github.com/eclipse/lemminx
--- __Installation__: 'paru -S lemminx'
lspconfig.lemminx = add_lsp {
  name = "lemminx",
  language = "xml",
  file_patterns = { "%.xml$" },
  command = { "lemminx" },
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
  language = "nim",
  file_patterns = { "%.nim$" },
  command = { "nimlsp" },
  requests_per_second = 25,
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
  verbose = false
}

---# Odin
--- __Status__: Works
--- __Site__: https://github.com/DanielGavin/ols
--- __Installation__: `paru -S odinls`
lspconfig.odinls = add_lsp {
  name = "odinls",
  language = "odin",
  file_patterns = { "%.odin$" },
  command = { "ols" },
  verbose = false
}

---# omnisharp
--- __Status__: Works but, freeze on large projects (https://github.com/ppy/osu.git)
--- __Site__: https://github.com/OmniSharp/omnisharp-roslyn
--- __Installation__: See official website for instructions
lspconfig.omnisharp = add_lsp {
  name = "omnisharp",
  language = "csharp",
  file_patterns = { "%.cs$" },
  command = { "omnisharp", "-lsp" },
  verbose = false
}

---# PerlNavigator - Perl
--- __Status__: Works
--- __Site__: https://github.com/bscan/PerlNavigator
--- __Installation__: `paru -S perlnavigator`
lspconfig.perlnavigator = add_lsp {
  name = "perlnavigator",
  language = "perl",
  file_patterns = { "%.pl$", "%.pm$" },
  command = { "perlnavigator" },
  settings = {
    perlnavigator = {
      -- The following setting is only needed if you want to set a custom perl path. It already defaults to "perl"
      perlPath = "perl"
    }
  }
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

---# quick-lint-js
--- __Status__: Works
--- __Site__: https://github.com/quick-lint/quick-lint-js
--- __Installation__: Arch Linux: `yay -Syu quick-lint-js`
lspconfig.quicklintjs = add_lsp {
  name = "quick-lint-js",
  language = {
    { id = "javascriptreact",      pattern = "%.jsx$"   },
    { id = "javascript",           pattern = "%.js$"    },
    { id = "typescriptdefinition", pattern = "%.d%.ts$" },
    { id = "typescriptsource",     pattern = "%.ts$"    },
    { id = "typescriptreact",      pattern = "%.tsx$"   },
    { id = "typescript",           pattern = ".*"       },
  },
  file_patterns = { "%.[mc]?jsx?$", "%.tsx?$" },
  command = { "quick-lint-js", "--lsp-server" },
  verbose = false
}

---# R
-- __Status__: Works
-- __Site__:https://github.com/REditorSupport/languageserver#installation
-- __Installation__: `paru -S r-languageserver`
lspconfig.rlanguageserver = add_lsp {
  name = "rlanguageserver",
  language = "r",
  file_patterns = { "%.r$", "%.R$" },
  command = {'R', '--slave', '-e', 'languageserver::run()'},
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

---# Ruby LSP
--- __Status__: Untested
--- __Site__: https://github.com/Shopify/ruby-lsp
--- __Instalation__: gem install ruby-lsp
--- __Note__: Also don't forget to install any additional optional dependecies
--- for additional features (see official site for details).
lspconfig.ruby_lsp = add_lsp {
  name = "ruby-lsp",
  language = "ruby",
  file_patterns = { "%.rb$" },
  command = { 'ruby-lsp' },
  -- Override command to one below if You want to use it with bundler
  -- command = { 'bundle', 'exec', 'ruby-lsp'},
  incremental_changes = true,
  init_options = {
    enabledFeatures = {
      "codeActions",
      "diagnostics",
      -- semanticHighlighting should be use only when running with bundle at the moment
      --"semanticHighlighting",
      "documentHighlights",
      "documentLink",
      "documentSymbols",
      "foldingRanges",
      "formatting",
      "hover",
      "inlayHint",
      "onTypeFormatting",
      "selectionRanges",
      "completion"
      },
    -- enableExperimentalFeatures = true,
    -- rubyVersionManager = "",
  },
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
--- __Status__: Works
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
        callSnippet = snippets and "Replace" or "Disable",
        keywordSnippet = snippets and "Replace" or "Disable"
      },
      develop = {
        enable = false,
        debuggerPort = 11412,
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
          DATADIR,
          USERDIR
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

---# Tailwind CSS
--- __Status__: Broken (freezes when writing class names inside html doc, requires new implementation of json.lua)
--- __Site__: https://github.com/tailwindlabs/tailwindcss-intellisense
--- __Installation__: Arch Linux: `sudo pacman -S tailwindcss-language-server`
lspconfig.tailwindcss = add_lsp {
  name = "tailwindcss",
  language = "html",
  file_patterns = { "%.html$"},
  command = {'tailwindcss-language-server', '--stdio'},
  fake_snippets = true,
  verbose = false
}

---# LaTeX Texlab language server
--- __Status__: Works
--- __Site__: https://github.com/latex-lsp/texlab
--- __Installation__: git clone https://github.com/latex-lsp/texlab.git , then inside the texlab folder, run: cargo build --release
--- __Note__: Rust has to be installed
lspconfig.texlab = add_lsp {
  name = "texlab",
  language = "latex",
  file_patterns = { "%.tex$", "%.bib$" , "%.dtx$", "%.sty$", "%.ins$", "%.cls$" },
  command = { 'texlab' }
}

---# TOML - Taplo
--- __Status__: Works
--- __Site__: https://github.com/tamasfe/taplo
--- __Installation__: 'sudo pacman -S taplo-cli'
lspconfig.taplo = add_lsp {
  name = "taplo",
  language = "toml",
  file_patterns = { "%.toml$" },
  command = { "taplo", "lsp", "stdio" },
  verbose = false
}

---# typescript-language-server
--- __Status__: Works
--- __Site__: https://github.com/typescript-language-server/typescript-language-server
--- __Installation__: `npm install -g typescript-language-server typescript`
lspconfig.tsserver = add_lsp {
  name = "typescript-language-server",
  language = {
    { id = "javascript",      pattern = "%.[cm]?js$"  },
    { id = "javascriptreact", pattern = "%.jsx$"      },
    { id = "typescript",      pattern = "%.ts$"       },
    { id = "typescriptreact", pattern = "%.tsx$"      },
  },
  file_patterns = { "%.jsx?$", "%.[cm]js$", "%.tsx?$" },
  command = { 'typescript-language-server', '--stdio' },
  verbose = false
}

---# typst-lsp 
--- __Status: Works
--- __Site__: https://github.com/nvarner/typst-lsp
--- __Instalation__: `yay typst-lsp-bin`
lspconfig.typst_lsp = add_lsp {
  name = "typst-lsp",
  language = "typst",
  file_patterns = { "%.typ$" },
  command = { 'typst-lsp' },
  verbose = false,
  settings = {
    exportPdf = "never", -- Choose onType, onSave or never.
    experimentalFormatterMode = "on" -- Choose on, or off
  }
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

---# V
--- __Status__: Works
--- __Site__: https://github.com/vlang/v-analyzer
--- __Installation__: https://github.com/vlang/v-analyzer?tab=readme-ov-file#installation
lspconfig.v_analyzer = add_lsp {
  name = "v_analyzer",
  language = "v",
  file_patterns = { "%.vv?$", "%.vsh$" },
  command = { "v-analyzer", "--stdio" },
  verbose = false
}

---# Vala - vala-language-server
--- __Status__: Works
--- __Site__: https://github.com/vala-lang/vala-language-server
--- __Installation__: `paru -S vala-language-server`
lspconfig.vala_ls = add_lsp {
  name = "vala_ls",
  language = "vala",
  file_patterns = { "%.vala$" },
  command = { "vala-language-server" },
  verbose = false
}

---# vlang-vls
--- __Status__: doesn't respond to completion requests (no longer officially maintained in favor of v-analyzer)
--- __Site__: https://github.com/vlang/vls
--- __Installation__: https://github.com/vlang/vls?tab=readme-ov-file#installation
lspconfig.vls = add_lsp {
  name = "vlang-vls",
  language = "v",
  file_patterns = { "%.vv?$", "%.vsh$" },
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
