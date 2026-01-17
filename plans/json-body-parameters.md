# JSON Body Parameters Feature Plan

## Overview

Add support for JSON request body parameters in ZoiPhoenixSwagger by integrating with Phoenix Swagger's `swagger_definitions` and `Schema.ref()` functionality. This will allow Zoi schemas to be converted into reusable Swagger schema definitions that can be referenced in body parameters.

## Current State

### What We Have

- **Parameter Locations Supported**: Query (default), Path, Header
- **Parameter Handling**: Nested `Zoi.map()` structures are recursively flattened into bracket notation (e.g., `filter[status]`)
- **Supported Zoi Types**: string, integer, float, boolean, enum, datetime, array, map
- **Metadata Support**: Parameters can specify location via `metadata: [in: :location]`
- **Integration Point**: `ZoiPhoenixSwagger.parameters/2` function in swagger_path blocks

### What's Missing

- **No Body Parameter Support**: Cannot specify `metadata: [in: :body]`
- **No Schema Definitions**: Does not generate or use Phoenix Swagger's `swagger_definitions`
- **No Schema References**: Cannot reference reusable schemas with `Schema.ref(:SchemaName)`
- **Always Flattens Objects**: Nested maps are always flattened into bracket notation, which doesn't work for JSON bodies

## Phoenix Swagger Body Parameters

### How Body Parameters Work

According to Phoenix Swagger documentation, body parameters are defined using schema references:

```elixir
# In controller module
def swagger_definitions do
  %{
    User: swagger_schema do
      title "User"
      description "A user of the application"
      properties do
        name :string, "User's name", required: true
        email :string, "User's email", required: true
        address Schema.ref(:Address), "Home address"
      end
      example %{
        name: "Joe",
        email: "joe@example.com",
        address: %{
          street: "123 Main St",
          city: "Springfield"
        }
      }
    end,
    Address: swagger_schema do
      title "Address"
      properties do
        street :string, "Street address"
        city :string, "City"
        state :string, "State"
      end
    end
  }
end

# In swagger_path
swagger_path :create do
  post "/api/users"
  parameters do
    user :body, Schema.ref(:User), "User to create", required: true
  end
  response 201, "Created"
end
```

### Key Characteristics

1. **Schema Definitions**: Defined in `swagger_definitions/0` function
2. **Schema References**: Used via `Schema.ref(:SchemaName)` in body parameters
3. **Nested Objects**: Properties can reference other schemas
4. **Examples**: Can include top-level example showing full JSON structure
5. **Location**: Body parameters use `:body` location

## Proposed Solution

### New Function: `schema_definition/2`

Create a new function that converts a Zoi schema into a Phoenix Swagger schema definition suitable for use in `swagger_definitions`:

```elixir
@spec schema_definition(atom(), Zoi.schema()) :: {atom(), map()}
def schema_definition(schema_name, zoi_schema)
```

**Purpose**: Transform Zoi schema into Phoenix Swagger schema definition with proper nesting (not flattened) and top-level example.

**Returns**: A tuple `{schema_name, schema_map}` that can be used in `swagger_definitions/0`

### Design Approach

#### 1. Schema Conversion Strategy

Unlike `parameters/2` which flattens nested maps, `schema_definition/2` should:

- **Preserve Object Nesting**: Convert `Zoi.map()` to nested `properties` without flattening
- **Generate Schema Properties**: Extract type, description, required fields, enum, format, etc.
- **Handle Nested Objects**: Recursively convert nested maps into nested properties
- **Generate Top-Level Example**: Create a complete example showing the full JSON structure
- **Support All Zoi Types**: Handle all existing Zoi types (string, integer, float, boolean, enum, datetime, array, map)

#### 2. Example Generation

For a schema like:

```elixir
Zoi.map(%{
  name: Zoi.string(description: "User's name", example: "John Doe"),
  email: Zoi.string(description: "Email address", example: "john@example.com"),
  age: Zoi.integer(description: "User's age", example: 30) |> Zoi.optional(),
  address: Zoi.map(%{
    street: Zoi.string(example: "123 Main St"),
    city: Zoi.string(example: "Springfield")
  })
})
```

Should generate example:

```elixir
%{
  name: "John Doe",
  email: "john@example.com",
  age: 30,
  address: %{
    street: "123 Main St",
    city: "Springfield"
  }
}
```

### Implementation Details

#### Function Signature

