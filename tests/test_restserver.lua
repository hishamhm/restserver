local lu = require("luaunit")
local inspect = require("inspect")
local restserver = require("restserver")
local json = require("dkjson")


local connector = require "wsapi.mock"

local server = restserver:new():port(8080)

server:add_resource("todo", {
   {
      method = "GET",
      path = "/",
      produces = "application/json",
      handler = function()
         return restserver.response():status(200):entity({})
      end
   },
   {
      method = "GET",
      path = "/html",
      produces = "text/html", -- text/html content-type is not supported in 'produces'
      handler = function()
         return restserver.response():status(200):entity("<html></html>")
      end
   },   
   {
      method = "GET",
      path = "{id:[%d]+}/status",
      produces = "application/json",
      handler = function(_,id)
         return restserver.response():status(200):entity({id=tonumber(id)})
      end
   },
   {
      -- use lua patterns with range syntax instead of %x
      method = "GET",
      path = "useRange/{id:[0-9]+}/status",
      produces = "application/json",
      handler = function(_,id)
         return restserver.response():status(200):entity({id=tonumber(id)})
      end
   }   
})

server:add_resource("contact", {
    {
      method = "POST",
      path = "/echo",
      consumes = "application/json",
      produces = "application/json",
      handler = function(body)
        return restserver.response():status(200):entity(body)
      end
    },
    {
      method = "POST",
      path = "/schema",
      consumes = "application/json",
      produces = "application/json",
      input_schema = {
        name = { type = "string"},
        age = { type = "number", optional = true },
        address = {type = "table"},
      },      
      handler = function(body)
        return restserver.response():status(200):entity(body)
      end
    },
    {
      method = "POST",
      path = "/singleHeader",
      consumes = "application/json",
      produces = "application/json",
      handler = function(body)
        return restserver.response():status(200):entity({status="ok"}):headers({Link="/contacts/1"})
      end
    },
    {
      method = "GET",
      path = "/manyHeaders",
      produces = "application/json",
      handler = function(body)
        return restserver.response():status(200):entity({status="ok"}):headers({Link="/contacts/1",["my-custom-header"]="header content"})
      end
    },
    {
      method = "GET",
      path = "/overrideDefault",
      produces = "application/json",
      handler = function(body)
        return restserver.response():status(200):entity({status="ok"}):headers({["Content-Type"]="text/html"})
      end
    },
    {
      method = "GET",
      path = "/noProduces",
      handler = function(body)
        return restserver.response():status(200):entity({status="ok"})
      end
    }  
  })

-- Test authentication hooks
server:add_resource("protected", {
    {
      method = "GET",
      path = "/",
      produces = "application/json",
      auth = function() return {user = "guest"} end,
      handler = function(_,user)
        return restserver.response():status(200):entity({status="ok", message="hello "..user})
      end
    }
})

   
local app = connector.make_handler(server.wsapi_handler)


TestTodo = {}

  function TestTodo:testContentTypeAndEmpty()
    local response, request = app:get("/todo")
    lu.assertEquals(response.code, 200)
    --assert(request.query_string             == "?hello=world")
    lu.assertEquals(response.headers["Content-Type"], "application/json") -- mind the letter casing. Content-type    
    lu.assertEquals(response.body, "[]")
  end
  
  -- text/html content type is not supported
  function TestTodo:testTextHtmlContentType()
    local response, request = app:get("/todo/html")
    lu.assertTrue(string.match(response.body,"Mimetype text/html not supported") ~= nil)
    --lu.assertEquals(response.code, 500) -- TODO in the test code, the 'code' field also contains the error message. It's not a pure '500' value'. I'm disabling this check for now.
  end
  
  --[[
  function TestTodo:testResourceDoesNotExist()
    local response, request = app:get("/missing")
    lu.assertEquals(response.code, 404) -- TODO: currently returns 405. But running in xavante it works ok
  end
  --]]
  
  function TestTodo:testPathParam1()
    local response, request = app:get("/todo/6/status")
    lu.assertEquals(response.code, 200)
    lu.assertEquals(response.body, '{"id":6}')
  end
  
  --- this is a known issue - https://github.com/hishamhm/restserver/issues/5
  function TestTodo:testRangedPattern()
    local response, request = app:get("/todo/useRange/5/status")
    lu.assertEquals(response.code, 200)
    lu.assertEquals(response.body, '{"id":5}')
  end

-- end of table TestTodo

