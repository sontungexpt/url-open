--- Handlers for opening urls
--
--
local api = vim.api
local fn = vim.fn

local patterns_module = require("url-open.modules.patterns")
local logger = require("url-open.modules.logger")

local M = {}

--- Call a vim command
--- @tparam string command : The command to execute
--- @tparam table msg : The message to print on success or error
M.call_cmd = function(command, msg)
	local success, error_message = pcall(api.nvim_command, command)
	if success then
		if msg and msg.success then
			logger.info(msg.success, { title = "URL Handler" })
		else
			logger.info("Success", { title = "URL Handler" })
		end
	else
		if msg and msg.error then
			logger.error(msg.error .. ": " .. error_message, { title = "URL Handler" })
		else
			logger.error("Error: " .. error_message, { title = "URL Handler" })
		end
	end
end

--- Check if the file path matches any of the patterns
--- @tparam table file_patterns : Patterns to match the file path
--- @tparam boolean is_excluded : If the file path is excluded (optional) (default: false)
--- @treturn boolean : True if the file path matches any of the patterns, otherwise false
M.check_file_patterns = function(file_patterns, is_excluded)
	if type(file_patterns) == "string" then file_patterns = { file_patterns } end
	if file_patterns == nil or #file_patterns == 0 then return not is_excluded end

	local file_path = api.nvim_buf_get_name(0)
	for _, pattern in ipairs(file_patterns) do
		if file_path:match(pattern) then return true end
	end
	return false
end

--- Check if the text contains any of the patterns
--- @tparam string text  : Text to search for patterns
--- @tparam table patterns : Patterns to search for urls in the text
--- @tparam number start_pos : Start position to search from (optional) (default: 0)
--- @tparam number found_url_smaller_pos : The position of the found url must be smaller than this number (optional) (default: string.len(text))
--- @see url-open.modules.patterns
M.find_first_url_matching_patterns = function(text, patterns, start_pos, found_url_smaller_pos)
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
			not M.check_file_patterns(subs.excluded_file_patterns, true)
			and M.check_file_patterns(subs.file_patterns)
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

--- Find the first url in the text
--- @tparam table user_opts : User options
--- @tparam string text : Text to search for urls
--- @tparam number start_pos : Start position to search from (optional) (default: 1)
--- @treturn number start_pos, number end_pos, string url: Start position, end position, and url of the first url found (all nil if not found)
--- @see url-open.modules.patterns
M.find_first_url_in_text = function(user_opts, text, start_pos)
	-- check default patterns first
	local start_found, end_found, url_found =
		M.find_first_url_matching_patterns(text, patterns_module.PATTERNS, start_pos)

	-- check extra patterns of user if found nothing in default patterns
	-- if find a url in extra patterns and
	-- its start position is smaller than the start position of the url found in default patterns,
	-- then use it otherwise use the url found in default patterns
	local extra_start_found, extra_end_found, extra_url_found =
		M.find_first_url_matching_patterns(text, user_opts.extra_patterns, start_pos, start_found)

	if extra_start_found then
		start_found, end_found, url_found = extra_start_found, extra_end_found, extra_url_found
	end

	-- fallback to deep pattern
	if user_opts.deep_pattern then
		local results = fn.matchstrpos(text, patterns_module.DEEP_PATTERN, start_pos)
		-- result[1] is url, result[2] is start_pos, result[3] is end_pos
		-- >= to make deep_pattern has higher priority than default patterns
		if results[1] ~= "" and (start_found or string.len(text)) >= results[2] + 1 then
			start_found, end_found, url_found = results[2] + 1, results[3], results[1]
		end
	end

	return start_found, end_found, url_found
end

--- Open the url under the cursor
--- If there is only one url in the line, then open it anywhere in the line.
--- @tparam table user_opts : User options
M.open_url = function(user_opts)
	local cursor_pos = api.nvim_win_get_cursor(0)
	local cursor_col = cursor_pos[2]
	local line = api.nvim_get_current_line()

	local url_to_open = nil

	-- get the first url in the line
	local start_pos, end_pos, url = M.find_first_url_in_text(user_opts, line)

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

		--if cursor_col >= start_pos and cursor_col < end_pos then break end
		-- end pos is the next char after the url
		if cursor_col < end_pos then break end

		-- find the next url
		start_pos, end_pos, url = M.find_first_url_in_text(user_opts, line, end_pos + 1)
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
					logger.error("Unknown command to open url on Linux", { title = "URL Handler" })
					return
				end
			elseif vim.loop.os_uname().sysname == "Darwin" then
				if fn.executable("open") == 1 then
					command = "silent! !open " .. shell_safe_url
				else
					logger.error("Unknown command to open url on MacOS", { title = "URL Handler" })
					return
				end
			elseif vim.loop.os_uname().sysname == "Windows" then
				if fn.executable("start") == 1 then
					command = "silent! !start " .. shell_safe_url
				else
					logger.error("Unknown command to open url on Windows", { title = "URL Handler" })
					return
				end
			else
				logger.error("Unknown operating system.", { title = "URL Handler" })
				return
			end
		else
			if fn.executable(user_opts.open_app) == 1 then
				command = "silent! !" .. user_opts.open_app .. " " .. shell_safe_url
			else
				logger.error("Unknown application to open url", { title = "URL Handler" })
				return
			end
		end
		M.call_cmd(command, {
			success = "Opening " .. url_to_open .. " successfully.",
			error = "Opening " .. url_to_open .. " failed.",
		})
	else
		logger.error("No url found.", { title = "URL Handler" })
	end
end

--- Delete the syntax matching rules for URLs/URIs if set.
M.delete_url_effect = function(group_name)
	for _, match in ipairs(fn.getmatches()) do
		if match.group == group_name then fn.matchdelete(match.id) end
	end
end

--- Add syntax matching rules for highlighting URLs/URIs.
--- @see url-open.modules.patterns
M.set_url_effect = function(user_opts)
	M.delete_url_effect("HighlightAllUrl")
	fn.matchadd("HighlightAllUrl", patterns_module.DEEP_PATTERN, 15)
end

--- Highlight the url under the cursor
--- @tparam table user_opts : User options
--- @see url-open.modules.patterns
M.highlight_cursor_url = function(user_opts)
	-- clear old highlight when moving cursor
	M.delete_url_effect("HighlightCursorUrl")

	local cursor_pos = api.nvim_win_get_cursor(0)
	local cursor_row = cursor_pos[1]
	local cursor_col = cursor_pos[2]
	local line = api.nvim_get_current_line()

	local start_pos, end_pos, url = M.find_first_url_in_text(user_opts, line)

	while url do
		-- clear the other highlight url to make sure only one url is highlighted
		M.delete_url_effect("HighlightCursorUrl")
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
		start_pos, end_pos, url = M.find_first_url_in_text(user_opts, line, end_pos + 1)
	end
end

--- Change the color of the highlight
--- @tparam table opts : The user options
--- @tparam string group_name : The name of the highlight group
--- @treturn nil
--- @see url-open.modules.handlers.highlight_cursor_url
--- @see url-open.modules.handlers.set_url_effect
--- @see url-open.modules.autocmd.setup
--- @see url-open.setup
M.change_color_highlight = function(opts, group_name)
	opts.enabled = nil
	if opts.fg and opts.fg == "text" then opts.fg = nil end

	api.nvim_set_hl(0, group_name, opts)
end

return M
