--- Setup the OpenUrlUnderCursor command.
--
local M = {}
local new_cmd = vim.api.nvim_create_user_command

local handlers = require("url-open.modules.handlers")
local logger = require("url-open.modules.logger")
local highlight = require("url-open.modules.highlight")

--- Setup the OpenUrlUnderCursor command and URLOpenHighlightAlls command.
--- @tparam table user_opts : User options.
--- @see url-open.modules.handlers.open_url
--- @see url-open.modules.highlight.set_url_effect
--- @see url-open.modules.highlight.change_color_highlight
--- @usage require("url-open.modules.commands").setup(opts)
M.setup = function(user_opts)
	new_cmd("OpenUrlUnderCursor", function()
		logger.warn("OpenUrlUnderCursor is deprecated, please use URLOpenUnderCursor instead.")
		handlers.open_url(user_opts)
	end, { nargs = 0 })

	new_cmd("URLOpenUnderCursor", function() handlers.open_url(user_opts) end, { nargs = 0 })

	new_cmd("URLOpenHighlightAll", function()
		highlight.set_url_effect()
		highlight.change_color_highlight(user_opts.highlight_url.all_urls, "URLOpenHighlightAll")
	end, { nargs = 0 })

	new_cmd(
		"URLOpenHighlightAllClear",
		function() highlight.delete_url_effect("URLOpenHighlightAll") end,
		{ nargs = 0 }
	)
end

return M
