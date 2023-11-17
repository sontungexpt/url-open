--- The module for working with the highlight effects.
--
local M = {}

local api = vim.api
local fn = vim.fn

local patterns = require("url-open.modules.patterns")
local handlers = require("url-open.modules.handlers")

--- Change the color of the highlight
--- @tparam table opts : The user options
--- @tparam string group_name : The name of the highlight group
--- @see url-open.modules.options
M.change_color_highlight = function(opts, group_name)
	opts.enabled = nil -- Remove the enabled key from the table
	if opts.fg and opts.fg == "text" then opts.fg = nil end
	api.nvim_set_hl(0, group_name, opts)
end

--- Delete the syntax matching rules for URLs/URIs if set.
M.delete_url_effect = function(group_name)
	for _, match in ipairs(fn.getmatches()) do
		if match.group == group_name then fn.matchdelete(match.id) end
	end
end

--- Add syntax matching rules for highlighting URLs/URIs.
--- @see url-open.modules.options
--- @see url-open.modules.patterns
M.set_url_effect = function(user_opts)
	M.delete_url_effect("URLOpenHighlightAll")
	fn.matchadd("URLOpenHighlightAll", patterns.DEEP_PATTERN, 15)
end

--- Highlight the url under the cursor
--- @tparam table user_opts : User options
--- @see url-open.modules.options
M.highlight_cursor_url = function(user_opts)
	-- clear old highlight when moving cursor
	M.delete_url_effect("URLOpenHighlightCursor")

	local cursor_pos = api.nvim_win_get_cursor(0)
	local cursor_row = cursor_pos[1]
	local cursor_col = cursor_pos[2]
	local line = api.nvim_get_current_line()

	-- Fixes vim:E976 error when cursor is on a blob
	if fn.type(line) == vim.v.t_blob then return end

	handlers.foreach_url_in_line(user_opts, line, function(_, start_found, end_found)
		M.delete_url_effect("URLOpenHighlightCursor")
		if user_opts.open_only_when_cursor_on_url then
			if cursor_col >= start_found - 1 and cursor_col < end_found then
				fn.matchaddpos(
					"URLOpenHighlightCursor",
					{ { cursor_row, start_found, end_found - start_found + 1 } },
					20
				)
				return true -- no need to continue the loop
			end
		else
			fn.matchaddpos(
				"URLOpenHighlightCursor",
				{ { cursor_row, start_found, end_found - start_found + 1 } },
				20
			)
			return cursor_col < end_found -- if cursor is on the url, no need to continue the loop
		end
	end)
end

return M
