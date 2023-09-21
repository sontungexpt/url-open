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
		local is_loaded = false
		local cursor_hold_id = 0
		-- TODO: Need to find a other way to enable command when open neovim
		cursor_hold_id = api.nvim_create_autocmd({ "CursorHold" }, {
			desc = "URL Highlighting",
			group = api.nvim_create_augroup("HighlightAllUrlWhenOpenNeovim", { clear = true }),
			callback = function()
				if not is_loaded then
					api.nvim_command("HighlightAllUrls")
					is_loaded = true
				else --remove autocmd after first run
					api.nvim_del_autocmd(cursor_hold_id)
				end
			end,
		})

		api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
			desc = "URL Highlighting",
			group = api.nvim_create_augroup("HighlightAllUrl", { clear = true }),
			command = "HighlightAllUrls",
		})
	end

	if highlight_url.cursor_move.enabled then
		api.nvim_create_autocmd({ "CursorMoved" }, {
			desc = "URL Highlighting CursorMoved",
			group = api.nvim_create_augroup("HighlightCursorUrl", { clear = true }),
			callback = function()
				handlers.highlight_cursor_url(user_opts)
				handlers.change_color_highlight(highlight_url.cursor_move, "HighlightCursorUrl")
			end,
		})
	end
end

return M
