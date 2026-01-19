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

      assert %{
               type: :object,
               required: [:name, :age],
               properties: %{
                 name: %{
                   type: :string,
                   description: "Name",
                   example: "John"
                 },
                 age: %{
                   type: :integer,
                   description: "Age",
                   example: 30
                 }
               },
               example: %{
                 name: "John",
                 age: 30
               }
             } == swagger_schema
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

      assert %{
               type: :object,
               required: [:user],
               properties: %{
                 user: %{
                   type: :object,
                   required: [:name, :email],
                   properties: %{
                     name: %{type: :string, example: "John"},
                     email: %{type: :string, example: "john@example.com"}
                   }
                 }
               },
               example: %{
                 user: %{
                   name: "John",
                   email: "john@example.com"
                 }
               }
             } == swagger_schema
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

      assert %{
               type: :object,
               required: [:tags],
               properties: %{
                 tags: %{
                   type: :array,
                   items: %{type: :string},
                   example: ["tag1", "tag2"]
                 }
               },
               example: %{
                 tags: ["tag1", "tag2"]
               }
             } == swagger_schema
    end

    test "handles enums" do
      schema =
        Zoi.map(%{
          status: Zoi.enum(["active", "inactive"], example: "active")
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert %{
               type: :object,
               required: [:status],
               properties: %{
                 status: %{
                   type: :string,
                   enum: ["active", "inactive"],
                   example: "active"
                 }
               },
               example: %{
                 status: "active"
               }
             } == swagger_schema
    end

    test "handles datetime format" do
      schema =
        Zoi.map(%{
          created_at: Zoi.datetime()
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert %{
               type: :object,
               required: [:created_at],
               properties: %{
                 created_at: %{
                   type: :string,
                   format: :"date-time"
                 }
               }
             } == swagger_schema
    end

    test "handles default values" do
      schema =
        Zoi.map(%{
          direction: Zoi.enum(["asc", "desc"]) |> Zoi.default("asc")
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert %{
               type: :object,
               required: [],
               properties: %{
                 direction: %{
                   type: :string,
                   enum: ["asc", "desc"],
                   default: "asc"
                 }
               },
               example: %{
                 direction: "asc"
               }
             } == swagger_schema
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

      assert %{
               type: :object,
               required: [:name, :email, :tags],
               properties: %{
                 name: %{
                   type: :string,
                   description: "User name",
                   example: "John Doe"
                 },
                 email: %{
                   type: :string,
                   description: "Email",
                   example: "john@example.com"
                 },
                 age: %{
                   type: :integer,
                   example: 30
                 },
                 preferences: %{
                   type: :object,
                   required: [:newsletter, :theme],
                   properties: %{
                     newsletter: %{
                       type: :boolean,
                       example: true
                     },
                     theme: %{
                       type: :string,
                       enum: ["light", "dark"],
                       example: "dark"
                     }
                   }
                 },
                 tags: %{
                   type: :array,
                   items: %{type: :string},
                   example: ["developer", "elixir"]
                 }
               },
               example: %{
                 name: "John Doe",
                 email: "john@example.com",
                 age: 30,
                 preferences: %{
                   newsletter: true,
                   theme: "dark"
                 },
                 tags: ["developer", "elixir"]
               }
             } == swagger_schema
    end

    test "handles float type" do
      schema =
        Zoi.map(%{
          price: Zoi.float(description: "Price", example: 19.99)
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert %{
               type: :object,
               required: [:price],
               properties: %{
                 price: %{
                   type: :number,
                   description: "Price",
                   example: 19.99
                 }
               },
               example: %{
                 price: 19.99
               }
             } == swagger_schema
    end

    test "handles boolean type" do
      schema =
        Zoi.map(%{
          active: Zoi.boolean(description: "Active status", example: true)
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert %{
               type: :object,
               required: [:active],
               properties: %{
                 active: %{
                   type: :boolean,
                   description: "Active status",
                   example: true
                 }
               },
               example: %{
                 active: true
               }
             } == swagger_schema
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

      assert %{
               type: :object,
               required: [:organization],
               properties: %{
                 organization: %{
                   type: :object,
                   required: [:name, :address],
                   properties: %{
                     name: %{type: :string, example: "Acme Corp"},
                     address: %{
                       type: :object,
                       required: [:street, :city, :country],
                       properties: %{
                         street: %{type: :string, example: "123 Main St"},
                         city: %{type: :string, example: "Springfield"},
                         country: %{
                           type: :object,
                           required: [:code, :name],
                           properties: %{
                             code: %{type: :string, example: "US"},
                             name: %{type: :string, example: "United States"}
                           }
                         }
                       }
                     }
                   }
                 }
               },
               example: %{
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
             } == swagger_schema
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

      assert %{
               type: :object,
               required: [:users],
               properties: %{
                 users: %{
                   type: :array,
                   items: %{
                     type: :object,
                     required: [:name, :email],
                     properties: %{
                       name: %{type: :string, example: "John"},
                       email: %{type: :string, example: "john@example.com"}
                     }
                   },
                   example: [%{name: "John", email: "john@example.com"}]
                 }
               },
               example: %{
                 users: [%{name: "John", email: "john@example.com"}]
               }
             } == swagger_schema
    end

    test "handles schema without examples" do
      schema =
        Zoi.map(%{
          name: Zoi.string(),
          age: Zoi.integer()
        })

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert %{
               type: :object,
               required: [:name, :age],
               properties: %{
                 name: %{type: :string},
                 age: %{type: :integer}
               }
             } == swagger_schema
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

      assert %{
               type: :object,
               required: [:user],
               properties: %{
                 user: %{
                   type: :object,
                   required: [:name, :email],
                   properties: %{
                     name: %{type: :string, example: "John"},
                     email: %{type: :string}
                   }
                 }
               },
               example: %{
                 user: %{
                   name: "John"
                 }
               }
             } == swagger_schema
    end

    test "handles empty map schema" do
      schema = Zoi.map(%{})

      swagger_schema = ZoiPhoenixSwagger.schema_definition(schema)

      assert %{
               type: :object,
               required: [],
               properties: %{}
             } == swagger_schema
    end
  end
end
