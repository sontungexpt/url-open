--- Setup the OpenUrlUnderCursor command.
--
local M = {}
local new_cmd = vim.api.nvim_create_user_command

local handlers = require("url-open.modules.handlers")
local logger = require("url-open.modules.logger")

--- Setup the OpenUrlUnderCursor command and URLOpenHighlightAlls command.
--- @tparam table user_opts : User options.
--- @see url-open.modules.handlers.open_url
--- @see url-open.modules.handlers.set_url_effect
--- @see url-open.modules.handlers.change_color_highlight
--- @usage require("url-open.modules.commands").setup(opts)
M.setup = function(user_opts)
	new_cmd("OpenUrlUnderCursor", function()
		handlers.open_url(user_opts)
		logger.warning("OpenUrlUnderCursor is deprecated, please use URLOpenUnderCursor instead.")
	end, { nargs = 0 })

	new_cmd("URLOpenUnderCursor", function() handlers.open_url(user_opts) end, { nargs = 0 })

	new_cmd("URLOpenHighlightAll", function()
		handlers.set_url_effect()
		handlers.change_color_highlight(user_opts.highlight_url.all_urls, "URLOpenHighlightAll")
	end, { nargs = 0 })

	new_cmd(
		"URLOpenStopHighlightAll",
		function() handlers.delete_url_effect("URLOpenHighlightAll") end,
		{ nargs = 0 }
	)
end

return M
