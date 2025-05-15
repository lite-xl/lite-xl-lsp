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

-- NOTE: as of 15/05/2025, the LSP-server-specific naming conventions used here are described in https://github.com/neovim/nvim-lspconfig/blob/ac1dfbe3b60e5e23a2cff90e3bd6a3bc88031a57/CONTRIBUTING.md#walkthrough:~:text=When%20choosing%20a,(jsonnet_ls).

---# Bash - bash_ls
--- __Status__: Works
--- __Site__: https://github.com/bash-lsp/bash-language-server
--- __Installation__: https://github.com/bash-lsp/bash-language-server?tab=readme-ov-file#installation
lspconfig.bash_ls = add_lsp {
  name = "bash_ls",
  language = "shellscript",
  file_patterns = { "%.sh$" },
  command = { "bash-language-server", "start" },
  incremental_changes = true,
  verbose = false
}

---# C/C++ - ccls
--- __Status__: Works
--- __Site__: https://github.com/MaskRay/ccls/
--- __Installation__: https://github.com/MaskRay/ccls/wiki/Install
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

---# C/C++ - clangd
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

---# Clojure - clojure_lsp
--- __Status__: Works
--- __Site__: https://clojure-lsp.github.io/
--- __Installation__: https://clojure-lsp.github.io/clojure-lsp/installation/
lspconfig.clojure_lsp = add_lsp {
  name = "clojure_lsp",
  language = "clojure",
  file_patterns = { "%.clj$", "%.cljs$", "%.clc$", "%.edn$" },
  command = { "clojure-lsp" },
  verbose = false
}

---# Crystal - crystalline
--- __Status__: Works
--- __Site__: https://github.com/elbywan/crystalline
--- __Installation__: https://github.com/elbywan/crystalline?tab=readme-ov-file#installation
lspconfig.crystalline = add_lsp {
  name = "crystalline",
  language = "crystal",
  file_patterns = { "%.cr$" },
  command = { "crystalline", "--stdio" },
  verbose = false
}

