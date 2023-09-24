--- Handlers for opening urls
--
--
local api = vim.api
local fn = vim.fn

local patterns_module = require("url-open.modules.patterns")
local logger = require("url-open.modules.logger")
local os_uname = vim.loop.os_uname().sysname

local M = {}

--- Call a vim command
--- @tparam string command : The command to execute
--- @tparam table msg : The message to print on success or error
M.call_cmd = function(command, msg)
	local success, error_message = pcall(api.nvim_command, command)
	if success then
		logger.info(msg and msg.success or "Success")
	else
		logger.error((msg and msg.error or "Error") .. ": " .. error_message)
	end
end

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
--- @see url-open.modules.handlers.call_cmd
M.open_url_with_app = function(apps, url)
	for _, app in ipairs(apps) do
		if fn.executable(app) == 1 then
			local shell_safe_url = fn.shellescape(url)
			local command = "silent! !" .. app .. " " .. shell_safe_url
			M.call_cmd(command, {
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
	logger.error(error_message)
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
				M.open_url_with_app({ "xdg-open", "gvfs-open", "gnome-open" }, url)
			elseif vim.loop.os_uname().sysname == "Darwin" then
				M.open_url_with_app({ "open" }, url)
			elseif vim.loop.os_uname().sysname == "Windows" then
				M.open_url_with_app({ "start" }, url)
			else
				logger.error("Unknown operating system")
			end
		else
			M.open_url_with_app({ open_app }, url)
		end
	else
		logger.error("No url found")
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
	local start_pos, end_pos, url = M.find_first_url_in_line(user_opts, line)

	while url do
		-- if the url under cursor, then break
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
		start_pos, end_pos, url = M.find_first_url_in_line(user_opts, line, end_pos + 1)
	end

	M.system_open_url(user_opts, url_to_open)
end

return M
