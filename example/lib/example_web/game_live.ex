defmodule ExampleWeb.Example.GameLive do
  use ExampleWeb, :live_view

  alias Example.Games
  alias Example.Games.TicTacToe

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="win-block">
        <h1>{@render_win}</h1>
      </div>
      <div class="center">
        <div class="grid">
          <%= for {x, y, mark} <- @grid do %>
            <%= if @ended? do %>
              <div phx-value-x={x} phx-value-y={y} class={"mark-#{mark}"}>
                {mark}
              </div>
            <% else %>
              <div phx-click="mark" phx-value-x={x} phx-value-y={y} class={"mark-#{mark}"}>
                {mark}
              </div>
            <% end %>
          <% end %>
        </div>
      </div>
      <.css />
    </Layouts.app>
    """
  end

  def mount(%{"id" => id}, _session, socket) do
    case Games.get_tictactoe(id) do
      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Game not found, creating new game")
         |> push_navigate(to: "/")}

      {:ok, game} ->
        {:ok,
         socket
         |> assign(:game, game)
         |> assign(:grid, render_grid(game))
         |> assign(:ended?, ended?(game))
         |> assign(:render_win, render_win(game))}
    end
  end

  def mount(_params, _session, socket) do
    {:ok, game} = Games.new_tictactoe()

    {:ok,
     socket
     |> put_flash(:info, "Creating new game")
     |> push_navigate(to: "/game/#{game.id}")}
  end

  def handle_event("mark", %{"x" => x, "y" => y}, socket) do
    {x, ""} = Integer.parse(x)
    {y, ""} = Integer.parse(y)

    case TicTacToe.mark(%{game: socket.assigns.game, x: x, y: y}) do
      {:ok, new_game} ->
        game =
          socket.assigns.game
          |> Ash.Changeset.for_update(
            :update,
            AshGleam.Diff.resource_changes(socket.assigns.game, new_game)
          )
          |> Ash.update!()

        {:noreply,
         socket
         |> assign(:game, game)
         |> assign(:grid, render_grid(game))
         |> assign(:ended?, ended?(game))
         |> assign(:render_win, render_win(game))}

      {:error, _error} ->
        {:noreply, socket}
    end
  end

  defp ended?(%TicTacToe{} = game) do
    case TicTacToe.win!(%{game: game}) do
      nil -> false
      _ -> true
    end
  end

  defp render_win(%TicTacToe{} = game) do
    case TicTacToe.win!(%{game: game}) do
      {:player, :x} -> "Game! X 🎉"
      {:player, :o} -> "Game! O 🎉"
      :draw -> "Draw"
      nil -> nil
    end
  end

  defp render_grid(%TicTacToe{} = game) do
    for y <- [0, 1, 2], x <- [0, 1, 2] do
      case TicTacToe.peek!(%{game: game, x: x, y: y}) do
        :empty -> {x, y, nil}
        mark -> {x, y, mark}
      end
    end
  end

  defp css(assigns) do
    ~H"""
    <style>
      .grid {
        height: 600px;
        width: 600px;
        display: grid;
        grid-template-columns: 1fr 1fr 1fr;
        grid-template-rows: 1fr 1fr 1fr;
        background-color: #292d3e;
        gap: 5px;
      }
      .grid > div {
        background-color: #fffefb;
        text-align: center;
        padding: 40px 0px;
        font-size: 60px;
        font-family: monospace;
      }
      .mark-x {
        color: #ffaff3;
      }
      .mark-o {
        color: #4e2a8e;
      }
      .center {
        display: flex;
        justify-content: center;
        height: 100vh;
      }
      .win-block {
        padding-top: 16px;
        padding-bottom: 16px;
        height: 160;
      }
      .win-block > h1 {
        font-family: cursive;
        text-align: center;
        font-size: 100px;
        margin: 0;
      }
    </style>
    """
  end
end
