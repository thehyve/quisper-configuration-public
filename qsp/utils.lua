--
-- This file contains several helper methods used in the nginx configuration.
-- These methods are provided by 3scale, and have not been changed since
-- downloading the config from the 3scale system.
-- User: robert
-- Date: 7/10/14
--
local qsp_utils = {
    logging = {}
}

-- Logging Helpers
function qsp_utils.logging.show_table(a)
    for k,v in pairs(a) do
        local msg = ""
        msg = msg.. k
        if type(v) == "string" then
            msg = msg.. " => " .. v
        end
        ngx.log(0,msg)
    end
end

function qsp_utils.logging.log_message(str)
    ngx.log(0, str)
end

function qsp_utils.logging.log(content)
    if type(content) == "table" then
        qsp_utils.logging.show_table(content)
    else
        qsp_utils.logging.log_message(content)
    end
    qsp_utils.logging.newline()
end

function qsp_utils.logging.newline()
    ngx.log(0,"  ---   ")
end
-- End Logging Helpers

--[[
  Aux function to split a string
]]--

function string:split(delimiter)
    local result = { }
    local from = 1
    local delim_from, delim_to = string.find( self, delimiter, from )
    while delim_from do
        table.insert( result, string.sub( self, from , delim_from-1 ) )
        from = delim_to + 1
        delim_from, delim_to = string.find( self, delimiter, from )
    end
    table.insert( result, string.sub( self, from ) )
    return result
end

function qsp_utils.first_values(a)
    r = {}
    for k,v in pairs(a) do
        if type(v) == "table" then
            r[k] = v[1]
        else
            r[k] = v
        end
    end
    return r
end

function qsp_utils.set_or_inc(t, name, delta)
    return (t[name] or 0) + delta
end


function qsp_utils.copy_table(t)
    local u = { }
    for k, v in pairs(t) do u[k] = v end
    return setmetatable(u, getmetatable(t))
end

---
-- Builds a query string from a table.
--
-- This is the inverse of <code>parse_query</code>.
-- @param query A dictionary table where <code>table['name']</code> =
-- <code>value</code>.
-- @return A query string (like <code>"name=value2&name=value2"</code>).
-----------------------------------------------------------------------------
function qsp_utils.build_query(query)
    local qstr = ""

    for i,v in pairs(query) do
        qstr = qstr .. i .. '=' .. v .. '&'
    end
    return string.sub(qstr, 0, #qstr-1)
end

return qsp_utils