# SPDX-FileCopyrightText: 2025 ash_gleam contributors <https://github.com/NduatiK/ash_gleam/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.MixProject do
  use Mix.Project

  @app :ash_gleam
  @version "0.3.3"

  @description """
  Generate type-safe Gleam clients directly from your Ash resources and actions, ensuring end-to-end type safety between Gleam and Elixir.
  """

  def project do
    [
      app: @app,
      description: @description,
      version: @version,
      package: package(),
            docs: &docs/0,

      #
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      archives: [mix_gleam: "~> 0.6.2"],
      compilers: compilers(Mix.env()),
      erlc_paths: erlc_paths(Mix.env()),
      erlc_include_path: "_build/#{Mix.env()}/lib/#{@app}/include",
      prune_code_paths: false,
      consolidate_protocols: Mix.env() != :test,
      usage_rules: usage_rules()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp compilers(:test), do: [:gleam | Mix.compilers()]
  defp compilers(_), do: Mix.compilers()

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
  
  defp docs do
    [
      extras: [
        "README.md"
      ]
    ]
  end

  defp package do
    [
      maintainers: [
        "Nduati Kuria"
      ],
      licenses: ["MIT"],
      files: ~w(lib .formatter.exs mix.exs README* doc),
      links: %{
        "GitHub" => "https://github.com/NduatiK/ash_gleam"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, "~> 3.2 and >= 3.21.1"},
      {:ash_sum_type, "~> 1.0.3"},
      {:gleam_stdlib, "~> 0.62", only: [:test]},
      {:gleeunit, "~> 1.0", only: [:test], runtime: false},
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
      {:usage_rules, "~> 1.0", only: [:dev]},
      {:tidewave, "~> 0.5", only: [:dev, :test]},
      {:ex_check, "~> 0.12", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      "deps.get": ["deps.get", "gleam.deps.get"],
      "test.codegen": "ash_gleam.codegen",
      "test.compile_generated": "cmd cd test/ts && npm run compileGenerated",
      "test.compile_should_pass": "cmd cd test/ts && npm run compileShouldPass",
      "test.compile_should_fail": "cmd cd test/ts && npm run compileShouldFail",
      sobelow: "sobelow --skip",
      credo: "credo --strict"
      # "spark.formatter":
      #   "spark.formatter --extensions AshGleam.Rpc,AshGleam.Resource,AshGleam.TypedController.Dsl,AshGleam.TypedChannel.Dsl",
      # "spark.cheat_sheets":
      #   "spark.cheat_sheets --extensions AshGleam.Rpc,AshGleam.Resource,AshGleam.TypedController.Dsl,AshGleam.TypedChannel.Dsl"
    ]
  end

 defp usage_rules do
  # Example for those using claude.
  [
    file: "CLAUDE.md",
    # rules to include directly in CLAUDE.md
    # :usage_rules itself provides rules for search_docs, docs, etc.
    # use a regex to match multiple deps, or atoms/strings for specific ones
    usage_rules: [:usage_rules, :ash, ~r/^ash_/],
    # If your CLAUDE.md is getting too big, link instead of inlining:
    usage_rules: [:ash, {~r/^ash_/, link: :markdown}],
    # or use skills
    skills: [
      location: ".claude/skills",
      # build skills that combine multiple usage rules
      build: [
        "ash-framework": [
          # The description tells people how to use this skill.
          description: "Use this skill working with Ash Framework or any of its extensions. Always consult this when making any domain changes, features or fixes.",
          # Include all Ash dependencies
          usage_rules: [:ash, ~r/^ash_/]
        ],
        "phoenix-framework": [
          description: "Use this skill working with Phoenix Framework. Consult this when working with the web layer, controllers, views, liveviews etc.",
          # Include all Phoenix dependencies
          usage_rules: [:phoenix, ~r/^phoenix_/]
        ]
      ]
    ]
  ]
end
end
