--- Provide options for the plugin
--
local M = {}
local validate = vim.validate

--- Default options
--- @table DEFAULT_OPTIONS
--  @field open_app string : The app to open the url with
--  @field open_only_when_cursor_on_url boolean : Open url only when cursor on url
--  @field highlight_url.enabled boolean : Enable highlight url
--  @field highlight_url.fg string : Change foreground color of the url highlight
--  @field highlight_url.bg string : Change background color of the url highlight
--  @field highlight_url.underline boolean : Change underline of the url highlight
--  @field highlight_url.cursor_only boolean : Highlight only when cursor on url or highlight all urls
--  @field deep_pattern boolean : Enable deep pattern
--  @field extra_patterns table : Extra patterns to match
M.DEFAULT_OPTIONS = {
	open_app = "default",
	open_only_when_cursor_on_url = false,
	highlight_url = {
		all_urls = {
			enabled = false,
			fg = "#21d5ff", -- "text" or "#rrggbb"
			-- fg = "text",
			bg = nil, -- nil or "#rrggbb"
			underline = true,
		},
		cursor_move = {
			enabled = true,
			fg = "#199eff", -- "text" or "#rrggbb"
			-- fg = "text",
			bg = nil, -- nil or "#rrggbb"
			underline = true,
		},
	},
	deep_pattern = false,
	extra_patterns = {
		-- [pattern] = prefix: string only or nil
		-- [pattern] = {prefix = "", suffix = ""},
		--
		-- Ex: ['["]([^%s]*)["]:'] = "https://www.npmjs.com/package/",
		-- so the url will be https://www.npmjs.com/package/[pattern_found]
		--
		-- Ex: ['["]([^%s]*)["]:'] = {prefix = "https://www.npmjs.com/package/", suffix = "/issues"},
		-- so the url will be https://www.npmjs.com/package/<pattern_found>/issues
	},
}

--- Validate options
--- @tparam table opts : Options to validate
--- @return table|nil: Validated options
--- @see DEFAULT_OPTIONS
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
			for _, cond in ipairs(opts.extra_patterns) do
				validate {
					pattern = { cond.pattern, "string" },
				}
			end
		end

		if opts.highlight_url then
			validate {
				all_urls = { opts.highlight_url.all_urls, "table", true },
				cursor_move = { opts.highlight_url.cursor_move, "table", true },
			}

			if opts.highlight_url.all_urls then
				validate {
					enabled = { opts.highlight_url.all_urls.enabled, "boolean", true },
					fg = { opts.highlight_url.all_urls.fg, "string", true },
					bg = { opts.highlight_url.all_urls.bg, "string", true },
					underline = { opts.highlight_url.all_urls.underline, "boolean", true },
				}
			end

			if opts.highlight_url.cursor_move then
				validate {
					enabled = { opts.highlight_url.cursor_move.enabled, "boolean", true },
					fg = { opts.highlight_url.cursor_move.fg, "string", true },
					bg = { opts.highlight_url.cursor_move.bg, "string", true },
					underline = { opts.highlight_url.cursor_move.underline, "boolean", true },
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
--- @tparam table user_opts : User options
--- @return table: Merged options
--- @see validate_opts
--- @see DEFAULT_OPTIONS
M.apply_user_options = function(user_opts)
	user_opts = M.validate_opts(user_opts)
	return vim.tbl_deep_extend("force", M.DEFAULT_OPTIONS, user_opts or {})
end

return M
