# SPDX-FileCopyrightText: 2025 ash_gleam contributors <https://github.com/NduatiK/ash_gleam/graphs/contributors>
#
# SPDX-License-Identifier: MIT

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.AshGleam.Install do
    @shortdoc "Installs AshGleam into a project. Should be called with `mix igniter.install ash_gleam`"

    @moduledoc """
    #{@shortdoc}

    Configures your Mix project to use MixGleam and AshGleam by applying the
    changes described in the MixGleam README:

    - Adds `archives: [mix_gleam: "~> 0.6"]` to project/0
    - Adds `:gleam` to the compilers list
    - Adds `erlc_paths` pointing to Gleam build artefacts
    - Sets `erlc_include_path` for Gleam-generated include files
    - Sets `prune_code_paths: false` (required for Elixir >= v1.15.0)
    - Adds a `deps.get` alias that also runs `gleam.deps.get`
    - Adds `gleam_stdlib` and `gleeunit` to deps
    - Creates a `src/` directory for Gleam source files
    - Adds `build/` to `.gitignore`
    """

    use Igniter.Mix.Task

    alias Igniter.Project.MixProject
    alias Igniter.Project.TaskAliases

    @impl Igniter.Mix.Task
    def info(_argv, _source) do
      %Igniter.Mix.Task.Info{
        group: :ash,
        installs: [],
        schema: [],
        defaults: [],
        composes: [],
        extra_args?: false
      }
    end

    @impl Igniter.Mix.Task
    def igniter(igniter) do
      app_name = Igniter.Project.Application.app_name(igniter)

      igniter
      |> add_mix_gleam_archive()
      |> add_gleam_compiler()
      |> add_erlc_paths(app_name)
      |> add_erlc_include_path(app_name)
      |> add_prune_code_paths()
      |> add_deps_get_alias()
      |> add_gleam_deps()
      |> create_src_dir()
      |> add_build_to_gitignore()
      |> add_next_steps_notice()
    end

    # Add archives: [mix_gleam: "~> 0.6"] to project/0
    defp add_mix_gleam_archive(igniter) do
      MixProject.update(igniter, :project, [:archives], fn
        _ ->
          {:ok, {:code, [{:mix_gleam, "~> 0.6"}]}}
      end)
    end

    # Add :gleam to the compilers list (prepend so it runs before Mix.compilers())
    defp add_gleam_compiler(igniter) do
      MixProject.update(igniter, :project, [:compilers], fn
        nil ->
          {:ok, {:code, quote(do: [:gleam | Mix.compilers()])}}

        zipper ->
          try_put(
            zipper,
            :gleam,
            "Could not prepend `:gleam` to compilers. Please add it manually."
          )
      end)
    end

    def try_put(zipper, value, error) do
      case Igniter.Code.List.move_to_list_item(
             zipper,
             &Igniter.Code.Common.nodes_equal?(&1, value)
           ) do
        {:ok, _} ->
          {:ok, zipper}

        :error ->
          case Igniter.Code.List.prepend_new_to_list(zipper, value) do
            {:ok, zipper} ->
              {:ok, zipper}

            :error ->
              # Handle `[...] ++ Mix.compilers()` — cursor lands on the left-side list
              case Igniter.Code.Common.move_to_cursor(zipper, "__cursor__() ++ Mix.compilers()") do
                {:ok, left_zipper} ->
                  case Igniter.Code.List.prepend_new_to_list(left_zipper, value) do
                    {:ok, updated} -> {:ok, updated}
                    :error -> {:warning, error}
                  end

                :error ->
                  {:warning, error}
              end
          end
      end
    end

    # Add erlc_paths pointing to Gleam artefacts
    defp add_erlc_paths(igniter, app_name) do
      gleam_artefacts = "_build/dev/lib/#{app_name}/_gleam_artefacts"
      gleam_build = "_build/dev/lib/#{app_name}/build"

      MixProject.update(igniter, :project, [:erlc_paths], fn
        nil ->
          {:ok, {:code, [gleam_artefacts, gleam_build]}}

        zipper ->
          with {:ok, zipper} <- Igniter.Code.List.append_new_to_list(zipper, gleam_artefacts),
               {:ok, zipper} <- Igniter.Code.List.append_new_to_list(zipper, gleam_build) do
            {:ok, zipper}
          else
            :error ->
              {:warning,
               "Could not add Gleam artefact paths to erlc_paths. Please add them manually."}
          end
      end)
    end

    # Set erlc_include_path for Gleam-generated include files
    defp add_erlc_include_path(igniter, app_name) do
      include_path = "_build/dev/lib/#{app_name}/include"

      MixProject.update(igniter, :project, [:erlc_include_path], fn
        nil -> {:ok, {:code, "\"#{include_path}\""}}
        zipper -> {:ok, zipper}
      end)
    end

    # Set prune_code_paths: false (required for Elixir >= v1.15.0 with Gleam)
    defp add_prune_code_paths(igniter) do
      MixProject.update(igniter, :project, [:prune_code_paths], fn
        nil -> {:ok, {:code, false}}
        zipper -> {:ok, zipper}
      end)
    end

    # Add "deps.get": ["deps.get", "gleam.deps.get"] alias
    defp add_deps_get_alias(igniter) do
      TaskAliases.add_alias(
        igniter,
        "deps.get",
        ["deps.get", "gleam.deps.get"],
        if_exists: :ignore
      )
    end

    # Add gleam_stdlib and gleeunit to deps
    defp add_gleam_deps(igniter) do
      igniter
      |> Igniter.Project.Deps.add_dep({:gleam_stdlib, "~> 0.34 or ~> 1.0"}, on_exists: :skip)
      |> Igniter.Project.Deps.add_dep(
        {:gleeunit, "~> 1.0", [only: [:dev, :test], runtime: false]},
        on_exists: :skip
      )
    end

    # Create the src/ directory for Gleam source files
    defp create_src_dir(igniter) do
      Igniter.create_new_file(igniter, "src/.keep", "", on_exists: :skip)
    end

    # Add build/ to .gitignore
    defp add_build_to_gitignore(igniter) do
      gitignore_path = ".gitignore"

      if Igniter.exists?(igniter, gitignore_path) do
        igniter = Igniter.include_existing_file(igniter, gitignore_path)
        source = Rewrite.source!(igniter.rewrite, gitignore_path)
        content = Rewrite.Source.get(source, :content)

        add_to_gitignore = fn text ->
          if String.contains?(content, "\n#{text}") or String.starts_with?(content, "#{text}") do
            igniter
          else
            new_content = String.trim_trailing(content) <> "\n#{text}\n"

            Igniter.update_file(igniter, gitignore_path, fn source ->
              Rewrite.Source.update(source, :content, new_content)
            end)
          end
        end

        add_to_gitignore.("build/")
        add_to_gitignore.(AshGleam.Info.manifest_path())
      else
        Igniter.create_new_file(igniter, gitignore_path, "build/\n", on_exists: :skip)
      end
    end

    defp add_next_steps_notice(igniter) do
      Igniter.add_notice(igniter, """
      AshGleam installed!

      Next Steps:
      1. Install the Gleam compiler: https://gleam.run/getting-started/installing-gleam.html
      2. Install the MixGleam archive:
           mix archive.install hex mix_gleam
      3. Run `mix deps.get` to fetch all dependencies (including Gleam deps)
      4. Put your Gleam source files in the `src/` directory
      5. Use the AshGleam.Resource extension on your Ash resources
      6. Run `mix ash_gleam.codegen` to generate Gleam types and FFI wrappers

      Documentation: https://hexdocs.pm/ash_gleam
      MixGleam: https://github.com/gleam-lang/mix_gleam
      """)
    end
  end
else
  defmodule Mix.Tasks.AshGleam.Install do
    @moduledoc "Installs AshGleam into a project. Should be called with `mix igniter.install ash_gleam`"

    @shortdoc @moduledoc

    use Mix.Task

    def run(_argv) do
      Mix.shell().error("""
      The task 'ash_gleam.install' requires igniter to be run.

      Please install igniter and try again.

      For more information, see: https://hexdocs.pm/igniter
      """)

      exit({:shutdown, 1})
    end
  end
end
