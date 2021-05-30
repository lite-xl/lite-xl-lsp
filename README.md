# (WIP) LSP Plugin for Lite XL editor

This is a work in progress LSP plugin for the __Lite XL__ code editor.
It requires the __dev__ branch of __Lite XL__ which includes the new lua
__process__ functionality in order to communicate with lsp servers.

To test, clone this project, place the __lsp__ directory in your plugins
directory, then replace the __autocomplete.lua__ plugin with the version
on this repository which should later be merged into upstream.

To add an lsp server in your user init.lua file you can see the
__serverlist.lua__ as an example or:

```lua
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
```

## TODO

* Exit LSP server if no open document needs it.
* Fix issues when parsing stdout from some lsp servers (eg: css-languageserver).
* Detect if lsp server hangs and restart it (eg: clangd)
* More improvements to autocomplete.lua plugin (Done?)
* Add hover support for function arguments (partially)
  * Add custom tooltip that accents active parameter and signature
* Add hover support for symbols (Done)
* Generate list of current document symbols for easy document navigation (Done?)
* Goto definition (Done)
  * Display select box when more than one result (Done)
* Figure out how to get an autocompletion item full documentation with
'completionItem/resolve' or any other in order to better populate
the new autocomplete item description
* Show diagnostics on active document similar to the linter plugin.


## Screenshots

Some images to easily visualize the progress :)

### Completion
![Completion](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/completion01.png)

![Completion](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/completion02.png)

![Completion](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/completion03.png)

![Completion](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/completion04.png)

### Symbol hover
![Hover](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/hover01.png)

![Hover](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/hover02.png)

### Function signatures
![Signature](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/signatures01.png)

### Document symbols
![Signature](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/docsym01.png)
![Signature](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/docsym02.png)
