title = "url-open"
project = "url-open"
description = "Open url under cursor in the default browser without netrw"
format="discount"
dir="docs"
readme="README.md"
sort=true
file="./lua/"
sort_modules=true

local upat = "http://www.url-open.org/docs/%s/%s.%s.html"
custom_see_handler('^([%w_]+)%((%d)%)$',function(name,section)
    local url = upat:format(section,name,section)
    local name = name .. '(' ..section..')'
    return name, url
end)


