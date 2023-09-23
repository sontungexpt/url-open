--- Provides default patterns to match urls
--
local M = {}

--- Deep Pattern to match urls from text. This pattern will find urls in the following formats:
--  http://example.com
--  https://www.example.com
--  ftp://ftp.example.com
--  file:///path/to/file.txt
--  ssh://user@hostname
--  git://github.com/user/repo
--  http://example.com/path?param=value
--  https://www.example.com/another/path#section
--  http://example.com:8080
--  https://www.example.com:8443
--  ftp://ftp.example.com:2121
M.DEEP_PATTERN =
	"\\v\\c%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)%([&:#*@~%<>_\\-=?!+;/0-9a-z]+%(%([.;/?]|[.][.]+)[&:#*@~%<>_\\-=?!+/0-9a-z]+|:\\d+|,%(%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)@![0-9a-z]+))*|\\([&:#*@~%_\\-=?!+;/.0-9a-z]*\\)|\\[[&:#*@~%_\\-=?!+;/.0-9a-z]*\\]|\\{%([&:#*@~%_\\-=?!+;/.0-9a-z]*|\\{[&:#*@~%_\\-=?!+;/.0-9a-z]*\\})\\})+"

---
-- Default Patterns to match urls.
--
-- Http(s) URL pattern
-- Matches URLs starting with "http://" or "https://"
-- Example: "http://example.com", "https://www.example.com"
-- Pattern: "(https?://[%w-_%.]+%.%w[%w-_%.%%%?%.:/+=&%%[%]#<>]*)"
-- Prefix: ""
-- Suffix: ""
-- File_patterns: All files
-- Extra_condition: None
-- Excluded_file_patterns: None
-- Note: This pattern is used to match urls in all files
--
--
-- Npm Package pattern
-- Matches npm package names
-- Example: "react", "react-dom"
-- Pattern: '["]([^%s]*)["]:%s*"[^"]*%d[%d%.]*"'
-- Prefix: "https://www.npmjs.com/package/"
-- Suffix: ""
-- File_patterns: "package%.json"
-- Extra_condition: pattern_found ~= "version" and pattern_found ~= "proxy"
-- Excluded_file_patterns: None
-- Note: This pattern is used to match npm packages in package.json files
--
-- Git Plugin pattern
-- Matches git plugin names
-- Example: "airblade/vim-gitgutter", "tpope/vim-fugitive"
-- Pattern: "[\"']([^%s~/]*/[^%s~/]*)[\"']"
-- Prefix: "https://github.com/"
-- Suffix: ""
-- File_patterns: All files except package.json and package-lock.json
-- Extra_condition: None
-- Excluded_file_patterns: "package%.json", "package%-lock%.json"
-- Note: This pattern is used to match git plugins in all files except package.json and package-lock.json
--
--
-- Brew Formula pattern
-- Matches brew formula names
-- Example: "bat", "exa"
-- Pattern: 'brew ["]([^%s]*)["]'
-- Prefix: "https://formulae.brew.sh/formula/"
-- Suffix: ""
-- File_patterns: All files
-- Extra_condition: None
-- Excluded_file_patterns: None
-- Note: This pattern is used to match brew formulas in all files
--
-- Cask Formula pattern
-- Matches cask formula names
-- Example: "firefox", "google-chrome"
-- Pattern: 'cask ["]([^%s]*)["]'
-- Prefix: "https://formulae.brew.sh/cask/"
-- Suffix: ""
-- File_patterns: All files
-- Extra_condition: None
-- Excluded_file_patterns: None
-- Note: This pattern is used to match cask formulas in all files
--
-- Cargo Package pattern
-- Matches cargo package names
-- Example: "serde", "serde_json"
-- Pattern: "^%s*([%w_]+)%s*="
-- Prefix: "https://crates.io/crates/"
-- Suffix: ""
-- File_patterns: "Cargo%.toml"
-- Extra_condition: not vim.tbl_contains({
--   "name",
--   "version",
--   "edition",
--   "authors",
--   "description",
--   "license",
--   "repository",
--   "homepage",
--   "documentation",
--   "keywords",
--   }, pattern_found)
-- Excluded_file_patterns: None
-- Note: This pattern is used to match cargo packages in Cargo.toml files
M.PATTERNS = {
	["(https?://[%w-_%.]+%.%w[%w-_%.%%%?%.:/+=&%%[%]#<>]*)"] = "", --- url http(s)
	['["]([^%s]*)["]:%s*"[^"]*%d[%d%.]*"'] = {
		prefix = "https://www.npmjs.com/package/",
		suffix = "",
		file_patterns = { "package%.json" },
		extra_condition = function(pattern_found)
			return pattern_found ~= "version" and pattern_found ~= "proxy"
		end,
	}, --- npm package
	["[\"']([^%s~/]*/[^%s~/]*)[\"']"] = {
		prefix = "https://github.com/",
		suffix = "",
		excluded_file_patterns = { "package%.json", "package%-lock%.json" },
	}, --- plugin name git
	['brew ["]([^%s]*)["]'] = {
		prefix = "https://formulae.brew.sh/formula/",
		suffix = "",
	}, --- brew formula
	['cask ["]([^%s]*)["]'] = {
		prefix = "https://formulae.brew.sh/cask/",
		suffix = "",
	}, --- cask formula
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
