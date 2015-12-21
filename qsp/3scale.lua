--
-- Created by IntelliJ IDEA.
-- User: robert
-- Date: 7/10/14
-- Time: 2:26 PM
-- To change this template use File | Settings | File Templates.
--

--
-- This module contains the methods needed to handle
-- authentication and logging using 3scale
--

local threescale = {}

--
-- Builds a URL query string from a given table
-- where each key is surrounded by "usage[...]"
-- This method is used to send usage details to
-- the 3scale backend
--
-- For example:
--   Input: { hits: 3 }
--   Output: usage[hits]=3
--
function threescale.build_usage_querystring(query)
    local qstr = ""

    for i,v in pairs(query) do
        qstr = qstr .. 'usage[' .. i .. ']' .. '=' .. v .. '&'
    end
    return string.sub(qstr, 0, #qstr-1)
end

--
-- Extracts the usage information to be sent to
-- the 3scale backend from the request.
-- First return value is a query string to be used for sending data to 3scale
-- Second return value is a list of rules matched. This is only used for debugging purposes
--
function threescale.extract_usage(service, request)
    local usage, matched_rules = service.extract_usage(request)
    local found = next(usage) ~= nil

    -- if there was no match, usage is set to nil and it will respond a 404, this behavior can be changed
    if found then
        return threescale.build_usage_querystring(usage), table.concat(matched_rules, ", ")
    else
        return nil
    end
end

function threescale.get_debug_value()
    local h = ngx.req.get_headers()
    if h["X-3scale-debug"] == '<YOUR_PROVIDER_KEY>' then
        return true
    else
        return false
    end
end

--[[
  Authorization logic
]]--

threescale.authorization = {}

--
-- Extracts the authorization parameters from the
-- header, url or body, depending on the setting
--
function threescale.authorization.get_auth_params(where, method)
    local params = {}
    if where == "headers" then
        params = ngx.req.get_headers()
    elseif method == "GET" then
        params = ngx.req.get_uri_args()
    else
        ngx.req.read_body()
        params = ngx.req.get_post_args()
    end
    return qsp_utils.first_values(params)
end


threescale.authorization.check_credentials = {}

function threescale.authorization.check_credentials.app_id_app_key(params, service)
    if params["app_id"] == nil or params["app_key"] == nil then
        threescale.error.no_credentials(service)
    end
end

function threescale.authorization.check_credentials.access_token(params, service)
    if params["access_token"] == nil then -- TODO: check where the params come
        threescale.error.no_credentials(service)
    end
end

function threescale.authorization.check_credentials.user_key(params, service)
    if params["user_key"] == nil then
        threescale.error.no_credentials(service)
    end
end

function threescale.authorization.authorize(auth_strat, params, service)
    if auth_strat == 'oauth' then
        threescale.authorization.oauth(params, service)
    else
        threescale.authorization.authrep(params, service)
    end
end

function threescale.authorization.oauth(params, service)
    local res = ngx.location.capture("/_threescale/toauth_authorize?access_token="..
            params.access_token ..
            "&user_id="..
            params.access_token,
        { share_all_vars = true })
    if ngx.var.usage ~= nil  then
        ngx.var.usage = threescale.authorization.add_trans(ngx.var.usage)
    end

    if res.status == 200 then
        local res2 = ngx.location.capture("/_threescale/oauth_report?access_token="..
                params.access_token, {method = ngx.HTTP_POST, share_all_vars = true})

        if res2.status ~= 202   then
            ngx.header.content_type = "application/json; charset=utf-8"
            ngx.print('{"error": "not authenticated in 3scale end"}')
            ngx.exit(ngx.HTTP_OK)
        end
    else
        ngx.print('{"error": "not authenticated in 3scale authorize returned'.. res.status .. ' "}')
        ngx.exit(ngx.HTTP_OK)
    end
end

function threescale.authorization.authrep(params, service)
    ngx.var.cached_key = ngx.var.cached_key .. ":" .. ngx.var.usage
    local api_keys = ngx.shared.api_keys
    local is_known = api_keys:get(ngx.var.cached_key)

    if is_known ~= 200 then
        local res = ngx.location.capture("/threescale_authrep", { share_all_vars = true })

        -- IN HERE YOU DEFINE THE ERROR IF CREDENTIALS ARE PASSED, BUT THEY ARE NOT VALID
        if res.status ~= 200 then
            -- remove the key, if it's not 200 let's go the slow route, to 3scale's backend
            api_keys:delete(ngx.var.cached_key)
            ngx.status = res.status
            ngx.header.content_type = "application/json"
            threescale.error.authorization_failed(service)
        else
            api_keys:set(ngx.var.cached_key,200)
        end

        ngx.var.cached_key = nil
    end

end

function threescale.authorization.add_trans(usage)
    local us = usage:split("&")
    local ret = ""
    for i,v in ipairs(us) do
        ret =  ret .. "transactions[0][usage]" .. string.sub(v, 6) .. "&"
    end
    return string.sub(ret, 1, -2)
end


--
-- Error Codes
--

threescale.error = {}

function threescale.error.raise(error)
    ngx.status = error.status
    ngx.header.content_type = error.headers
    ngx.print(error.text)
    ngx.exit(ngx.HTTP_OK)
end


function threescale.error.no_credentials(service)
    threescale.error.raise(service.error.no_credentials)
end

function threescale.error.authorization_failed(service)
    threescale.error.raise(service.error.auth_failed)
end

function threescale.error.no_match(service)
    threescale.error.raise(service.error.no_match)
end

function threescale.error.no_service()
    threescale.error.raise({
        status = 404,
        text = 'No service found',
        headers = 'text/plain; charset=us-ascii'
    })
end

-- End Error Codes

return threescale