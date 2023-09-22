--- The module that handles the autocmds
--
local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local handlers = require("url-open.modules.handlers")

local M = {}

--- Setup the autocmds
--- @tparam table user_opts : The user options
--- @treturn nil
--- @see url-open.setup
--- @see url-open.modules.handlers.highlight_cursor_url
--- @see url-open.modules.handlers.set_url_effect

M.setup = function(user_opts)
	local highlight_url = user_opts.highlight_url

	if highlight_url.all_urls.enabled then
		api.nvim_command("HighlightAllUrls") -- Highlight all urls on startup

		autocmd({ "BufEnter", "WinEnter" }, {
			desc = "Highlight all urls in the buffer",
			group = augroup("HighlightAllUrl", { clear = true }),
			command = "HighlightAllUrls",
		})
	end

	if highlight_url.cursor_move.enabled then
		autocmd({ "CursorMoved" }, {
			desc = "Highlight the url under the cursor",
			group = augroup("HighlightCursorUrl", { clear = true }),
			callback = function()
				handlers.highlight_cursor_url(user_opts)
				handlers.change_color_highlight(highlight_url.cursor_move, "HighlightCursorUrl")
			end,
		})
	end
end

return M
