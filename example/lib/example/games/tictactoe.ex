defmodule Example.Games.TicTacToe do
  use Ash.Resource,
    domain: Example.Games,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  ets do
    private? false
    table :games_tictactoe
  end

  gleam do
    type_name "TicTacToe"
  end

  attributes do
    uuid_primary_key :id

    attribute :board, {:array, :atom} do
      public? true
      constraints items: [one_of: [:x, :o, nil]]
      default [nil, nil, nil, nil, nil, nil, nil, nil, nil]
    end

  attribute :current_player, :atom do
    public? true
    allow_nil? false
    constraints one_of: [:x, :o]
    default :x
  end

  attribute :winner, :atom do
    public? true
    allow_nil? true
    constraints one_of: [:x, :o, :draw]
  end

  attribute :status, :atom do
    public? true
    allow_nil? false
    constraints one_of: [:in_progress, :finished]
    default :in_progress
  end
end

  actions do
  end

  gleam_actions do
    # action :add, :integer do
    #   argument :a, :integer, allow_nil?: false
    #   argument :b, :integer, allow_nil?: false

    #   run &:test_gleam.add/2
    # end

    # action :safe_add, :integer do
    #   argument :a, :integer, allow_nil?: false
    #   argument :b, :integer, allow_nil?: false

    #   run &:test_gleam.safe_add/2
    # end

    # action :mark_completed, __MODULE__ do
    #   argument :todo, __MODULE__, allow_nil?: false

    #   run &:test_gleam.mark_completed/1
    # end

    # action :safe_mark_completed, __MODULE__ do
    #   argument :todo, __MODULE__, allow_nil?: false

    #   run &:test_gleam.safe_mark_completed/1
    # end

    # action :first_completed_from_elixir, __MODULE__ do
    #   run &:test_gleam.first_completed_from_elixir/0
    # end

    # action :delete_from_elixir, :boolean do
    #   argument :todo, __MODULE__, allow_nil?: false

    #   run &:test_gleam.delete_from_elixir/1
    # end
  end
end
