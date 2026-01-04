defmodule ZoiPhoenixSwagger do
  @moduledoc """
  Integration between Zoi schema validation and Phoenix Swagger documentation.

  Converts Zoi schemas into Phoenix Swagger parameter definitions.
  """

  alias PhoenixSwagger.Path
  alias PhoenixSwagger.Path.PathObject

  @doc """
  Converts a Zoi schema to Phoenix Swagger parameters.

  Usage in swagger_path block:

      swagger_path :index do
        get("/api/categories/{category_id}")
        ZoiPhoenixSwagger.parameters(@index_params)
      end

  The phoenix_swagger macro automatically injects path_object as first argument.
  """
  @spec parameters(PathObject.t(), Zoi.schema()) :: PathObject.t()
  def parameters(path_object, zoi_schema) do
    json_schema = Zoi.to_json_schema(zoi_schema)

    build_params(
      json_schema[:properties] || %{},
      json_schema[:required] || [],
      [],
      path_object
    )
  end

  defp build_params(properties, required, path, path_object) do
    Enum.reduce(properties, path_object, fn {key, prop_schema}, acc ->
      build_param(key, prop_schema, required, path, acc)
    end)
  end

  defp build_param(
         key,
         %{type: :object, properties: nested_props} = prop_schema,
         _required,
         path,
         path_object
       ) do
    nested_required = prop_schema[:required] || []
    build_params(nested_props, nested_required, path ++ [key], path_object)
  end

  defp build_param(key, prop_schema, required, path, path_object) do
    name = build_param_name(path, key)
    location = :query
    type = prop_schema[:type]
    description = ""
    is_required = key in required

    opts = [required: is_required]
    opts = maybe_add_opt(opts, :enum, prop_schema[:enum])
    opts = maybe_add_opt(opts, :format, prop_schema[:format])
    opts = maybe_add_opt(opts, :default, prop_schema[:default])

    Path.parameter(path_object, name, location, type, description, opts)
  end

  defp build_param_name([], key), do: to_string(key)

  defp build_param_name(path, key) do
    base = path |> List.first() |> to_string()
    rest = (tl(path) ++ [key]) |> Enum.map(&"[#{&1}]") |> Enum.join()
    base <> rest
  end

  defp maybe_add_opt(opts, _key, nil), do: opts
  defp maybe_add_opt(opts, key, value), do: Keyword.put(opts, key, value)
end
