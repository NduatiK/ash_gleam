# SPDX-FileCopyrightText: 2025 ash_gleam contributors <https://github.com/NduatiK/ash_gleam/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.MixProject do
  use Mix.Project

  @app :ash_gleam
  @version "0.17.1"

  @description """
  Generate type-safe Gleam clients directly from your Ash resources and actions, ensuring end-to-end type safety between your backend and frontend.
  """

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      archives: [mix_gleam: "~> 0.6.2"],
      compilers: [:gleam | Mix.compilers()],
      elixirc_paths: elixirc_paths(Mix.env()),
      erlc_paths: erlc_paths(Mix.env()),
      erlc_include_path: "_build/#{Mix.env()}/lib/#{@app}/include",
      prune_code_paths: false,
      package: package(),
      deps: deps(),
      aliases: aliases(),
      docs: &docs/0,
      description: @description,
      source_url: "https://github.com/NduatiK/ash_gleam",
      homepage_url: "https://github.com/NduatiK/ash_gleam",
      dialyzer: [
        plt_add_apps: [:mix]
      ],
      consolidate_protocols: Mix.env() != :test
    ]
  end

  def cli do
    [
      preferred_envs: [
        "test.codegen": :test,
        "test.test_valibot": :test,
        tidewave: :test
      ]
    ]
  end

  def ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash", override: true]
      "main" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp erlc_paths(env) do
    env = to_string(env)

    [
      "_build/#{env}/lib/#{@app}/_gleam_artefacts",
      "_build/#{env}/lib/#{@app}/build"
    ]
  end

  def application do
    application(Mix.env())
  end

  defp application(:test) do
    [
      mod: {AshGleam.TestApp, []},
      extra_applications: [:logger]
    ]
  end

  defp application(_) do
    [
      extra_applications: [:logger]
    ]
  end

  defp package do
    [
      maintainers: [
        "Torkild Kjevik <torkild.kjevik@boitano.no>"
      ],
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README*
        CHANGELOG* documentation usage-rules.md LICENSES priv),
      links: %{
        "GitHub" => "https://github.com/NduatiK/ash_gleam",
        "Changelog" => "https://github.com/NduatiK/ash_gleam/blob/main/CHANGELOG.md",
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      extra_section: "GUIDES",
      extras: [
        # Home
        {"README.md", title: "Home"},

        # Getting Started
        "documentation/getting-started/installation.md",
        "documentation/getting-started/first-rpc-action.md",
        "documentation/getting-started/frontend-frameworks.md",

        # Guides
        "documentation/guides/crud-operations.md",
        "documentation/guides/field-selection.md",
        "documentation/guides/querying-data.md",
        "documentation/guides/typed-queries.md",
        "documentation/guides/error-handling.md",
        "documentation/guides/form-validation.md",
        "documentation/guides/typed-controllers.md",

        # Features
        "documentation/features/rpc-action-options.md",
        "documentation/features/phoenix-channels.md",
        "documentation/features/typed-channels.md",
        "documentation/features/lifecycle-hooks.md",
        "documentation/features/multitenancy.md",
        "documentation/features/action-metadata.md",
        "documentation/features/developer-experience.md",

        # Advanced
        "documentation/advanced/union-types.md",
        "documentation/advanced/embedded-resources.md",
        "documentation/advanced/custom-fetch.md",
        "documentation/advanced/custom-types.md",
        "documentation/advanced/field-name-mapping.md",

        # Reference
        "documentation/reference/configuration.md",
        "documentation/reference/mix-tasks.md",
        "documentation/reference/troubleshooting.md",

        # DSLs
        {"documentation/dsls/DSL-AshGleam.Rpc.md",
         search_data: Spark.Docs.search_data_for(AshGleam.Rpc)},
        {"documentation/dsls/DSL-AshGleam.Resource.md",
         search_data: Spark.Docs.search_data_for(AshGleam.Resource)},

        # About
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        "Getting Started": ~r'documentation/getting-started',
        Guides: ~r'documentation/guides',
        Features: ~r'documentation/features',
        Advanced: ~r'documentation/advanced',
        Reference: ~r'documentation/reference',
        DSLs: ~r'documentation/dsls',
        "About AshGleam": [
          "CHANGELOG.md"
        ]
      ],
      before_closing_head_tag: fn type ->
        if type == :html do
          """
          <script>
            if (location.hostname === "hexdocs.pm") {
              var script = document.createElement("script");
              script.src = "https://plausible.io/js/script.js";
              script.setAttribute("defer", "defer")
              script.setAttribute("data-domain", "ashhexdocs")
              document.head.appendChild(script);
            }
          </script>
          """
        end
      end
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.2 and >= 3.21.1"},
      {:gleam_stdlib, "~> 0.62"},
      {:gleeunit, "~> 1.0", only: [:dev, :test], runtime: false},
      {:git_ops, "~> 2.0", only: [:dev], runtime: false},
      {:spark, "~> 2.0"},
      {:sourceror, "~> 1.7", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:igniter, "~> 0.7", only: [:dev, :test]},
      {:ex_doc, "~> 0.37", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:picosat_elixir, "~> 0.2", only: [:dev, :test]},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:usage_rules, "~> 0.1", only: [:dev]},
      {:tidewave, "~> 0.5", only: [:dev, :test]},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
    ]
  end

  defp aliases do
    [
      "deps.get": ["deps.get", "gleam.deps.get"],
      "test.codegen": "ash_gleam.codegen",
      "test.compile_generated": "cmd cd test/ts && npm run compileGenerated",
      "test.compile_should_pass": "cmd cd test/ts && npm run compileShouldPass",
      "test.compile_should_fail": "cmd cd test/ts && npm run compileShouldFail",
      "test.test_zod": "cmd cd test/ts && npm run testZod",
      "test.test_valibot": "cmd cd test/ts && npm run testValibot",
      sobelow: "sobelow --skip",
      docs: [
        "spark.cheat_sheets",
        "docs",
        "spark.replace_doc_links"
      ],
      sync_usage_rules: [
        "usage_rules.sync AGENTS.md --all --link-to-folder deps --link-style at"
      ],
      credo: "credo --strict"
      # "spark.formatter":
      #   "spark.formatter --extensions AshGleam.Rpc,AshGleam.Resource,AshGleam.TypedController.Dsl,AshGleam.TypedChannel.Dsl",
      # "spark.cheat_sheets":
      #   "spark.cheat_sheets --extensions AshGleam.Rpc,AshGleam.Resource,AshGleam.TypedController.Dsl,AshGleam.TypedChannel.Dsl"
    ]
  end
end
