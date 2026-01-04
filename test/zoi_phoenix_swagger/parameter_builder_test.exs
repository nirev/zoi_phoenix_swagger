defmodule ZoiPhoenixSwagger.ParameterBuilderTest do
  use ExUnit.Case, async: true

  alias PhoenixSwagger.Path.PathObject
  alias PhoenixSwagger.Path.OperationObject

  describe "parameters/2" do
    setup do
      path = %PathObject{
        operation: %OperationObject{
          parameters: []
        }
      }

      {:ok, path: path}
    end

    # Phase 1: Foundation - Single Parameters

    test "converts single required string to query parameter", %{path: path} do
      schema =
        Zoi.map(%{
          name: Zoi.string()
        })

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.name == "name"
      assert param.in == :query
      assert param.type == :string
      assert param.required == true
    end

    test "converts optional string to non-required parameter", %{path: path} do
      schema =
        Zoi.map(%{
          name: Zoi.string() |> Zoi.optional()
        })

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.required == false
    end

    test "converts integer to integer type parameter", %{path: path} do
      schema = Zoi.map(%{age: Zoi.integer()})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.type == :integer
    end

    test "converts float to number type parameter", %{path: path} do
      schema = Zoi.map(%{price: Zoi.float()})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.type == :number
    end

    test "converts boolean to boolean type parameter", %{path: path} do
      schema = Zoi.map(%{active: Zoi.boolean()})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.type == :boolean
    end

    # Phase 2: Special Types

    test "converts enum to string with enum values", %{path: path} do
      schema = Zoi.map(%{status: Zoi.enum(["pending", "approved", "rejected"])})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.type == :string
      assert param.enum == ["pending", "approved", "rejected"]
    end

    test "converts datetime to string with date-time format", %{path: path} do
      schema = Zoi.map(%{created_at: Zoi.datetime()})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.type == :string
      assert param.format == :"date-time"
    end

    test "converts field with default to parameter with default value", %{path: path} do
      schema = Zoi.map(%{direction: Zoi.enum(["asc", "desc"]) |> Zoi.default("asc")})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.default == "asc"
    end

    # Phase 3: Location Handling

    test "uses metadata to set path location", %{path: path} do
      schema = Zoi.map(%{category_id: Zoi.string(metadata: [in: :path])})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.in == :path
      assert param.required == true
    end

    test "uses metadata to set header location", %{path: path} do
      schema = Zoi.map(%{authorization: Zoi.string(metadata: [in: :header])})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.in == :header
    end

    # Phase 4: Nested Maps

    test "flattens nested map with bracket notation", %{path: path} do
      schema = Zoi.map(%{filter: Zoi.map(%{status: Zoi.string()})})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.name == "filter[status]"
    end

    test "flattens deeply nested maps", %{path: path} do
      schema = Zoi.map(%{filter: Zoi.map(%{user: Zoi.map(%{name: Zoi.string()})})})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.name == "filter[user][name]"
    end

    test "mixes top-level and nested parameters", %{path: path} do
      schema =
        Zoi.map(%{
          order_by: Zoi.string(),
          filter: Zoi.map(%{status: Zoi.string()})
        })

      result = ZoiPhoenixSwagger.parameters(path, schema)

      params = result.operation.parameters
      assert length(params) == 2

      order_param = Enum.find(params, &(&1.name == "order_by"))
      filter_param = Enum.find(params, &(&1.name == "filter[status]"))

      assert order_param != nil
      assert filter_param != nil
    end

    # Phase 5: Array Types

    test "converts array of strings to array parameter", %{path: path} do
      schema = Zoi.map(%{tags: Zoi.array(Zoi.string())})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.type == :array
      assert param.items == %{type: :string}
    end

    test "converts array of enums to array with enum items", %{path: path} do
      schema = Zoi.map(%{statuses: Zoi.array(Zoi.enum(["active", "inactive"]))})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.type == :array
      assert param.items == %{type: :string, enum: ["active", "inactive"]}
    end

    # Phase 6: Description & Example

    test "uses description from schema", %{path: path} do
      schema = Zoi.map(%{name: Zoi.string(description: "The user's full name")})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert param.description == "The user's full name"
    end

    test "uses example from schema", %{path: path} do
      schema = Zoi.map(%{category_id: Zoi.string(example: "abc123")})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      # phoenix_swagger translates example to x-example
      assert Map.get(param, :"x-example") == "abc123"
    end
  end
end
