# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Info do
  @moduledoc false

  @default_output "lib/ash_gleam/generated"

  @spec otp_app(Keyword.t()) :: atom()
  def otp_app(opts \\ []) do
    opts[:otp_app] || Mix.Project.config()[:app]
  end

  @spec domains(Keyword.t()) :: [module()]
  def domains(opts \\ []) do
    otp_app(opts)
    |> Ash.Info.domains()
    |> Enum.uniq()
  end

  @spec resources(Keyword.t()) :: [module()]
  def resources(opts \\ []) do
    opts
    |> domains()
    |> Enum.flat_map(&Ash.Domain.Info.resources/1)
    |> Enum.uniq()
  end

  @spec output_dir(Keyword.t()) :: String.t()
  def output_dir(opts \\ []) do
    opts[:output] || Application.get_env(:ash_gleam, :output, @default_output)
  end

  @spec gleam_dir(Keyword.t()) :: String.t()
  def gleam_dir(opts \\ []) do
    output_dir(opts) <> "/src"
  end

  @spec gleam_module_prefix(Keyword.t()) :: String.t()
  def gleam_module_prefix(opts \\ []) do
    segments = Path.split(gleam_dir(opts))

    case Enum.split_while(segments, &(&1 != "src")) do
      {_before, ["src" | rest]} when rest != [] ->
        Path.join(rest)

      _ ->
        Path.basename(output_dir(opts)) <> "/src"
    end
  end

  @spec manifest_path(Keyword.t()) :: String.t()
  def manifest_path(opts \\ []) do
    output_dir(opts) <> "/manifest.term"
  end

  @spec elixir_dir(Keyword.t()) :: String.t()
  def elixir_dir(opts \\ []) do
    output_dir(opts) <> "/lib"
  end
end
