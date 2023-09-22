local api = vim.api
local fn = vim.fn
local levels = vim.log.levels
local notify = vim.notify
local schedule = vim.schedule

local Plugin = {}

local info = function(msg, opts)
	schedule(function() notify(msg, levels.INFO, opts or { title = "Information" }) end)
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
	-- ['["]([^%s]*)["]:'] = "https://www.npmjs.com/package/", --- npm package
	['["]([^%s]*)["]:%s*"[^"]*%d[%d%.]*"'] = {
		prefix = "https://www.npmjs.com/package/",
		suffix = "",
		file_patterns = { "package%.json" },
		-- excluded_file_patterns = {},
	}, --- npm package
	["[\"']([^%s~/]*/[^%s~/]*)[\"']"] = {
		prefix = "https://github.com/",
		suffix = "",
		-- file_patterns = {},
		excluded_file_patterns = { "package%.json", "package%-lock%.json" },
		-- extra_condition = function() return true end,
	}, --- plugin name git
	['brew ["]([^%s]*)["]'] = "https://formulae.brew.sh/formula/", --- brew formula
	['cask ["]([^%s]*)["]'] = "https://formulae.brew.sh/cask/", --- cask formula
}

local call_cmd = function(command, msg)
	local success, error_message = pcall(api.nvim_command, command)
	if success then
		if msg and msg.success then
			info(msg.success, { title = "URL Handler" })
		else
			info("Success", { title = "URL Handler" })
		end
	else
		if msg and msg.error then
			error(msg.error .. ": " .. error_message, { title = "URL Handler" })
		else
			error("Error: " .. error_message, { title = "URL Handler" })
		end
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

local find_first_url_matching_patterns = function(text, patterns, start_pos, found_url_smaller_pos)
	found_url_smaller_pos = found_url_smaller_pos or string.len(text)
	start_pos = start_pos or 1
	local start_found, end_found, url_found = nil, nil, nil

	for pattern, subs in pairs(patterns) do
		subs = subs or { prefix = "" }
		if type(subs) == "string" then subs = { prefix = subs } end -- support old version

		local extra_condition = subs.extra_condition
		if extra_condition and type(extra_condition) == "function" then
			extra_condition = extra_condition()
		else
			extra_condition = true
		end

		if type(extra_condition) ~= "boolean" then extra_condition = true end
		if
			not check_file_patterns(subs.excluded_file_patterns, true)
			and check_file_patterns(subs.file_patterns)
			and extra_condition
		then
			local start_pos_result, end_pos_result, url = text:find(pattern, start_pos)
			if url and found_url_smaller_pos > start_pos_result then
				found_url_smaller_pos = start_pos_result
				url = (subs.prefix or "") .. url .. (subs.suffix or "")
				start_found, end_found, url_found = start_pos_result, end_pos_result, url
			end
		end
	end
	return start_found, end_found, url_found
end

local find_first_url_in_text = function(user_opts, text, start_pos)
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
		if results[1] ~= "" and (start_found or string.len(text)) > results[2] + 1 then
			start_found, end_found, url_found = results[2] + 1, results[3], results[1]
		end
	end

	return start_found, end_found, url_found
end

