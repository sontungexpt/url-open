--- This module provides a simple wrapper around vim.notify to make it easier to
--
local M = {}

local levels = vim.log.levels
local notify = vim.notify
local schedule = vim.schedule

--- Show info level notification
--- @tparam string msg : The message to show
--- @tparam[opt] table opts : The options to pass to vim.notify
M.info = function(msg, opts)
	schedule(function() notify(msg, levels.INFO, opts or { title = "URL OPEN INFO" }) end)
end

--- Show warn level notification
--- @tparam string msg : The message to show
--- @tparam[opt] table opts : The options to pass to vim.notify
M.warn = function(msg, opts)
	schedule(function() notify(msg, levels.WARN, opts or { title = "URL OPEN WARNING" }) end)
end

--- Show error level notification
--- @tparam string msg : The message to show
--- @tparam[opt] table opts : The options to pass to vim.notify
M.error = function(msg, opts)
	schedule(function() notify(msg, levels.ERROR, opts or { title = "URL OPEN ERROR" }) end)
end

return M
