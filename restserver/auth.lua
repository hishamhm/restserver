-- authentication algorithms
local mod = {}

local base64 = require("base64")


-- http basic authentication 
function doBasicAuth(header_value, authenticate_user )
  --require("mobdebug").on()
  local scheme, credential = header_value:match("(%S+)%s(%S+)")
  if scheme and credential then
    if string.lower(scheme) == "basic" then
      local user, password = base64.decode(credential):match("(.*):(.*)")
      if authenticate_user(user, password) then
        return user
      else
        error("authentication error")
      end
    end
  end
  error("authentication error")
end

-- Public interface --

--[[ 
  Perform authentication of basic auth header value. Will parse the header and
  rely on separate function to verify username/password.
  
  Parameters
  
  header_value  : Authorization http header value e.g. "Basic thebase64hashhere=="
  authenticate_user : Function that can retrieve credentials by username 
  

  returns {errorcode = 401|403, message = "auth error", user = 'nick'}
  
  TODO - remove from module's public interface at some point

--]]
function mod.basic_auth(header_value, authenticate_user)
  ok, res = pcall(doBasicAuth, header_value, authenticate_user)
  if not ok then
    return {errorcode = 401, message = res}
  else
    return {user = res} -- the username is returned
  end
end


-- a cactch-all authentication function. Depending on method the respective authentication function is invoked.
function authenticate(env, method, verify_handler)
	if method == "basic" then
		local authheader = env["HTTP_AUTHORIZATION"]
		return mod.basic_auth(authheader, verify_handler)
	else
		return {errorcode = 400, message = "Unsupported auth method: "..(method or '')}
	end
end

--[[
  Add new verification callback. 'verify_handler' checks if the user credential or authentication token is valid.
  The interface of the callback depends on the authentication method. 
  
  A closure for the specific authentication method and verification handler is returned 
  that only furher needs the 'env' to do its thing.
--]]
function mod.add( method, verify_handler)
	return function(env)
		return authenticate(env, method, verify_handler) 
	end
end


return mod
