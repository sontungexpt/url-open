local api = vim.api
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local utils = require("url-open.modules.utils")
local M = {}

M.setup = function(opts)
	if opts.highlight_url_enabled then
		autocmd({ "BufWritePost", "BufEnter" }, {
			desc = "URL Highlighting",
			group = augroup("HighlightUrl", { clear = true }),
			callback = function() utils.set_url_effect() end,
		})
	end
end

return M
