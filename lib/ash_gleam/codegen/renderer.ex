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

    reusable_type_modules =
      Enum.map(manifest.reusable_types, fn {_name, reusable_type} ->
        %{
          path: "#{reusable_type.module_name}.gleam",
          contents: render_reusable_type_module(reusable_type, manifest.reusable_types, prefix)
        }
      end)

    resource_modules =
      Enum.flat_map(manifest.resources, fn {_name, resource} ->
        render_resource_files(resource, manifest.reusable_types, prefix)
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

    context_module = [%{path: "ash_gleam/context.gleam", contents: render_context_module()}]

    %{
      gleam: context_module ++ reusable_type_modules ++ resource_modules ++ ffi_modules,
      elixir: elixir
    }
  end

  defp render_context_module do
    """
    pub type Context
    """
  end

  defp render_resource_files(resource, reusable_types, prefix) do
    atom_modules =
      resource.fields
      |> inline_atom_type_definitions()
      |> Enum.map(fn %{module_name: module_name, definition: definition} ->
        %{
          path: "#{module_name}.gleam",
          contents: render_atom_type_module(resource, prefix, definition)
        }
      end)

    atom_modules ++
      [
        %{
          path: "#{resource.module_name}.gleam",
          contents: render_resource(resource, reusable_types, prefix)
        }
      ]
  end

  defp render_atom_type_module(_resource, _prefix, %{name: type_name, variants: variants}) do
    """
    pub type #{type_name} {
    #{Enum.map_join(variants, "\n", fn variant -> "  #{variant}" end)}
    }
    """
  end

  defp render_reusable_type_module(
         %{kind: :enum, gleam_type: type_name, variants: variants},
         _reusable_types,
         _prefix
       ) do
    render_atom_type_module(nil, nil, %{
      name: type_name,
      variants: Enum.map(variants, &atom_variant!(&1.name))
    })
  end

  defp render_reusable_type_module(%{kind: :union} = reusable_type, reusable_types, prefix) do
    imports =
      reusable_type.variants
      |> Enum.flat_map(fn variant ->
        Enum.flat_map(variant.fields, &direct_resource_modules(&1.type, &1.constraints))
      end)
      |> Enum.uniq()
      |> Enum.map_join("\n", fn mod ->
        type_name = AshGleam.Resource.Info.gleam_type_name!(mod)
        module_name = AshGleam.Resource.Info.gleam_module_name(mod)
        "import #{prefix}/#{module_name}.{type #{type_name}}"
      end)

    shared_imports =
      reusable_type.variants
      |> Enum.flat_map(fn variant ->
        Enum.flat_map(variant.fields, &direct_reusable_type_modules(&1.type, &1.constraints))
      end)
      |> Enum.uniq()
      |> Enum.reject(&(&1 == reusable_type.module))
      |> Enum.map_join("\n", fn mod ->
        definition = reusable_types[inspect(mod)]
        "import #{prefix}/#{definition.module_name}.{type #{definition.gleam_type}}"
      end)

    joined_imports = join_imports(imports, shared_imports)

    definitions =
      Enum.map_join(reusable_type.variants, "\n", fn variant ->
        variant_name = atom_variant!(variant.name)

        payload =
          Enum.map_join(variant.fields, ", ", fn field ->
            gleam_type_for_type(field.type, field.constraints, field.allow_nil?, field.name)
          end)

        case variant.fields do
          [] ->
            "  #{variant_name}"

          _ ->
            "  #{variant_name}(#{payload})"
        end
      end)

    """
    #{if(String.contains?(definitions, "Option("), do: "import gleam/option.{type Option}", else: "")}
    #{joined_imports}pub type #{reusable_type.gleam_type} {
    #{definitions}
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

  defp atom_type_imports(_resource, fields, prefix) do
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

  defp inline_atom_type_definitions(fields) do
    fields
    |> Enum.flat_map(&field_inline_atom_type_definition/1)
    |> Enum.uniq_by(& &1.module_name)
  end

  defp field_atom_type_definition(%{name: field_name, type: type} = field) do
    constraints = Map.get(field, :constraints, [])

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

    case AshGleam.TypeMapper.constrained_atom_values(type, constraints) do
      {:ok, values} -> do_x.(values)
      :error -> []
    end
  end

  defp field_inline_atom_type_definition(%{type: type, constraints: constraints} = field) do
    with {:ok, _values} <- AshGleam.TypeMapper.constrained_atom_values(type, constraints),
         :error <- AshGleam.TypeMapper.reusable_type_module(type, constraints) do
      field_atom_type_definition(field)
    else
      _ -> []
    end
  end

  defp field_inline_atom_type_definition(field) do
    field_atom_type_definition(field)
  end

  defp atom_variant!(value) when is_atom(value), do: value |> Atom.to_string() |> Macro.camelize()

  # Returns the resource module(s) referenced by a field's type.
  defp field_resource_modules(%{type: type} = field) do
    constraints = Map.get(field, :constraints, [])
    direct_resource_modules(type, constraints)
  end

  defp render_resource(resource, reusable_types, prefix) do
    imports = resource_imports(resource.fields, prefix, resource.module)
    atom_imports = atom_type_imports(resource, resource.fields, prefix)
    reusable_imports = reusable_type_imports(resource.fields, reusable_types, prefix)

    fields =
      Enum.map_join(resource.fields, ",\n", fn field ->
        "    #{field.name}: #{gleam_type!(field, field.allow_nil?)}"
      end)

    sorts =
      Enum.map_join(resource.fields, "\n", fn field ->
        base = Macro.camelize(to_string(field.name))
        "  #{base}(Sorter)"
      end)

    filters =
      Enum.map_join(resource.fields, "\n", fn field ->
        "  #{Macro.camelize(to_string(field.name))}Eq(#{gleam_type!(field, false)})"
      end)

    """
    #{if(String.contains?(fields, "Option("), do: "import gleam/option.{type Option}", else: "")}
    #{imports}#{atom_imports}#{reusable_imports}pub type #{resource.gleam_type} {
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

    pub type #{resource.gleam_type}Filter {
    #{filters}
    }
    """
  end

  defp render_ffi(domain_module, resource, ffi, prefix) do
    action_module = Macro.camelize(Atom.to_string(ffi.ffi_name))
    resource_type = resource.gleam_type
    resource_module = resource.module_name
    resource_import = "#{prefix}/#{resource_module}"
    context_import = "import #{prefix}/ash_gleam/context.{type Context}"

    case ffi.kind do
      :create ->
        create_fields = AshGleam.Spec.Resource.create_fields(resource)

        extra_imports = resource_imports(create_fields, prefix, resource.module)
        atom_imports = atom_type_imports(resource, create_fields, prefix)
        reusable_imports = reusable_type_imports(create_fields, %{}, prefix)

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
        import gleam/option.{type Option, None}
        import #{resource_import}.{type #{resource_type}}
        #{extra_imports}#{atom_imports}#{reusable_imports}#{context_import}
        pub type #{action_module} {
          #{action_module}(
        #{fields},
            context: Option(Context),
          )
        }

        pub fn new(#{args}) -> #{action_module} {
          #{action_module}(#{constructor}, None)
        }

        pub fn set_context(builder: #{action_module}, ctx: Context) -> #{action_module} {
          #{action_module}(..builder, context: option.Some(ctx))
        }

        @external(erlang, "Elixir.#{inspect(domain_module)}.Generated", "#{ffi.ffi_name}")
        pub fn run(builder: #{action_module}) -> Result(#{resource_type}, String)
        """

      :get ->
        atom_imports = atom_type_imports(resource, ffi.arguments, prefix)
        reusable_imports = reusable_type_imports(ffi.arguments, %{}, prefix)

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

        {type_definition, constructor_call, set_context_body} =
          if ffi.arguments == [] do
            {"#{action_module}(context: Option(Context))", "#{action_module}(context: None)",
             """
             pub fn set_context(_builder: #{action_module}, ctx: Context) -> #{action_module} {
              #{action_module}(context: option.Some(ctx))
             }
             """}
          else
            {"#{action_module}(#{type_fields}, context: Option(Context))",
             "#{action_module}(#{constructor}, None)",
             """
             pub fn set_context(builder: #{action_module}, ctx: Context) -> #{action_module} {
               #{action_module}(..builder, context: option.Some(ctx))
             }
             """}
          end

        """
        import gleam/option.{type Option, None}
        import #{resource_import}.{type #{resource_type}}
        #{atom_imports}#{reusable_imports}#{context_import}

        pub type #{action_module} {
          #{type_definition}
        }

        pub fn new(#{args}) -> #{action_module} {
          #{constructor_call}
        }

        #{set_context_body}

        @external(erlang, "Elixir.#{inspect(domain_module)}.Generated", "#{ffi.ffi_name}")
        pub fn run(builder: #{action_module}) -> Result(#{resource_type}, String)
        """

      :action ->
        atom_imports = atom_type_imports(resource, ffi.arguments, prefix)
        reusable_imports = reusable_type_imports(ffi.arguments, %{}, prefix)

        gleam_return_type = gleam_type_for_type(ffi.returns, [], ffi.allow_nil?, nil)

        args =
          Enum.map_join(ffi.arguments, ", ", fn argument ->
            "#{argument.name}: #{gleam_type!(argument, argument.allow_nil?)}"
          end)

        type_fields =
          Enum.map_join(ffi.arguments, ", ", fn argument ->
            "#{argument.name}: #{gleam_type!(argument, argument.allow_nil?)}"
          end)

        constructor =
          Enum.map_join(ffi.arguments, ", ", fn argument -> argument.name end)

        {type_definition, constructor_call, set_context_body} =
          if ffi.arguments == [] do
            {"#{action_module}(context: Option(Context))", "#{action_module}(context: None)",
             "pub fn set_context(_builder: #{action_module}, ctx: Context) -> #{action_module} {\n  #{action_module}(context: option.Some(ctx))\n}"}
          else
            {"#{action_module}(#{type_fields}, context: Option(Context))",
             "#{action_module}(#{constructor}, None)",
             "pub fn set_context(builder: #{action_module}, ctx: Context) -> #{action_module} {\n  #{action_module}(..builder, context: option.Some(ctx))\n}"}
          end

        """
        import gleam/option.{type Option, None}
        #{atom_imports}#{reusable_imports}#{context_import}

        pub type #{action_module} {
          #{type_definition}
        }

        pub fn new(#{args}) -> #{action_module} {
          #{constructor_call}
        }

        #{set_context_body}

        @external(erlang, "Elixir.#{inspect(domain_module)}.Generated", "#{ffi.ffi_name}")
        pub fn run(builder: #{action_module}) -> Result(#{gleam_return_type}, String)
        """

      :destroy ->
        """
        import gleam/option.{type Option, None}
        import #{resource_import}.{type #{resource_type}}
        #{context_import}

        pub type #{action_module} {
          #{action_module}(record: #{resource_type}, context: Option(Context))
        }

        pub fn new(record: #{resource_type}) -> #{action_module} {
          #{action_module}(record, None)
        }

        pub fn set_context(builder: #{action_module}, ctx: Context) -> #{action_module} {
          #{action_module}(..builder, context: option.Some(ctx))
        }

        @external(erlang, "Elixir.#{inspect(domain_module)}.Generated", "#{ffi.ffi_name}")
        pub fn run(builder: #{action_module}) -> Result(Bool, String)
        """

      _ ->
        """
        import gleam/option.{None, type Option}
        import #{resource_import}.{type #{resource_type}, type #{resource_type}Filter, type #{resource_type}Sort}
        #{context_import}

        pub type #{action_module} {
          #{action_module}(
            filter: List(#{resource_type}Filter),
            sort: List(#{resource_type}Sort),
            limit: Option(Int),
            context: Option(Context),
          )
        }

        pub fn new() -> #{action_module} {
          #{action_module}([], [], None, None)
        }

        pub fn filter(builder: #{action_module}, filters: List(#{resource_type}Filter)) -> #{action_module} {
          #{action_module}(..builder, filter: filters)
        }

        pub fn sort(builder: #{action_module}, sorts: List(#{resource_type}Sort)) -> #{action_module} {
          #{action_module}(..builder, sort: sorts)
        }

        pub fn limit(builder: #{action_module}, limit: Option(Int)) -> #{action_module} {
          #{action_module}(..builder, limit: limit)
        }

        pub fn set_context(builder: #{action_module}, ctx: Context) -> #{action_module} {
          #{action_module}(..builder, context: option.Some(ctx))
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
      |> String.trim()

    """
    defmodule #{inspect(domain.module)}.Generated do
      @moduledoc false

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
            {params, ctx_opts} =
              AshGleam.Generated.Bridge.decode_create(
                builder,
                #{inspect(resource.module)},
                #{inspect(create_field_names)}
              )

            base_opts = [domain: #{inspect(domain_module)}] ++ ctx_opts

            #{inspect(resource.module)}
            |> Ash.Changeset.for_create(#{inspect(ffi.action)}, params, base_opts)
            |> Ash.create(base_opts)
            |> AshGleam.Generated.Bridge.encode_result(&AshGleam.Marshal.to_gleam(#{inspect(resource.module)}, &1))
          end
        """

      :action ->
        """
          def #{ffi.ffi_name}(builder) do
            {params, ctx_opts} = AshGleam.Generated.Bridge.decode_action(builder, #{inspect(ffi.arguments)})

            base_opts = [domain: #{inspect(domain_module)}] ++ ctx_opts

            #{inspect(resource.module)}
            |> Ash.ActionInput.for_action(#{inspect(ffi.action)}, params, base_opts)
            |> Ash.run_action(base_opts)
            |> AshGleam.Generated.Bridge.encode_result(& &1)
          end
        """

      :get ->
        """
          def #{ffi.ffi_name}(builder) do
            {params, ctx_opts} = AshGleam.Generated.Bridge.decode_action(builder, #{inspect(ffi.arguments)})

            base_opts = [domain: #{inspect(domain_module)}] ++ ctx_opts

            #{inspect(resource.module)}
            |> Ash.Query.for_read(#{inspect(ffi.action)}, params, base_opts)
            |> Ash.read_one(base_opts)
            |> AshGleam.Generated.Bridge.encode_result(&AshGleam.Marshal.to_gleam(#{inspect(resource.module)}, &1))
          end
        """

      :destroy ->
        """
          def #{ffi.ffi_name}(builder) do
            {%{record: record}, ctx_opts} =
              AshGleam.Generated.Bridge.decode_action(
                builder,
                [%{name: :record, type: #{inspect(resource.module)}, allow_nil?: false}]
              )

            base_opts = [domain: #{inspect(domain_module)}] ++ ctx_opts

            record
            |> Ash.Changeset.for_destroy(#{inspect(ffi.action)}, %{}, base_opts)
            |> Ash.destroy(base_opts)
            |> AshGleam.Generated.Bridge.encode_result(fn
              :ok -> true
              _ -> true
            end)
          end
        """

      _ ->
        """
          def #{ffi.ffi_name}(builder) do
            {query, ctx_opts} =
              #{inspect(resource.module)}
              |> Ash.Query.for_read(#{inspect(ffi.action)}, %{}, domain: #{inspect(domain_module)})
              |> AshGleam.Generated.Bridge.apply_read_builder(#{inspect(resource.module)}, builder)

            base_opts = [domain: #{inspect(domain_module)}] ++ ctx_opts

            query
            |> Ash.read(base_opts)
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

  defp gleam_type!(%{name: field_name, type: type, constraints: constraints}, allow_nil?) do
    gleam_type_for_type(type, constraints, allow_nil?, field_name)
  end

  defp gleam_type!(%{name: field_name, type: type}, allow_nil?) do
    gleam_type_for_type(type, [], allow_nil?, field_name)
  end

  defp gleam_type!(type, allow_nil?) do
    gleam_type_for_type(type, [], allow_nil?, nil)
  end

  defp gleam_type_for_type(type, constraints, allow_nil?, name) do
    {:ok, type_name} =
      AshGleam.TypeMapper.gleam_type(type,
        allow_nil?: allow_nil?,
        constraints: constraints,
        name: name
      )

    type_name
  end

  defp reusable_type_imports(fields, reusable_types, prefix) do
    fields
    |> Enum.flat_map(fn field ->
      type = Map.fetch!(field, :type)
      constraints = Map.get(field, :constraints, [])
      direct_reusable_type_modules(type, constraints)
    end)
    |> Enum.uniq()
    |> Enum.map_join("\n", fn mod ->
      definition = reusable_types[inspect(mod)] || reusable_type_definition(mod)
      "import #{prefix}/#{definition.module_name}.{type #{definition.gleam_type}}"
    end)
    |> case do
      "" -> ""
      imports -> imports <> "\n"
    end
  end

  defp reusable_type_definition(mod) do
    {:ok, definition} = AshGleam.ReusableType.definition(mod)
    %{module_name: definition.module_name, gleam_type: definition.gleam_type}
  end

  defp direct_reusable_type_modules({:array, inner}, constraints) do
    item_constraints =
      constraints
      |> Keyword.get(:items, [])
      |> List.wrap()

    direct_reusable_type_modules(inner, item_constraints)
  end

  defp direct_reusable_type_modules(type, constraints) do
    case AshGleam.TypeMapper.reusable_type_module(type, constraints) do
      {:ok, module} -> [module]
      :error -> []
    end
  end

  defp direct_resource_modules({:array, inner}, constraints) do
    item_constraints =
      constraints
      |> Keyword.get(:items, [])
      |> List.wrap()

    direct_resource_modules(inner, item_constraints)
  end

  defp direct_resource_modules(type, constraints) do
    case AshGleam.TypeMapper.normalize(type, constraints) do
      {:ok, {:resource, mod}} -> [mod]
      _ -> []
    end
  end

  defp join_imports(left, right) do
    [left, right]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n")
    |> case do
      "" -> ""
      imports -> imports <> "\n"
    end
  end
end
