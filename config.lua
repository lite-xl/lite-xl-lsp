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

local function add_lsp(o)
  return {
    setup = function(p)
      local options = merge(o, p)
      lsp.add_server(options)
    end
  }
end


local lspconfig = {}

-- bash-language-server
-- Status: Works but performs really badly
--         set 'requests_per_second' to 2-4 if too slow
-- Site: https://github.com/bash-lsp/bash-language-server
-- Installation: npm i -g bash-language-server
lspconfig.bashls = add_lsp {
  name = "bash-language-server",
  language = "shell",
  file_patterns = { "%.sh$" },
  command = { "bash-language-server", "start" },
  incremental_changes = true,
  verbose = false
}

-- ccls
-- Status: Works
-- Site: https://github.com/MaskRay/ccls/
-- Installation: https://github.com/MaskRay/ccls/wiki
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

-- clangd
-- Status: Works
-- Site: https://clangd.llvm.org/
-- Installation: install the clang software package on your system
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

-- Clojure
-- Status: Untested
-- Site: https://clojure-lsp.github.io/
-- Installation: https://clojure-lsp.github.io/clojure-lsp/installation/
lspconfig.clojure_lsp = add_lsp {
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
lspconfig.cssls = add_lsp {
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
lspconfig.dockerls = add_lsp {
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
lspconfig.flow = add_lsp {
  name = "flow",
  language = "javascript",
  file_patterns = { "%.js$", "%.jsx$" },
  command = { "flow", "lsp" },
  verbose = false
}

-- gopls
-- Status: Works
-- Site: https://pkg.go.dev/golang.org/x/tools/gopls
-- Installation: go get -u golang.org/x/tools/gopls
lspconfig.gopls = add_lsp {
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
lspconfig.groovyls = add_lsp {
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
lspconfig.hls = add_lsp {
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
lspconfig.html = add_lsp {
  name = "html-languageserver",
  language = "html",
  file_patterns = { "%.html$" },
  command = { 'html-languageserver', '--stdio' },
  verbose = false
}

-- intelephense
-- Status: Works
-- Site: https://github.com/bmewburn/intelephense-docs
-- Installation: npm -g install intelephense
-- Note: Set your license and storage by passing the init_options as follows:
-- init_options = { licenceKey = "...", storagePath = "/some/path"}
lspconfig.intelephense = add_lsp {
  name = "intelephense",
  language = "php",
  file_patterns = {"%.php$"},
  command = { "intelephense", "--stdio" },
  verbose = false
}

-- vscode-json-languageserver
-- Status: Untested
-- Site: https://www.npmjs.com/package/vscode-json-languageserver
-- Installation: npm install -g vscode-json-languageserver
lspconfig.jsonls = add_lsp {
  name = "vscode-json-languageserver",
  language = "json",
  file_patterns = { "%.json$", "%.jsonc$" },
  command = { 'vscode-json-languageserver', '--stdio' },
  verbose = false
}

-- kotlin-language-server
-- Status: Untested
-- Site: https://github.com/fwcd/kotlin-language-server
-- Installation: https://github.com/fwcd/kotlin-language-server/releases
lspconfig.kotlin_language_server = add_lsp {
  name = "kotlin-language-server",
  language = "kotlin",
  file_patterns = { "%.kt$", "%.kts$", "%.ktm$" },
  command = { 'kotlin-language-server' },
  verbose = false
}

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

-- ocaml-lsp
-- Status: Reported working on https://github.com/jgmdev/lite-xl-lsp/issues/17
-- Site: https://github.com/ocaml/ocaml-lsp
-- Installation: https://github.com/ocaml/ocaml-lsp#installation
lspconfig.ocaml_lsp = add_lsp {
  name = "ocaml-lsp",
  language = "ocaml",
  file_patterns = {"%.ml$", "%.mli$"},
  command = {"ocamllsp"},
  id_not_extension = true,
  verbose = false
}

-- python-language-server
-- Status: Works (deprecated in favor of python-lsp-server)
-- Site: https://github.com/palantir/python-language-server
-- Installation: pip install python-language-server
-- Note: Also don't forget to install any additional optional dependencies
-- for additional features (see official site for details).
lspconfig.pyls = add_lsp {
  name = "pyls",
  language = "python",
  file_patterns = { "%.py$" },
  command = { 'pyls' },
  verbose = false
}

-- python-lsp-server
-- Status: Works
-- Site: https://github.com/python-lsp/python-lsp-server
-- Installation: pip install python-lsp-server
-- Note: Also don't forget to install any additional optional dependencies
-- for additional features (see official site for details).
lspconfig.pylsp = add_lsp {
  name = "pylsp",
  language = "python",
  file_patterns = { "%.py$" },
  command = { 'pylsp' },
  verbose = false
}

-- Rust Language Server
-- Status: Works
-- Site: https://github.com/rust-lang/rls
-- Installation: Install rust on your system
lspconfig.rls = add_lsp {
  name = "rust-language-server",
  language = "rust",
  file_patterns = { "%.rs$" },
  command = { 'rls' },
  verbose = false
}

-- Rust Analyzer
-- Status: Works
-- Site: https://rust-analyzer.github.io/
-- Installation: See official website for instructions
lspconfig.rust_analyzer = add_lsp {
  name = "rust-analyzer",
  language = "rust",
  file_patterns = { "%.rs$" },
  command = { 'rust-analyzer' },
  verbose = false
}

-- Solargraph
-- Status: Untested
-- Site: https://github.com/castwide/solargraph
-- Installation: gem install solargraph
lspconfig.solargraph = add_lsp {
  name = "solargraph",
  language = "ruby",
  file_patterns = { "%.rb$" },
  command = { 'solargraph', 'stdio' },
  verbose = false
}

-- sql-language-server
-- Status: Untested
-- Site: https://github.com/joe-re/sql-language-server
-- Installation: npm i -g sql-language-server
lspconfig.sqlls = add_lsp {
  name = "sql-language-server",
  language = "sql",
  file_patterns = { "%.sql$" },
  command = { 'sql-language-server', 'up', '--method', 'stdio' },
  verbose = false
}

-- lua-language-server
-- Status: Works
-- Site: https://github.com/sumneko/lua-language-server
-- Installation: https://github.com/sumneko/lua-language-server/wiki/Build-and-Run-(Standalone)
lspconfig.sumneko_lua = add_lsp {
  name = "lua-language-server",
  language = "lua",
  file_patterns = {"%.lua$"},
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
          [DATADIR] = true
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

-- typescript-language-server
-- Status: Untested
-- Site: https://github.com/theia-ide/typescript-language-server
-- Installation: npm install -g typescript typescript-language-server
lspconfig.tsserver = add_lsp {
  name = "typescript-language-server",
  language = "javascript",
  file_patterns = { "%.js$", "%.cjs$", "%.mjs$" },
  command = { 'typescript-language-server', '--stdio' },
  verbose = false
}

-- vim-language-server
-- Status: Untested
-- Site: https://github.com/iamcco/vim-language-server
-- Installation: npm install -g vim-language-server
lspconfig.vimls = add_lsp {
  name = "vim-language-server",
  language = "vim",
  file_patterns = { "%.vim$" },
  command = { 'vim-language-server', '--stdio' },
  verbose = false
}

-- vlang-vls
-- Status: Initializes but doesn't responds to completion requests
--         at least it helped improve lit-xl-lsp requests mechanism
-- Site: https://github.com/vlang/vls
-- Installation:
--  git clone https://github.com/vlang/vls.git vls && cd vls/
--  v -prod cmd/vls
--  mv cmd/vls vlang-vls
lspconfig.vls = add_lsp {
  name = "vlang-vls",
  language = "v",
  file_patterns = { "%.v$" },
  command = { 'vlang-vls' },
  verbose = false
}

-- yaml-language-server
-- Status: Untested
-- Site: https://github.com/redhat-developer/yaml-language-server
-- Installation: See official website for instructions
lspconfig.yamlls = add_lsp {
  name = "yaml-language-server",
  language = "yaml",
  file_patterns = { "%.yml$", "%.yaml$" },
  command = { 'yaml-language-server', '--stdio' },
  verbose = false
}

-- Zig Language Server
-- Status: Untested
-- Site: https://github.com/zigtools/zls
-- Installation: See official website for instructions
lspconfig.zls = add_lsp {
  name = "zls",
  language = "zig",
  file_patterns = { "%.zig$" },
  command = { 'zls' },
  verbose = false
}

return lspconfig
