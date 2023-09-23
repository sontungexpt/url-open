--- The module that handles the autocmds
--
local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local highlight = require("url-open.modules.highlight")

local M = {}

--- Setup the autocmds
--- @tparam table user_opts : The user options
--- @see url-open.modules.commands
--- @see url-open.modules.highlight.highlight_cursor_url
--- @see url-open.modules.highlight.change_color_highlight
--- @usage require("url-open.modules.autocmd").setup(opts)
M.setup = function(user_opts)
	local highlight_url = user_opts.highlight_url

	if highlight_url.all_urls.enabled then
		api.nvim_command("URLOpenHighlightAll") -- Highlight all urls on startup

		autocmd({ "BufEnter", "WinEnter" }, {
			desc = "Highlight all urls in the buffer",
			group = augroup("URLOpenHighlightAll", { clear = true }),
			command = "URLOpenHighlightAll",
		})
	end

	if highlight_url.cursor_move.enabled then
		autocmd({ "CursorMoved" }, {
			desc = "Highlight the url under the cursor",
			group = augroup("URLOpenHighlightCursor", { clear = true }),
			callback = function()
				highlight.highlight_cursor_url(user_opts)
				highlight.change_color_highlight(highlight_url.cursor_move, "URLOpenHighlightCursor")
			end,
		})
	end
end

return M
