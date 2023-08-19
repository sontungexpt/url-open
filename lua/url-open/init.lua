local Plugin = {}

local option_module = require("modules.options")
local command_module = require("modules.commands")

Plugin.setup = function(user_opts)
	local file = io.open("/home/stilux/Data/My-Workspaces/nvim-extensions/url-open/test.txt", "a")
	if file == nil then
		print("Error opening file")
		return
	end
	file:write("Hello World")
	file:close()
	local options = option_module.apply_user_options(user_opts)
	command_module.setup(options)
end

return Plugin
