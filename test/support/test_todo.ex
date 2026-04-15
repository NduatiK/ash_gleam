defmodule AshGleam.TestTodo do
  use Ash.Resource,
    otp_app: :ash_gleam,
    domain: AshGleam.TestDomain,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  ets do
    private? false
    table :ash_gleam_test_todos
  end

  gleam do
    type_name "Todo"
    module_name "todo_item"
  end

  attributes do
    uuid_primary_key :id
    attribute :title, :string, allow_nil?: false, public?: true
    attribute :completed, :boolean, allow_nil?: false, default: false, public?: true
  end

  actions do
    defaults [:read]

    create :create do
      accept [:title, :completed]
    end

    update :update do
      accept [:title, :completed]
      require_atomic? false
    end

    read :get do
      get_by [:id]
    end
  end

  gleam_actions do
    action :add, :integer do
      argument :a, :integer, allow_nil?: false
      argument :b, :integer, allow_nil?: false

      run &:test_gleam.add/2
    end

    action :mark_completed, __MODULE__ do
      argument :todo, __MODULE__, allow_nil?: false

      run &:test_gleam.mark_completed/1
    end
  end
end
