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
		api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
			desc = "URL Highlighting",
			group = api.nvim_create_augroup("HighlightAllUrl", { clear = true }),
			callback = function()
				handlers.set_url_effect()
				M.change_color_highlight(highlight_url.all_urls, "HighlightAllUrl")
			end,
		})
	end

	if highlight_url.cursor_move.enabled then
		api.nvim_create_autocmd({ "CursorMoved" }, {
			desc = "URL Highlighting CursorMoved",
			group = api.nvim_create_augroup("HighlightCursorUrl", { clear = true }),
			callback = function()
				handlers.highlight_cursor_url(user_opts)
				M.change_color_highlight(highlight_url.cursor_move, "HighlightCursorUrl")
			end,
		})
	end
end

--- Change the color of the highlight
--- @tparam table opts : The user options
--- @tparam string group_name : The name of the highlight group
--- @treturn nil
--- @see url-open.modules.handlers.highlight_cursor_url
--- @see url-open.modules.handlers.set_url_effect
--- @see url-open.modules.autocmd.setup
--- @see url-open.setup
M.change_color_highlight = function(opts, group_name)
	opts.enabled = nil

	api.nvim_set_hl(0, group_name, opts)
end

return M
