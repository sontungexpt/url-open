local vim = vim
local api = vim.api
local fn = vim.fn
local levels = vim.log.levels
local notify = vim.notify
local schedule = vim.schedule
local uv = vim.uv or vim.loop
local os_uname = uv.os_uname().sysname
local new_cmd = api.nvim_create_user_command
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local Plugin = {}

local info = function(msg, opts)
	schedule(function() notify(msg, levels.INFO, opts or { title = "URL OPEN INFO" }) end)
end

local warn = function(msg, opts)
	schedule(function() notify(msg, levels.WARN, opts or { title = "URL OPEN WARNING" }) end)
end

local error = function(msg, opts)
	schedule(function() notify(msg, levels.ERROR, opts or { title = "URL OPEN ERROR" }) end)
end

local DEFAULT_OPTIONS = {
	open_app = "default",
	open_only_when_cursor_on_url = false,
	highlight_url = {
		all_urls = {
			enabled = false,
			fg = "#19d5ff", -- nil will use default color
			bg = nil, -- transparent
			underline = true,
		},
		cursor_move = {
			enabled = true,
			fg = "#199eff", -- nil will use default color
			bg = nil, -- transparent
			underline = true,
		},
	},
	deep_pattern = false,
	extra_patterns = {},
}
local DEEP_PATTERN =
	"\\v\\c%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)%([&:#*@~%_\\-=?!+;/0-9a-z]+%(%([.;/?]|[.][.]+)[&:#*@~%_\\-=?!+/0-9a-z]+|:\\d+|,%(%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)@![0-9a-z]+))*|\\([&:#*@~%_\\-=?!+;/.0-9a-z]*\\)|\\[[&:#*@~%_\\-=?!+;/.0-9a-z]*\\]|\\{%([&:#*@~%_\\-=?!+;/.0-9a-z]*|\\{[&:#*@~%_\\-=?!+;/.0-9a-z]*\\})\\})+"

local PATTERNS = {
	{
		pattern = "(https?://[%w-_%.]+%.%w[%w-_%.%%%?%.:/+=&%%[%]#]*)",
		prefix = "",
		suffix = "",
		file_patterns = nil,
		excluded_file_patterns = nil,
		extra_condition = nil,
	},
	{
		pattern = '["]([^%s]*)["]:%s*"[^"]*%d[%d%.]*"',
		prefix = "https://www.npmjs.com/package/",
		suffix = "",
		file_patterns = { "package%.json" },
		excluded_file_patterns = nil,
		extra_condition = function(pattern_found)
			return not vim.tbl_contains({ "version", "proxy", "name" }, pattern_found)
		end,
	},
	{
		pattern = "[\"']([^%s~/]+/[^%s~/]+)[\"']",
		prefix = "https://github.com/",
		suffix = "",
		file_patterns = nil,
		excluded_file_patterns = { "package%.json", "package%-lock%.json" },
		extra_condition = nil,
	},
	{
		pattern = 'brew ["]([^%s]*)["]',
		prefix = "https://formulae.brew.sh/formula/",
		suffix = "",
		file_patterns = nil,
		excluded_file_patterns = nil,
		extra_condition = nil,
	},
	{
		pattern = 'cask ["]([^%s]*)["]',
		prefix = "https://formulae.brew.sh/cask/",
		suffix = "",
		file_patterns = nil,
		excluded_file_patterns = nil,
		extra_condition = nil,
	},
	{
		pattern = "^%s*([%w_]+)%s*=",
		prefix = "https://crates.io/crates/",
		suffix = "",
		file_patterns = { "Cargo%.toml" },
		excluded_file_patterns = nil,
		extra_condition = function(pattern_found)
			return not vim.tbl_contains({
				"name",
				"version",
				"edition",
				"authors",
				"description",
				"license",
				"repository",
				"homepage",
				"documentation",
				"keywords",
			}, pattern_found)
		end,
	},
	{
		pattern = "gem ['\"]([^%s]*)['\"]",
		prefix = "https://rubygems.org/gems/",
		suffix = "",
		file_patterns = { "Gemfile", "gems.rb" },
		excluded_file_patterns = nil,
		extra_condition = nil,
	},
	-- Dockerfile images: unprefix, unnamespaced (the library images, like `ruby:3.2`)
	-- results in: https://hub.docker.com/_/ruby/
	{
		pattern = "^FROM ([^:.]+):",
		prefix = "https://hub.docker.com/_/",
		suffix = "/",
		file_patterns = { "Dockerfile%S*", "Containerfile%S*" },
		excluded_file_patterns = nil,
		extra_condition = function(matched_pattern) return not matched_pattern:match("/") end,
	},
	-- Dockerfile images: unprefixed but namespaced (like crystallang/crystal)
	-- results in: https://hub.docker.com/r/crystallang/crystal
	{
		pattern = "FROM ([^:.]+):",
		prefix = "https://hub.docker.com/r/",
		suffix = "/",
		file_patterns = { "Dockerfile%S*", "Containerfile%S*" },
		excluded_file_patterns = nil,
		extra_condition = function(matched_pattern) return matched_pattern:match("/") end,
	},
}

