local M = {}

--- Deep Pattern to match urls
-- http://example.com
-- https://www.example.com
-- ftp://ftp.example.com
-- file:///path/to/file.txt
-- ssh://user@hostname
-- git://github.com/user/repo
-- http://example.com/path?param=value
-- https://www.example.com/another/path#section
-- http://example.com:8080
-- https://www.example.com:8443
-- ftp://ftp.example.com:2121
M.DEEP_PATTERN =
	"\\v\\c%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)%([&:#*@~%_\\-=?!+;/0-9a-z]+%(%([.;/?]|[.][.]+)[&:#*@~%_\\-=?!+/0-9a-z]+|:\\d+|,%(%(%(h?ttps?|ftp|file|ssh|git)://|[a-z]+[@][a-z]+[.][a-z]+:)@![0-9a-z]+))*|\\([&:#*@~%_\\-=?!+;/.0-9a-z]*\\)|\\[[&:#*@~%_\\-=?!+;/.0-9a-z]*\\]|\\{%([&:#*@~%_\\-=?!+;/.0-9a-z]*|\\{[&:#*@~%_\\-=?!+;/.0-9a-z]*\\})\\})+"

--- Default Patterns to match urls
M.PATTERNS = {
	["(https?://[%w-_%.%?%.:/%+=&]+%f[^%w])"] = "", --url http(s)
	['["]([^%s]*)["]:'] = "https://www.npmjs.com/package/", --npm package
	["[\"']([^%s~/]*/[^%s~/]*)[\"']"] = "https://github.com/", --plugin name git
	["%[.*%]%((https?://[a-zA-Z0-9_/%-%.~@\\+#=?&]+)%)"] = "", --markdown link
	['brew ["]([^%s]*)["]'] = "https://formulae.brew.sh/formula/", --brew formula
	['cask ["]([^%s]*)["]'] = "https://formulae.brew.sh/cask/", -- cask formula
}

return M
