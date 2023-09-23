local api = vim.api
local fn = vim.fn
local levels = vim.log.levels
local notify = vim.notify
local schedule = vim.schedule
local os_uname = vim.loop.os_uname().sysname
local new_cmd = api.nvim_create_user_command
local autocmd = api.nvim_create_autocmd
local augroup = api.nvim_create_augroup

local Plugin = {}

local info = function(msg, opts)
	schedule(function() notify(msg, levels.INFO, opts or { title = "Information" }) end)
end

local warn = function(msg, opts)
	schedule(function() notify(msg, levels.WARN, opts or { title = "URL OPEN WARNING" }) end)
end

local error = function(msg, opts)
	schedule(function() notify(msg, levels.ERROR, opts or { title = "Error" }) end)
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
	"\\v\\c%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)%([&:#*@~%<>_\\-=?!+;/0-9a-z]+%(%([.;/?]|[.][.]+)[&:#*@~%<>_\\-=?!+/0-9a-z]+|:\\d+|,%(%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)@![0-9a-z]+))*|\\([&:#*@~%_\\-=?!+;/.0-9a-z]*\\)|\\[[&:#*@~%_\\-=?!+;/.0-9a-z]*\\]|\\{%([&:#*@~%_\\-=?!+;/.0-9a-z]*|\\{[&:#*@~%_\\-=?!+;/.0-9a-z]*\\})\\})+"

local PATTERNS = {
	["(https?://[%w-_%.]+%.%w[%w-_%.%%%?%.:/+=&%%[%]#<>]*)"] = "", --- url http(s)
	['["]([^%s]*)["]:%s*"[^"]*%d[%d%.]*"'] = {
		prefix = "https://www.npmjs.com/package/",
		suffix = "",
		file_patterns = { "package%.json" },
		extra_condition = function(pattern_found)
			return pattern_found ~= "version" and pattern_found ~= "proxy"
		end,
	}, -- npm package
	["[\"']([^%s~/]*/[^%s~/]*)[\"']"] = {
		prefix = "https://github.com/",
		suffix = "",
		excluded_file_patterns = { "package%.json", "package%-lock%.json" },
	}, -- plugin name git
	['brew ["]([^%s]*)["]'] = {
		prefix = "https://formulae.brew.sh/formula/",
		suffix = "",
	}, -- brew formula
	['cask ["]([^%s]*)["]'] = {
		prefix = "https://formulae.brew.sh/cask/",
		suffix = "",
	}, -- cask formula
	["^%s*([%w_]+)%s*="] = {
		prefix = "https://crates.io/crates/",
		suffix = "",
		file_patterns = { "Cargo%.toml" },
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
	}, -- cargo package
}

local call_cmd = function(command, msg)
	local success, error_message = pcall(api.nvim_command, command)
	if success then
		info(msg and msg.success or "Success")
	else
		error((msg and msg.error or "Error") .. ": " .. error_message)
	end
end

local check_file_patterns = function(file_patterns, is_excluded)
	if type(file_patterns) == "string" then file_patterns = { file_patterns } end
	if file_patterns == nil or #file_patterns == 0 then return not is_excluded end

	local file_path = api.nvim_buf_get_name(0)
	for _, pattern in ipairs(file_patterns) do
		if file_path:match(pattern) then return true end
	end
	return false
end

local check_condition_pattern = function(pattern_found, condition)
	if type(condition) == "function" then condition = condition(pattern_found) end
	return type(condition) ~= "boolean" and true or condition
end

local find_first_url_matching_patterns = function(text, patterns, start_pos, found_url_smaller_pos)
	found_url_smaller_pos = found_url_smaller_pos or #text
	start_pos = start_pos or 1
	local start_found, end_found, url_found = nil, nil, nil

	for pattern, subs in pairs(patterns) do
		subs = subs or { prefix = "" }
		if type(subs) == "string" then subs = { prefix = subs } end -- support old version

		if
			not check_file_patterns(subs.excluded_file_patterns, true)
			and check_file_patterns(subs.file_patterns)
		then
			local start_pos_result, end_pos_result, url = text:find(pattern, start_pos)
			if
				url
				and found_url_smaller_pos > start_pos_result
				and check_condition_pattern(url, subs.extra_condition)
			then
				found_url_smaller_pos = start_pos_result
				url_found = (subs.prefix or "") .. url .. (subs.suffix or "")
				start_found, end_found = start_pos_result, end_pos_result
			end
		end
	end
	return start_found, end_found, url_found
end

local find_first_url_in_line = function(user_opts, text, start_pos)
	local start_found, end_found, url_found = find_first_url_matching_patterns(text, PATTERNS, start_pos)

	local extra_start_found, extra_end_found, extra_url_found =
		find_first_url_matching_patterns(text, user_opts.extra_patterns, start_pos, start_found)

	if extra_start_found then
		start_found, end_found, url_found = extra_start_found, extra_end_found, extra_url_found
	end

	-- fallback to deep pattern
	if user_opts.deep_pattern then
		local results = fn.matchstrpos(text, DEEP_PATTERN, start_pos)
		-- result[1] is url, result[2] is start_pos, result[3] is end_pos
		if results[1] ~= "" and (start_found or #text) > results[2] + 1 then
			start_found, end_found, url_found = results[2] + 1, results[3], results[1]
		end
	end

	return start_found, end_found, url_found
end

local open_url_with_app = function(apps, url)
	for _, app in ipairs(apps) do
		if fn.executable(app) == 1 then
			local shell_safe_url = fn.shellescape(url)
			local command = "silent! !" .. app .. " " .. shell_safe_url
			call_cmd(command, {
				success = "Opening " .. url .. " successfully.",
				error = "Opening " .. url .. " failed.",
			})
			return
		end
	end
	local error_message = "Cannot find any of the following applications to open the URL: "
		.. table.concat(apps, ", ")
		.. "on "
		.. os_uname
		.. ". Please install one of these applications or add your preferred app to the URL options."
	error(error_message)
end

local system_open_url = function(user_opts, url)
	if url then
		local open_app = user_opts.open_app
		if open_app == "default" or open_app == "" then
			if os_uname == "Linux" then
				open_url_with_app({ "xdg-open", "gvfs-open", "gnome-open" }, url)
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

local open_url = function(user_opts)
	local cursor_pos = api.nvim_win_get_cursor(0)
	local cursor_col = cursor_pos[2]
	local line = api.nvim_get_current_line()
	local url_to_open = nil

	-- get the first url in the line
	local start_pos, end_pos, url = find_first_url_in_line(user_opts, line)

	while url do
		if user_opts.open_only_when_cursor_on_url then
			if cursor_col >= start_pos - 1 and cursor_col < end_pos then
				url_to_open = url
				break
			end
		else
			url_to_open = url
		end
		if cursor_col < end_pos then break end
		-- find the next url
		start_pos, end_pos, url = find_first_url_in_line(user_opts, line, end_pos + 1)
	end

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

	local start_pos, end_pos, url = find_first_url_in_line(user_opts, line)

	while url do
		-- clear the other highlight url to make sure only one url is highlighted
		delete_url_effect("URLOpenHighlightCursor")
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

		start_pos, end_pos, url = find_first_url_in_line(user_opts, line, end_pos + 1)
	end
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
	local options = vim.tbl_deep_extend("force", DEFAULT_OPTIONS, user_opts or {})
	init_command(options)
	init_autocmd(options)
end

return Plugin
