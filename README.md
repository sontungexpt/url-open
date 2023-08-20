## Introduction

This plugin allow you to open url under cursor in neovim without netrw with
default browser of your system.

- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

<!--toc:end-->

## Features

- Open the url under cursor include markdown link (e.g. `https://github.com/sontungexpt/url-open`)
- Open the github page of neovim plugin name under cursor (e.g. `Plug 'nvim-lua/plenary.nvim'`, "sontungexpt/url-open")
- Open the npm package in package.json (e.g. `"lodash": "^4.17.21",`)
- Support brew formula, and cask
- Support deep pattern (disabled by default) to match with url below
  - http://example.com
  - https://www.example.com
  - ftp://ftp.example.com
  - file:///path/to/file.txt
  - ssh://user@hostname
  - git://github.com/user/repo
  - http://example.com/path?param=value
  - https://www.example.com/another/path#section
  - http://example.com:8080
  - https://www.example.com:8443
  - ftp://ftp.example.com:2121
- Allow you to open url from anywhere in the line if it only contains 1 url

## Installation

```lua
-- lazy.nvim
{
	"sontungexpt/url-open",
	cmd = "OpenUrlUnderCursor",
	config = function()
		local status_ok, url_open = pcall(require, "url-open")
		if not status_ok then
			return
		end
		url_open.setup ({})
	end,
},
```

- NOTE: If you want to use minimal source with no commnets, no validate configs,
  you can use branch `mini` instead of `main` branch. Make sure you know that your config is valid

```lua
-- lazy.nvim
{
	"sontungexpt/url-open",
    branch = "mini",
	cmd = "OpenUrlUnderCursor",
	config = function()
		local status_ok, url_open = pcall(require, "url-open")
		if not status_ok then
			return
		end
		url_open.setup ({})
	end,
},
```

## Configuration

You can easily add more patterns to open url under cursor by adding more patterns to `extra_patterns` config

```lua
-- default values
require("url_open").setup({
	deep_pattern = false,
	extra_patterns = {
		-- [pattern] = prefix: string only or nil
		-- [pattern] = {prefix = "", suffix = ""},
		--
		-- E.g: ['["]([^%s]*)["]:'] = "https://www.npmjs.com/package/",
		-- so the url will be https://www.npmjs.com/package/<pattern found>
		--
		-- E.g: ['["]([^%s]*)["]:'] = {prefix = "https://www.npmjs.com/package/", suffix = "/issues"},
		-- so the url will be https://www.npmjs.com/package/<pattern found>/issues
	},
})
```

## Usage

- This plugin provide a command `:OpenUrlUnderCursor` to open url under cursor

- This plugin will not map any key by default, you can map it by yourself

```lua
vim.keymap.set("n", "gx", "<esc>:OpenUrlUnderCursor<cr>")
```

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
