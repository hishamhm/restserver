
local restserver_xavante = {}

local xavante = require("xavante")
local httpd = require("xavante.httpd")
local wsapi = require("wsapi.xavante")

local function start(self)
   local rules = {}
   local handler = wsapi.makeHandler(self.wsapi_handler)
   for path, _ in pairs(self.config.paths) do
      -- TODO support placeholders in paths
      rules[#rules + 1] = {
         match = path:gsub("%$", "/$"),
         with = handler,
      }
      rules[#rules + 1] = {
         match = path,
         with = handler,
      }
   end

   -- HACK: There's no public API to change the server identification
   xavante._VERSION = self.server_name or "RestServer"
   xavante.HTTP {
      server = {host = self.config.host or "*", port = self.config.port or 8080 },
      defaultHost = {
         rules = rules
      }
   }

   local function make_error_handler(code, msg)
      httpd["err_" .. tostring(code)] = function(_, res)
         res.statusline = "HTTP/1.1 " .. tostring(code) .. " " .. msg
         local rest_res = self:get_error_response(code, msg)
         for k, v in pairs(rest_res.headers) do
            res.headers[k] = v
         end
         res.content = rest_res.content
         return res
      end
   end
   
   make_error_handler(403, "Forbidden")
   make_error_handler(404, "Not Found")
   make_error_handler(405, "Method Not Allowed")
   
   local ok, err = pcall(xavante.start, function()
      io.stdout:flush()
      io.stderr:flush()
      return false
   end, nil)
   
   if not ok then
      return nil, err
   end
   return true
end

function restserver_xavante.extend(self)
   self.start = start
end

return restserver_xavante

