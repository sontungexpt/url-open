--- Provide options for the plugin
--
local M = {}

--- Default options
-- @field deep_pattern: boolean
-- @field extra_patterns: table
-- @table DEFAULT_OPTIONS
M.DEFAULT_OPTIONS = {
	open_only_when_cursor_on_url = false,
	highlight_url_enabled = true,
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
		vim.validate { opts = { opts, "table", true } }

		if opts then
			vim.validate {
				open_only_when_cursor_on_url = { opts.open_only_when_cursor_on_url, "boolean", true },
				highlight_url_enabled = { opts.highlight_url_enabled, "boolean", true },
				deep_pattern = { opts.deep_pattern, "boolean", true },
				extra_patterns = { opts.extra_patterns, "table", true },
			}
		end

		if opts.extra_patterns then
			for pattern, sub in pairs(opts.extra_patterns) do
				vim.validate {
					pattern = { pattern, "string" },
					sub = { sub, { "table", "string" } },
				}
			end
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
