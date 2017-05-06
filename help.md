# Help File

Create the rails app as api-only, with Postgres as the database:
```bash
rails new todo-list-api --api --database=postgresql
```

## Dependencies
Add to the Gemfile
```rb
# Password digest
gem 'bcrypt', '~> 3.1.7'
# faker for generating fake data for testing
gem 'faker'

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platform: :mri
end

group :development do
  gem 'listen'
  gem 'spring'
  gem 'spring-watcher-listen'
end

group :test do
  gem 'rails-controller-testing'
  gem 'minitest-reporters'
  gem 'guard'
  gem 'guard-minitest'
end
```

Then run `bundle install`.

## API Specs

|  Endpoint                     |  Functionality                |
|-------------------------------|-------------------------------|
|  POST /signup                 |  Signup                       |
|  POST /auth/login             |  Login                        |
|  GET /auth/logout             |  Logout                       |
|  GET /todos                   |  List all todos               |
|  POST /todos                  |  Add a todo                   |
|  GET /todos/:id               |  View a todo                  |
|  PUT /todos/:id               |  Update a todo                |
|  DELETE /todos/:id            |  Delete a todo and its items  |
|  GET /todos/:id/items         |  Get a todo item              |
|  PUT /todos/:id/items         |  Update a todo item           |
|  DELETE /todos/:id/items      |  Delete a todo item           |

## Models
Generate the `Todo` model and `Item` model to reference the `Todo` model:
```bash
rails g model Todo title:string created_by:string

rails g model Item name:string done:boolean todo:references

rails db:migrate
```

Add tests for the model validations in `todo_test.rb` and `item_test.rb` respectively:
```rb
def setup
    @todo = Todo.new(title: "Study React", created_by: "Joshua")
end
  
test "should be valid" do
    assert @todo.valid?
end
  
test "title should be present" do
    @todo.title = ""
    assert_not @todo.valid?
end
  
test "created_by should be present" do
    @todo.created_by = ""
    assert_not @todo.valid?
end
```

Create a test todo in the `fixtures/todos.yml` called `todo_one`:
```yml
todo_one:
  title: MyString
  created_by: MyString
```

Add to `item_test.rb`:
```rb
def setup
    @todo = todos(:todo_one)
    @item = @todo.items.build(name: "time")
end
  
  test "should be valid" do
    assert @item.valid?
end
  
test "name must be present" do
    @item.name = ""
    assert_not @item.valid?
end
```

Add the `Item` association to the `Todo.rb` model, and validate for presence of title and created_by:
```rb
has_many :items

validates :title, presence: true
validates :created_by, presence: true
```

Add the `name` validation to the `Item.rb` model:
```rb
validates :name, presence: true
```

## Controllers
Create the controllers for both models:
```bash
rails g controller Todos
rails g controller Items
```

Specify the RESTful routes in `routes.rb`:
```rb
resources :todos do
    resources :items
end
```

Now we define the controller actions for the Todos controller in the `todos_controller.rb` file:
```rb
class TodosController < ApplicationController
    before_action :set_todo, only: [:show, :update, :destroy]

    # GET /todos
    def index
        @todos = Todo.all
        json_response(@todos)
    end

    # POST /todos
    def create
        @todo = Todo.create!(todo_params)
        json_response(@todo, :created)
    end

    # GET /todos/:id
    def show
        json_response(@todo)
    end
    
    # PUT /todos/:id
    def update
        @todo.update(todo_params)
        head :no_content
    end
    
    # DELETE /todos/:id
    def destroy
        @todo.destroy
        head :no_content
    end
    
    private

    def todo_params
        params.permit(:title, :created_by)
    end
    
    def set_todo
        @todo = Todo.find(params[:id])
    end
    
end
```

In the `controllers/concerns` folder, we create a `response.rb` file that provides the `json_response` helper:
```rb
module Response
    def json_response(object, status = :ok)
        render json: object, status: status
    end
end
```

**Note:** In our `create` method in the TodosController, we're using `create!` instead of `create`. This way, the model will raise an exception `ActiveRecord::RecordInvalid`. This way, we can avoid deep nested if statements in the controller. Thus, we rescue from this exception in the `ExceptionHandler` module.

In the same folder, create and `exceptions_handler.rb` file to catch `ActiveRecord::RecordNotFound` error. This is for the `set_todo` callback method in the Todos controller that finds a todo by its `id`.
```rb
module ExceptionHandler
  # provides the more graceful `included` method
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound do |e|
      json_response({ message: e.message }, :not_found)
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      json_response({ message: e.message }, :unprocessable_entity)
    end
  end
end
``` 

Include the two created files in the `application_controller.rb` file as below:
```rb
class ApplicationController < ActionController::API
  include Response
  include ExceptionHandler
end
```

Use [httpie](https://httpie.org) to test the API:
```bash
rails s

# GET /todos
$ http :3000/todos

# POST /todos
$ http POST :3000/todos title=Mozart created_by=1

# PUT /todos/:id
$ http PUT :3000/todos/1 title=Beethoven

# DELETE /todos/:id
$ http DELETE :3000/todos/1
```

## TodoItems API
In the `items_controller.rb` file, add:
```rb
class ItemsController < ApplicationController
  before_action :set_todo
  before_action :set_todo_item, only: [:show, :update, :destroy]

  # GET /todos/:todo_id/items
  def index
    json_response(@todo.items)
  end
  
  # GET /todos/:todo_id/items/:id
  def show
    json_response(@item)
  end
  
  # POST /todos/:todo_id/items
  def create
    @todo.items.create!(item_params)
    json_response(@todo, :created)
  end
  
  # PUT /todos/:todo_id/items/:id
  def update
    @item.update(item_params)
    head :no_content
  end

  # DELETE /todos/:todo_id/items/:id
  def destroy
    @item.destroy
    head :no_content
  end

  private

  def item_params
    params.permit(:name, :done)
  end

  def set_todo
    @todo = Todo.find(params[:todo_id])
  end

  def set_todo_item
    @item = @todo.items.find_by!(id: params[:id]) if @todo
  end
  
end
```

Run some manual tests for the todo items API using `httpie`:
```bash
# GET /todos/:todo_id/items
$ http :3000/todos/2/items

# POST /todos/:todo_id/items
$ http POST :3000/todos/2/items name='Listen to News' done=false

# PUT /todos/:todo_id/items/:id
$ http PUT :3000/todos/2/items/1 done=true

# DELETE /todos/:todo_id/items/1
$ http DELETE :3000/todos/2/items/1
```

The next phase is [JWT Authentication](help_jwt_auth.md).