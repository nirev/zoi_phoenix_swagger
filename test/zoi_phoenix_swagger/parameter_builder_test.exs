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
  end
end
