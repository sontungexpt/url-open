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

	local start_pos, end_pos, url = handlers.find_first_url_in_line(user_opts, line)

	while url do
		-- clear the other highlight url to make sure only one url is highlighted
		M.delete_url_effect("URLOpenHighlightCursor")
		if user_opts.open_only_when_cursor_on_url then
			if cursor_col >= start_pos - 1 and cursor_col < end_pos then
				fn.matchaddpos(
					"URLOpenHighlightCursor",
					{ { cursor_row, start_pos, end_pos - start_pos + 1 } },
					20
				)
				break
			end
		else
			fn.matchaddpos(
				"URLOpenHighlightCursor",
				{ { cursor_row, start_pos, end_pos - start_pos + 1 } },
				20
			)
		end

		if cursor_col < end_pos then break end

		-- find the next url
		start_pos, end_pos, url = handlers.find_first_url_in_line(user_opts, line, end_pos + 1)
	end
end

return M
