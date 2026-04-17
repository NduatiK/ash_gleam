defmodule Example.Games.TicTacToe do
  use Ash.Resource,
    domain: Example.Games,
    data_layer: Ash.DataLayer.Ets,
    extensions: [AshGleam.Resource, AshGleam.Actions]

  alias Example.Games.TicTacToe.Mark
  alias Example.Games.TicTacToe.Player
  alias Example.Games.TicTacToe.Winner

  ets do
    private? false
    table :games_tictactoe
  end

  gleam do
    type_name("TicTacToe")
    
    actions do
      action :win, Winner do
        argument :game, __MODULE__, allow_nil?: false

        run &:tictactoe.win/1
      end

      action :mark, __MODULE__ do
        update? true
        argument :game, __MODULE__, allow_nil?: false
        argument :x, :integer, allow_nil?: false
        argument :y, :integer, allow_nil?: false

        run &:tictactoe.mark/3
      end

      action :peek, Mark do
        argument :game, __MODULE__, allow_nil?: false
        argument :x, :integer, allow_nil?: false
        argument :y, :integer, allow_nil?: false

        run &:tictactoe.peek/3
      end
    end
  end

  code_interface do
    define :update, action: :update
  end

  actions do
    create :create do
    end

    update :update do
      accept :*
      require_atomic? false
    end

    read :read do
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :board, {:array, Mark} do
      allow_nil? false
      public? true
      default [:empty, :empty, :empty, :empty, :empty, :empty, :empty, :empty, :empty]
    end

    attribute :current_player, Player do
      allow_nil? false
      public? true
      default :x
    end

    attribute :winner, Winner do
      public? true
      allow_nil? true
    end
  end
end
