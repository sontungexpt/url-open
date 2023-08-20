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
	start_pos = start_pos or 0

	for pattern, prefix in pairs(patterns_module.PATTERNS) do
		local start_pos_result, end_pos_result, url = text:find(pattern, start_pos)
		if url then
			url = prefix .. url
			return start_pos_result, end_pos_result, url
		end
	end

	-- check extra patterns
	for pattern, subs in pairs(user_opts.extra_patterns) do
		local start_pos_result, end_pos_result, url = text:find(pattern, start_pos)
		if url then
			subs = subs or ""
			if type(subs) == "string" then
				url = subs .. url
			else
				url = (subs.prefix or "") .. url .. (subs.suffix or "")
			end
			return start_pos_result, end_pos_result, url
		end
	end

	-- fallback to deep pattern
	if user_opts.deep_pattern then
		local results = fn.matchstrpos(text, patterns_module.DEEP_PATTERN, start_pos)
		-- result[1] is url, result[2] is start_pos, result[3] is end_pos
		if results[1] ~= "" then return results[2], results[3], results[1] end
	end

	return nil, nil, nil -- no url found
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
		url_to_open = url
		-- if the url under cursor, then break
		if cursor_col >= start_pos and cursor_col <= end_pos then break end

		-- find the next url
		start_pos, end_pos, url = M.find_url(user_opts, line, end_pos + 1)
	end

	if url_to_open then
		local shell_safe_url = fn.shellescape(url_to_open)
		local command = ""
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
		M.call_cmd(command, {
			success = "Opening " .. url_to_open .. " successfully.",
			error = "Opening " .. url_to_open .. " failed.",
		})
	end
end

return M
