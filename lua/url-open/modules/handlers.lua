--- Handlers for opening urls
--
--
local api = vim.api
local fn = vim.fn

local patterns_module = require("url-open.modules.patterns")
local logger = require("url-open.modules.logger")

local M = {}

--- Call a vim command
-- @tparam string command : The command to execute
-- @tparam table msg : The message to print on success or error
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

--- Find the first url in the text
-- @tparam table user_opts : User options
-- @tparam string text : Text to search for urls
-- @tparam number start_pos : Start position to search from (optional) (default: 0)
-- @return start_pos, end_pos, url: Start position, end position, and url of the first url found (all nil if not found)
-- @see url-open.modules.patterns
M.find_url = function(user_opts, text, start_pos)
	start_pos = start_pos or 1

	local min_start_pos_found = string.len(text)
	local start_found, end_found, url_found = nil, nil, nil
	for pattern, prefix in pairs(patterns_module.PATTERNS) do
		local start_pos_result, end_pos_result, url = text:find(pattern, start_pos)
		if url and min_start_pos_found > start_pos_result then
			min_start_pos_found = start_pos_result
			url = prefix .. url
			start_found, end_found, url_found = start_pos_result, end_pos_result, url
		end
	end

	-- check extra patterns
	for pattern, subs in pairs(user_opts.extra_patterns) do
		local start_pos_result, end_pos_result, url = text:find(pattern, start_pos)
		if url and min_start_pos_found > start_pos_result then
			min_start_pos_found = start_pos_result
			subs = subs or ""
			if type(subs) == "string" then
				url = subs .. url
			else
				url = (subs.prefix or "") .. url .. (subs.suffix or "")
			end
			start_found, end_found, url_found = start_pos_result, end_pos_result, url
		end
	end

	-- fallback to deep pattern
	if user_opts.deep_pattern then
		local results = fn.matchstrpos(text, patterns_module.DEEP_PATTERN, start_pos)
		-- result[1] is url, result[2] is start_pos, result[3] is end_pos
		if results[1] ~= "" and min_start_pos_found > results[2] then
			min_start_pos_found = results[2]
			start_found, end_found, url_found = results[2], results[3], results[1]
		end
	end

	return start_found, end_found, url_found
end

--- Open the url under the cursor
-- If there is only one url in the line, then open it anywhere in the line.
-- @tparam table user_opts : User options
M.open_url = function(user_opts)
	local cursor_pos = api.nvim_win_get_cursor(0)
	local cursor_col = cursor_pos[2]
	local line = api.nvim_get_current_line()

	local url_to_open = nil

	-- get the first url in the line
	local start_pos, end_pos, url = M.find_url(user_opts, line)

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
		start_pos, end_pos, url = M.find_url(user_opts, line, end_pos + 1)
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
-- @see url-open.modules.patterns
M.set_url_effect = function(user_opts)
	M.delete_url_effect("HighlightAllUrl")
	fn.matchadd("HighlightAllUrl", patterns_module.DEEP_PATTERN, 15)
end

--- Highlight the url under the cursor
-- @tparam table user_opts : User options
-- @see url-open.modules.patterns
M.highlight_cursor_url = function(user_opts)
	-- clear old highlight when moving cursor
	M.delete_url_effect("HighlightCursorUrl")

	local cursor_pos = api.nvim_win_get_cursor(0)
	local cursor_row = cursor_pos[1]
	local cursor_col = cursor_pos[2]
	local line = api.nvim_get_current_line()

	local start_pos, end_pos, url = M.find_url(user_opts, line)

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
		start_pos, end_pos, url = M.find_url(user_opts, line, end_pos + 1)
	end
end
return M