```elixir
defmodule ZoiPhoenixSwagger do
  # ... existing code ...

  @doc """
  Converts a Zoi schema to a Phoenix Swagger schema definition.

  Returns a tuple suitable for use in swagger_definitions/0.

  ## Example

      def swagger_definitions do
        %{
          ZoiPhoenixSwagger.schema_definition(:User, @user_schema)
        }
      end

  Or used inline in parameters:

      swagger_path :create do
        post "/api/users"
        {name, schema} = ZoiPhoenixSwagger.schema_definition(:CreateUser, @create_user_schema)
        parameters do
          body :body, Schema.new(schema), "User to create", required: true
        end
      end
  """
  @spec schema_definition(atom(), Zoi.schema()) :: {atom(), map()}
  def schema_definition(schema_name, zoi_schema) do
    json_schema = Zoi.to_json_schema(zoi_schema)

    swagger_schema = %{
      type: :object,
      title: Atom.to_string(schema_name),
      properties: convert_properties(json_schema[:properties] || %{}),
      required: json_schema[:required] || []
    }

    # Add top-level example if we can generate one
    swagger_schema = maybe_add_example(swagger_schema, json_schema)

    {schema_name, swagger_schema}
  end

  # ... implementation functions ...
end
```

#### Core Implementation Functions

```elixir
# Convert JSON Schema properties to Swagger properties
defp convert_properties(json_properties) do
  Map.new(json_properties, fn {key, prop_schema} ->
    {key, convert_property(prop_schema)}
  end)
end

# Convert a single property
defp convert_property(%{type: :object, properties: nested_props} = schema) do
  # Nested object - recursively convert
  %{
    type: :object,
    properties: convert_properties(nested_props)
  }
  |> maybe_add_property_opt(:required, schema[:required])
  |> maybe_add_property_opt(:description, schema[:description])
  |> maybe_add_property_opt(:example, schema[:example])
end

defp convert_property(%{type: :array} = schema) do
  # Array type - convert items
  %{
    type: :array,
    items: convert_property(schema[:items] || %{type: :string})
  }
  |> maybe_add_property_opt(:description, schema[:description])
  |> maybe_add_property_opt(:example, schema[:example])
end

defp convert_property(schema) do
  # Primitive type
  %{type: schema[:type]}
  |> maybe_add_property_opt(:description, schema[:description])
  |> maybe_add_property_opt(:enum, schema[:enum])
  |> maybe_add_property_opt(:format, schema[:format])
  |> maybe_add_property_opt(:default, schema[:default])
  |> maybe_add_property_opt(:example, schema[:example])
end

defp maybe_add_property_opt(map, _key, nil), do: map
defp maybe_add_property_opt(map, key, value), do: Map.put(map, key, value)

# Generate top-level example from schema
defp maybe_add_example(swagger_schema, json_schema) do
  case generate_example(json_schema) do
    nil -> swagger_schema
    example -> Map.put(swagger_schema, :example, example)
  end
end

defp generate_example(%{properties: properties}) when is_map(properties) do
  example =
    properties
    |> Enum.map(fn {key, prop_schema} ->
      case generate_property_example(prop_schema) do
        nil -> nil
        value -> {key, value}
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()

  if map_size(example) > 0, do: example, else: nil
end

defp generate_example(_), do: nil

defp generate_property_example(%{example: example}), do: example

defp generate_property_example(%{type: :object, properties: nested_props}) do
  generate_example(%{properties: nested_props})
end

defp generate_property_example(%{type: :array, items: items}) do
  case generate_property_example(items) do
    nil -> nil
    item_example -> [item_example]
  end
end

defp generate_property_example(%{default: default}), do: default
defp generate_property_example(_), do: nil
```

## Usage Example

### Complete Example

```elixir
defmodule MyAppWeb.UserController do
  use MyAppWeb, :controller
  use PhoenixSwagger

  # Define Zoi schema for validation
  @create_user_schema Zoi.map(%{
    name: Zoi.string(description: "User's full name", example: "John Doe"),
    email: Zoi.string(description: "Email address", example: "john@example.com"),
    age: Zoi.integer(description: "User's age", example: 30) |> Zoi.optional(),
    preferences: Zoi.map(%{
      newsletter: Zoi.boolean(example: true),
      theme: Zoi.enum(["light", "dark"], example: "dark")
    }) |> Zoi.optional(),
    tags: Zoi.array(Zoi.string(), example: ["developer", "elixir"])
  })

  # Generate Swagger definition
  def swagger_definitions do
    %{
      ZoiPhoenixSwagger.schema_definition(:CreateUserRequest, @create_user_schema)
    }
  end

  swagger_path :create do
    post "/api/users"
    description "Create a new user"
    parameters do
      body :body, Schema.ref(:CreateUserRequest), "User to create", required: true
    end
    response 201, "Created", Schema.ref(:User)
    response 422, "Validation error"
  end

  def create(conn, params) do
    # Use Zoi for validation
    with {:ok, validated} <- Zoi.validate(@create_user_schema, params) do
      # ... create user ...
    end
  end
end
```

### Generated Swagger Schema

The above would generate:

