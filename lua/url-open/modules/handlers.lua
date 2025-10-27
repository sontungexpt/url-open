--- Handlers for opening urls
--
--
local api = vim.api
local fn = vim.fn
local uv = vim.uv or vim.loop
local os_uname = uv.os_uname().sysname

local patterns_module = require("url-open.modules.patterns")

local M = {}

--- Check if the file path matches any of the patterns
--- @tparam table file_patterns : Patterns to match the file path
--- @tparam boolean is_excluded : If the file path is excluded (optional) (default: false)
--- @treturn boolean : True if the file path matches any of the patterns, otherwise false
M.matches_file_patterns = function(file_patterns, is_excluded)
	if type(file_patterns) == "string" then file_patterns = { file_patterns } end
	if file_patterns == nil or #file_patterns == 0 then return not is_excluded end

	local file_path = api.nvim_buf_get_name(0)
	for _, pattern in ipairs(file_patterns) do
		if file_path:match(pattern) then return true end
	end
	return false
end

--- Check if the pattern found matches the condition
--- @tparam string pattern_found : The url to check
--- @tparam function|boolean condition : The condition to check (function(pattern_found))
--- @treturn boolean : True if the pattern found matches the condition, otherwise false
--- @see url-open.modules.patterns
M.matches_condition_pattern = function(pattern_found, condition)
	-- type(nil) == nil
	if type(condition) == "function" then condition = condition(pattern_found) end
	return type(condition) ~= "boolean" and true or condition
end

--- Find the first url in the text that matches any of the patterns
--- @tparam string text  : Text to search for patterns
--- @tparam table patterns : Patterns to search for urls in the text
--- @tparam number start_pos : Start position to search from (optional) (default: 0)
--- @tparam number found_url_smaller_pos : The position of the found url must be smaller than this number (optional) (default: string.len(text))
--- @see url-open.modules.patterns
M.find_first_matching_url = function(text, patterns, start_pos, found_url_smaller_pos)
	start_pos = start_pos or 1
	found_url_smaller_pos = found_url_smaller_pos or #text
	local start_found, end_found, url_found = nil, nil, nil

	for _, cond in ipairs(patterns) do
		if
			not M.matches_file_patterns(cond.excluded_file_patterns, true)
			and M.matches_file_patterns(cond.file_patterns)
		then
			local start_pos_result, end_pos_result, url = text:find(cond.pattern, start_pos)
			if
				url
				and found_url_smaller_pos > start_pos_result
				and M.matches_condition_pattern(url, cond.extra_condition)
			then
				found_url_smaller_pos = start_pos_result
				url_found = (cond.prefix or "") .. url .. (cond.suffix or "")
				start_found, end_found = start_pos_result, end_pos_result
			end
		end
	end

	return start_found, end_found, url_found
end

--- Find the first url in the line
--- @tparam table user_opts : User options
--- @tparam string text : Text to search for urls
--- @tparam number start_pos : Start position to search from (optional) (default: 1)
--- @treturn number start_pos, number end_pos, string url: Start position, end position, and url of the first url found (all nil if not found)
--- @see url-open.modules.patterns
--- @see url-open.modules.options
--- @see url-open.modules.handlers.find_first_matching_url
M.find_first_url_in_line = function(user_opts, text, start_pos)
	-- check default patterns first
	local start_found, end_found, url_found =
		M.find_first_matching_url(text, patterns_module.PATTERNS, start_pos)

	local extra_start_found, extra_end_found, extra_url_found =
		M.find_first_matching_url(text, user_opts.extra_patterns, start_pos, start_found)

	if extra_start_found then
		start_found, end_found, url_found = extra_start_found, extra_end_found, extra_url_found
	end

	-- fallback to deep pattern
	if user_opts.deep_pattern then
		local results = fn.matchstrpos(text, patterns_module.DEEP_PATTERN, start_pos)
		-- result[1] is url, result[2] is start_pos, result[3] is end_pos
		-- >= to make deep_pattern has higher priority than default patterns
		if results[1] ~= "" and (start_found or #text) >= results[2] + 1 then
			start_found, end_found, url_found = results[2] + 1, results[3], results[1]
		end
	end

	return start_found, end_found, url_found
end

--- Open the url with the specified app
--- @tparam table apps : The table of apps to open the url
--- @tparam string url : The url to open
M.open_url_with_app = function(apps, url)
	for _, app in ipairs(apps) do
		if fn.executable(app) == 1 or os_uname == "Windows_NT" then
			local command = app .. " " .. fn.shellescape(url)
			fn.jobstart(command, {
				detach = os_uname ~= "Windows_NT",
				on_exit = function(_, code, _)
					if code ~= 0 then
						require("url-open.modules.logger").error("Failed to open " .. url)
					else
						require("url-open.modules.logger").info("Opening " .. url)
					end
				end,
			})
			return
		end
	end
	require("url-open.modules.logger").error(
		string.format(
			"Cannot find any of the following applications to open the URL: %s on %s. Please install one of these applications or add your preferred app to the URL options.",
			table.concat(apps, ", "),
			os_uname
		)
	)
end

--- Open the url relying on the operating system
--- @tparam table user_opts : User options
--- @tparam string url : The url to open
--- @see url-open.modules.handlers.open_url_with_app
M.system_open_url = function(user_opts, url)
	if url then
		local open_app = user_opts.open_app
		if open_app == "default" or open_app == "" then
			if os_uname == "Linux" then
				M.open_url_with_app({ "xdg-open", "gvfs-open", "gnome-open", "wslview" }, url)
			elseif os_uname == "Darwin" then
				M.open_url_with_app({ "open" }, url)
			elseif os_uname == "Windows_NT" then
				M.open_url_with_app({ "start" }, url)
			else
				require("url-open.modules.logger").error("Unknown operating system")
			end
		else
			M.open_url_with_app({ open_app }, url)
		end
	else
		require("url-open.modules.logger").error("No url found")
	end
end

--- Iterate through all urls in the line
--- @tparam table user_opts : User options
--- @tparam string line : The line to iterate through
--- @tparam function callback : The callback function to call for each url
--- @see url-open.modules.handlers.find_first_url_in_line
M.foreach_url_in_line = function(user_opts, line, callback)
	local start_found, end_found, url = M.find_first_url_in_line(user_opts, line)

	while url do
		if callback(url, start_found, end_found) then return end
		start_found, end_found, url = M.find_first_url_in_line(user_opts, line, end_found + 1)
	end
end

--- Open the url under the cursor
--- If there is only one url in the line, then open it anywhere in the line.
--- @tparam table user_opts : User options
--- @see url-open.modules.options
--- @see url-open.modules.handlers.find_first_url_in_line
--- @see url-open.modules.handlers.system_open_url
M.open_url = function(user_opts)
	local cursor_pos = api.nvim_win_get_cursor(0)
	local cursor_col = cursor_pos[2]
	local line = api.nvim_get_current_line()
	local url_to_open = nil

	-- get the first url in the line
	M.foreach_url_in_line(user_opts, line, function(url, start_found, end_found)
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

	M.system_open_url(user_opts, url_to_open)
end

return M
