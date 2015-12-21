--
-- This script filters the bodies of the webservices returned
-- in order to rewrite any URLs
-- The strings to replace are specified in services.lua
--
services = require( 'conf.qsp.services' )
local service = services[ ngx.var.service_id ]

if( service.webservice_substitutions and next(service.webservice_substitutions) ~= nil) then
    local body = ngx.arg[1]
    for key,value in pairs(service.webservice_substitutions) do
        body = string.gsub( body, key, value )
    end
    ngx.arg[1] = body
end
