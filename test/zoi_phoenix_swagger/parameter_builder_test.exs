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
  end
end
