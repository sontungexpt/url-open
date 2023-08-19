local M = {}

M.setup = function(user_opts)
	vim.api.nvim_create_user_command(
		"OpenUrlUnderCursor",
		function() require("modules.handlers").open_url(user_opts) end,
		{ nargs = 0 }
	)
end

return M
