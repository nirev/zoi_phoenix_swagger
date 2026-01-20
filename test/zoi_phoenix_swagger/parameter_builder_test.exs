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
      assert match?(%{name: "name", in: :query, type: :string, required: true}, param)
    end

    test "converts optional string to non-required parameter", %{path: path} do
      schema =
        Zoi.map(%{
          name: Zoi.string() |> Zoi.optional()
        })

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert match?(%{name: "name", in: :query, type: :string, required: false}, param)
    end

    test "converts integer to integer type parameter", %{path: path} do
      schema = Zoi.map(%{age: Zoi.integer()})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert match?(%{name: "age", in: :query, type: :integer, required: true}, param)
    end

    test "converts float to number type parameter", %{path: path} do
      schema = Zoi.map(%{price: Zoi.float()})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert match?(%{name: "price", in: :query, type: :number, required: true}, param)
    end

    test "converts boolean to boolean type parameter", %{path: path} do
      schema = Zoi.map(%{active: Zoi.boolean()})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert match?(%{name: "active", in: :query, type: :boolean, required: true}, param)
    end

    # Phase 2: Special Types

    test "converts enum to string with enum values", %{path: path} do
      schema = Zoi.map(%{status: Zoi.enum(["pending", "approved", "rejected"])})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters

      assert match?(
               %{
                 name: "status",
                 in: :query,
                 type: :string,
                 enum: ["pending", "approved", "rejected"],
                 required: true
               },
               param
             )
    end

    test "converts datetime to string with date-time format", %{path: path} do
      schema = Zoi.map(%{created_at: Zoi.datetime()})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters

      assert match?(
               %{
                 name: "created_at",
                 in: :query,
                 type: :string,
                 format: :"date-time",
                 required: true
               },
               param
             )
    end

    test "converts field with default to parameter with default value", %{path: path} do
      schema = Zoi.map(%{direction: Zoi.enum(["asc", "desc"]) |> Zoi.default("asc")})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters

      assert match?(
               %{
                 name: "direction",
                 in: :query,
                 type: :string,
                 enum: ["asc", "desc"],
                 default: "asc",
                 required: true
               },
               param
             )
    end

    # Phase 3: Location Handling

    test "uses metadata to set path location", %{path: path} do
      schema = Zoi.map(%{category_id: Zoi.string(metadata: [in: :path])})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert match?(%{name: "category_id", in: :path, type: :string, required: true}, param)
    end

    test "uses metadata to set header location", %{path: path} do
      schema = Zoi.map(%{authorization: Zoi.string(metadata: [in: :header])})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert match?(%{name: "authorization", in: :header, type: :string, required: true}, param)
    end

    # Phase 4: Nested Maps

    test "flattens nested map with bracket notation", %{path: path} do
      schema = Zoi.map(%{filter: Zoi.map(%{status: Zoi.string()})})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      assert match?(%{name: "filter[status]", in: :query, type: :string, required: true}, param)
    end

    test "flattens deeply nested maps", %{path: path} do
      schema = Zoi.map(%{filter: Zoi.map(%{user: Zoi.map(%{name: Zoi.string()})})})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters

      assert match?(
               %{name: "filter[user][name]", in: :query, type: :string, required: true},
               param
             )
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

      assert match?(%{name: "order_by", in: :query, type: :string, required: true}, order_param)

      assert match?(
               %{name: "filter[status]", in: :query, type: :string, required: true},
               filter_param
             )
    end

    # Phase 5: Array Types

    test "converts array of strings to array parameter", %{path: path} do
      schema = Zoi.map(%{tags: Zoi.array(Zoi.string())})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters

      assert match?(
               %{name: "tags", in: :query, type: :array, items: %{type: :string}, required: true},
               param
             )
    end

    test "converts array of enums to array with enum items", %{path: path} do
      schema = Zoi.map(%{statuses: Zoi.array(Zoi.enum(["active", "inactive"]))})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters

      assert match?(
               %{
                 name: "statuses",
                 in: :query,
                 type: :array,
                 items: %{type: :string, enum: ["active", "inactive"]},
                 required: true
               },
               param
             )
    end

    # Phase 6: Description & Example

    test "uses description from schema", %{path: path} do
      schema = Zoi.map(%{name: Zoi.string(description: "The user's full name")})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters

      assert match?(
               %{
                 name: "name",
                 in: :query,
                 type: :string,
                 description: "The user's full name",
                 required: true
               },
               param
             )
    end

    test "uses example from schema", %{path: path} do
      schema = Zoi.map(%{category_id: Zoi.string(example: "abc123")})

      result = ZoiPhoenixSwagger.parameters(path, schema)

      assert [param] = result.operation.parameters
      # phoenix_swagger translates example to x-example
      assert match?(
               %{
                 name: "category_id",
                 in: :query,
                 type: :string,
                 "x-example": "abc123",
                 required: true
               },
               param
             )
    end

    # Phase 7: Full Integration

    test "handles complete schema from requirements", %{path: path} do
      schema =
        Zoi.map(%{
          filter:
            Zoi.map(%{
              category_id: Zoi.string(metadata: [in: :path]),
              status: Zoi.enum(["pending", "approved", "rejected"]) |> Zoi.optional(),
              inserted_at_from: Zoi.datetime() |> Zoi.optional(),
              inserted_at_to: Zoi.datetime() |> Zoi.optional(),
              reviewed_by: Zoi.string() |> Zoi.optional()
            }),
          order_by: Zoi.enum(["inserted_at", "status", "category_id"]) |> Zoi.optional(),
          order_by_direction: Zoi.enum(["asc", "desc"]) |> Zoi.default("asc")
        })

      result = ZoiPhoenixSwagger.parameters(path, schema)

      params = result.operation.parameters
      assert length(params) == 7

      category_param = Enum.find(params, &(&1.name == "category_id"))
      status_param = Enum.find(params, &(&1.name == "filter[status]"))
      from_param = Enum.find(params, &(&1.name == "filter[inserted_at_from]"))
      direction_param = Enum.find(params, &(&1.name == "order_by_direction"))

      # Check category_id is path param with flat name
      assert match?(
               %{name: "category_id", in: :path, type: :string, required: true},
               category_param
             )

      # Check status is optional enum with bracket notation
      assert match?(
               %{
                 name: "filter[status]",
                 in: :query,
                 type: :string,
                 enum: ["pending", "approved", "rejected"],
                 required: false
               },
               status_param
             )

      # Check datetime format
      assert match?(
               %{
                 name: "filter[inserted_at_from]",
                 in: :query,
                 type: :string,
                 format: :"date-time",
                 required: false
               },
               from_param
             )

      # Check default value
      assert match?(
               %{
                 name: "order_by_direction",
                 in: :query,
                 type: :string,
                 enum: ["asc", "desc"],
                 default: "asc",
                 required: true
               },
               direction_param
             )
    end
  end
end
