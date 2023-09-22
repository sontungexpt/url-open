--- Setup the OpenUrlUnderCursor command.
--
local M = {}
local nvim_create_user_command = vim.api.nvim_create_user_command

local handlers = require("url-open.modules.handlers")

--- Setup the OpenUrlUnderCursor command and HighlightAllUrls command.
--- @tparam table user_opts : User options.
--- @see url-open.modules.handlers.open_url
--- @see url-open.modules.handlers.set_url_effect
--- @see url-open.modules.handlers.change_color_highlight
--- @usage require("url-open.modules.commands").setup(opts)
M.setup = function(user_opts)
	nvim_create_user_command(
		"OpenUrlUnderCursor",
		function() handlers.open_url(user_opts) end,
		{ nargs = 0 }
	)

	nvim_create_user_command("HighlightAllUrls", function()
		handlers.set_url_effect()
		handlers.change_color_highlight(user_opts.highlight_url.all_urls, "HighlightAllUrl")
	end, { nargs = 0 })
end

return M
