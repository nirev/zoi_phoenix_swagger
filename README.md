# ZoiPhoenixSwagger

Integration library between [Zoi](https://github.com/phcurado/zoi) and [Phoenix Swagger](https://github.com/xerions/phoenix_swagger) for automatic parameter validation and OpenAPI documentation generation.

## Overview

ZoiPhoenixSwagger bridges the gap between Zoi's runtime parameter validation and Phoenix Swagger's OpenAPI documentation generation. Define your parameter schemas once using Zoi, and automatically generate both validation logic and Swagger/OpenAPI documentation.

## Features

- Define controller parameters using Zoi schemas
- Automatically generate Phoenix Swagger parameter definitions from Zoi schemas
- Maintain a single source of truth for parameter validation and API documentation
- Type-safe parameter validation with comprehensive error messages

## Installation

Add `zoi_phoenix_swagger` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:zoi_phoenix_swagger, "~> 0.1.0"}
  ]
end
```

## Usage

Define your Zoi schema once and use it for both validation and Swagger documentation.

### Parameters (query, path, body params)

```elixir
defmodule MyAppWeb.ItemController do
  use MyAppWeb, :controller
  use PhoenixSwagger

  @list_params Zoi.map(%{
    category_id: Zoi.string(metadata: [in: :path]),
    status: Zoi.enum(["pending", "approved"]) |> Zoi.optional(),
    order_by: Zoi.enum(["inserted_at", "name"]) |> Zoi.default("inserted_at")
  })

  swagger_path :index do
    get("/api/categories/{category_id}/items")
    ZoiPhoenixSwagger.parameters(@list_params)
    response(200, "Success")
  end

  def index(conn, params) do
    with {:ok, validated} <- Zoi.validate(@list_params, params) do
      # Use validated params
    end
  end
end
```

### Schema Definitions (request/response bodies)

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use PhoenixSwagger

  @create_user_schema Zoi.map(%{
    name: Zoi.string(description: "User name", example: "John Doe"),
    email: Zoi.string(description: "Email address", example: "john@example.com"),
    age: Zoi.integer(example: 30) |> Zoi.optional()
  })

  def swagger_definitions do
    %{
      CreateUserRequest: ZoiPhoenixSwagger.schema_definition(@create_user_schema)
    }
  end

  swagger_path :create do
    post("/api/users")
    parameter("user", :body, Schema.ref(:CreateUserRequest), "User attributes")
    response(201, "Created")
  end

  def create(conn, params) do
    with {:ok, user_data} <- Zoi.validate(@create_user_schema, params) do
      # Create user
    end
  end
end
```

## Development

### Running Tests

```bash
mix test
```

### Code Formatting

```bash
mix format
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

Copyright 2026

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
