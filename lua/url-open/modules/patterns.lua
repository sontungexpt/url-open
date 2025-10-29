--- Provides default patterns to match urls
--
local M = {}

--- Deep Pattern to match URLs from text. This pattern will find URLs in various formats.
--- Supported URL formats:
--
-- - http://example.com
-- - https://www.example.com
-- - ftp://ftp.example.com
-- - file:///path/to/file.txt
-- - ssh://user@hostname
-- - git://github.com/user/repo
-- - http://example.com/path?param=value
-- - https://www.example.com/another/path#section
-- - http://example.com:8080
-- - https://www.example.com:8443
-- - ftp://ftp.example.com:2121
M.DEEP_PATTERN =
	"\\v\\c%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)%([&:#*@~%_\\-=?!+;/0-9a-z]+%(%([.;/?]|[.][.]+)[&:#*@~%_\\-=?!+/0-9a-z]+|:\\d+|,%(%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)@![0-9a-z]+))*|\\([&:#*@~%_\\-=?!+;/.0-9a-z]*\\)|\\[[&:#*@~%_\\-=?!+;/.0-9a-z]*\\]|\\{%([&:#*@~%_\\-=?!+;/.0-9a-z]*|\\{[&:#*@~%_\\-=?!+;/.0-9a-z]*\\})\\})+"

---
--- Default patterns to match urls
--- @table PATTERNS
--- @tfield string pattern : Pattern to match urls (required)
--- @tfield string|nil prefix : Prefix to add to the url
--- @tfield string|nil suffix : Suffix to add to the url
--- @tfield table|string|nil file_patterns : File patterns to match against
--- @tfield table|string|nil excluded_file_patterns : File patterns to exclude
--- @tfield function(pattern_found)|boolean|nil extra_condition : A callback function will be called with the pattern found as argument. If the function returns false, the pattern will be ignored. If the function returns true, the pattern will be used.
M.PATTERNS = {
	{
		pattern = "(https?://[%w-_%.]+%.%w[%w-_%.%%%?%.:/+=&%%[%]#]*)",
		prefix = "",
		suffix = "",
		file_patterns = nil,
		excluded_file_patterns = nil,
		extra_condition = nil,
	},
	{
		pattern = '["]([^%s]*)["]:%s*"[^"]*%d[%d%.]*"',
		prefix = "https://www.npmjs.com/package/",
		suffix = "",
		file_patterns = { "package%.json" },
		excluded_file_patterns = nil,
		extra_condition = function(pattern_found)
			return not vim.tbl_contains({ "name", "version", "proxy" }, pattern_found)
		end,
	},
	{
		pattern = "[\"']([^%s~/]+/[^%s~/]+)[\"']",
		prefix = "https://github.com/",
		suffix = "",
		file_patterns = nil,
		excluded_file_patterns = { "package%.json", "package%-lock%.json" },
		extra_condition = nil,
	},
	{
		pattern = 'brew ["]([^%s]*)["]',
		prefix = "https://formulae.brew.sh/formula/",
		suffix = "",
		file_patterns = nil,
		excluded_file_patterns = nil,
		extra_condition = nil,
	},
	{
		pattern = 'cask ["]([^%s]*)["]',
		prefix = "https://formulae.brew.sh/cask/",
		suffix = "",
		file_patterns = nil,
		excluded_file_patterns = nil,
		extra_condition = nil,
	},
	{
		pattern = "^%s*([%w-_]+)%s*=",
		prefix = "https://crates.io/crates/",
		suffix = "",
		file_patterns = { "Cargo%.toml" },
		excluded_file_patterns = nil,
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
	},
	{
		pattern = "gem ['\"]([^%s]*)['\"]",
		prefix = "https://rubygems.org/gems/",
		suffix = "",
		file_patterns = { "Gemfile", "gems.rb" },
		excluded_file_patterns = nil,
	},
	-- Dockerfile images: unprefix, unnamespaced (the library images, like `ruby:3.2`)
	-- results in: https://hub.docker.com/_/ruby/
	{
		pattern = "^FROM ([^:.]+):",
		prefix = "https://hub.docker.com/_/",
		suffix = "/",
		file_patterns = { "Dockerfile%S*", "Containerfile%S*" },
		excluded_file_patterns = nil,
		extra_condition = function(matched_pattern) return not matched_pattern:match("/") end,
	},
	-- Dockerfile images: unprefixed but namespaced (like crystallang/crystal)
	-- results in: https://hub.docker.com/r/crystallang/crystal
	{
		pattern = "FROM ([^:.]+):",
		prefix = "https://hub.docker.com/r/",
		suffix = "/",
		file_patterns = { "Dockerfile%S*", "Containerfile%S*" },
		excluded_file_patterns = nil,
		extra_condition = function(matched_pattern) return matched_pattern:match("/") end,
	},
}

return M
