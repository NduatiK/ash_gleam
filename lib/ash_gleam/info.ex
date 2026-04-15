# SPDX-FileCopyrightText: 2026 Nduati Kuria
#
# SPDX-License-Identifier: MIT

defmodule AshGleam.Info do
  @moduledoc false

  @default_output "src/ash_ffi"
  @default_manifest ".ash_gleam/manifest.term"
  @default_elixir_output "lib/ash_gleam/generated"

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

  @spec manifest_path(Keyword.t()) :: String.t()
  def manifest_path(opts \\ []) do
    opts[:manifest] || Application.get_env(:ash_gleam, :manifest, @default_manifest)
  end

  @spec elixir_output_dir(Keyword.t()) :: String.t()
  def elixir_output_dir(opts \\ []) do
    opts[:elixir_output] ||
      Application.get_env(:ash_gleam, :elixir_output, @default_elixir_output)
  end
end
