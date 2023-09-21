--- Setup the OpenUrlUnderCursor command.
--
local M = {}

local handlers = require("url-open.modules.handlers")

--- Setup the OpenUrlUnderCursor command.
--- @tparam table user_opts : User options.
--- @see url-open.modules.handlers.open_url
--- @usage require("url-open.modules.commands").setup(opts)
M.setup = function(user_opts)
	vim.api.nvim_create_user_command(
		"OpenUrlUnderCursor",
		function() handlers.open_url(user_opts) end,
		{ nargs = 0 }
	)

	vim.api.nvim_create_user_command("HighlightAllUrls", function()
		handlers.set_url_effect()
		handlers.change_color_highlight(user_opts.highlight_url.all_urls, "HighlightAllUrl")
	end, { nargs = 0 })
end

return M
