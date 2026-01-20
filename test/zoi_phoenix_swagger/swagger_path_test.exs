defmodule ZoiPhoenixSwagger.SwaggerPathTest do
  use ExUnit.Case, async: true
  use PhoenixSwagger

  # Plain PhoenixSwagger version
  swagger_path :index_phoenix do
    get("/api/categories/{category_id}/items")
    summary("List items")
    produces("application/json")

    parameters do
      category_id(:path, :string, "", required: true)
      order_by(:query, :string, "", enum: ["inserted_at", "status"])

      order_by_direction(:query, :string, "",
        required: true,
        enum: ["asc", "desc"],
        default: "asc"
      )
    end

    parameter("filter[status]", :query, :string, "", enum: ["pending", "approved", "rejected"])
    parameter("filter[inserted_at_from]", :query, :string, "", format: :"date-time")

    response(200, "Success", Schema.ref(:IndexResponse))
  end

  # ZoiPhoenixSwagger version

  @index_params Zoi.map(%{
                  filter:
                    Zoi.map(%{
                      category_id: Zoi.string(metadata: [in: :path]),
                      status: Zoi.enum(["pending", "approved", "rejected"]) |> Zoi.optional(),
                      inserted_at_from: Zoi.datetime() |> Zoi.optional()
                    }),
                  order_by: Zoi.enum(["inserted_at", "status"]) |> Zoi.optional(),
                  order_by_direction: Zoi.enum(["asc", "desc"]) |> Zoi.default("asc")
                })

  swagger_path :index_zoi do
    get("/api/categories/{category_id}/items")
    summary("List items")
    produces("application/json")

    ZoiPhoenixSwagger.parameters(@index_params)

    response(200, "Success", Schema.ref(:IndexResponse))
  end

  defp normalize_swagger(swagger) do
    # Helper to normalize swagger output for comparison
    # Sorts parameters by name and removes operationId (which differs by function name)
    # swagger is %{"/path" => %{"verb" => %{...operation...}}}
    Map.new(swagger, fn {path, verbs} ->
      normalized_verbs =
        Map.new(verbs, fn {verb, operation} ->
          normalized_operation =
            operation
            |> Map.delete("operationId")
            |> Map.update!("parameters", &Enum.sort_by(&1, fn p -> p["name"] end))

          {verb, normalized_operation}
        end)

      {path, normalized_verbs}
    end)
  end

  describe "swagger_path equivalence" do
    test "ZoiPhoenixSwagger produces same structure as plain PhoenixSwagger" do
      route = %{verb: "get", path: "/api/categories/{category_id}/items"}

      phoenix_result = swagger_path_index_phoenix(route) |> normalize_swagger()
      zoi_result = swagger_path_index_zoi(route) |> normalize_swagger()

      assert phoenix_result == zoi_result
    end
  end
end
