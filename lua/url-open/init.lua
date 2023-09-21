--- The main entry point for the plugin to setup the plugin
--
local Plugin = {}

local command_module = require("url-open.modules.commands")
local option_module = require("url-open.modules.options")
local autocmd_module = require("url-open.modules.autocmd")

--- Setup the plugin with the user options
--- @param user_opts table: The user options to setup the plugin with
--- @see url-open.modules.commands
--- @see url-open.modules.options
--- @usage require("url-open").setup({})
Plugin.setup = function(user_opts)
	local options = option_module.apply_user_options(user_opts)
	command_module.setup(options)
	autocmd_module.setup(options)
end

return Plugin
