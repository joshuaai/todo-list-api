# API Versioning, Pagination and Serialization
The full tutorial is [here](https://scotch.io/tutorials/build-a-restful-json-api-with-rails-5-part-three).
## Versioning
When building an API whether public or internal facing, it's highly recommended that you version it. This might seem trivial when you have total control over all clients. However, when the API is public facing, you want to establish a contract with your clients. Every breaking change should be a new version.

In order to version a Rails API, we need to do two things:
* Add a route constraint - this will select a version based on the request headers
* Namespace the controllers - have different controller namespaces to handle different versions.

Rails routing supports advanced constraints. Provided an object that responds to `matches?`, you can control which controller handles a specific route.

We'll define an `ApiVersion` class that checks the API version from the request headers and routes to the appropriate controller module. The class will live in `app/lib` since it's non-domain-specific.

```bash
touch app/lib/api_version.rb
```

In `app/lib/api_version.rb`, implement the class as follows:
```rb
class ApiVersion
  attr_reader :version, :default

  def initialize(version, default = false)
    @version = version
    @default = default
  end

  # check whether version is specified or is default
  def matches?(request)
    check_headers(request.headers) || default
  end

  private

  def check_headers(headers)
    # check version from Accept headers; expect custom media type `todos`
    accept = headers[:accept]
    accept && accept.include?("application/vnd.todos.#{version}+json")
  end    
end
```

The `ApiVersion` class accepts a `version` and a `default` flag on initialization. In accordance with Rails constraints, we implement an instance method `matches?`. This method will be called with the request object upon initialization. From the request object, we can access the `Accept` headers and check for the requested version or if the instance is the default version. This process is called content negotiation.

## Content Negotiation
REST is closely tied to the HTTP specification. HTTP defines mechanisms that make it possible to serve different versions (representations) of a resource at the same URI. This is called content negotiation.

Our `ApiVersion` class implements server-driven content negotiation where the client (user agent) informs the server what media types it understands by providing an Accept HTTP header.

Since we don't want to have the version number as part of the URI (this is argued as an anti-pattern), we'll make use of the module scope to namespace our controllers.

Let's move the existing `todos` and `todo-items` resources into a v1 namespace in `routes.rb`:
```rb
scope module: :v1, constraints: ApiVersion.new('v1', true) do
    resources :todos do
        resources :items
    end
end 
```

We've set the version constraint at the namespace level. Thus, this will be applied to all resources within it. We've also defined `v1` as the default version; in cases where the version is not provided, the API will default to `v1`. In the event we were to add new versions, they would have to be defined above the default version since Rails will cycle through all routes from top to bottom searching for one that `matches` (till method `matches?` resolves to true).

Next up, let's move the existing todos and items controllers into the v1 namespace. Create a module directory in the controllers folder and move the files into the module folder.: 
```bash
mkdir app/controllers/v1

mv app/controllers/{todos_controller.rb,items_controller.rb} app/controllers/v1
```

Lets redefine the controllers in the `v1` namespace. In the `todos_controller.rb` and `items_controller.rb` files, refactor respectively as follows:
```rb
module V1
  class TodosController < ApplicationController
  # [...]
  end
end
```

```rb
module V1
  class ItemsController < ApplicationController
  # [...]
  end
end
```

Fire up the server and run some tests as follows:
```bash
rails s

http :3000/auth/login email=foo@bar.com password=foobar

http :3000/todos Accept:'application/vnd.todos.v1+json' Authorization:"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE0OTQyNjYxMTh9.prbADs0F1nItwm3MPFqsYeEQbVw2TT-Js6zt9qUcqLg"

http :3000/todos Accept:'application/vnd.todos.v2+json' Authorization:"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE0OTQyNjYxMTh9.prbADs0F1nItwm3MPFqsYeEQbVw2TT-Js6zt9qUcqLg"
```

### Generate a v2 Todos Controller
In case we attempt to access a nonexistent version, the API will default to v1 since we set it as the default version. For testing purposes, let's define v2.
```bash
rails g controller v2/todos
```

In the `routes.rb` file, add at the top as non-default versions have to be defined above the default version:
```rb
# module the controllers without affecting the URI
scope module: :v2, constraints: ApiVersion.new('v2') do
  resources :todos, only: :index
end
```

Since this is test controller, we'll define an index controller with a dummy response in `app/controllers/v2/todos_controller.rb`:
```rb
def index
  json_response({ message: 'Hello there'})
end
```

The next part is [API Serializing and Pagination](help_api_serializing_pagination.md).







