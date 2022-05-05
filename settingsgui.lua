-- Try to load settings plugin for registering config options
local settings_loaded, settings = pcall(require, "plugins.settings")

if settings_loaded then
  settings.add("Language Server Protocol",
    {
      {
        label = "Log File",
        description = "Absolute path to a file for logging all json.",
        path = "log_file",
        type = settings.type.STRING
      },
      {
        label = "Prettify JSON",
        description = "Prettify json for more readability but impacts performance.",
        path = "prettify_json",
        type = settings.type.TOGGLE,
        default = false
      },
      {
        label = "Diagnostics",
        description = "Show diagnostic messages with lint+.",
        path = "show_diagnostics",
        type = settings.type.TOGGLE,
        default = false
      },
      {
        label = "Stop Servers",
        description = "Stop servers that aren't needed by any of the open files.",
        path = "stop_unneeded_servers",
        type = settings.type.TOGGLE,
        default = true
      },
      {
        label = "Log Standard Error",
        description = "Send a server stderr output to lite log.",
        path = "log_server_stderr",
        type = settings.type.TOGGLE,
        default = false
      },
      {
        label = "Force Verbosity Off",
        description = "Turn verbosity off even if a server is configured with verbosity on.",
        path = "force_verbosity_off",
        type = settings.type.TOGGLE,
        default = false
      },
      {
        label = "More Yielding",
        description = "Yield when reading from LSP which may give you better UI responsiveness.",
        path = "more_yielding",
        type = settings.type.TOGGLE,
        default = false
      }
    },
    "lsp"
  )
end