```json
{
  "CreateUserRequest": {
    "type": "object",
    "title": "CreateUserRequest",
    "required": ["name", "email", "tags"],
    "properties": {
      "name": {
        "type": "string",
        "description": "User's full name",
        "example": "John Doe"
      },
      "email": {
        "type": "string",
        "description": "Email address",
        "example": "john@example.com"
      },
      "age": {
        "type": "integer",
        "description": "User's age",
        "example": 30
      },
      "preferences": {
        "type": "object",
        "properties": {
          "newsletter": {
            "type": "boolean",
            "example": true
          },
          "theme": {
            "type": "string",
            "enum": ["light", "dark"],
            "example": "dark"
          }
        }
      },
      "tags": {
        "type": "array",
        "items": {
          "type": "string"
        },
        "example": ["developer", "elixir"]
      }
    },
    "example": {
      "name": "John Doe",
      "email": "john@example.com",
      "age": 30,
      "preferences": {
        "newsletter": true,
        "theme": "dark"
      },
      "tags": ["developer", "elixir"]
    }
  }
}
```

## Integration with Existing Code

### No Breaking Changes

The new `schema_definition/2` function is completely separate from the existing `parameters/2` function:

- **Existing code continues to work**: `parameters/2` still handles query/path/header parameters with bracket notation
- **New functionality is opt-in**: Users must explicitly call `schema_definition/2` for body parameters
- **Different use cases**:
  - `parameters/2`: Flattened parameters (query/path/header)
  - `schema_definition/2`: Nested schemas (body parameters)

### Code Organization

```
lib/zoi_phoenix_swagger.ex
├── parameters/2          # Existing - for query/path/header params
├── schema_definition/2   # New - for body parameter schemas
├── build_params/5        # Existing - flattens nested maps
├── convert_properties/1  # New - preserves nested structure
├── convert_property/1    # New - converts individual properties
├── generate_example/1    # New - generates top-level examples
└── ... (existing helper functions)
```

## Testing Strategy

### Unit Tests

Create `test/zoi_phoenix_swagger/schema_definition_test.exs`:

```elixir
defmodule ZoiPhoenixSwagger.SchemaDefinitionTest do
  use ExUnit.Case, async: true

  describe "schema_definition/2" do
    test "converts simple schema with primitive types" do
      schema = Zoi.map(%{
        name: Zoi.string(description: "Name", example: "John"),
        age: Zoi.integer(description: "Age", example: 30)
      })

      {name, swagger_schema} = ZoiPhoenixSwagger.schema_definition(:User, schema)

      assert name == :User
      assert swagger_schema.type == :object
      assert swagger_schema.title == "User"
      assert swagger_schema.required == [:name, :age]

      assert swagger_schema.properties.name == %{
        type: :string,
        description: "Name",
        example: "John"
      }

      assert swagger_schema.properties.age == %{
        type: :integer,
        description: "Age",
        example: 30
      }

      assert swagger_schema.example == %{
        name: "John",
        age: 30
      }
    end

    test "handles nested objects without flattening" do
      schema = Zoi.map(%{
        user: Zoi.map(%{
          name: Zoi.string(example: "John"),
          email: Zoi.string(example: "john@example.com")
        })
      })

      {_name, swagger_schema} = ZoiPhoenixSwagger.schema_definition(:Request, schema)

      assert swagger_schema.properties.user.type == :object
      assert swagger_schema.properties.user.properties.name.type == :string
      assert swagger_schema.properties.user.properties.email.type == :string

      assert swagger_schema.example == %{
        user: %{
          name: "John",
          email: "john@example.com"
        }
      }
    end

    test "handles optional fields" do
      schema = Zoi.map(%{
        required_field: Zoi.string(),
        optional_field: Zoi.string() |> Zoi.optional()
      })

      {_name, swagger_schema} = ZoiPhoenixSwagger.schema_definition(:Schema, schema)

      assert :required_field in swagger_schema.required
      refute :optional_field in swagger_schema.required
    end

    test "handles arrays" do
      schema = Zoi.map(%{
        tags: Zoi.array(Zoi.string(), example: ["tag1", "tag2"])
      })

      {_name, swagger_schema} = ZoiPhoenixSwagger.schema_definition(:Schema, schema)

      assert swagger_schema.properties.tags.type == :array
      assert swagger_schema.properties.tags.items.type == :string
      assert swagger_schema.example.tags == ["tag1", "tag2"]
    end

    test "handles enums" do
      schema = Zoi.map(%{
        status: Zoi.enum(["active", "inactive"], example: "active")
      })

      {_name, swagger_schema} = ZoiPhoenixSwagger.schema_definition(:Schema, schema)

      assert swagger_schema.properties.status.type == :string
      assert swagger_schema.properties.status.enum == ["active", "inactive"]
      assert swagger_schema.example.status == "active"
    end

    test "handles datetime format" do
      schema = Zoi.map(%{
        created_at: Zoi.datetime()
      })

      {_name, swagger_schema} = ZoiPhoenixSwagger.schema_definition(:Schema, schema)

      assert swagger_schema.properties.created_at.type == :string
      assert swagger_schema.properties.created_at.format == :"date-time"
    end

    test "handles default values" do
      schema = Zoi.map(%{
        direction: Zoi.enum(["asc", "desc"]) |> Zoi.default("asc")
      })

      {_name, swagger_schema} = ZoiPhoenixSwagger.schema_definition(:Schema, schema)

      assert swagger_schema.properties.direction.default == "asc"
      assert swagger_schema.example.direction == "asc"
    end

    test "handles complex nested schema" do
      schema = Zoi.map(%{
        name: Zoi.string(description: "User name", example: "John Doe"),
        email: Zoi.string(description: "Email", example: "john@example.com"),
        age: Zoi.integer(example: 30) |> Zoi.optional(),
        preferences: Zoi.map(%{
          newsletter: Zoi.boolean(example: true),
          theme: Zoi.enum(["light", "dark"], example: "dark")
        }) |> Zoi.optional(),
        tags: Zoi.array(Zoi.string(), example: ["developer", "elixir"])
      })

      {_name, swagger_schema} = ZoiPhoenixSwagger.schema_definition(:CreateUser, schema)

      # Verify structure
      assert swagger_schema.type == :object
      assert swagger_schema.required == [:name, :email, :tags]

      # Verify nested preferences is an object
      assert swagger_schema.properties.preferences.type == :object
      assert swagger_schema.properties.preferences.properties.newsletter.type == :boolean

      # Verify complete example
      assert swagger_schema.example == %{
        name: "John Doe",
        email: "john@example.com",
        age: 30,
        preferences: %{
          newsletter: true,
          theme: "dark"
        },
        tags: ["developer", "elixir"]
      }
    end
  end
end
```