local matches_file_patterns = function(file_patterns, is_excluded)
	if type(file_patterns) == "string" then file_patterns = { file_patterns } end
	if file_patterns == nil or #file_patterns == 0 then return not is_excluded end

	local file_path = api.nvim_buf_get_name(0)
	for _, pattern in ipairs(file_patterns) do
		if file_path:match(pattern) then return true end
	end
	return false
end

local matches_condition_pattern = function(pattern_found, condition)
	if type(condition) == "function" then condition = condition(pattern_found) end
	return type(condition) ~= "boolean" and true or condition
end

local find_first_matching_url = function(text, patterns, start_pos, found_url_smaller_pos)
	found_url_smaller_pos = found_url_smaller_pos or #text
	start_pos = start_pos or 1
	local start_found, end_found, url_found = nil, nil, nil

	for _, cond in ipairs(patterns) do
		if
			not matches_file_patterns(cond.excluded_file_patterns, true)
			and matches_file_patterns(cond.file_patterns)
		then
			local start_pos_result, end_pos_result, url = text:find(cond.pattern, start_pos)
			if
				url
				and found_url_smaller_pos > start_pos_result
				and matches_condition_pattern(url, cond.extra_condition)
			then
				found_url_smaller_pos = start_pos_result
				url_found = (cond.prefix or "") .. url .. (cond.suffix or "")
				start_found, end_found = start_pos_result, end_pos_result
			end
		end
	end

	return start_found, end_found, url_found
end

