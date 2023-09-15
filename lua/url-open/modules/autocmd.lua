local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local handlers = require("url-open.modules.handlers")

local M = {}

M.setup = function(user_opts)
	if user_opts.highlight_url.enabled then
		if not user_opts.highlight_url.cursor_only then
			api.nvim_create_autocmd({ "VimEnter", "FileType", "BufEnter", "WinEnter" }, {
				desc = "URL Highlighting",
				group = api.nvim_create_augroup("HightlightAllUrl", { clear = true }),
				callback = function() handlers.set_url_effect() end,
			})
		else
			api.nvim_create_autocmd({ "CursorMoved" }, {
				desc = "URL Highlighting CursorMoved",
				group = api.nvim_create_augroup("HighlightCursorUrl", { clear = true }),
				callback = function()
					handlers.highlight_cursor_url(user_opts)
					api.nvim_set_hl(0, "HighlightCursorUrl", { underline = true })
				end,
			})
		end
	end
end

return M