## Implementation Phases

### Phase 1: Core Schema Conversion
- Implement `schema_definition/2` function
- Implement `convert_properties/1` and `convert_property/1`
- Handle primitive types (string, integer, float, boolean)
- Handle nested objects without flattening
- Add basic tests

### Phase 2: Advanced Type Support
- Handle arrays with items
- Handle enums
- Handle datetime format
- Handle optional fields and required array
- Add tests for all type conversions

### Phase 3: Example Generation
- Implement `generate_example/1` and `generate_property_example/1`
- Extract examples from Zoi schema metadata
- Generate nested examples for objects
- Generate array examples
- Use defaults as example fallback
- Add comprehensive example generation tests

### Phase 4: Documentation & Polish
- Add @doc and @spec annotations
- Update README with usage examples
- Add integration example to documentation
- Consider adding helper for inline schema definitions

## Alternative Approaches Considered

### 1. Extend `parameters/2` to Handle Body

**Rejected because**: Body parameters work fundamentally differently from query/path/header parameters. Body parameters need schema references and nested structures, while other parameters need flattening. Mixing both concerns in one function would create complexity.

### 2. Auto-detect Body Parameters by Metadata

**Rejected because**: The `swagger_definitions/0` function needs to be defined at module level, not within a swagger_path block. Auto-detecting would require registering definitions globally, which is more complex than letting users explicitly call `schema_definition/2`.

### 3. Generate Schema Names Automatically

**Rejected because**: Users should have control over schema naming for reusability. Auto-generated names like `Index_Body_Param_1` are not user-friendly and don't support schema reuse across endpoints.

## Success Criteria

- ✅ Can convert Zoi schemas to Phoenix Swagger schema definitions
- ✅ Preserves nested object structure (doesn't flatten)
- ✅ Supports all existing Zoi types
- ✅ Generates complete top-level examples
- ✅ No breaking changes to existing `parameters/2` function
- ✅ Clear documentation and usage examples
- ✅ Comprehensive test coverage
- ✅ Users can define body parameters in `swagger_definitions/0`
- ✅ Users can reference schemas with `Schema.ref(:SchemaName)`

## Future Enhancements

1. **Auto-generate swagger_definitions**: Helper function that scans module for Zoi schemas and generates definitions
2. **Schema composition**: Support for combining multiple Zoi schemas into one definition
3. **Response schemas**: Similar function for generating response schemas
4. **Schema validation**: Validate that generated schemas match OpenAPI 2.0/3.0 spec

## References

- Phoenix Swagger Documentation: https://hexdocs.pm/phoenix_swagger/
- Phoenix Swagger GitHub: https://github.com/xerions/phoenix_swagger
- Zoi Documentation: https://github.com/phcurado/zoi
- OpenAPI 2.0 Specification: https://swagger.io/specification/v2/
