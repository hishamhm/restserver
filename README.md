RestServer
----------

A simple server API for writing REST services running over WSAPI.

A plugin for launching on Xavante is provided. Currently, it is the only way
to run this out-of-the box.

Installing
----------

    luarocks install restserver-xavante

Using
-----

Define API in lua file and start the server.

*server.lua*
```
local restserver = require("restserver")


local server = restserver:new():port(8585) -- create server

-- define REST api here
server:add_resource("todo", {

        {
                method = "GET",
                path = "/",
                produces = "application/json",
                handler = function()
                        todos = {
                                "wash the dishes",
                                "get the dog out for a walk"
                        }

                        return restserver.response():status(200):entity(todos)
                end,
        }
})

server:enable("restserver.xavante"):start() -- start server
```

Check the todo-list example in the `examples/` directory for a more in-depth look.


REST handlers
-------------

### GET - No authentication

    function handler(queryParams, pathParam1, pathParam2,...)

* _queryParams_ is an object with key-value pairs the parameters of the **query** or is an empty object {}
* one or more pathParam* arguments may be present as second, third arguments etc. and represent the parameters passed in the **path** as {paramname: syntax}

#### Examples

    GET /server/query?a=1&b=2
    handler({a=1,b=2})
 <br>
 
    GET /server/user/{id:[0-9]+}/items/{itemid:[0-9]+}
    handler({},id,itemid)

### GET - Authenticated

    function handler(queryParams, user, pathParam1, pathParam2,...)
    
If authentication is enabled, i.e. an authentication function was specified in add_resource(), the username is present as an additional parameter in the handler().

#### Examples 

    GET /server/query?a=1&b=2
    handler({a=1,b=2}, usere)

    GET /server/user/{id:[0-9]+}/items/{itemid:[0-9]+}
    handler({},user, id,itemid)
    
### POST - No authentication

    function handler(postBody, pathParam1, pathParam2, ...)

* _postBody_ - the post body in application/json content type. Form posts are not supported.
* _pathParamX_ - zero or more path parameters follow

Note, query parameters are not supplied in this type of handler.

#### Examples

    path: /server/people 
 
    POST /server/people
    --> {"name":"Alice"}
    
    handler({name=Alice})
<br>  

    path: /server/people/{name:[a-zA-Z]+}/items
    
    POST /server/people/Alice/items
    --> {"name":"Laptop"}
    
    handler({name=Laptop},Alice)

### POST - Authenticated

    function handler(postBody, username, pathParam1, pathParam2, ...)

* _postBody_ - the post body in application/json content type. Form posts are not supported.
* _username_ - authenticated username
* _pathParamX_ - zero or more path parameters follow

Again, query parameters are not supplied in this type of handler. 

#### Examples

    path: /server/people 
 
    POST /server/people
    --> {"name":"Alice"}
    headers: Authorization: Basic Ym9iOnNlY3JldA==  - i.e. bob:secret
    
    handler({name=Alice},"bob")
<br>  

    path: /server/people/{name:[a-zA-Z]+}/items
    
    POST /server/people/Alice/items
    --> {"name":"Laptop"}
    Authorization: Basic Ym9iOnNlY3JldA== - i.e. bob:secret
    
    handler({name=Laptop},Bob,Alice)




Authors and Maintainance
------------------------

Hisham Muhammad - [@hisham_hm](http://mastodon.social/@hisham_hm) - http://hisham.hm/  
Currently maintained by Orestis Tsakiridis - [@otsakir](https://fosstodon.org/@otsakir) - https://twitter.com/otsakir

License
-------

MIT/X11. Enjoy! :-D

