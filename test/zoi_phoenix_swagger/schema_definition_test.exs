defmodule ZoiPhoenixSwagger.SchemaDefinitionTest do
  use ExUnit.Case, async: true

  describe "schema_definition/1" do
    test "converts simple schema with primitive types" do
      schema =
        Zoi.map(%{
          name: Zoi.string(description: "Name", example: "John"),
          age: Zoi.integer(description: "Age", example: 30)
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert swagger_schema.type == :object
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
      schema =
        Zoi.map(%{
          user:
            Zoi.map(%{
              name: Zoi.string(example: "John"),
              email: Zoi.string(example: "john@example.com")
            })
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

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
      schema =
        Zoi.map(%{
          required_field: Zoi.string(),
          optional_field: Zoi.string() |> Zoi.optional()
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert :required_field in swagger_schema.required
      refute :optional_field in swagger_schema.required
    end

    test "handles arrays" do
      schema =
        Zoi.map(%{
          tags: Zoi.array(Zoi.string(), example: ["tag1", "tag2"])
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert swagger_schema.properties.tags.type == :array
      assert swagger_schema.properties.tags.items.type == :string
      assert swagger_schema.example.tags == ["tag1", "tag2"]
    end

    test "handles enums" do
      schema =
        Zoi.map(%{
          status: Zoi.enum(["active", "inactive"], example: "active")
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert swagger_schema.properties.status.type == :string
      assert swagger_schema.properties.status.enum == ["active", "inactive"]
      assert swagger_schema.example.status == "active"
    end

    test "handles datetime format" do
      schema =
        Zoi.map(%{
          created_at: Zoi.datetime()
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert swagger_schema.properties.created_at.type == :string
      assert swagger_schema.properties.created_at.format == :"date-time"
    end

    test "handles default values" do
      schema =
        Zoi.map(%{
          direction: Zoi.enum(["asc", "desc"]) |> Zoi.default("asc")
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert swagger_schema.properties.direction.default == "asc"
      assert swagger_schema.example.direction == "asc"
    end

    test "handles complex nested schema" do
      schema =
        Zoi.map(%{
          name: Zoi.string(description: "User name", example: "John Doe"),
          email: Zoi.string(description: "Email", example: "john@example.com"),
          age: Zoi.integer(example: 30) |> Zoi.optional(),
          preferences:
            Zoi.map(%{
              newsletter: Zoi.boolean(example: true),
              theme: Zoi.enum(["light", "dark"], example: "dark")
            })
            |> Zoi.optional(),
          tags: Zoi.array(Zoi.string(), example: ["developer", "elixir"])
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

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

    test "handles float type" do
      schema =
        Zoi.map(%{
          price: Zoi.float(description: "Price", example: 19.99)
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert swagger_schema.properties.price.type == :number
      assert swagger_schema.properties.price.description == "Price"
      assert swagger_schema.properties.price.example == 19.99
    end

    test "handles boolean type" do
      schema =
        Zoi.map(%{
          active: Zoi.boolean(description: "Active status", example: true)
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert swagger_schema.properties.active.type == :boolean
      assert swagger_schema.properties.active.description == "Active status"
      assert swagger_schema.properties.active.example == true
    end

    test "handles deeply nested objects" do
      schema =
        Zoi.map(%{
          organization:
            Zoi.map(%{
              name: Zoi.string(example: "Acme Corp"),
              address:
                Zoi.map(%{
                  street: Zoi.string(example: "123 Main St"),
                  city: Zoi.string(example: "Springfield"),
                  country:
                    Zoi.map(%{
                      code: Zoi.string(example: "US"),
                      name: Zoi.string(example: "United States")
                    })
                })
            })
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      # Verify deep nesting structure
      assert swagger_schema.properties.organization.type == :object
      assert swagger_schema.properties.organization.properties.address.type == :object

      assert swagger_schema.properties.organization.properties.address.properties.country.type ==
               :object

      # Verify example is properly nested
      assert swagger_schema.example == %{
               organization: %{
                 name: "Acme Corp",
                 address: %{
                   street: "123 Main St",
                   city: "Springfield",
                   country: %{
                     code: "US",
                     name: "United States"
                   }
                 }
               }
             }
    end

    test "handles arrays of objects" do
      schema =
        Zoi.map(%{
          users:
            Zoi.array(
              Zoi.map(%{
                name: Zoi.string(example: "John"),
                email: Zoi.string(example: "john@example.com")
              }),
              example: [%{name: "John", email: "john@example.com"}]
            )
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert swagger_schema.properties.users.type == :array
      assert swagger_schema.properties.users.items.type == :object
      assert swagger_schema.properties.users.items.properties.name.type == :string

      assert swagger_schema.example.users == [%{name: "John", email: "john@example.com"}]
    end

    test "handles schema without examples" do
      schema =
        Zoi.map(%{
          name: Zoi.string(),
          age: Zoi.integer()
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert swagger_schema.type == :object
      assert swagger_schema.required == [:name, :age]
      assert swagger_schema.properties.name.type == :string
      assert swagger_schema.properties.age.type == :integer
      refute Map.has_key?(swagger_schema, :example)
    end

    test "handles partial examples in nested objects" do
      schema =
        Zoi.map(%{
          user:
            Zoi.map(%{
              name: Zoi.string(example: "John"),
              email: Zoi.string()
            })
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      # Example should still be generated with partial data
      assert swagger_schema.example == %{
               user: %{
                 name: "John"
               }
             }
    end

    test "handles empty map schema" do
      schema = Zoi.map(%{})

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert swagger_schema.type == :object
      assert swagger_schema.required == []
      assert swagger_schema.properties == %{}
      refute Map.has_key?(swagger_schema, :example)
    end
  end
end
