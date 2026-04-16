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
    attribute :priority, :integer, allow_nil?: false, default: 1, public?: true
  end

  actions do
    defaults [:read]

    create :create do
      accept [:title, :completed, :priority]
    end

    update :update do
      accept [:title, :completed, :priority]
      require_atomic? false
    end

    destroy :destroy

    read :get do
      get_by [:id]
    end

    read :first_completed do
      get? true
      filter expr(completed == true)
      prepare build(sort: [title: :asc], limit: 1)
    end
  end

  gleam_actions do
    action :add, :integer do
      argument :a, :integer, allow_nil?: false
      argument :b, :integer, allow_nil?: false

      run &:test_gleam.add/2
    end

    action :safe_add, :integer do
      argument :a, :integer, allow_nil?: false
      argument :b, :integer, allow_nil?: false

      run &:test_gleam.safe_add/2
    end

    action :mark_completed, __MODULE__ do
      argument :todo, __MODULE__, allow_nil?: false

      run &:test_gleam.mark_completed/1
    end

    action :safe_mark_completed, __MODULE__ do
      argument :todo, __MODULE__, allow_nil?: false

      run &:test_gleam.safe_mark_completed/1
    end

    action :first_completed_from_elixir, __MODULE__ do
      run &:test_gleam.first_completed_from_elixir/0
    end

    action :delete_from_elixir, :boolean do
      argument :todo, __MODULE__, allow_nil?: false

      run &:test_gleam.delete_from_elixir/1
    end

    action :next_mark, :atom do
      constraints one_of: [:x, :o, :empty]

      run &:test_gleam.next_mark/0
    end
  end
end
