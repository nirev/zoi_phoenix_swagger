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
    metadata_map = extract_metadata(zoi_schema)

    build_params(
      json_schema[:properties] || %{},
      json_schema[:required] || [],
      [],
      metadata_map,
      path_object
    )
  end

  defp build_params(properties, required, path, metadata_map, path_object) do
    Enum.reduce(properties, path_object, fn {key, prop_schema}, acc ->
      build_param(key, prop_schema, required, path, metadata_map, acc)
    end)
  end

  defp build_param(
         key,
         %{type: :object, properties: nested_props} = prop_schema,
         _required,
         path,
         metadata_map,
         path_object
       ) do
    nested_required = prop_schema[:required] || []
    build_params(nested_props, nested_required, path ++ [key], metadata_map, path_object)
  end

  defp build_param(key, prop_schema, required, path, metadata_map, path_object) do
    full_path = path ++ [key]
    location = get_location(metadata_map, full_path)
    name = build_param_name(path, key, location)
    type = prop_schema[:type]
    description = prop_schema[:description] || ""
    is_required = location == :path or key in required

    opts = [required: is_required]
    opts = maybe_add_opt(opts, :enum, prop_schema[:enum])
    opts = maybe_add_opt(opts, :format, prop_schema[:format])
    opts = maybe_add_opt(opts, :default, prop_schema[:default])
    opts = maybe_add_opt(opts, :items, prop_schema[:items])
    opts = maybe_add_opt(opts, :example, prop_schema[:example])

    Path.parameter(path_object, name, location, type, description, opts)
  end

  # Extract metadata from Zoi schema into a map keyed by path
  defp extract_metadata(zoi_schema), do: extract_metadata(zoi_schema, [], %{})

  defp extract_metadata(%Zoi.Types.Map{fields: fields}, path, acc) do
    Enum.reduce(fields, acc, fn {key, field_schema}, acc ->
      extract_metadata(field_schema, path ++ [key], acc)
    end)
  end

  defp extract_metadata(%{meta: meta} = schema, path, acc) do
    # Handle wrapper types (Optional, Default, etc.) by checking for inner
    acc =
      if meta && meta.metadata && meta.metadata != [] do
        Map.put(acc, path, meta.metadata)
      else
        acc
      end

    # Recurse into inner if present (for Optional, Default, etc.)
    case Map.get(schema, :inner) do
      nil -> acc
      inner -> extract_metadata(inner, path, acc)
    end
  end

  defp extract_metadata(_, _path, acc), do: acc

  defp get_location(metadata_map, path) do
    case Map.get(metadata_map, path) do
      nil -> :query
      metadata -> Keyword.get(metadata, :in, :query)
    end
  end

  # Path params use flat name (no brackets) to match URL template
  defp build_param_name(_path, key, :path), do: to_string(key)
  defp build_param_name([], key, _location), do: to_string(key)

  defp build_param_name(path, key, _location) do
    base = path |> List.first() |> to_string()
    rest = (tl(path) ++ [key]) |> Enum.map(&"[#{&1}]") |> Enum.join()
    base <> rest
  end

  defp maybe_add_opt(opts, _key, nil), do: opts
  defp maybe_add_opt(opts, key, value), do: Keyword.put(opts, key, value)
end
