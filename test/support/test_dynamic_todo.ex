defmodule AshGleam.TestDynamicTodo do
  use Ash.Resource,
    otp_app: :ash_gleam,
    domain: AshGleam.TestDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  ets do
    private? false
    table :ash_gleam_test_dynamic_todos
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :metadata, :map, public?: true
    attribute :status, :atom, public?: true
  end

  actions do
    defaults [create: :*]
  end

  gleam do
    type_name "DynamicTodo"
    module_name "dynamic_todo_item"

    actions do
      action :round_trip_dynamic, __MODULE__ do
        argument :todo, __MODULE__, allow_nil?: false

        run &:test_gleam.round_trip_dynamic/1
      end
    end
  end
end
