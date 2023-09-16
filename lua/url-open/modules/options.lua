--- Provide options for the plugin
--
local M = {}
local validate = vim.validate

--- Default options
-- @field open_only_when_cursor_on_url: boolean : Open url only when cursor on url
-- @field highlight_url: table
-- @field highlight_url.enabled: boolean : Enable highlight url
-- @field highlight_url.fg: string : Change foreground color of the url highlight
-- @field highlight_url.bg: string : Change background color of the url highlight
-- @field highlight_url.underline: boolean : Change underline of the url highlight
-- @field highlight_url.cursor_only: boolean : Highlight only when cursor on url or highlight all urls
-- @field deep_pattern: boolean : Enable deep pattern
-- @field extra_patterns: table : Extra patterns to match
-- @table DEFAULT_OPTIONS
M.DEFAULT_OPTIONS = {
	open_app = "default",
	open_only_when_cursor_on_url = false,
	highlight_url = {
		enabled = true,
		cursor_only = true, -- highlight only when cursor on url or highlight all urls
		fg = "#199bff",
		bg = nil, -- transparent
		underline = true,
	},
	deep_pattern = false,
	extra_patterns = {
		-- [pattern] = prefix: string only or nil
		-- [pattern] = {prefix = "", suffix = ""},
		--
		-- Ex: ['["]([^%s]*)["]:'] = "https://www.npmjs.com/package/",
		-- so the url will be https://www.npmjs.com/package/<pattern found>
		--
		-- Ex: ['["]([^%s]*)["]:'] = {prefix = "https://www.npmjs.com/package/", suffix = "/issues"},
		-- so the url will be https://www.npmjs.com/package/<pattern found>/issues
	},
}

--- Validate options
-- @tparam table opts : Options to validate
-- @return table: Validated options
-- @see DEFAULT_OPTIONS
M.validate_opts = function(opts)
	local success, error_msg = pcall(function()
		validate { opts = { opts, "table", true } }

		if opts then
			validate {
				open_app = { opts.open_app, "string", true },
				open_only_when_cursor_on_url = { opts.open_only_when_cursor_on_url, "boolean", true },
				highlight_url = {
					opts.highlight_url,
					{ "table", "boolean" },
					true,
				},
				deep_pattern = { opts.deep_pattern, "boolean", true },
				extra_patterns = { opts.extra_patterns, "table", true },
			}
		end

		if opts.extra_patterns then
			for pattern, sub in pairs(opts.extra_patterns) do
				validate {
					pattern = { pattern, "string" },
					sub = { sub, { "table", "string" } },
				}
			end
		end

		if opts.highlight_url then
			validate {
				enabled = { opts.highlight_url.enabled, "boolean" },
				cursor_only = { opts.highlight_url.cursor_only, "boolean" },
				fg = { opts.highlight_url.fg, "string", true },
				bg = { opts.highlight_url.bg, "string", true },
				underline = { opts.highlight_url.underline, "boolean", true },
			}
		end
	end)

	if not success then
		error("Error: " .. error_msg)
		return nil
	end

	return opts
end

--- Apply user options
-- @tparam table user_opts : User options
-- @return table: Merged options
-- @see DEFAULT_OPTIONS
-- @see validate_opts
M.apply_user_options = function(user_opts)
	user_opts = M.validate_opts(user_opts)
	return vim.tbl_deep_extend("force", M.DEFAULT_OPTIONS, user_opts or {})
end

return M
