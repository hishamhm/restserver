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

Check the todo-list example in the `examples/` directory.
It should be easy to follow!

The server is a Lua script and the example client exercising the
REST API provided by the server is a shell script powered by Curl.

HTTP API
--------

### GET - No authentication

function handler(queryParams, pathParam1, pathParam2,...)

* _queryParams_ is an object with key-value pairs the parameters of the **query** or is an empty object {}
* one or more pathParam* arguments may be present as second, third arguments etc. and represent the parameters passed in the **path** as {paramname: syntax}

#### Examples

    GET /server/query?a=1&b=2
    handler({a=1,b=2})

    GET /server/user/{id:[0-9]+}/items/{itemid:[0-9]+}
    handler({},id,itemid)

### GET - Authenticated

If authentication is enabled, i.e. an authentication function was specified in add_resource(), the username is present as an additional parameter in the handler().

function handler(queryParams, user, pathParam1, pathParam2,...)

#### Examples 

    GET /server/query?a=1&b=2
    handler({a=1,b=2}, usere)

    GET /server/user/{id:[0-9]+}/items/{itemid:[0-9]+}
    handler({},user, id,itemid)


Authors and Maintainance
------------------------

Hisham Muhammad - [@hisham_hm](http://mastodon.social/@hisham_hm) - http://hisham.hm/  
Currently maintained by Orestis Tsakiridis - [@otsakir](https://fosstodon.org/@otsakir) - https://twitter.com/otsakir

License
-------

MIT/X11. Enjoy! :-D

