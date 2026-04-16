defmodule ExampleWeb.Example.GameLive do
  use Phoenix.LiveView

  alias Example.Games
  alias Example.Games.TicTacToe

  def render(assigns) do
    ~H"""
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
    """
  end

  def mount(_params, _session, socket) do
    {:ok, game} = Games.new_tictactoe()

    {:ok,
     socket
     |> assign(:game, game)
     |> assign(:grid, render_grid(game))
     |> assign(:ended?, ended?(game))
     |> assign(:render_win, render_win(game))}
  end

  def handle_event("mark", %{"x" => x, "y" => y}, socket) do
    {x, ""} = Integer.parse(x)
    {y, ""} = Integer.parse(y)

    case TicTacToe.mark(%{game: socket.assigns.game, x: x, y: y}) do
      {:ok, game} ->
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
    case TicTacToe.win(%{game: game}) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp render_win(%TicTacToe{} = game) do
    case TicTacToe.win(%{game: game}) do
      {:ok, :x} -> "Game! X 🎉"
      {:ok, :o} -> "Game! O 🎉"
      {:ok, :draw} -> "Draw"
      {:error, _} -> nil
    end
  end

  defp render_grid(%TicTacToe{} = game) do
    for y <- [0, 1, 2], x <- [0, 1, 2] do
      case TicTacToe.peek(%{game: game, x: x, y: y}) do
        {:ok, :empty} -> {x, y, nil}
        {:ok, mark} -> {x, y, mark}
      end
    end
  end

  defp css(assigns) do
    ~H"""
    <style>
      .grid {
        height: 750px;
        width: 750px;
        display: grid;
        grid-template-columns: 1fr 1fr 1fr;
        grid-template-rows: 1fr 1fr 1fr;
        background-color: #292d3e;
        gap: 5px;
      }
      .grid > div {
        background-color: #fffefb;
        text-align: center;
        padding: 61px 0px;
        font-size: 100px;
        font-family: verdana;
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