local find_first_url_in_line = function(user_opts, text, start_pos)
	local start_found, end_found, url_found = find_first_matching_url(text, PATTERNS, start_pos)

	local extra_start_found, extra_end_found, extra_url_found =
		find_first_matching_url(text, user_opts.extra_patterns, start_pos, start_found)

	if extra_start_found then
		start_found, end_found, url_found = extra_start_found, extra_end_found, extra_url_found
	end

	-- fallback to deep pattern
	if user_opts.deep_pattern then
		local results = fn.matchstrpos(text, DEEP_PATTERN, start_pos)
		-- result[1] is url, result[2] is start_pos, result[3] is end_pos
		if results[1] ~= "" and (start_found or #text) >= results[2] + 1 then
			start_found, end_found, url_found = results[2] + 1, results[3], results[1]
		end
	end

	return start_found, end_found, url_found
end

local open_url_with_app = function(apps, url)
	for _, app in ipairs(apps) do
		if fn.executable(app) == 1 then
			local command = app .. " " .. fn.shellescape(url)
			fn.jobstart(command, {
				detach = true,
				on_exit = function(_, code, _)
					if code ~= 0 then
						error("Opening " .. url .. " failed.")
					else
						info("Opening " .. url .. " successfully.")
					end
				end,
			})
			return
		end
	end
	error(
		string.format(
			"Cannot find any of the following applications to open the URL: %s on %s. Please install one of these applications or add your preferred app to the URL options.",
			table.concat(apps, ", "),
			os_uname
		)
	)
end

local system_open_url = function(user_opts, url)
	if url then
		local open_app = user_opts.open_app
		if open_app == "default" or open_app == "" then
			if os_uname == "Linux" then
				open_url_with_app({ "xdg-open", "gvfs-open", "gnome-open", "wslview" }, url)
			elseif vim.loop.os_uname().sysname == "Darwin" then
				open_url_with_app({ "open" }, url)
			elseif vim.loop.os_uname().sysname == "Windows" then
				open_url_with_app({ "start" }, url)
			else
				error("Unknown operating system")
			end
		else
			open_url_with_app({ open_app }, url)
		end
	else
		error("No url found")
	end
end

local foreach_url_in_line = function(user_opts, line, callback)
	local start_found, end_found, url = find_first_url_in_line(user_opts, line)

	while url do
		if callback(url, start_found, end_found) then return end
		start_found, end_found, url = find_first_url_in_line(user_opts, line, end_found + 1)
	end
end

local open_url = function(user_opts)
	local cursor_col = api.nvim_win_get_cursor(0)[2]
	local line = api.nvim_get_current_line()
	local url_to_open = nil

	foreach_url_in_line(user_opts, line, function(url, start_found, end_found)
		if user_opts.open_only_when_cursor_on_url then
			if cursor_col >= start_found - 1 and cursor_col < end_found then
				url_to_open = url
				return true -- no need to continue the loop
			end
		else
			url_to_open = url
			return cursor_col < end_found -- if cursor is on the url, no need to continue the loop
		end
	end)

	system_open_url(user_opts, url_to_open)
end

local change_color_highlight = function(opts, group_name)
	opts.enabled = nil
	if opts.fg and opts.fg == "text" then opts.fg = nil end
	api.nvim_set_hl(0, group_name, opts)
end

local delete_url_effect = function(group_name)
	for _, match in ipairs(fn.getmatches()) do
		if match.group == group_name then fn.matchdelete(match.id) end
	end
end

local set_url_effect = function()
	delete_url_effect("URLOpenHighlightAll")
	fn.matchadd("URLOpenHighlightAll", DEEP_PATTERN, 15)
end

local init_command = function(user_opts)
	new_cmd("OpenUrlUnderCursor", function()
		warn("OpenUrlUnderCursor is deprecated, please use URLOpenUnderCursor instead.")
		open_url(user_opts)
	end, { nargs = 0 })

	new_cmd("URLOpenUnderCursor", function() open_url(user_opts) end, { nargs = 0 })

	new_cmd("URLOpenHighlightAll", function()
		set_url_effect()
		change_color_highlight(user_opts.highlight_url.all_urls, "URLOpenHighlightAll")
	end, { nargs = 0 })

	new_cmd(
		"URLOpenHighlightAllClear",
		function() delete_url_effect("URLOpenHighlightAll") end,
		{ nargs = 0 }
	)
end

local function highlight_cursor_url(user_opts)
	delete_url_effect("URLOpenHighlightCursor")

	local cursor_pos = api.nvim_win_get_cursor(0)
	local cursor_row = cursor_pos[1]
	local cursor_col = cursor_pos[2]
	local line = api.nvim_get_current_line()

	-- Fixes vim:E976 error when cursor is on a blob
	if fn.type(line) == vim.v.t_blob then return end

	foreach_url_in_line(user_opts, line, function(_, start_found, end_found)
		delete_url_effect("URLOpenHighlightCursor")
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

local init_autocmd = function(user_opts)
	local highlight_url = user_opts.highlight_url

	if highlight_url.all_urls.enabled then
		api.nvim_command("URLOpenHighlightAll") -- Highlight all urls on startup

		autocmd({ "BufEnter", "WinEnter" }, {
			desc = "URL Highlighting",
			group = augroup("URLOpenHighlightAll", { clear = true }),
			command = "URLOpenHighlightAll",
		})
	end

	if highlight_url.cursor_move.enabled then
		autocmd({ "CursorMoved" }, {
			desc = "URL Highlighting CursorMoved",
			group = augroup("URLOpenHighlightCursor", { clear = true }),
			callback = function()
				highlight_cursor_url(user_opts)
				change_color_highlight(highlight_url.cursor_move, "URLOpenHighlightCursor")
			end,
		})
	end
end

Plugin.setup = function(user_opts)
	local options = type(user_opts) ~= "table" and DEFAULT_OPTIONS
		or vim.tbl_deep_extend("force", DEFAULT_OPTIONS, user_opts)
	init_command(options)
	init_autocmd(options)
end

return Plugin
