-- Only update api key if not cached
if ngx.var.cached_key ~= nil then
    local res1 = ngx.location.capture("/threescale_authrep", { share_all_vars = true })
    if res1.status ~= 200 then
        local api_keys = ngx.shared.api_keys
        api_keys:delete(ngx.var.cached_key)
    end

    ngx.status = 200
    ngx.header.content_length = 0
    ngx.exit(ngx.HTTP_OK)
else
    ngx.status = 200
    ngx.header.content_length = 0
    ngx.exit(ngx.HTTP_OK)
end
