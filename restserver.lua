
local restserver = {}

local request = require("wsapi.request")
local response = require("wsapi.response")
local json = require("dkjson")
local unpack = unpack or table.unpack

local function add_resource(self, name, entries)
   for _, entry in ipairs(entries) do
      local path = ("^/" .. name .. "/" .. entry.path):gsub("%-", "%%-"):gsub("/+", "/"):gsub("/$", "") .. "$"
      entry.rest_path = path
      entry.match_path = path:gsub("{[^:]*:([^}]*)}", "(%1)"):gsub("{[^}]*}", "([^/]+)")
      path = path:gsub("{[^:]*:([^}]*)}", "%1"):gsub("{[^}]*}", "[^/]+")
      local methods = self.config.paths[path]
      if not methods then
         methods = {}
         self.config.paths[path] = methods
         table.insert(self.config.path_list, path)
      end
      if methods[entry.method] then
         local ui_path = "/" .. name .. "/" .. entry.path
         error("A handler for method "..entry.method.." in path "..ui_path.." is already defined.")
      end
      methods[entry.method] = entry
   end
end

local function set_error_handler(self, entry)
   self.error_handler = function(_, code, msg)
      return {
         response = entry.handler(code, msg),
         headers = { ["Content-Type"] = entry.produces or "text/plain" }
      }
   end
   self.error_schema = entry.output_schema
end

local function type_check(tbl, schema)
   for k, s in pairs(schema) do
      if not tbl[k] and not s.optional then
         return nil, "missing field '"..k.."'"
      elseif type(tbl[k]) ~= s.type then
         return nil, "in field '"..k.."', expected type "..s.type..", got "..type(tbl[k])
      elseif s.array and next(tbl[k]) and not tbl[k][1] then
         return nil, "in field '"..k.."', expected an array"
      end
   end
   return true
end

local function decode(data, mimetype, schema)
   if mimetype == "application/json" then
      local tbl = json.decode(data)
      if schema then
         local ok, err = type_check(tbl, schema)
         if not ok then
            return nil, err
         end
      end
      return tbl
   elseif mimetype == "text/plain" then
      return data or ""
   elseif not mimetype or mimetype == "*/*" then
      return data or ""
   else
      error("Mimetype "..mimetype.." not supported.")
   end
end

local function encode(data, mimetype, schema)
   if mimetype == "application/json" then
      if schema then
         local ok, err = type_check(data, schema)
         if not ok then
            return nil, err
         end
      end
      return json.encode(data)
   elseif mimetype == "text/plain" then
      return data or ""
   elseif not mimetype then
      return data or ""
   else
      error("Mimetype "..mimetype.." not supported.")
   end
end

local function get_error_response(self, code, msg, wreq)
   local res = self.error_handler(wreq, code, msg)
   res.headers = res.headers or { ["Content-Type"] = "text/plain" }
   local output, err = encode(res.response, res.headers["Content-Type"], self.error_schema)
   if not output then
      return nil, err
   end
   res.content = output
   return res
end

local function fail(self, wreq, code, msg)
   local res, err = get_error_response(self, wreq, code, msg)
   local wres = response.new(code, res.headers)
   local output
   if res then
      wres = response.new(500, { ["Content-Type"] = "text/plain" })
      output = "Internal Server Error - Server built a response that fails schema validation: "..err
   else
      output = res.content
   end
   wres:write(output)
   return wres:finish()
end

local function match_path(self, path_info)
   for _, path in ipairs(self.config.path_list) do
      if path_info:match(path) then
         return self.config.paths[path]
      end
   end
end

local function wsapi_handler_with_self(self, wsapi_env, rs_api)
   local wreq = request.new(wsapi_env)
   local input_path = wsapi_env.PATH_INFO:gsub("/$", "")
   local methods = self.config.paths["^" .. input_path .. "$"] or match_path(self, wsapi_env.PATH_INFO)
   local entry = methods and methods[wreq.method]
   if not entry then
      return fail(self, wreq, 405, "Method Not Allowed")
   end

   local input, err
   if wreq.method == "POST" then
      input, err = decode(wreq.POST.post_data, entry.consumes, entry.input_schema)
   elseif wreq.method == "GET" then
      input = wreq.GET
   elseif wreq.method == "DELETE" then
      input = ""
   else
      error("Other methods not implemented yet.")
   end
   if not input then
      return fail(self, wreq, 400, "Bad Request - Your request fails schema validation: "..err)
   end

   local placeholder_matches = (entry.rest_path ~= entry.match_path) and { input_path:match(entry.match_path) } or {}

   local ok, res
   local handler
   local pass_wreq = false
   if rs_api == "0.3" then
      handler = entry.handler
      pass_wreq = true
   elseif entry.handle_req then
      handler = entry.handle_req
      pass_wreq = true
   else
      handler = entry.handler
      pass_wreq = false
   end

   if pass_wreq then
      ok, res = pcall(handler, wreq, input, unpack(placeholder_matches))
   else
      ok, res = pcall(handler, input, unpack(placeholder_matches))
   end

   if not ok then
      return fail(self, wreq, 500, "Internal Server Error - Error in application: "..res)
   end
   if not res then
      return fail(self, wreq, 500, "Internal Server Error - Server failed to produce a response.")
   end

   local output, err = encode(res.config.entity, entry.produces, entry.output_schema)
   if not output then
      return fail(self, wreq, 500, "Internal Server Error - Server built a response that fails schema validation: "..err)
   end

   local wres = response.new(res.config.status, { ["Content-Type"] = entry.produces or "text/plain" })
   wres:write(output)
   return wres:finish()
end

local function add_setter(self, var)
   self[var] = function (self, val)
      self.config[var] = val
      return self
   end
end

function restserver.new(rs_api)
   local server = {
      config = {
         paths = {},
         path_list = {},
      },
      enable = function(self, plugin_name)
         local mod = require(plugin_name)
         mod.extend(self)
         return self
      end,
      add_resource = add_resource,
      set_error_handler = set_error_handler,
      get_error_response = get_error_response, -- To be used by server plugins
   }
   add_setter(server, "host")
   add_setter(server, "port")
   server.wsapi_handler = function(wsapi_env)
      return wsapi_handler_with_self(server, wsapi_env, rs_api)
   end
   server.error_handler = function(wreq, code, msg)
      return { response = tostring(code).." "..msg }
   end
   return server
end

function restserver.response()
   local res = {
      config = {},
   }
   add_setter(res, "status")
   add_setter(res, "entity")
   return res
end

return restserver
