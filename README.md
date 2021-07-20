# LSP Plugin for Lite XL editor

Plugin that provides intellisense for Lite XL by leveraging the
[LSP protocol](https://microsoft.github.io/language-server-protocol/specifications/specification-current/).
While still a work in progress it already implements all the most important
features to make your life easier while coding with Lite XL. Using it
requires the latest changes on the master branch of __Lite XL__ which
includes the new lua __process__ functionality in order to communicate
with lsp servers. Also [lint+](https://github.com/liquidev/lintplus)
is used for diagnostics so make sure to grab that too.

To test, clone this project, place the __lsp__ directory in your plugins
directory, then replace or overwrite __autocomplete.lua__ plugin with the
version on this repository which should later be merged into upstream.
Finally you will need the [Widgets](https://github.com/jgmdev/lite-xl-widgets)
small lib so make sure to also drop it into your lite-xl configs directory.
The lite-xl configs directory should have:

* lite-xl/widget/
* lite-xl/plugins/lsp/
* lite-xl/plugins/autocomplete.lua

## Features

Stuff that is currently implemented:

* Code auto completion (__ctrl+space__)
* Function signatures tooltip (__ctrl+shift+space__)
* Current cursor symbol details tooltip (__alt+a__)
* Goto definition (__alt+d__)
* Goto implementation (__alt+shift+d__)
* View/jump to current document symbols (__alt+s__)
* Find workspace symbols (__alt+shift+s__)
* View/jump to symbol references (__alt+f__)
* View/jump to document diagnostic messages (__alt+e__)
* Optional diagnostics rendering while typing with
  [LintPlus](https://github.com/liquidev/lintplus) (__alt+shift+e__ to toggle)
* List all documents with diagnostics (__ctrl+alt+e__)

## Setting a LSP Server

To add an lsp server in your user init.lua file you can see the
__[serverlist.lua](https://github.com/jgmdev/lite-xl-lsp/blob/master/lsp/serverlist.lua)__
as an example, the structure is as follows:

```lua
local lsp = require "plugins.lsp"

lsp.add_server {
  name = "name of server",
  language = "main language",
  file_patterns = {...},
  command = { "lsp-command", "arguments" },
  -- Note that also having a settings.json or settings.lua in
  -- your workspace directory is supported
  settings = {"Optional table of settings to pass into the lsp"},
  init_options = {"Optional table of initializationOptions for the LSP"},
  -- Set by default to 16 should only be modified if having issues with a server
  requests_per_second = 16
  -- By default each request is written to the server stdin in chunks of
  -- 10KB, if this gives issues set to false to write everything at once.
  requests_in_chunks = true,
  -- Some servers like bash language server support incremental changes
  -- which are more performant but don't advertise it
  incremental_changes = false,
  -- True to debug the lsp client when developing it
  verbose = false
}
```

## TODO

- [ ] Handle window/showMessage, window/showMessageRequest,
  $/progress, telemetry/event
- [x] Be able to search workspace symbols 'workspace/symbol'
- [ ] Completion preselectSupport (needs autocomplete plugin change)
- [ ] Add symbol renaming support 'textDocument/rename'
- [ ] Add Snippets support (this will need a whole standalone plugin).
- [ ] Fix issues when parsing stdout from some lsp servers (eg: css-languageserver).
- [x] More improvements to autocomplete.lua plugin
  - [x] Detect view edges and render to the most visible side
  - [x] Description box, detect view width and expand accordingly
  - [ ] Support for pre-selected item
  - [ ] Be able to use a custom sorting field.
- [x] Add hover support for function arguments
  - [ ] Add custom tooltip that accents active parameter and signature
- [x] Figure out how to get an autocompletion item full documentation with
'completionItem/resolve' or any other in order to better populate
the new autocomplete item description
- [x] (we kill it) Detect if lsp server hangs and restart it (eg: clangd)
- [x] Exit LSP server if no open document needs it.
- [x] Add hover support for symbols
- [x] Generate list of current document symbols for easy document navigation
- [x] Goto definition
  - [x] Display select box when more than one result
- [x] Show diagnostics on active document similar to the linter plugin.
- [x] Send incremental changes on textDocument/didChange notification
  since sending the whole document content on big files is slow and bad.


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
![Doc Symbols](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/docsym01.png)
![Doc Symbols](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/docsym02.png)

### Goto definition
![Goto Definition](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/gotodef01.png)

### Diagnostics rendering using Lint+
![Diagnostics](https://raw.githubusercontent.com/jgmdev/lite-xl-lsp/master/screenshots/diagnostics01.png)
