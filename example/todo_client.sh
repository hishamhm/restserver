#!/bin/bash

function say() {
   echo
   echo
   echo "$@"
   echo
}

say "We start with an empty todo-list"

curl -v localhost:8080/todo

say "We add an item..."

curl -v -H "Content-Type: application/json" -X POST -d '{ "task": "Clean bedroom" }' http://localhost:8080/todo

say "...And the list is no longer empty:"

curl -v localhost:8080/todo

say "We add another item..."

curl -v -H "Content-Type: application/json" -X POST -d '{ "task": "Groceries" }' http://localhost:8080/todo

say "...and now we have two items:"

curl -v localhost:8080/todo

say "We can check a single item:"

curl -v localhost:8080/todo/2/status

say "And when we go for groceries, we mark it done:"

curl -v localhost:8080/todo/2/done

say "There it is!"

curl -v localhost:8080/todo/2/status

say "If we look for an invalid id, we get a proper HTTP error"

curl -v localhost:8080/todo/9/status

say "We can also delete an item:"

curl -v -H "Content-Type: application/json" -X DELETE http://localhost:8080/todo/2

say "And now our list looks like this:"

curl -v localhost:8080/todo

say "That's all folks!"

curl localhost:8080/todo/reset &> /dev/null # So we get the same results if we run again!
