#!/usr/bin/env lua

--[[

A simple todo-list server example.

This example requires the restserver-xavante rock to run.

A fun example session:

curl localhost:8080/todo
curl -v -H "Content-Type: application/json" -X POST -d '{ "task": "Clean bedroom" }' http://localhost:8080/todo
curl -v localhost:8080/todo
curl -v -H "Content-Type: application/json" -X POST -d '{ "task": "Groceries" }' http://localhost:8080/todo
curl -v localhost:8080/todo
curl -v localhost:8080/todo/2/status
curl -v localhost:8080/todo/2/done
curl -v localhost:8080/todo/2/status
curl -v localhost:8080/todo/9/status
curl -v -H "Content-Type: application/json" -X DELETE http://localhost:8080/todo/2
curl -v localhost:8080/todo

]]

local restserver = require("restserver")

local server = restserver:new():port(8080)

local todo_list = {}
local next_id = 0

server:add_resource("todo", {

   {
      method = "GET",
      path = "/",
      produces = "application/json",
      handler = function()
         return restserver.response():status(200):entity(todo_list)
      end,
   },
   
   {
      method = "POST",
      path = "/",
      consumes = "application/json",
      produces = "application/json",
      input_schema = {
         task = { type = "string" },
      },
      handler = function(task_submission)
         print("Received task: " .. task_submission.task)
         next_id = next_id + 1
         task_submission.id = next_id
         task_submission.done = false
         table.insert(todo_list, task_submission)
         local result = {
            id = task_submission.id
         }
         return restserver.response():status(200):entity(result)
      end,
   },

   {
      method = "GET",
      path = "{id:[0-9]+}/status",
      produces = "application/json",
      handler = function(_, id)
         for _, task in ipairs(todo_list) do
            if task.id == tonumber(id) then
               return restserver.response():status(200):entity(task)
            end
         end
         return restserver.response():status(404):entity("Id not found.")
      end,
   },

   {
      method = "GET",
      path = "{id:[0-9]+}/done",
      produces = "application/json",
      handler = function(_, id)
         for _, task in ipairs(todo_list) do
            if task.id == tonumber(id) then
               task.done = true
               return restserver.response():status(200):entity(task)
            end
         end
         return restserver.response():status(404):entity("Id not found.")
      end,
   },

   {
      method = "DELETE",
      path = "{id:[0-9]+}",
      produces = "application/json",
      handler = function(_, id)
         for i, task in ipairs(todo_list) do
            if task.id == tonumber(id) then
               table.remove(todo_list, i)
               return restserver.response():status(200):entity(task)
            end
         end
         return restserver.response():status(404):entity("Id not found.")
      end,
   },

   {
      method = "GET",
      path = "/reset",
      produces = "application/json",
      handler = function()
         todo_list = {}
         next_id = 0
         return restserver.response():status(200)
      end,
   },
   
})

-- This loads the restserver.xavante plugin
server:enable("restserver.xavante"):start()

