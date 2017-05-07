# JWT Authentication
We'll implement token-based authentication with JWT (JSON Web Tokens). Tutorial with tests is [here](https://scotch.io/tutorials/build-a-restful-json-api-with-rails-5-part-two).

```bash
rails g model User name:string email:string password_digest:string
rails db:migrate
```

Our user model defines a 1:m relationship with the todo model and also adds field validations. Implement the `user.rb` model:
```rb
class User < ApplicationRecord
  # encrypt password
  has_secure_password

  # Model associations
  has_many :todos, foreign_key: :created_by

  # Validations
  validates_presence_of :name, :email, :password_digest
end
```

Add the `bcrypt` gem to the `Gemfile` for encrypting the password:
```rb
# Use ActiveModel has_secure_password
gem 'bcrypt', '~> 3.1.7'
```

## JSON Web Token
We'll make use of the `jwt` gem to manage JSON web tokens(jwt). Let's add this to the Gemfile and install it:
```rb
gem 'jwt'
```

```bash
bundle install
```

Our class will live in the lib directory since it's not domain specific; if we were to move it to a different application it should work with minimal configuration. But ss of Rails 5, autoloading is disabled in production because of thread safety. This is a huge concern for us since `lib` is part of auto-load paths. To counter this change, we'll add our `lib` in `app` since all code in app is auto-loaded in development and eager-loaded in production.

```bash
mkdir app/lib

touch app/lib/json_web_token.rb
```

Define the jwt singleton in `app/lib/json_web_token.rb`:
```rb
class JsonWebToken
  # secret to encode and decode token
  HMAC_SECRET = Rails.application.secrets.secret_key_base

  def self.encode(payload, exp = 24.hours.from_now)
    # set expiry to 24 hours from creation time
    payload[:exp] = exp.to_i
    # sign token with application secret
    JWT.encode(payload, HMAC_SECRET)
  end
  
  def self.decode(token)
    # get payload; first index in decoded Array
    body = JWT.decode(token, HMAC_SECRET)[0]
    HashWithIndifferentAccess.new body

    # rescue from expiry exception
  rescue JWT::ExpiredSignature, JWT::VerificationError => e
    # raise custom error to be handled by custom handler
    raise ExceptionHandler::InvalidToken, e.message
  end
    
end
```
This singleton wraps `JWT` to provide token encoding and decoding methods. The encode method will be responsible for creating tokens based on a payload (user id) and expiration period. Since every Rails application has a unique secret key, we'll use that as our secret to sign tokens. The decode method, on the other hand, accepts a token and attempts to decode it using the same secret used in encoding. In the event token decoding fails, be it due to expiration or validation, `JWT` will raise respective exceptions which will be handled in the `Exception Handler` module.

Add to the `exception_handler.rb` file:
```rb
# Define custom error subclasses - rescue catches `StandardErrors`
class AuthenticationError < StandardError; end
class MissingToken < StandardError; end
class InvalidToken < StandardError; end

included do
    # Define custom handlers
    rescue_from ActiveRecord::RecordInvalid, with: :four_twenty_two
    rescue_from ExceptionHandler::AuthenticationError, with: :unauthorized_request
    rescue_from ExceptionHandler::MissingToken, with: :four_twenty_two
    rescue_from ExceptionHandler::InvalidToken, with: :four_twenty_two

    rescue_from ActiveRecord::RecordNotFound do |e|
      json_response({ message: e.message }, :not_found)
    end

    rescue_from ActiveRecord::RecordInvalid do |e|
      json_response({ message: e.message }, :unprocessable_entity)
    end
end

private

# JSON response with message; Status code 422 - unprocessable entity
def four_twenty_two(e)
    json_response({ message: e.message }, :unprocessable_entity)
end

# JSON response with message; Status code 401 - Unauthorized
def unauthorized_request(e)
    json_response({ message: e.message }, :unauthorized)
end
```

We've defined custom `Standard Error` sub-classes to help handle exceptions raised. By defining error classes as sub-classes of standard error, we're able to `rescue_from` them once raised.

## Authorize API Request
This class will be responsible for authorizing all API requests making sure that all requests have a valid token and user payload.

Since this is an authentication service class, it'll live in `app/auth`.
```bash
# create auth folder to house auth services
$ mkdir app/auth
$ touch app/auth/authorize_api_request.rb
```

The `AuthorizeApiRequest` service should have an entry method `call` that returns a valid user object when the request is valid and raises an error when invalid. In the `authorize_api_request` file, add:

```rb
class AuthorizeApiRequest
  def initialize(headers = {})
    @headers = headers
  end

  # Service entry point - return valid user object
  def call
    {
      user: user
    }
  end

  private

  attr_reader :headers

  def user
    # check if user is in the database
    # memoize user object
    @user ||= User.find(decoded_auth_token[:user_id]) if decoded_auth_token
    # handle user not found
  rescue ActiveRecord::RecordNotFound => e
    # raise custom error
    raise(
      ExceptionHandler::InvalidToken,
      ("#{Message.invalid_token} #{e.message}")
    )
  end

  # decode authentication token
  def decoded_auth_token
    @decoded_auth_token ||= JsonWebToken.decode(http_auth_header)
  end

  # check for token in `Authorization` header
  def http_auth_header
    if headers['Authorization'].present?
      return headers['Authorization'].split(' ').last
    end
      raise(ExceptionHandler::MissingToken, Message.missing_token)
  end    
end
```

The `AuthorizeApiRequest` service gets the token from the authorization headers, attempts to decode it to return a valid user object. 

