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
    type_name("TicTacToe")
  end

  gleam_actions do
    action :win, :term do
      argument :game, __MODULE__, allow_nil?: false

      run &:tictactoe.win/1
    end

    action :mark, __MODULE__ do
      argument :game, __MODULE__, allow_nil?: false
      argument :x, :integer, allow_nil?: false
      argument :y, :integer, allow_nil?: false

      run &:tictactoe.mark/3
    end

    action :peek, :term do
      # TODO support atom with constraints items: [one_of: [:x, :o, :empty]]
      # 
      argument :game, __MODULE__, allow_nil?: false
      argument :x, :integer, allow_nil?: false
      argument :y, :integer, allow_nil?: false

      run &:tictactoe.peek/3
    end
  end

  actions do
    create :create do
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :board, {:array, :atom} do
      allow_nil? false
      public? true
      constraints items: [one_of: [:x, :o, :empty]]
      default [:empty, :empty, :empty, :empty, :empty, :empty, :empty, :empty, :empty]
    end

    attribute :current_player, :atom do
      allow_nil? false
      public? true
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
end
