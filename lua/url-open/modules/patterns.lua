--- Provides default patterns to match urls
--
local M = {}

--- Deep Pattern to match urls from text. This pattern will find urls in the following formats:
-- @field http://example.com
-- @field https://www.example.com
-- @field ftp://ftp.example.com
-- @field file:///path/to/file.txt
-- @field ssh://user@hostname
-- @field git://github.com/user/repo
-- @field http://example.com/path?param=value
-- @field https://www.example.com/another/path#section
-- @field http://example.com:8080
-- @field https://www.example.com:8443
-- @field ftp://ftp.example.com:2121

M.DEEP_PATTERN =
	"\\v\\c%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)%([&:#*@~%<>_\\-=?!+;/0-9a-z]+%(%([.;/?]|[.][.]+)[&:#*@~%<>_\\-=?!+/0-9a-z]+|:\\d+|,%(%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)@![0-9a-z]+))*|\\([&:#*@~%_\\-=?!+;/.0-9a-z]*\\)|\\[[&:#*@~%_\\-=?!+;/.0-9a-z]*\\]|\\{%([&:#*@~%_\\-=?!+;/.0-9a-z]*|\\{[&:#*@~%_\\-=?!+;/.0-9a-z]*\\})\\})+"
--
---
-- Default Patterns to match urls.
--
-- Format: key: pattern, value: {prefix, suffix} or string prefix.
--
-- Http(s): ["(https?://[%w-_%.]+%.%w[%w-_%.%%%?%.:/+=&%%[%]#<>]*)"]
--
-- Npm Package: ['["]([^%s]*)["]:%s*"[^"]*%d[%d%.]*"']
--
-- Git Plugin: ["[\"']([^%s~/]*/[^%s~/]*)[\"']"]
--
-- Markdown Link: %[.*%]%((https?://[a-zA-Z0-9_/%-%.~@\\+#=?&]+)%)"
--
-- Brew Formula: ['brew ["]([^%s]*)["]']
--
-- Cask Formula: ['cask ["]([^%s]*)["]']
--
-- Cargo Package: ["^%s*([%w_]+)%s*="]
M.PATTERNS = {
	["(https?://[%w-_%.]+%.%w[%w-_%.%%%?%.:/+=&%%[%]#<>]*)"] = "", --- url http(s)
	['["]([^%s]*)["]:%s*"[^"]*%d[%d%.]*"'] = {
		prefix = "https://www.npmjs.com/package/",
		suffix = "",
		file_patterns = { "package%.json" },
		extra_condition = function(pattern_found)
			return pattern_found ~= "version" and pattern_found ~= "proxy"
		end,
		-- excluded_file_patterns = {},
	}, --- npm package
	["[\"']([^%s~/]*/[^%s~/]*)[\"']"] = {
		prefix = "https://github.com/",
		suffix = "",
		-- file_patterns = {},
		excluded_file_patterns = { "package%.json", "package%-lock%.json" },
	}, --- plugin name git
	['brew ["]([^%s]*)["]'] = "https://formulae.brew.sh/formula/", --- brew formula
	['cask ["]([^%s]*)["]'] = "https://formulae.brew.sh/cask/", --- cask formula
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
	}, --- cargo package
}

return M
