local M = {}

--- @see url-open.modules.handlers
local handlers = require("url-open.modules.handlers")

--- Setup the OpenUrlUnderCursor command.
-- @tparam table user_opts: User options.
-- @usage require("url-open.modules.commands").setup()
-- @see url-open.modules.handlers.open_url
M.setup = function(user_opts)
	vim.api.nvim_create_user_command(
		"OpenUrlUnderCursor",
		function() handlers.open_url(user_opts) end,
		{ nargs = 0, complete = "customlist,UrlOpenComplete" }
	)
end

return M
