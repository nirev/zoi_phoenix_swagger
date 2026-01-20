defmodule ZoiPhoenixSwagger.SchemaDefinitionTest do
  use ExUnit.Case, async: true

  import PhoenixSwagger
  require PhoenixSwagger.Schema, as: Schema

  describe "schema_definition/1" do
    test "converts simple schema with primitive types" do
      zoi_schema =
        Zoi.map(%{
          name: Zoi.string(description: "Name", example: "John"),
          age: Zoi.integer(description: "Age", example: 30)
        })

      expected =
        schema do
          properties do
            name(:string, "Name", required: true, example: "John")
            age(:integer, "Age", required: true, example: 30)
          end

          example(%{
            name: "John",
            age: 30
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles nested objects without flattening" do
      zoi_schema =
        Zoi.map(%{
          user:
            Zoi.map(%{
              name: Zoi.string(example: "John"),
              email: Zoi.string(example: "john@example.com")
            })
        })

      expected =
        schema do
          properties do
            user(
              Schema.new do
                properties do
                  name(:string, nil, required: true, example: "John")
                  email(:string, nil, required: true, example: "john@example.com")
                end
              end,
              nil,
              required: true
            )
          end

          example(%{
            user: %{
              name: "John",
              email: "john@example.com"
            }
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles optional fields" do
      zoi_schema =
        Zoi.map(%{
          required_field: Zoi.string(),
          optional_field: Zoi.string() |> Zoi.optional()
        })

      expected =
        schema do
          properties do
            required_field(:string, nil, required: true)
            optional_field(:string, nil)
          end
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles arrays" do
      zoi_schema =
        Zoi.map(%{
          tags: Zoi.array(Zoi.string(), example: ["tag1", "tag2"])
        })

      expected =
        schema do
          properties do
            tags(:array, nil, required: true, example: ["tag1", "tag2"], items: %{type: :string})
          end

          example(%{
            tags: ["tag1", "tag2"]
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles enums" do
      zoi_schema =
        Zoi.map(%{
          status: Zoi.enum(["active", "inactive"], example: "active")
        })

      expected =
        schema do
          properties do
            status(:string, nil,
              required: true,
              enum: ["active", "inactive"],
              example: "active"
            )
          end

          example(%{
            status: "active"
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles datetime format" do
      zoi_schema =
        Zoi.map(%{
          created_at: Zoi.datetime()
        })

      expected =
        schema do
          properties do
            created_at(:string, nil, required: true, format: :"date-time")
          end
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles default values" do
      zoi_schema =
        Zoi.map(%{
          direction: Zoi.enum(["asc", "desc"]) |> Zoi.default("asc")
        })

      expected =
        schema do
          properties do
            direction(:string, nil,
              required: true,
              enum: ["asc", "desc"],
              default: "asc"
            )
          end

          example(%{
            direction: "asc"
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles complex nested schema" do
      zoi_schema =
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

      expected =
        schema do
          properties do
            name(:string, "User name", required: true, example: "John Doe")
            email(:string, "Email", required: true, example: "john@example.com")
            age(:integer, nil, example: 30)

            preferences(
              Schema.new do
                properties do
                  newsletter(:boolean, nil, required: true, example: true)
                  theme(:string, nil, required: true, enum: ["light", "dark"], example: "dark")
                end
              end,
              nil
            )

            tags(:array, nil,
              required: true,
              items: %{type: :string},
              example: ["developer", "elixir"]
            )
          end

          example(%{
            name: "John Doe",
            email: "john@example.com",
            age: 30,
            preferences: %{
              newsletter: true,
              theme: "dark"
            },
            tags: ["developer", "elixir"]
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles float type" do
      zoi_schema =
        Zoi.map(%{
          price: Zoi.float(description: "Price", example: 19.99)
        })

      expected =
        schema do
          properties do
            price(:number, "Price", required: true, example: 19.99)
          end

          example(%{
            price: 19.99
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles boolean type" do
      zoi_schema =
        Zoi.map(%{
          active: Zoi.boolean(description: "Active status", example: true)
        })

      expected =
        schema do
          properties do
            active(:boolean, "Active status", required: true, example: true)
          end

          example(%{
            active: true
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles deeply nested objects" do
      zoi_schema =
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

      expected =
        schema do
          properties do
            organization(
              Schema.new do
                properties do
                  name(:string, nil, required: true, example: "Acme Corp")

                  address(
                    Schema.new do
                      properties do
                        street(:string, nil, required: true, example: "123 Main St")
                        city(:string, nil, required: true, example: "Springfield")

                        country(
                          Schema.new do
                            properties do
                              code(:string, nil, required: true, example: "US")
                              name(:string, nil, required: true, example: "United States")
                            end
                          end,
                          nil,
                          required: true
                        )
                      end
                    end,
                    nil,
                    required: true
                  )
                end
              end,
              nil,
              required: true
            )
          end

          example(%{
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
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles arrays of objects" do
      zoi_schema =
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

      expected =
        schema do
          properties do
            users(
              :array,
              nil,
              required: true,
              items:
                Schema.new do
                  properties do
                    name(:string, nil, required: true, example: "John")
                    email(:string, nil, required: true, example: "john@example.com")
                  end
                end,
              example: [%{name: "John", email: "john@example.com"}]
            )
          end

          example(%{
            users: [%{name: "John", email: "john@example.com"}]
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles schema without examples" do
      zoi_schema =
        Zoi.map(%{
          name: Zoi.string(),
          age: Zoi.integer()
        })

      expected =
        schema do
          properties do
            name(:string, nil, required: true)
            age(:integer, nil, required: true)
          end
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles partial examples in nested objects" do
      zoi_schema =
        Zoi.map(%{
          user:
            Zoi.map(%{
              name: Zoi.string(example: "John"),
              email: Zoi.string()
            })
        })

      expected =
        schema do
          properties do
            user(
              Schema.new do
                properties do
                  name(:string, nil, required: true, example: "John")
                  email(:string, nil, required: true)
                end
              end,
              nil,
              required: true
            )
          end

          example(%{
            user: %{
              name: "John"
            }
          })
        end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end

    test "handles empty map schema" do
      zoi_schema = Zoi.map(%{})

      expected = schema do
      end

      assert expected == ZoiPhoenixSwagger.schema_definition(zoi_schema)
    end
  end
end
