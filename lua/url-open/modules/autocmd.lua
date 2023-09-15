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
					local highlight_url = user_opts.highlight_url
					api.nvim_set_hl(
						0,
						"HighlightCursorUrl",
						{ underline = highlight_url.underline, fg = highlight_url.fg, bg = highlight_url.bg }
					)
				end,
			})
		else
			api.nvim_create_autocmd({ "VimEnter", "FileType", "BufEnter", "WinEnter" }, {
				desc = "URL Highlighting",
				group = api.nvim_create_augroup("HightlightAllUrl", { clear = true }),
				callback = function() handlers.set_url_effect() end,
			})
		end
	end
end

return M
