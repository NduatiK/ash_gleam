# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Codegen.Renderer do
  @moduledoc false

  @spec render(map(), Keyword.t()) :: %{
          gleam: [%{path: String.t(), contents: String.t()}],
          elixir: [%{path: String.t(), contents: String.t()}]
        }
  def render(manifest, opts \\ []) do
    prefix = AshGleam.Info.gleam_module_prefix(opts)

    resource_modules =
      Enum.flat_map(manifest.resources, fn {_name, resource} ->
        render_resource_files(resource, prefix)
      end)

    ffi_modules =
      Enum.flat_map(manifest.domains, fn {_name, domain} ->
        Enum.map(
          domain.ffi,
          &%{
            path: "#{Atom.to_string(&1.ffi_name)}.gleam",
            contents: render_ffi(domain.module, manifest.resources[&1.resource], &1, prefix)
          }
        )
      end)

    elixir =
      Enum.map(manifest.domains, fn {_name, domain} ->
        %{
          path: elixir_bridge_path(domain.module),
          contents: render_elixir_bridge(domain, manifest.resources)
        }
      end)

    %{gleam: resource_modules ++ ffi_modules, elixir: elixir}
  end

  defp render_resource_files(resource, prefix) do
    atom_modules =
      resource.fields
      |> atom_type_definitions()
      |> Enum.map(fn %{module_name: module_name, definition: definition} ->
        %{
          path: "#{module_name}.gleam",
          contents: render_atom_type_module(resource, prefix, definition)
        }
      end)

    atom_modules ++
      [%{path: "#{resource.module_name}.gleam", contents: render_resource(resource, prefix)}]
  end

  defp render_atom_type_module(resource, prefix, %{name: type_name, variants: variants}) do
    resource_import = ""
    # "import #{prefix}/#{resource.module_name}.{type #{resource.gleam_type}}"

    """
    #{resource_import}

    pub type #{type_name} {
    #{Enum.map_join(variants, "\n", fn variant -> "  #{variant}" end)}
    }
    """
  end

  # Collect import lines for any fields whose type references another resource module.
  # `exclude_module` is the resource module for the file being rendered (to avoid self-import).
  defp resource_imports(fields, prefix, exclude_module) do
    fields
    |> Enum.flat_map(&field_resource_modules/1)
    |> Enum.uniq()
    |> Enum.reject(&(&1 == exclude_module))
    |> Enum.map_join("\n", fn mod ->
      type_name = AshGleam.Resource.Info.gleam_type_name!(mod)
      module_name = AshGleam.Resource.Info.gleam_module_name(mod)
      "import #{prefix}/#{module_name}.{type #{type_name}}"
    end)
    |> case do
      "" -> ""
      imports -> imports <> "\n"
    end
  end

  defp atom_type_imports(resource, fields, prefix) do
    fields
    |> atom_type_definitions()
    |> Enum.map_join("\n", fn %{module_name: module_name, name: type_name} ->
      "import #{prefix}/#{module_name}.{type #{type_name}}"
    end)
    |> case do
      "" -> ""
      imports -> imports <> "\n"
    end
  end

  defp atom_type_definitions(fields) do
    fields
    |> Enum.flat_map(&field_atom_type_definition/1)
    |> Enum.uniq_by(& &1.module_name)
  end

  defp field_atom_type_definition(
         %{name: field_name, type: type, constraints: constraints} = attribute
       )
       when type in [:atom, Ash.Type.Atom, {:array, :atom}, {:array, Ash.Type.Atom}] do
    do_x = fn values ->
      type_name = Macro.camelize(to_string(field_name))
      module_name = "#{Macro.underscore(type_name)}"

      variants =
        values
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&atom_variant!/1)

      [
        %{
          name: type_name,
          module_name: module_name,
          definition: %{name: type_name, variants: variants}
        }
      ]
    end

    array_values =
      try do
        Keyword.get(constraints, :items)
        |> Keyword.get(:one_of)
      rescue
        _ -> nil
      end

    values = Keyword.get(constraints, :one_of)

    cond do
      is_list(array_values) and array_values != [] ->
        do_x.(array_values)

      is_list(values) and values != [] ->
        do_x.(values)

      true ->
        []
    end
  end

  defp field_atom_type_definition(_field) do
    []
  end

  defp atom_enum_values({:atom_enum, values}), do: values
  defp atom_enum_values({:array, inner}), do: atom_enum_values(inner)
  defp atom_enum_values(_), do: nil

  defp atom_variant!(value) when is_atom(value), do: value |> Atom.to_string() |> Macro.camelize()

  # Returns the resource module(s) referenced by a field's type.
  defp field_resource_modules(%{type: type, constraints: constraints}) do
    case AshGleam.TypeMapper.normalize(type, constraints) do
      {:ok, {:resource, mod}} -> [mod]
      {:ok, {:array, {:resource, mod}}} -> [mod]
      _ -> []
    end
  end

  defp render_resource(resource, prefix) do
    imports = resource_imports(resource.fields, prefix, resource.module)
    atom_imports = atom_type_imports(resource, resource.fields, prefix)

    fields =
      Enum.map_join(resource.fields, ",\n", fn field ->
        "    #{field.name}: #{gleam_type!(field, field.allow_nil?)}"
      end)

    sort_helpers =
      Enum.map_join(resource.fields, "\n\n", fn field ->
        base = Macro.camelize(to_string(field.name))
        field_name = to_string(field.name)

        """
        pub fn #{field_name}_asc() -> #{resource.gleam_type}Sort {
          #{base}(Asc)
        }

        pub fn #{field_name}_desc() -> #{resource.gleam_type}Sort {
          #{base}(Desc)
        }
        """
      end)

    sorts =
      Enum.map_join(resource.fields, "\n", fn field ->
        base = Macro.camelize(to_string(field.name))
        "  #{base}(Sorter)"
      end)

    filter_helpers =
      Enum.map_join(resource.fields, "\n\n", fn field ->
        variant = "#{Macro.camelize(to_string(field.name))}Eq"
        field_name = to_string(field.name)

        """
        pub fn #{field_name}_eq(value: #{gleam_type!(field, false)}) -> #{resource.gleam_type}Filter {
          #{variant}(value)
        }
        """
      end)

    filters =
      Enum.map_join(resource.fields, "\n", fn field ->
        "  #{Macro.camelize(to_string(field.name))}Eq(#{gleam_type!(field, false)})"
      end)

    """
    import gleam/option.{type Option}
    #{imports}#{atom_imports}pub type #{resource.gleam_type} {
      #{resource.gleam_type}(
    #{fields}
      )
    }

    pub type Sorter {
      Asc
      Desc
    }

    pub type #{resource.gleam_type}Sort {
    #{sorts}
    }

    #{sort_helpers}

    pub type #{resource.gleam_type}Filter {
    #{filters}
    }

    #{filter_helpers}
    """
  end

  defp render_ffi(domain_module, resource, ffi, prefix) do
    action_module = Macro.camelize(Atom.to_string(ffi.ffi_name))
    resource_type = resource.gleam_type
    resource_module = resource.module_name
    resource_import = "#{prefix}/#{resource_module}"

    case ffi.kind do
      :create ->
        create_fields =
          Enum.filter(resource.fields, fn field ->
            not field.primary_key? and field.writable? and not field.generated?
          end)

        extra_imports = resource_imports(create_fields, prefix, resource.module)
        atom_imports = atom_type_imports(resource, create_fields, prefix)

        fields =
          Enum.map_join(create_fields, ",\n", fn field ->
            "    #{field.name}: #{gleam_type!(field, field.allow_nil?)}"
          end)

        args =
          Enum.map_join(create_fields, ", ", fn field ->
            "#{field.name}: #{gleam_type!(field, field.allow_nil?)}"
          end)

        constructor =
          Enum.map_join(create_fields, ", ", fn field -> field.name end)

        """
        import #{resource_import}.{type #{resource_type}}
        #{extra_imports}#{atom_imports}pub type #{action_module} {
          #{action_module}(
        #{fields}
          )
        }

        pub fn new(#{args}) -> #{action_module} {
          #{action_module}(#{constructor})
        }

        @external(erlang, "Elixir.#{inspect(domain_module)}.Generated", "#{ffi.ffi_name}")
        pub fn run(builder: #{action_module}) -> Result(#{resource_type}, String)
        """

      :get ->
        atom_imports = atom_type_imports(resource, ffi.arguments, prefix)

        args =
          Enum.map_join(ffi.arguments, ", ", fn argument ->
            "#{argument.name}: #{gleam_type!(argument, argument.allow_nil?)}"
          end)

        type_fields =
          Enum.map_join(ffi.arguments, ", ", fn argument ->
            "#{argument.name}: #{gleam_type!(argument, argument.allow_nil?)}"
          end)

        constructor =
          Enum.map_join(ffi.arguments, ", ", fn argument ->
            argument.name
          end)

        type_definition =
          if ffi.arguments == [] do
            "#{action_module}"
          else
            "#{action_module}(#{type_fields})"
          end

        constructor_call =
          if ffi.arguments == [] do
            action_module
          else
            "#{action_module}(#{constructor})"
          end

        """
        import #{resource_import}.{type #{resource_type}}
        #{atom_imports}
        pub type #{action_module} {
          #{type_definition}
        }

        pub fn new(#{args}) -> #{action_module} {
          #{constructor_call}
        }

        @external(erlang, "Elixir.#{inspect(domain_module)}.Generated", "#{ffi.ffi_name}")
        pub fn run(builder: #{action_module}) -> Result(#{resource_type}, String)
        """

      :destroy ->
        """
        import #{resource_import}.{type #{resource_type}}

        pub type #{action_module} {
          #{action_module}(record: #{resource_type})
        }

        pub fn new(record: #{resource_type}) -> #{action_module} {
          #{action_module}(record)
        }

        @external(erlang, "Elixir.#{inspect(domain_module)}.Generated", "#{ffi.ffi_name}")
        pub fn run(builder: #{action_module}) -> Result(Bool, String)
        """

      _ ->
        """
        import gleam/option.{None, type Option}
        import #{resource_import}.{type #{resource_type}, type #{resource_type}Filter, type #{resource_type}Sort}

        pub type #{action_module} {
          #{action_module}(
            filter: List(#{resource_type}Filter),
            sort: List(#{resource_type}Sort),
            limit: Option(Int),
          )
        }

        pub fn new() -> #{action_module} {
          #{action_module}([], [], None)
        }

        pub fn filter(builder: #{action_module}, filters: List(#{resource_type}Filter)) -> #{action_module} {
          let #{action_module}(_, sort, limit) = builder
          #{action_module}(filters, sort, limit)
        }

        pub fn sort(builder: #{action_module}, sorts: List(#{resource_type}Sort)) -> #{action_module} {
          let #{action_module}(filter, _, limit) = builder
          #{action_module}(filter, sorts, limit)
        }

        pub fn limit(builder: #{action_module}, limit: Option(Int)) -> #{action_module} {
          let #{action_module}(filter, sort, _) = builder
          #{action_module}(filter, sort, limit)
        }

        @external(erlang, "Elixir.#{inspect(domain_module)}.Generated", "#{ffi.ffi_name}")
        pub fn run(builder: #{action_module}) -> Result(List(#{resource_type}), String)
        """
    end
  end

  defp render_elixir_bridge(domain, resources) do
    actions =
      Enum.map_join(domain.ffi, "\n\n", fn ffi ->
        render_bridge_function(domain.module, resources[ffi.resource], ffi)
      end)

    """
    defmodule #{inspect(domain.module)}.Generated do
      @moduledoc false

      alias Ash.Query

    #{actions}
    end
    """
  end

  defp render_bridge_function(domain_module, resource, ffi) do
    case ffi.kind do
      :create ->
        create_field_names =
          resource.fields
          |> Enum.filter(fn field ->
            not field.primary_key? and field.writable? and not field.generated?
          end)
          |> Enum.map(& &1.name)

        """
          def #{ffi.ffi_name}(builder) do
            params =
              AshGleam.Generated.Bridge.decode_create(
                builder,
                #{inspect(resource.module)},
                #{inspect(create_field_names)}
              )

            #{inspect(resource.module)}
            |> Ash.Changeset.for_create(#{inspect(ffi.action)}, params, domain: #{inspect(domain_module)})
            |> Ash.create(domain: #{inspect(domain_module)})
            |> AshGleam.Generated.Bridge.encode_result(&AshGleam.Marshal.to_gleam(#{inspect(resource.module)}, &1))
          end
        """

      :get ->
        """
          def #{ffi.ffi_name}(builder) do
            params = AshGleam.Generated.Bridge.decode_action(builder, #{inspect(ffi.arguments)})

            #{inspect(resource.module)}
            |> Query.for_read(#{inspect(ffi.action)}, params, domain: #{inspect(domain_module)})
            |> Ash.read_one(domain: #{inspect(domain_module)})
            |> AshGleam.Generated.Bridge.encode_result(&AshGleam.Marshal.to_gleam(#{inspect(resource.module)}, &1))
          end
        """

      :destroy ->
        """
          def #{ffi.ffi_name}(builder) do
            %{record: record} =
              AshGleam.Generated.Bridge.decode_action(
                builder,
                [%{name: :record, type: #{inspect(resource.module)}, allow_nil?: false}]
              )

            record
            |> Ash.Changeset.for_destroy(#{inspect(ffi.action)}, %{}, domain: #{inspect(domain_module)})
            |> Ash.destroy(domain: #{inspect(domain_module)})
            |> AshGleam.Generated.Bridge.encode_result(fn
              :ok -> true
              _ -> true
            end)
          end
        """

      _ ->
        """
          def #{ffi.ffi_name}(builder) do
            query =
              #{inspect(resource.module)}
              |> Query.for_read(#{inspect(ffi.action)}, %{}, domain: #{inspect(domain_module)})
              |> AshGleam.Generated.Bridge.apply_read_builder(#{inspect(resource.module)}, builder)

            query
            |> Ash.read(domain: #{inspect(domain_module)})
            |> AshGleam.Generated.Bridge.encode_result(fn records ->
              Enum.map(records, &AshGleam.Marshal.to_gleam(#{inspect(resource.module)}, &1))
            end)
          end
        """
    end
  end

  defp elixir_bridge_path(domain_module) do
    domain_module
    |> Module.split()
    |> Enum.map(&Macro.underscore/1)
    |> Path.join()
    |> Kernel.<>("/generated.ex")
  end

  defp gleam_type!(%{name: field_name, type: type, constraints: constraints}, allow_nil?)
       when type in [:atom, Ash.Type.Atom] do
    type_name =
      case Keyword.get(constraints, :one_of) do
        values when is_list(values) and values != [] -> Macro.camelize(to_string(field_name))
        _ -> raise ArgumentError, "atom fields require a one_of constraint"
      end

    if allow_nil? do
      "Option(#{type_name})"
    else
      type_name
    end
  end

  defp gleam_type!(%{name: field_name, type: type, constraints: constraints}, allow_nil?) do
    {:ok, type_name} =
      AshGleam.TypeMapper.gleam_type(type,
        allow_nil?: allow_nil?,
        constraints: constraints,
        name: field_name
      )

    type_name
  end

  defp gleam_type!(%{name: field_name, type: type}, allow_nil?) do
    {:ok, type_name} =
      AshGleam.TypeMapper.gleam_type(type,
        allow_nil?: allow_nil?,
        constraints: [],
        name: field_name
      )

    type_name
  end

  defp gleam_type!(type, allow_nil?) do
    {:ok, type_name} =
      AshGleam.TypeMapper.gleam_type(type, allow_nil?: allow_nil?, constraints: [])

    type_name
  end
end