local open_url = function(user_opts)
	local cursor_pos = api.nvim_win_get_cursor(0)
	local cursor_col = cursor_pos[2]
	local line = api.nvim_get_current_line()

	local url_to_open = nil

	-- get the first url in the line
	local start_pos, end_pos, url = find_first_url_in_text(user_opts, line)

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
		start_pos, end_pos, url = find_first_url_in_text(user_opts, line, end_pos + 1)
	end

	if url_to_open then
		local shell_safe_url = fn.shellescape(url_to_open)
		local command = ""
		if user_opts.open_app == "default" or user_opts.open_app == "" then
			if vim.loop.os_uname().sysname == "Linux" then
				if fn.executable("xdg-open") == 1 then
					command = "silent! !xdg-open " .. shell_safe_url
				elseif fn.executable("gnome-open") then
					command = "silent! !gnome-open " .. shell_safe_url
				else
					error("Unknown command to open url on Linux", { title = "URL Handler" })
					return
				end
			elseif vim.loop.os_uname().sysname == "Darwin" then
				if fn.executable("open") == 1 then
					command = "silent! !open " .. shell_safe_url
				else
					error("Unknown command to open url on MacOS", { title = "URL Handler" })
					return
				end
			elseif vim.loop.os_uname().sysname == "Windows" then
				if fn.executable("start") == 1 then
					command = "silent! !start " .. shell_safe_url
				else
					error("Unknown command to open url on Windows", { title = "URL Handler" })
					return
				end
			else
				error("Unknown operating system.", { title = "URL Handler" })
				return
			end
		else
			if fn.executable(user_opts.open_app) == 1 then
				command = "silent! !" .. user_opts.open_app .. " " .. shell_safe_url
			else
				error("Unknown application to open url", { title = "URL Handler" })
				return
			end
		end
		call_cmd(command, {
			success = "Opening " .. url_to_open .. " successfully.",
			error = "Opening " .. url_to_open .. " failed.",
		})
	else
		error("No url found.", { title = "URL Handler" })
	end
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

--- Add syntax matching rules for highlighting URLs/URIs.
local set_url_effect = function()
	delete_url_effect("HighlightAllUrl")
	fn.matchadd("HighlightAllUrl", DEEP_PATTERN, 15)
end

local init_command = function(user_opts)
	api.nvim_create_user_command("OpenUrlUnderCursor", function() open_url(user_opts) end, { nargs = 0 })
	api.nvim_create_user_command("HighlightAllUrls", function()
		set_url_effect()
		change_color_highlight(user_opts.highlight_url.all_urls, "HighlightAllUrl")
	end, { nargs = 0 })
end

local function highlight_cursor_url(user_opts)
	delete_url_effect("HighlightCursorUrl")

	local cursor_pos = api.nvim_win_get_cursor(0)
	local cursor_row = cursor_pos[1]
	local cursor_col = cursor_pos[2]
	local line = api.nvim_get_current_line()

	local start_pos, end_pos, url = find_first_url_in_text(user_opts, line)

	while url do
		-- clear the other highlight url to make sure only one url is highlighted
		delete_url_effect("HighlightCursorUrl")
		if user_opts.open_only_when_cursor_on_url then
			if cursor_col >= start_pos - 1 and cursor_col < end_pos then
				fn.matchaddpos("HighlightCursorUrl", { { cursor_row, start_pos, end_pos - start_pos + 1 } }, 20)
				break
			end
		else
			fn.matchaddpos("HighlightCursorUrl", { { cursor_row, start_pos, end_pos - start_pos + 1 } }, 20)
		end

		--if cursor_col >= start_pos and cursor_col < end_pos then break end
		-- end pos is the next char after the url
		if cursor_col < end_pos then break end
		-- find the next url
		start_pos, end_pos, url = find_first_url_in_text(user_opts, line, end_pos + 1)
	end
end

local init_autocmd = function(user_opts)
	local highlight_url = user_opts.highlight_url

	if highlight_url.all_urls.enabled then
		api.nvim_command("HighlightAllUrls") -- Highlight all urls on startup

		api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
			desc = "URL Highlighting",
			group = api.nvim_create_augroup("HighlightAllUrl", { clear = true }),
			command = "HighlightAllUrls",
		})
	end

	if highlight_url.cursor_move.enabled then
		api.nvim_create_autocmd({ "CursorMoved" }, {
			desc = "URL Highlighting CursorMoved",
			group = api.nvim_create_augroup("HighlightCursorUrl", { clear = true }),
			callback = function()
				highlight_cursor_url(user_opts)
				change_color_highlight(highlight_url.cursor_move, "HighlightCursorUrl")
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
