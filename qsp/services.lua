local qsp_utils = require( "conf.qsp.utils" )

local services = {
    -- Default settings for all webservices. Only changes these defaults if
    -- all webservices should behave differently. Otherwise, change the
    -- webservice specific settings at the end of this file.
    _default = {

        -- Backend to send the requests to. No default value, so MUST be overridden
        backend = nil,

        -- Hostname value to be sent to the backend webservice, as the proxy retrieves
        -- data only from the IP address
        hostname = nil,

        -- Service identifier that 3scale knows about. Must be overridden
        threescale_service_identifier = '',

        -- Which parameters are to be sent to the 3scale backend. By default
        -- for each request the same 'hits' parameter is being sent
        extract_usage = function(request)
            return { hits = 1 }, { 'default' }
        end,

        -- Determines whether a request needs authentication or not.
        -- Can be used to enable accessing the WSDL file without authentication
        -- By default, every request needs authentication
        need_authentication = function(request)
            return true
        end,

        -- Method of authentication: headers or not_headers
        authentication_method = 'headers',

        -- Method of authorization: app_id_app_key, access_token or user_key
        authorization_method = 'user_key',

        -- Secret token to talk to the API backend. This ensures the
        -- backend that the request is done through the QSP
        secret_token = '',

        -- Substitutions in the webservice body. See bodyfilter.lua for
        -- more information
        webservice_substitutions = {},

        -- Several error messages
        error = {
            no_credentials = {
                text = 'Authentication parameters missing',
                headers = 'text/plain; charset=us-ascii',
                status = 403
            },
            auth_failed = {
                text = 'Authentication failed',
                headers = 'text/plain; charset=us-ascii',
                status = 403
            },
            no_match = {
                text = 'No rule matched',
                headers = 'text/plain; charset=us-ascii',
                status = 404
            },
        },
    }
}

-- Helper method to be used when authentication is
-- not needed on GET requests
local not_with_get = function(request)
    return request.get_method() ~= "GET"
end

-- Helper method to extract usage from the request,
-- with a simple map of mapping rules.
--   Keys in the map are the names of the rules
--   Values in the map are maps with parameters to match
--     parameters can be 'regex' and 'method' for now
--     another value in the map must be 'metric'
local extract_usage_with_map = function(request, mapping_rules)
        -- By default the 'hits' metric is always increased
        local matched_rules = { 'default' }
        local usage_params = { hits = 1 }

        -- Extract the information from the request
        local t = string.split(request," ")
        local method = t[1]
        local path = t[2]

        -- Match all items, one by one
        if next(mapping_rules) ~= nil then
                for rule_name,rule_params in pairs(mapping_rules) do
                        -- Match on the mapping rule parameters: regex and method for now
                        if rule_params.regex == nil or ngx.re.match(path,rule_params.regex) then
                                if rule_params.method == nil or method == rule_params.method then
                                        table.insert(matched_rules,rule_name)
                                        usage_params[rule_params.metric] = qsp_utils.set_or_inc(usage_params, rule_params.metric, 1)
                                end
                        end
                end
        end

        return usage_params, matched_rules
end

----------------------------------------
--
-- Actual service descriptions
--
----------------------------------------

services.example = qsp_utils.copy_table( services._default )
services.example.backend = 'http://backend_example/path/to/service'
services.example.threescale_service_identifier = '1234567890'

return services
