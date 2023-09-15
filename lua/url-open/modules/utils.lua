local M = {}

local url_matcher = require("url-open.modules.patterns").DEEP_PATTERN

--- Delete the syntax matching rules for URLs/URIs if set.
M.delete_url_effect = function()
	for _, match in ipairs(vim.fn.getmatches()) do
		if match.group == "HighlightURL" then vim.fn.matchdelete(match.id) end
	end
end

--- Add syntax matching rules for highlighting URLs/URIs.
M.set_url_effect = function()
	M.delete_url_effect()
	vim.fn.matchadd("HighlightURL", url_matcher, 15)
end

return M
