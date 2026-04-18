defmodule AshGleam.TestEmptyDomain do
  use Ash.Domain,
    otp_app: :ash_gleam,
    extensions: [AshGleam.Domain]

  resources do
    resource AshGleam.TestEmptyResource
  end
end
