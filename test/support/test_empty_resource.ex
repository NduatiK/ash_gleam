defmodule AshGleam.TestEmptyResource do
  use Ash.Resource,
    domain: AshGleam.TestEmptyDomain,
    extensions: [AshGleam.Actions]

  gleam do
    actions do
      action :add, :integer do
        argument :a, :integer, allow_nil?: false
        argument :b, :integer, allow_nil?: false

        run &:test_gleam.add/2
      end
    end
  end
end
