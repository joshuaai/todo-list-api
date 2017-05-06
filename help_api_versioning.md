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


