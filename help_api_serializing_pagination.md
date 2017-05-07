## API Serializing Help
At this point, if we wanted to get a todo and its items, we'd have to make two API calls. Although this works well, it's not ideal.

We can achieve this with serializers. Serializers allow for custom representations of JSON responses. 

Active model serializers make it easy to define which model attributes and relationships need to be serialized. In order to get todos with their respective items, we need to define serializers on the `Todo` model to include its attributes and relationships.

Add active model serializers gem to the `Gemfile` as follows:
```rb
gem 'active_model_serializers', '~> 0.10.0'
```

Run the following commands to install and generate the serializer:
```bash
bundle install

rails g serializer todo
```

This creates a new directory `app/serializers` and adds a new file `todo_serializer.rb`. Let's define the todo serializer with the data that we want it to contain, int the new file:
```rb
# attributes to be serialized  
attributes :id, :title, :created_by, :created_at, :updated_at
# model association
has_many :items
```

We define a whitelist of attributes to be serialized and the model association (only defined attributes will be serialized). We've also defined a model association to the item model, this way the payload will include an array of items. Fire up the server,let's test this:
```bash
http POST :3000/todos/1/items name="Listen to Don Moen" Accept:'application/vnd.todos.v1+json' Authorization:"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE0OTQyNjYxMTh9.prbADs0F1nItwm3MPFqsYeEQbVw2TT-Js6zt9qUcqLg"

http :3000/todos Accept:'application/vnd.todos.v1+json' Authorization:"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE0OTQyNjYxMTh9.prbADs0F1nItwm3MPFqsYeEQbVw2TT-Js6zt9qUcqLg"
```

## API Pagination Help
As our data set grows, to make sure the requests are still fast and optimized, we're going to add pagination; we'll give clients the power to say what portion of data they require.

To achieve this, we'll make use of the `will_paginate` gem.

Let's add it to the `Gemfile`:
```rb
gem 'will_paginate', '~> 3.1.0'
```

Install it by running:
```bash
bundle install
```

Refactor the `todos_controller.rb` index action to paginate its response:
```rb
def index
  # get paginated current user todos
  @todos = current_user.todos.paginate(page: params[:page], per_page: 20)
  json_response(@todos)
end
```

The index action checks for the page number in the request params. If provided, it'll return the page data with each page having twenty records each. As always, let's fire up the Rails server and run some tests.

```bash
rails s

http :3000/todos Accept:'application/vnd.todos.v1+json' Authorization:"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE0OTQyNjYxMTh9.prbADs0F1nItwm3MPFqsYeEQbVw2TT-Js6zt9qUcqLg"

http :3000/todos page==1 Accept:'application/vnd.todos.v1+json' Authorization:"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE0OTQyNjYxMTh9.prbADs0F1nItwm3MPFqsYeEQbVw2TT-Js6zt9qUcqLg"

http :3000/todos page==2 Accept:'application/vnd.todos.v1+json' Authorization:"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE0OTQyNjYxMTh9.prbADs0F1nItwm3MPFqsYeEQbVw2TT-Js6zt9qUcqLg"
```