-- -*- mode: lua; -*-
-- Generated on: 2014-07-10 09:49:54 +0000 --
-- Version:
-- Error Messages per service

qsp_utils = require( 'conf.qsp.utils' )
services = require( 'conf.qsp.services' )
threescale = require( 'conf.qsp.3scale' )

--[[

  Mapping between url path to 3scale methods. In here you must output the usage string encoded as a query_string param.
  Here there is an example of 2 resources (word, and sentence) and 3 methods. The complexity of this function depends
  on the level of control you want to apply. If you only want to report hits for any of your methods it would be as simple
  as this:

  function extract_usage(request)
    return "usage[hits]=1&"
  end

  In addition. You do not have to do this on LUA, you can do it straight from the nginx conf via the location. For instance:

  location ~ ^/v1/word {
		set $provider_key null;
		set $app_id null;
		set $app_key null;
		set $usage "usage[hits]=1&";

		access_by_lua_file /Users/solso/3scale/proxy/nginx_sentiment.lua;

		proxy_pass http://sentiment_backend;
		proxy_set_header  X-Real-IP  $remote_addr;
		proxy_set_header  Host  $host;
	}

	This is totally up to you. We prefer to keep the nginx conf as clean as possible. But you might already have declared
	the resources there, in this case, it's better to declare the $usage explicitly

]]--

matched_rules = ""

local params = {}
local host = ngx.req.get_headers()["Host"]
local auth_strat = ""
local service = services[ ngx.var.service_id ]

-- If no or invalid service is specified, raise an error
if service == nil then
    threescale.errors.no_service()
end

-- Set parameters needed for every request
ngx.var.proxy_pass = service.backend

if service.hostname ~= nil then
    ngx.var.hostrewrite = service.hostname
else
    ngx.var.hostrewrite = ngx.var.host
end

ngx.var.threescale_service_identifier = service.threescale_service_identifier
ngx.var.secret_token = service.secret_token

-- Check if authentication is needed for this request
if( service.need_authentication(ngx.req) ) then
    -- Retrieve authorization parameters from the right place (headers, url or POST body)
    local parameters = threescale.authorization.get_auth_params(service.authentication_method, string.split(ngx.var.request, " ")[1] )
    params.user_key = parameters["user_key"]

    -- Check whether credentials are given
    threescale.authorization.check_credentials[ service.authorization_method ](params , service)

    -- Store key in cache
    ngx.var.cached_key = ngx.var.service_id .. ":" .. params.user_key
    auth_strat = "1"

    -- Set parameters used in the nginx config
    ngx.var.usage, matched_rules = threescale.extract_usage(service, ngx.var.request)
    ngx.var.credentials = qsp_utils.build_query(params)

    -- if true then
    --   qsp_utils.logging.log(ngx.var.app_id)
    --   qsp_utils.logging.log(ngx.var.app_key)
    --   qsp_utils.logging.log(ngx.var.usage)
    -- end

    -- WHAT TO DO IF NO USAGE CAN BE DERIVED FROM THE REQUEST.
    if ngx.var.usage == nil then
        ngx.header["X-3scale-matched-rules"] = ''
        threescale.error.no_match(service)
    end

    if threescale.get_debug_value() then
        ngx.header["X-3scale-matched-rules"] = matched_rules
        ngx.header["X-3scale-credentials"]   = ngx.var.credentials
        ngx.header["X-3scale-usage"]         = ngx.var.usage
        ngx.header["X-3scale-hostname"]      = ngx.var.hostname
    end

    -- this would be better with the whole authrep call, with user_id, and everything so that
    -- it can be replayed if it's a cached response
    threescale.authorization.authorize(auth_strat, params, service)
end

-- Remove the 'user_key' parameter from the url, to avoid issues on the webservice side
-- Some webservices don't accept this parameter when retrieving the wsdl
local args = ngx.req.get_uri_args()
args['user_key'] = nil
ngx.req.set_uri_args(args)

-- END OF SCRIPT
