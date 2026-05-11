defmodule ZoiPhoenixSwagger do
  @moduledoc """
  Integration between Zoi schema validation and Phoenix Swagger documentation.

  Converts Zoi schemas into Phoenix Swagger parameter definitions.
  """

  alias PhoenixSwagger.Path
  alias PhoenixSwagger.Path.PathObject
  alias PhoenixSwagger.Schema

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

  @doc """
  Converts a Zoi schema to a Phoenix Swagger schema definition.

  Returns a JSON map (with string keys) suitable for use in swagger_definitions/0,
  matching the output format of the `swagger_schema` macro.

  ## Example

      def swagger_definitions do
        %{
          CreateUserRequest: ZoiPhoenixSwagger.schema_definition(@create_user_schema),
          UpdateUserRequest: ZoiPhoenixSwagger.schema_definition(@update_user_schema)
        }
      end

  The schema name is specified as the map key, allowing for clean, readable definitions.
  """
  @spec schema_definition(Zoi.schema()) :: map()
  def schema_definition(zoi_schema) do
    json_schema = Zoi.to_json_schema(zoi_schema)
    metadata_map = extract_metadata(zoi_schema)
    json_schema = filter_doc_fields(json_schema, metadata_map, [])

    %Schema{type: :object}
    |> add_properties(json_schema[:properties] || %{})
    |> add_required(json_schema[:required] || [])
    |> maybe_add_schema_example(json_schema)
    |> PhoenixSwagger.to_json()
  end

  defp build_params(properties, required, path, metadata_map, path_object) do
    Enum.reduce(properties, path_object, fn {key, prop_schema}, acc ->
      if doc_hidden?(metadata_map, path ++ [key]) do
        acc
      else
        build_param(key, prop_schema, required, path, metadata_map, acc)
      end
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
    required? = location == :path or (key in required and not Map.has_key?(prop_schema, :default))

    opts = [required: required?]
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

  # Check if a field should be hidden from documentation
  defp doc_hidden?(metadata_map, path) do
    case Map.get(metadata_map, path) do
      nil -> false
      metadata -> Keyword.get(metadata, :doc) == false
    end
  end

  # Recursively remove fields with doc: false from JSON schema
  defp filter_doc_fields(%{properties: properties} = json_schema, metadata_map, path)
       when is_map(properties) and map_size(properties) > 0 do
    hidden_keys =
      for {key, _} <- properties,
          doc_hidden?(metadata_map, path ++ [key]),
          into: MapSet.new(),
          do: key

    if MapSet.size(hidden_keys) == 0 do
      filter_nested_doc_fields(json_schema, metadata_map, path)
    else
      filtered_properties =
        for {key, prop} <- properties,
            not MapSet.member?(hidden_keys, key),
            into: %{} do
          prop =
            if match?(%{type: :object, properties: _}, prop),
              do: filter_doc_fields(prop, metadata_map, path ++ [key]),
              else: prop

          {key, prop}
        end

      json_schema
      |> Map.put(:properties, filtered_properties)
      |> filter_required(hidden_keys)
    end
  end

  defp filter_doc_fields(json_schema, _metadata_map, _path), do: json_schema

  # Recurse into nested objects even when no fields are hidden at this level
  defp filter_nested_doc_fields(%{properties: properties} = json_schema, metadata_map, path) do
    filtered_properties =
      for {key, prop} <- properties, into: %{} do
        prop =
          if match?(%{type: :object, properties: _}, prop),
            do: filter_doc_fields(prop, metadata_map, path ++ [key]),
            else: prop

        {key, prop}
      end

    Map.put(json_schema, :properties, filtered_properties)
  end

  defp filter_required(%{required: required} = schema, hidden_keys) do
    Map.put(schema, :required, Enum.reject(required, &MapSet.member?(hidden_keys, &1)))
  end

  defp filter_required(schema, _hidden_keys), do: schema

  # Schema definition helper functions

  # Add properties to schema
  defp add_properties(schema, json_properties) when map_size(json_properties) == 0 do
    schema
  end

  defp add_properties(schema, json_properties) do
    properties =
      Map.new(json_properties, fn {key, prop_schema} ->
        {key, convert_to_schema(prop_schema)}
      end)

    %{schema | properties: properties}
  end

  # Add required fields to schema (sorted for consistency)
  defp add_required(schema, []), do: schema
  defp add_required(schema, required), do: %{schema | required: Enum.sort(required)}

  # Convert a single property to Schema struct - nested object
  defp convert_to_schema(%{type: :object, properties: nested_props} = prop_schema) do
    nested_required = prop_schema[:required] || []

    %Schema{type: :object}
    |> add_properties(nested_props)
    |> add_required(nested_required)
    |> maybe_add_schema_field(:description, prop_schema[:description])
    |> maybe_add_schema_field(:example, prop_schema[:example])
  end

  # Convert a single property to Schema struct - array type
  defp convert_to_schema(%{type: :array} = prop_schema) do
    items_schema = convert_to_schema(prop_schema[:items] || %{type: :string})

    %Schema{type: :array, items: items_schema}
    |> maybe_add_schema_field(:description, prop_schema[:description])
    |> maybe_add_schema_field(:example, prop_schema[:example])
  end

  # Convert a single property to Schema struct - primitive type
  defp convert_to_schema(prop_schema) do
    %Schema{type: prop_schema[:type]}
    |> maybe_add_schema_field(:description, prop_schema[:description])
    |> maybe_add_schema_field(:enum, prop_schema[:enum])
    |> maybe_add_schema_field(:format, prop_schema[:format])
    |> maybe_add_schema_field(:default, prop_schema[:default])
    |> maybe_add_schema_field(:example, prop_schema[:example])
  end

  defp maybe_add_schema_field(schema, _key, nil), do: schema
  defp maybe_add_schema_field(schema, key, value), do: Map.put(schema, key, value)

  # Generate top-level example from schema
  defp maybe_add_schema_example(swagger_schema, json_schema) do
    case generate_example(json_schema) do
      nil -> swagger_schema
      example -> %{swagger_schema | example: example}
    end
  end

  defp generate_example(%{properties: properties}) when is_map(properties) do
    example =
      properties
      |> Enum.map(fn {key, prop_schema} ->
        case generate_property_example(prop_schema) do
          nil -> nil
          value -> {key, value}
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Map.new()

    if map_size(example) > 0, do: example, else: nil
  end

  defp generate_example(_), do: nil

  defp generate_property_example(%{example: example}), do: example

  defp generate_property_example(%{type: :object, properties: nested_props}) do
    generate_example(%{properties: nested_props})
  end

  defp generate_property_example(%{type: :array, items: items}) do
    case generate_property_example(items) do
      nil -> nil
      item_example -> [item_example]
    end
  end

  defp generate_property_example(%{default: default}), do: default
  defp generate_property_example(_), do: nil
end
