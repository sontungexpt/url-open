--- The module that handles the autocmds
--
local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local handlers = require("url-open.modules.handlers")

local M = {}

--- Setup the autocmds
-- @tparam table user_opts : The user options
-- @treturn nil
-- @see url-open.setup
-- @see url-open.modules.handlers.highlight_cursor_url
-- @see url-open.modules.handlers.set_url_effect
M.setup = function(user_opts)
	if user_opts.highlight_url.enabled then
		if user_opts.highlight_url.cursor_only then
			api.nvim_create_autocmd({ "CursorMoved" }, {
				desc = "URL Highlighting CursorMoved",
				group = api.nvim_create_augroup("HighlightCursorUrl", { clear = true }),
				callback = function()
					handlers.highlight_cursor_url(user_opts)
					M.change_color_highlight(user_opts, "HighlightCursorUrl")
				end,
			})
		else
			api.nvim_create_autocmd({ "VimEnter", "FileType", "BufEnter", "WinEnter" }, {
				desc = "URL Highlighting",
				group = api.nvim_create_augroup("HightlightAllUrl", { clear = true }),
				callback = function()
					handlers.set_url_effect()
					M.change_color_highlight(user_opts, "HighlightAllUrl")
				end,
			})
		end
	end
end

--- Change the color of the highlight
-- @tparam table user_opts : The user options
-- @tparam string group_name : The name of the highlight group
-- @treturn nil
-- @see url-open.modules.handlers.highlight_cursor_url
-- @see url-open.modules.handlers.set_url_effect
-- @see url-open.modules.autocmd.setup
-- @see url-open.setup
M.change_color_highlight = function(user_opts, group_name)
	local highlight_url = user_opts.highlight_url

	local opts = {}
	for k, v in pairs(highlight_url) do
		if k ~= "enabled" and k ~= "cursor_only" then opts[k] = v end
	end

	api.nvim_set_hl(0, group_name, opts)
end

return M
