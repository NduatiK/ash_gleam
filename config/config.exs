# SPDX-FileCopyrightText: 2025 ash_typescript contributors <https://github.com/ash-project/ash_typescript/graphs/contributors>
#
# SPDX-License-Identifier: MIT

import Config

config :ash_gleam,
  output_file: "gleam/types.gleam"

if Mix.env() == :test do
  config :ash,
    validate_domain_resource_inclusion?: false,
    validate_domain_config_inclusion?: false,
    default_page_type: :keyset,
    disable_async?: true

  config :logger, :console, level: :info
end

if File.exists?("config/#{config_env()}.exs") do
  import_config "#{config_env()}.exs"
end
