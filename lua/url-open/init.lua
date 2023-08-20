local api = vim.api
local fn = vim.fn

local Plugin = {}

local DEFAULT_OPTIONS = {
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

local DEEP_PATTERN =
	"\\v\\c%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)%([&:#*@~%_\\-=?!+;/0-9a-z]+%(%([.;/?]|[.][.]+)[&:#*@~%_\\-=?!+/0-9a-z]+|:\\d+|,%(%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)@![0-9a-z]+))*|\\([&:#*@~%_\\-=?!+;/.0-9a-z]*\\)|\\[[&:#*@~%_\\-=?!+;/.0-9a-z]*\\]|\\{%([&:#*@~%_\\-=?!+;/.0-9a-z]*|\\{[&:#*@~%_\\-=?!+;/.0-9a-z]*\\})\\})+"

local PATTERNS = {
	["(https?://[%w-_%.%?%.:/%+=&]+%f[^%w])"] = "", --url http(s)
	['["]([^%s]*)["]:'] = "https://www.npmjs.com/package/", --npm package
	["[\"']([^%s~/]*/[^%s~/]*)[\"']"] = "https://github.com/", --plugin name git
	["%[.*%]%((https?://[a-zA-Z0-9_/%-%.~@\\+#=?&]+)%)"] = "", --markdown link
	['brew ["]([^%s]*)["]'] = "https://formulae.brew.sh/formula/", --brew formula
	['cask ["]([^%s]*)["]'] = "https://formulae.brew.sh/cask/", -- cask formula
}

local call_cmd = function(command, msg)
	local success, error_message = pcall(api.nvim_command, command)
	vim.schedule(function()
		if success then
			if msg and msg.success then
				vim.notify(msg.success, vim.log.levels.INFO, { title = "URL Handler" })
			else
				vim.notify("Success", vim.log.levels.INFO, { title = "URL Handler" })
			end
		else
			if msg and msg.error then
				vim.notify(msg.error .. ": " .. error_message, vim.log.levels.ERROR, { title = "URL Handler" })
			else
				vim.notify(error_message, vim.log.levels.ERROR, { title = "URL Handler" })
			end
		end
	end)
end

local find_url = function(user_opts, text, start_pos)
	start_pos = start_pos or 0

	for pattern, prefix in pairs(PATTERNS) do
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
		local results = fn.matchstrpos(text, DEEP_PATTERN, start_pos)
		-- result[1] is url, result[2] is start_pos, result[3] is end_pos
		if results[1] ~= "" then return results[2], results[3], results[1] end
	end

	return nil, nil, nil -- no url found
end

local open_url = function(user_opts)
    local cursor_pos = api.nvim_win_get_cursor(0)
    local cursor_col = cursor_pos[2]
    local line = api.nvim_get_current_line()

    local url_to_open = nil

    -- get the first url in the line
    local start_pos, end_pos, url = find_url(user_opts, line)

    while url do
        url_to_open = url
        -- if the url under cursor, then break
        if cursor_col >= start_pos and cursor_col <= end_pos then break end

        -- find the next url
        start_pos, end_pos, url = find_url(user_opts, line, end_pos + 1)
    end

    if url_to_open then
        local shell_safe_url = fn.shellescape(url_to_open)
        local command = ""
        if vim.loop.os_uname().sysname == "Linux" then
            command = "silent! !xdg-open " .. shell_safe_url
        elseif vim.loop.os_uname().sysname == "Darwin" then
            command = "silent! !open " .. shell_safe_url
        elseif vim.loop.os_uname().sysname == "Windows" then
            command = "silent! !start " .. shell_safe_url
        else
            print("Unknown operating system.")
            return
        end
        call_cmd(command, {
            success = "Opening " .. url_to_open .. " successfully.",
            error = "Opening " .. url_to_open .. " failed.",
        })
    end
end

local init_command = function(user_opts)
    vim.api.nvim_create_user_command(
        "OpenUrlUnderCursor",
        function() open_url(user_opts) end,
        { nargs = 0 }
    )
end

Plugin.setup = function(user_opts)
    local options = vim.tbl_deep_extend("force", DEFAULT_OPTIONS, user_opts or {})
	init_command(options)
end

return Plugin