Now we also create a singleton `Message` class to house all our messages; this an easier way to manage our application messages. We'll define it in `app/lib` as `message.rb` since it's non-domain-specific:
```rb
class Message
  def self.not_found(record = 'record')
    "Sorry, #{record} not found."
  end

  def self.invalid_credentials
    'Invalid credentials'
  end

  def self.invalid_token
    'Invalid token'
  end

  def self.missing_token
    'Missing token'
  end

  def self.unauthorized
    'Unauthorized request'
  end

  def self.account_created
    'Account created successfully'
  end

  def self.account_not_created
    'Account could not be created'
  end

  def self.expired_token
    'Sorry, your token has expired. Please login to continue.'
  end    
end
```

## Authenticate User
This class will be responsible for authenticating users via email and password. Since this is also an authentication service class, it'll live in app/auth.

```bash
touch app/auth/authenticate_user.rb
```

The `AuthenticateUser` service also has an entry point `#call`. It should return a token when user credentials are valid and raise an error when they're not. Let's go ahead and implement the class.

```rb
class AuthenticateUser
  def initialize(email, password)
    @email = email
    @password = password
  end

  # Service entry point
  def call
    JsonWebToken.encode(user_id: user.id) if user
  end

  private

  attr_reader :email, :password

  # verify user credentials
  def user
    user = User.find_by(email: email)
    return user if user && user.authenticate(password)
    # raise Authentication error if credentials are invalid
    raise(ExceptionHandler::AuthenticationError, Message.invalid_credentials)
  end    
end
```

## Authentication Controller
This controller will be responsible for orchestrating the authentication process making use of the auth service we have just created.

```bash
# generate the Authentication Controller
rails g controller Authentication
```

The authentication controller should expose an /auth/login endpoint that accepts user credentials and returns a JSON response with the result:

```rb
# return auth token once user is authenticated
def authenticate
    auth_token =
      AuthenticateUser.new(auth_params[:email], auth_params[:password]).call
    json_response(auth_token: auth_token)
end

private

def auth_params
    params.permit(:email, :password)
end
```

Notice how slim the authentication controller is, we have our service architecture to thank for that. Instead, we make use of the authentication controller to piece everything together; to control authentication. 

We also need to add routing for authentication action. In the `routes.rb` file, add:
```rb
post 'auth/login', to: 'authentication#authenticate'
```

In order to have users to authenticate in the first place, we need to have them signup first. This will be handled by the users controller.

```bash
rails g controller Users
```

The user controller should expose a `/signup` endpoint that accepts user information and returns a JSON response with the result. Add the signup to the `routes.rb` file:
```rb
post 'signup', to: 'users#create'
```

Now we implement the controller in `users_controller.rb`:
```rb
class UsersController < ApplicationController
  # POST /signup
  # return authenticated token upon signup
  def create
    user = User.create!(user_params)
    auth_token = AuthenticateUser.new(user.email, user.password).call
    response = { message: Message.account_created, auth_token: auth_token }
    json_response(response, :created)
  end

  private

  def user_params
    params.permit(
      :name,
      :email,
      :password,
      :password_confirmation
    )
  end
end
```

The users controller attempts to create a user and returns a JSON response with the result. We use Active Record's `create!` method so that in the event there's an error, an exception will be raised and handled in the exception handler.

We've wired up the user authentication bit but our API is still open; it does not authorize requests with a token. To fix this, we have to make sure that on every request (except authentication) our API checks for a valid token. To achieve this, we'll implement a callback in the application controller that authenticates every request. Since all controllers inherit from application controller, it will be propagated to all controllers.

In the `application_controller.rb` file, add:
```rb
# called before every action on controllers
before_action :authorize_request
attr_reader :current_user

private

# Check for valid request token and return user
def authorize_request
    @current_user = (AuthorizeApiRequest.new(request.headers).call)[:user]
end
```

On every request, the application will verify the request by calling the request authorization service. If the request is authorized, it will set the `current user` object to be used in the other controllers.

*Notice how we don't have lots of guard clauses and conditionals in our controllers, this is because of our error handling implementation.*

Let's remember that when signing up and authenticating a user we won't need a token. We'll only require user credentials. Thus, let's skip request authentication for these two actions.

First the authentication action in `authentication_controller.rb`:
```rb
skip_before_action :authorize_request, only: :authenticate

# return auth token once user is authenticated
def authenticate
  auth_token =
    AuthenticateUser.new(auth_params[:email], auth_params[:password]).call
  json_response(auth_token: auth_token)
end

private

def auth_params
  params.permit(:email, :password)
end
```

Then the user signup action in `users_controller.rb`:
```rb
skip_before_action :authorize_request, only: :create
```

### Adding Users to the Todos Controller
Add users to our Todos controller by refining the `index` and `create` actions in the `todos_controller.rb` file:
```rb
# GET /todos
def index
    @todos = current_user.todos
    json_response(@todos)
end

# POST /todos
def create
    @todo = current_user.todos.create!(todo_params)
    json_response(@todo, :created)
end
```

Start up the server and do some manual testing
```bash
# Attempt to access API without a token
http :3000/todos

# Signup a new user - get token from here
http :3000/signup name=ash email=ash@email.com password=foobar password_confirmation=foobar

# Get new user todos
http :3000/todos
Authorization:"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE0OTQxOTc4Mjh9.i-cAtprOPuFJ36ueEoLCzkRF-AXUfFXhipLCtBEG8_Y"

# create todo for new user
http POST :3000/todos title=Beethoven Authorization:"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE0OTQxOTc4Mjh9.i-cAtprOPuFJ36ueEoLCzkRF-AXUfFXhipLCtBEG8_Y"

# Get create todos
http :3000/todos
Authorization:"eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoxLCJleHAiOjE0OTQxOTc4Mjh9.i-cAtprOPuFJ36ueEoLCzkRF-AXUfFXhipLCtBEG8_Y"
```

The next and final part is on [API versioning, pagination and serialization](help_api_versioning.md).

