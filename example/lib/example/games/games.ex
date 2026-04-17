defmodule Example.Games do
  use Ash.Domain,
    otp_app: :example,
    extensions: [AshGleam.Domain]

  resources do
    resource Example.Games.TicTacToe do
      define :new_tictactoe, action: :create
      define :get_tictactoe, action: :read, get_by: :id
    end
  end
end