local contact = {
    name = "nick",
    age = 35,
    pin = {1,2,3},
    address = {
      street = "ofphiladelphia",
      po = "26534",
      city = "ny"
    }
}

TestContact = {}

  function TestContact:testPOST()
    local response, request = app:post("/contact/echo",json.encode(contact), {["Content-Type"]="application/json"}) -- empty array for headers
    lu.assertEquals(response.code, 200)
    local contact2 = json.decode(response.body)
    lu.assertEquals(contact2, contact)
  end
  
  function TestContact:testOptional()
    local con = json.encode({age=35, address={asdf="asdf"}}) -- no address specified. Since it's not optional, we expect an error
    local response, request = app:post("/contact/schema",con, {["Content-Type"]="application/json"}) -- empty array for headers
    lu.assertEquals(response.code, 400) -- because required (i.e. optional not defined) field 'name'ismissing

    con = json.encode({name="nick", age=35, address={asdf="asdf"}}) -- no address specified. Since it's not optional, we expect an error
    response, request = app:post("/contact/schema",con, {["Content-Type"]="application/json"}) -- empty array for headers
    lu.assertEquals(response.code, 200) -- name is present
  end
  
  function TestContact:testTable()
    local con = json.encode({name="nick", age=35, address=45}) -- address specified as number instead of table
    local response, request = app:post("/contact/schema",con, {["Content-Type"]="application/json"}) -- empty array for headers
    lu.assertEquals(response.code, 400)   
  end
  
  function TestContact:testEmptyTable()
    local con = json.encode({name="nick", age=35, address={}}) -- address specified as number instead of table
    local response, request = app:post("/contact/schema",con, {["Content-Type"]="application/json"}) -- empty array for headers
    lu.assertEquals(response.code, 200)
  end  
  
  function TestContact:testHeadersReturned()
    local response = app:post("/contact/singleHeader", "{}", {["Content-Type"]="application/json"})
    lu.assertEquals(response.code, 200)
    lu.assertEquals(response.headers["Link"], "/contacts/1");
  end
  
  function TestContact:testManyHeaders()
    local response = app:get("/contact/manyHeaders")
    lu.assertEquals(response.code, 200)
    lu.assertEquals(response.headers["Link"], "/contacts/1");
    lu.assertEquals(response.headers["my-custom-header"], "header content");
  end
  
  function TestContact:testOverrideDefault()
    local response = app:get("/contact/overrideDefault")
    lu.assertEquals(response.code, 200)
    lu.assertEquals(response.headers["Content-Type"], "text/html");
  end  
  
  -- check the default content-type header returerned. i.e. if no 'produces' directive is specified we should get text/plain
  function TestContact:testNoProduces()
    local response = app:get("/contact/noProduces")
    lu.assertEquals(response.code, 200)
    lu.assertEquals(response.headers["Content-Type"], "text/plain");
  end
  
-- end of table TestContact

TestProtected = {}
  function TestProtected:testGuestUser()
    local response = app:get("/protected")
    lu.assertEquals(response.code, 200)
    local body = json.decode(response.body)
    lu.assertEquals("hello guest", body.message)
  end
-- end of table TestProtected

TestPaths = {}

  function TestPaths:simplepaths()
    -- simplest path
    local server2 = restserver:new():port(8080)
    server2:add_resource("api",{{method = "GET", path="/contacts"}})
    lu.assertEquals(server2.config.path_list[1], "^/api/contacts$")
    -- test without the leading slash character
    server2 = restserver:new():port(8080)
    server2:add_resource("api",{{method = "GET", path="contacts"}})
    lu.assertEquals(server2.config.path_list[1], "^/api/contacts$")
    -- use a hyphen in path literal. It should be escaped as it's a magic character for lua patterns
    server2 = restserver:new():port(8080)
    server2:add_resource("api",{{method = "GET", path="/private-contacts"}})
    lu.assertEquals(server2.config.path_list[1], "^/api/private%-contacts$")    
  end
  
  function TestPaths:rangedPaths()
    local server2 = restserver:new():port(8080)
    server2:add_resource("api",{{method = "GET", path="/private-contacts/{[0-9]+}"}})
    print(inspect(server2.config))
    print(inspect(server2.config.path_list[1]))   
    lu.assertEquals(server2.config.path_list[1], "^/api/private%-contacts/[^/]+$")  
  end
  
-- end of table TesPaths

-- utility function
function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

os.exit(lu.LuaUnit.run())