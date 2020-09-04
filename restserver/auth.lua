-- authentication algorithms
local mod = {}

local base64 = require("base64")


function doBasicAuth(header_value, authenticate_user )
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

--]]
function mod.basic_auth(header_value, authenticate_user)
  ok, res = pcall(doBasicAuth, header_value, authenticate_user)
  if not ok then
    return {errorcode = 401, message = res}
  else
    return {user = res} -- the username is returned
  end
end


return mod