---# CSS - vscode_css_ls
--- __Status__: Works
--- __Site__: https://github.com/vscode-langservers/vscode-css-languageserver-bin
--- __Installation__: https://github.com/vscode-langservers/vscode-css-languageserver-bin?tab=readme-ov-file#installing
lspconfig.vscode_css_ls = add_lsp {
  name = "vscode_css_ls",
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

---# C# - omnisharp
--- __Status__: Works, but freezes on large projects (https://github.com/ppy/osu.git)
--- __Site__: https://github.com/OmniSharp/omnisharp-roslyn
--- __Installation__: https://github.com/OmniSharp/omnisharp-roslyn?tab=readme-ov-file#downloading-omnisharp
lspconfig.omnisharp = add_lsp {
  name = "omnisharp",
  language = "csharp",
  file_patterns = { "%.cs$" },
  command = { "omnisharp", "-lsp" },
  verbose = false
}

---# D - serve_d
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

---# Dart - dartls
--- __Status__: Works
--- __Site__: https://github.com/dart-lang/sdk
--- __Installation__: Provided by dart sdk
lspconfig.dartls = add_lsp {
  name = "dartls",
  language = "dart",
  file_patterns = { "%.dart$" },
  command = { "dart", "language-server", "--protocol=lsp" },
  verbose = false
}

---# Deno - deno_ls
--- __Status__: Works
--- __Site__: https://deno.land/manual/advanced/language_server
--- __Installation__: Provided in Deno runtime
lspconfig.deno_ls = add_lsp {
  name = "deno_ls",
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

---# Dockerfile - dockerfile_ls_nodejs
--- __Status__: Untested
--- __Site__: https://github.com/rcjsuen/dockerfile-language-server-nodejs
--- __Installation__: https://github.com/rcjsuen/dockerfile-language-server?tab=readme-ov-file#installation-instructions
lspconfig.dockerfile_ls_nodejs = add_lsp {
  name = "dockerfile_ls_nodejs",
  language = "dockerfile",
  file_patterns = { "Dockerfile$" },
  command = { "docker-langserver", "--stdio" },
  verbose = false
}

---# Elixir - elixir_ls
--- __Status__: Works
--- __Site__: https://github.com/elixir-lsp/elixir-ls
--- __Installation__: https://github.com/elixir-lsp/elixir-ls?tab=readme-ov-file#detailed-installation-instructions
lspconfig.elixir_ls = add_lsp {
  name = "elixir_ls",
  language = "elixir",
  file_patterns = { "%.ex$", "%.exs$" },
  command = { "elixir-ls" },
  verbose = false
}

---# Elm - elm_ls
--- __Status__: Works
--- __Site__: https://github.com/elm-tooling/elm-language-server
--- __Installation__: https://github.com/elm-tooling/elm-language-server?tab=readme-ov-file#installation
lspconfig.elm_ls = add_lsp {
  name = "elm_ls",
  language = "elm",
  file_patterns = { "%.elm$" },
  command = { "elm-language-server" },
  verbose = false
}

---# Erlang - erlang_ls
--- __Status__: Works
--- __Site__: https://github.com/erlang-ls/erlang_ls
--- __Installation__: https://github.com/erlang-ls/erlang_ls?tab=readme-ov-file#quickstart
lspconfig.erlang_ls = add_lsp {
  name = "erlang_ls",
  language = "erlang",
  file_patterns = { "%.erl$", "%.hrl$" },
  command = { 'Erlang', 'LS', '-t', 'stdio' },
  verbose = false
}

---# Fennel - fennel_ls
--- __Status__: Works
--- __Site__: https://git.sr.ht/~xerool/fennel-ls
--- __Installation__: https://git.sr.ht/~xerool/fennel-ls/tree/main/docs/manual.md#installation
lspconfig.fennel_ls = add_lsp {
  name = "fennel_ls",
  language = "fennel",
  file_patterns = { "%.fnl$" },
  command = { "fennel-ls" },
  verbose = false
}

---# Fortran - fort_ls
--- __Status__: Works
--- __Site__: https://fortls.fortran-lang.org/index.html
--- __Installation__: https://fortls.fortran-lang.org/quickstart.html
lspconfig.fort_ls = add_lsp {
  name = "fort_ls",
  language = "fortran",
  file_patterns = { "%.f$", "%.f90$", "%.f95$", "%.F$" },
  command = { "fortls", "--notify_init" },
  verbose = false
}

---# Gleam - gleam_ls
--- __Status__: Works (the gleam lsp itself acts kinda weird)
--- __Site__: https://gleam.run/
--- __Installation__: Included with the gleam compiler binary
lspconfig.gleam_ls = add_lsp {
	name = "gleam_ls",
	language = "gleam",
	file_patterns = { "%.gleam$" },
	command = { "gleam", "lsp" },
	verbose = false
}

---# Go - gopls
--- __Status__: Works
--- __Site__: https://pkg.go.dev/golang.org/x/tools/gopls
--- __Installation__: https://pkg.go.dev/golang.org/x/tools/gopls#readme-installation
lspconfig.gopls = add_lsp {
  name = "gopls",
  language = "go",
  file_patterns = { "%.go$" },
  command = { "gopls" },
  verbose = false
}

---# Groovy - groovy_ls
--- __Status__: Untested
--- __Site__: https://github.com/prominic/groovy-language-server
--- __Installation__: either install from your OS's package manager or build from source
--- __Note__: how to build from source: https://github.com/GroovyLanguageServer/groovy-language-server?tab=readme-ov-file#build
lspconfig.groovy_ls = add_lsp {
  name = "groovy_ls",
  language = "groovy",
  file_patterns = { "%.groovy$", "%.gvy$", "%.gy$", "%.gsh$" },
  -- command = { "java", "-jar", "/path/to/groovy-language-server-all.jar" },
  command = { "groovy-language-server" },
  verbose = false
}

---# Haskell - haskell_ls
--- __Status__: Untested
--- __Site__: https://github.com/haskell/haskell-language-server
--- __Installation__: https://haskell-language-server.readthedocs.io/en/latest/installation.html
lspconfig.haskell_ls = add_lsp {
  name = "haskell_ls",
  language = "haskell",
  file_patterns = { "%.hs$", "%.lhs$" },
  command = { 'haskell-language-server-wrapper', '--lsp' },
  verbose = false
}

---# HTML - vscode_html_ls
--- __Status__: Works
--- __Site__: https://github.com/vscode-langservers/vscode-html-languageserver-bin
--- __Installation__: https://github.com/vscode-langservers/vscode-html-languageserver-bin?tab=readme-ov-file#installing
lspconfig.vscode_html_ls = add_lsp {
  name = "vscode_html_ls",
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

---# Java - jdtls
--- __Status__: Works
--- __Site__: https://github.com/eclipse/eclipse.jdt.ls
--- __Installation__: https://github.com/eclipse-jdtls/eclipse.jdt.ls?tab=readme-ov-file#installation
lspconfig.jdtls = add_lsp {
  name = "jdtls",
  language = "java",
  file_patterns = { "%.java$" },
  command = { "jdtls" },
  verbose = false
}

---# Javascript - flow
--- __Status__: Untested
--- __Site__: https://flow.org/
--- __Installation__: https://flow.org/en/docs/install/
lspconfig.flow = add_lsp {
  name = "flow",
  language = "javascript",
  file_patterns = { "%.js$", "%.jsx$" },
  command = { "flow", "lsp" },
  verbose = false
}

---# Javascript - quick_lint_js
--- __Status__: Works
--- __Site__: https://github.com/quick-lint/quick-lint-js
--- __Installation__: https://github.com/quick-lint/quick-lint-js?tab=readme-ov-file#installing
lspconfig.quick_lint_js = add_lsp {
  name = "quick_lint_js",
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

---# JSON - vscode_json_ls
--- __Status__: Works
--- __Site__: https://www.npmjs.com/package/vscode-json-languageserver
--- __Installation__: https://www.npmjs.com/package/vscode-json-languageserver#integrate
lspconfig.vscode_json_ls = add_lsp {
  name = "vscode_json_ls",
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

---# Kotlin - kotlin_ls
--- __Status__: Works
--- __Site__: https://github.com/fwcd/kotlin-language-server
--- __Installation__: https://github.com/fwcd/kotlin-language-server?tab=readme-ov-file#getting-started
lspconfig.kotlin_ls = add_lsp {
  name = "kotlin_ls",
  language = "kotlin",
  file_patterns = { "%.kt$", "%.kts$", "%.ktm$" },
  command = { 'kotlin-language-server' },
  verbose = false
}

---# LaTeX - texlab
--- __Status__: Works
--- __Site__: https://github.com/latex-lsp/texlab
--- __Installation__: https://github.com/latex-lsp/texlab?tab=readme-ov-file#requirements
lspconfig.texlab = add_lsp {
  name = "texlab",
  language = "latex",
  file_patterns = { "%.tex$", "%.bib$" , "%.dtx$", "%.sty$", "%.ins$", "%.cls$" },
  command = { 'texlab' }
}

---# Lua - lua_ls
--- __Status__: Works
--- __Site__: https://github.com/sumneko/lua-language-server
--- __Installation__: https://github.com/sumneko/lua-language-server/wiki/Build-and-Run-(Standalone)
lspconfig.lua_ls = add_lsp {
  name = "lua_ls",
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

---# Markdown - marksman
--- __Status__: Works
--- __Site__: https://github.com/artempyanykh/marksman
--- __Installation__: https://github.com/artempyanykh/marksman/blob/main/docs/install.md
lspconfig.marksman = add_lsp {
  name = "marksman",
  language = "Markdown",
  file_patterns = { "%.md$" },
  command = { "marksman" },
  verbose = false
}

---# Nix - nil_ls
--- __Status__: Works
--- __Site__: https://github.com/oxalica/nil
--- __Installation__: https://github.com/oxalica/nil?tab=readme-ov-file#installation
lspconfig.nil_ls = add_lsp {
  name = "nil_ls",
  language = "nix",
  file_patterns = { "%.nix$" },
  command = { "nil" },
  verbose = false
}

---# Nim - nimlsp
--- __Status__: Works
--- __Site__: https://github.com/PMunch/nimlsp
--- __Installation__: https://github.com/PMunch/nimlsp?tab=readme-ov-file#installing-nimlsp
lspconfig.nimlsp = add_lsp {
  name = "nimlsp",
  language = "nim",
  file_patterns = { "%.nim$" },
  command = { "nimlsp" },
  requests_per_second = 25,
  incremental_changes = false,
  verbose = false
}

---# Ocaml - ocaml_lsp
--- __Status__: Reported working on https://github.com/jgmdev/lite-xl-lsp/issues/17
--- __Site__: https://github.com/ocaml/ocaml-lsp
--- __Installation__: https://github.com/ocaml/ocaml-lsp#installation
lspconfig.ocaml_lsp = add_lsp {
  name = "ocaml_lsp",
  language = "ocaml",
  file_patterns = { "%.ml$", "%.mli$" },
  command = { "ocamllsp" },
  verbose = false
}

---# Odin - ols
--- __Status__: Works
--- __Site__: https://github.com/DanielGavin/ols
--- __Installation__: https://github.com/DanielGavin/ols?tab=readme-ov-file#installation
lspconfig.ols = add_lsp {
  name = "ols",
  language = "odin",
  file_patterns = { "%.odin$" },
  command = { "ols" },
  verbose = false
}

---# Perl - perlnavigator
--- __Status__: Works
--- __Site__: https://github.com/bscan/PerlNavigator
--- __Installation__: https://github.com/bscan/PerlNavigator?tab=readme-ov-file#installation-for-other-editors
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

---# PHP - intelephense
--- __Status__: Works
--- __Site__: https://github.com/bmewburn/intelephense-docs
--- __Installation__: https://github.com/bmewburn/intelephense-docs/blob/master/installation.md
lspconfig.intelephense = add_lsp {
  name = "intelephense",
  language = "php",
  file_patterns = { "%.php$" },
  command = { "intelephense", "--stdio" },
  verbose = false
}

---# Python - python_ls_palantir
--- __Status__: Works (deprecated in favor of python-lsp-server)
--- __Site__: https://github.com/palantir/python-language-server
--- __Installation__: https://github.com/palantir/python-language-server?tab=readme-ov-file#installation
lspconfig.python_ls_palantir = add_lsp {
  name = "python_ls_palantir",
  language = "python",
  file_patterns = { "%.py$" },
  command = { 'pyls' },
  verbose = false
}

---# Python - python_ls
--- __Status__: Works
--- __Site__: https://github.com/python-lsp/python-lsp-server
--- __Installation__: https://github.com/python-lsp/python-lsp-server?tab=readme-ov-file#installation
lspconfig.python_ls = add_lsp {
  name = "python_ls",
  language = "python",
  file_patterns = { "%.py$" },
  command = { 'pylsp' },
  verbose = false
}

--# Python - pyright
--- __Status__: Works
--- __Site__: https://github.com/microsoft/pyright
--- __Installation__: https://microsoft.github.io/pyright/#/installation
lspconfig.pyright = add_lsp {
  name = "pyright",
  language = "python",
  file_patterns = { "%.py$" },
  command = { "pyright-langserver",  "--stdio" },
  verbose = false
}

---# R - r_ls
-- __Status__: Works
-- __Site__: https://github.com/REditorSupport/languageserver
-- __Installation__: https://github.com/REditorSupport/languageserver#installation
lspconfig.r_ls = add_lsp {
  name = "r_ls",
  language = "r",
  file_patterns = { "%.r$", "%.R$" },
  command = {'R', '--slave', '-e', 'languageserver::run()'},
  verbose = false
}

---# Ruby - ruby_lsp
--- __Status__: Untested
--- __Site__: https://github.com/Shopify/ruby-lsp
--- __Installation__: https://github.com/Shopify/ruby-lsp?tab=readme-ov-file#getting-started
lspconfig.ruby_lsp = add_lsp {
  name = "ruby_lsp",
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

---# Ruby - solargraph
--- __Status__: Untested
--- __Site__: https://github.com/castwide/solargraph
--- __Installation__: https://github.com/castwide/solargraph?tab=readme-ov-file#installation
lspconfig.solargraph = add_lsp {
  name = "solargraph",
  language = "ruby",
  file_patterns = { "%.rb$" },
  command = { 'solargraph', 'stdio' },
  verbose = false
}

---# Rust - rust_ls
--- __Status__: Works
--- __Site__: https://github.com/rust-lang/rls
--- __Installation__: https://github.com/rust-lang/rls?tab=readme-ov-file#setup
lspconfig.rust_ls = add_lsp {
  name = "rust_ls",
  language = "rust",
  file_patterns = { "%.rs$" },
  command = { 'rls' },
  verbose = false
}

---# Rust - rust_analyzer
--- __Status__: Works
--- __Site__: https://rust-analyzer.github.io/
--- __Installation__: https://rust-analyzer.github.io/manual.html#installation
lspconfig.rust_analyzer = add_lsp {
  name = "rust_analyzer",
  language = "rust",
  file_patterns = { "%.rs$" },
  command = { 'rust-analyzer' },
  verbose = false
}

---# Scala - metals
--- __Status__: Works
--- __Site__: https://scalameta.org/metals/
--- __Installation__: https://scalameta.org/metals/docs#installation
lspconfig.metals = add_lsp {
  name = "metals",
  language = "scala",
  file_patterns = { "%.scala$" },
  command = { "metals" },
  verbose = false
}

---# SQL - sql_ls
--- __Status__: Works
--- __Site__: https://github.com/joe-re/sql-language-server
--- __Installation__: https://github.com/joe-re/sql-language-server?tab=readme-ov-file#installation--how-to-setup
lspconfig.sql_ls = add_lsp {
  name = "sql_ls",
  language = "sql",
  file_patterns = { "%.sql$" },
  command = { 'sql-language-server', 'up', '--method', 'stdio' },
  verbose = false
}

---# Svelte - svelte_ls
--- __Status__: Works
--- __Site__: https://github.com/sveltejs/language-tools/tree/master/packages/language-server
--- __Installation__: `npm install -g svelte-language-server`
--- __Note__: https://github.com/sveltejs/language-tools/tree/master/packages/language-server#how-can-i-use-it
lspconfig.svelte_ls = add_lsp {
  name = "svelte_ls",
  language = "svelte",
  file_patterns = { "%.svelte$" },
  command = { 'svelteserver', '--stdio' },
  verbose = false
}

---# Tailwind CSS - tailwind_css_ls
--- __Status__: Broken (freezes when writing class names inside html doc, requires new implementation of json.lua)
--- __Site__: https://github.com/tailwindlabs/tailwindcss-intellisense
--- __Installation__: https://github.com/tailwindlabs/tailwindcss-intellisense?tab=readme-ov-file#installation
lspconfig.tailwind_css_ls = add_lsp {
  name = "tailwind_css_ls",
  language = "html",
  file_patterns = { "%.html$"},
  command = {'tailwindcss-language-server', '--stdio'},
  fake_snippets = true,
  verbose = false
}

---# TOML - taplo
--- __Status__: Works
--- __Site__: https://github.com/tamasfe/taplo
--- __Installation__: https://taplo.tamasfe.dev/cli/installation/binary.html
lspconfig.taplo = add_lsp {
  name = "taplo",
  language = "toml",
  file_patterns = { "%.toml$" },
  command = { "taplo", "lsp", "stdio" },
  verbose = false
}

---# Typescript - typescript_ls
--- __Status__: Works
--- __Site__: https://github.com/typescript-language-server/typescript-language-server
--- __Installation__: https://github.com/typescript-language-server/typescript-language-server?tab=readme-ov-file#installing
lspconfig.typescript_ls = add_lsp {
  name = "typescript_ls",
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

---# Typst - typst_lsp
--- __Status: Works
--- __Site__: https://github.com/nvarner/typst-lsp
--- __Installation__: https://github.com/nvarner/typst-lsp?tab=readme-ov-file#installation-guide
lspconfig.typst_lsp = add_lsp {
  name = "typst_lsp",
  language = "typst",
  file_patterns = { "%.typ$" },
  command = { 'typst-lsp' },
  verbose = false,
  settings = {
    exportPdf = "never", -- Choose onType, onSave or never.
    experimentalFormatterMode = "on" -- Choose on, or off
  }
}

---# V - v_analyzer
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

---# V - v_ls
--- __Status__: doesn't respond to completion requests (no longer officially maintained in favor of v-analyzer)
--- __Site__: https://github.com/vlang/vls
--- __Installation__: https://github.com/vlang/vls?tab=readme-ov-file#installation
lspconfig.v_ls = add_lsp {
  name = "v_ls",
  language = "v",
  file_patterns = { "%.vv?$", "%.vsh$" },
  command = { 'vlang-vls' },
  verbose = false
}

---# Vala - vala_ls
--- __Status__: Works
--- __Site__: https://github.com/vala-lang/vala-language-server
--- __Installation__: https://github.com/vala-lang/vala-language-server?tab=readme-ov-file#installation
lspconfig.vala_ls = add_lsp {
  name = "vala_ls",
  language = "vala",
  file_patterns = { "%.vala$" },
  command = { "vala-language-server" },
  verbose = false
}

---# Vim - vim_ls
--- __Status__: Untested
--- __Site__: https://github.com/iamcco/vim-language-server
--- __Installation__: https://github.com/iamcco/vim-language-server?tab=readme-ov-file#install
lspconfig.vim_ls = add_lsp {
  name = "vim_ls",
  language = "vim",
  file_patterns = { "%.vim$" },
  command = { 'vim-language-server', '--stdio' },
  verbose = false
}

---# XML - lemminx
--- __Status__: Works
--- __Site__: https://github.com/eclipse/lemminx
--- __Installation__: https://github.com/eclipse-lemminx/lemminx?tab=readme-ov-file#generating-a-native-binary
lspconfig.lemminx = add_lsp {
  name = "lemminx",
  language = "xml",
  file_patterns = { "%.xml$" },
  command = { "lemminx" },
  verbose = false
}

---# YAML - yaml_ls
--- __Status__: Untested
--- __Site__: https://github.com/redhat-developer/yaml-language-server
--- __Installation__: https://github.com/redhat-developer/yaml-language-server?tab=readme-ov-file#getting-started
lspconfig.yaml_ls = add_lsp {
  name = "yaml_ls",
  language = "yaml",
  file_patterns = { "%.yml$", "%.yaml$" },
  command = { 'yaml-language-server', '--stdio' },
  verbose = false
}

---# Zig - zls
--- __Status__: Untested
--- __Site__: https://github.com/zigtools/zls
--- __Installation__: https://zigtools.org/zls/install/
lspconfig.zls = add_lsp {
  name = "zls",
  language = "zig",
  file_patterns = { "%.zig$" },
  command = { 'zls' },
  verbose = false
}

return lspconfig
