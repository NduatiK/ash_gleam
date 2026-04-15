# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Codegen.Renderer do
  @moduledoc false

  @spec render(map(), Keyword.t()) :: %{
          gleam: [%{path: String.t(), contents: String.t()}],
          elixir: [%{path: String.t(), contents: String.t()}]
        }
  def render(manifest, _opts \\ []) do
    gleam =
      Enum.flat_map(manifest.resources, fn {_name, resource} ->
        [%{path: "#{resource.module_name}.gleam", contents: render_resource(resource)}]
      end) ++
        Enum.flat_map(manifest.domains, fn {_name, domain} ->
          Enum.map(
            domain.ffi,
            &%{
              path: "#{Atom.to_string(&1.ffi_name)}.gleam",
              contents: render_ffi(domain.module, manifest.resources[&1.resource], &1)
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

    %{gleam: gleam, elixir: elixir}
  end

  defp render_resource(resource) do
    fields =
      Enum.map_join(resource.fields, ",\n", fn field ->
        "    #{field.name}: #{gleam_type!(field.type, field.allow_nil?)}"
      end)

    field_helpers =
      Enum.map_join(resource.fields, "\n\n", fn field ->
        field_name = to_string(field.name)

        """
        pub fn #{field_name}_field() -> String {
          "#{field_name}"
        }
        """
      end)

    field_variants =
      Enum.map_join(resource.fields, "\n", fn field ->
        "  #{Macro.camelize(to_string(field.name))}"
      end)

    sort_helpers =
      Enum.map_join(resource.fields, "\n\n", fn field ->
        base = Macro.camelize(to_string(field.name))
        field_name = to_string(field.name)

        """
        pub fn #{field_name}_asc() -> #{resource.gleam_type}Sort {
          #{base}Asc
        }

        pub fn #{field_name}_desc() -> #{resource.gleam_type}Sort {
          #{base}Desc
        }
        """
      end)

    sorts =
      Enum.map_join(resource.fields, "\n", fn field ->
        base = Macro.camelize(to_string(field.name))
        "  #{base}Asc\n  #{base}Desc"
      end)

    filter_helpers =
      Enum.map_join(resource.fields, "\n\n", fn field ->
        variant = "#{Macro.camelize(to_string(field.name))}Eq"
        field_name = to_string(field.name)

        """
        pub fn #{field_name}_eq(value: #{gleam_type!(field.type, false)}) -> #{resource.gleam_type}Filter {
          #{variant}(value)
        }
        """
      end)

    filters =
      Enum.map_join(resource.fields, "\n", fn field ->
        "  #{Macro.camelize(to_string(field.name))}Eq(#{gleam_type!(field.type, false)})"
      end)

    """
    pub type #{resource.gleam_type} {
      #{resource.gleam_type}(
    #{fields}
      )
    }

    #{field_helpers}

    pub type #{resource.gleam_type}Field {
    #{field_variants}
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

  defp render_ffi(domain_module, resource, ffi) do
    action_module = Macro.camelize(Atom.to_string(ffi.ffi_name))
    resource_type = resource.gleam_type
    resource_module = resource.module_name

    case ffi.kind do
      :create ->
        create_fields =
          Enum.filter(resource.fields, fn field ->
            not field.primary_key? and field.writable? and not field.generated?
          end)

        fields =
          Enum.map_join(create_fields, ",\n", fn field ->
            "    #{field.name}: #{gleam_type!(field.type, field.allow_nil?)}"
          end)

        args =
          Enum.map_join(create_fields, ", ", fn field ->
            "#{field.name}: #{gleam_type!(field.type, field.allow_nil?)}"
          end)

        constructor =
          Enum.map_join(create_fields, ", ", fn field -> field.name end)

        """
        import #{resource_module}.{type #{resource_type}}

        pub type #{action_module} {
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
        pk = hd(resource.fields)

        """
        import #{resource_module}.{type #{resource_type}}

        pub type #{action_module} {
          #{action_module}(id: #{gleam_type!(pk.type, false)}, fields: List(String))
        }

        pub fn new(id: #{gleam_type!(pk.type, false)}) -> #{action_module} {
          #{action_module}(id, [])
        }

        pub fn fields(builder: #{action_module}, fields: List(String)) -> #{action_module} {
          let #{action_module}(id, _) = builder
          #{action_module}(id, fields)
        }

        @external(erlang, "Elixir.#{inspect(domain_module)}.Generated", "#{ffi.ffi_name}")
        pub fn run(builder: #{action_module}) -> Result(#{resource_type}, String)
        """

      _ ->
        """
        import gleam/option.{None, type Option}
        import #{resource_module}.{type #{resource_type}, type #{resource_type}Filter, type #{resource_type}Sort}

        pub type #{action_module} {
          #{action_module}(
            fields: List(String),
            filter: List(#{resource_type}Filter),
            sort: List(#{resource_type}Sort),
            limit: Option(Int),
          )
        }

        pub fn new() -> #{action_module} {
          #{action_module}([], [], [], None)
        }

        pub fn fields(builder: #{action_module}, fields: List(String)) -> #{action_module} {
          let #{action_module}(_, filter, sort, limit) = builder
          #{action_module}(fields, filter, sort, limit)
        }

        pub fn filter(builder: #{action_module}, filters: List(#{resource_type}Filter)) -> #{action_module} {
          let #{action_module}(fields, _, sort, limit) = builder
          #{action_module}(fields, filters, sort, limit)
        }

        pub fn sort(builder: #{action_module}, sorts: List(#{resource_type}Sort)) -> #{action_module} {
          let #{action_module}(fields, filter, _, limit) = builder
          #{action_module}(fields, filter, sorts, limit)
        }

        pub fn limit(builder: #{action_module}, limit: Option(Int)) -> #{action_module} {
          let #{action_module}(fields, filter, sort, _) = builder
          #{action_module}(fields, filter, sort, limit)
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
            {id, fields} = AshGleam.Generated.Bridge.decode_get(builder)

            #{inspect(resource.module)}
            |> Query.for_read(#{inspect(ffi.action)}, %{id: id}, domain: #{inspect(domain_module)})
            |> then(fn query ->
              if fields == [] do
                query
              else
                Ash.Query.select(query, Enum.map(fields, &String.to_existing_atom/1))
              end
            end)
            |> Ash.read_one(domain: #{inspect(domain_module)})
            |> AshGleam.Generated.Bridge.encode_result(&AshGleam.Marshal.to_gleam(#{inspect(resource.module)}, &1))
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

  defp gleam_type!(type, allow_nil?) do
    {:ok, type} = AshGleam.TypeMapper.gleam_type(type, allow_nil?: allow_nil?)
    type
  end
end
