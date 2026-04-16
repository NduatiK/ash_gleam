defmodule Example.GameLive do
  use Phoenix.LiveView, layout: {TicTacToe.LayoutLive, :live}

  @tictactoe :tictactoe

  def render(assigns) do
    ~H"""
    <div class="win-block">
      <h1><%= @render_win %></h1>
    </div>
    <div class="center">
      <div class="grid">
        <%= for {x, y, mark, class} <- @render_grid do %>
          <%= if @ended? do %>
            <div phx-value-x={x} phx-value-y={y} class={class}>
              <%= mark %>
            </div>
          <% else %>
            <div phx-click="mark" phx-value-x={x} phx-value-y={y} class={class}>
              <%= mark %>
            </div>
          <% end %>
        <% end %>
      </div>
    </div>
    <.css />
    """
  end

  def mount(_params, _session, socket) do
    game = @tictactoe.new()

    {:ok,
     socket
     |> assign(:game, game)
     |> assign(:ended?, ended?(game))
     |> assign(:render_win, render_win(game))
     |> assign(:render_grid, render_grid(game))}
  end

  def handle_event("mark", %{"x" => x, "y" => y}, socket) do
    {x, ""} = Integer.parse(x)
    {y, ""} = Integer.parse(y)

    case @tictactoe.mark(socket.assigns.game, x, y) do
      {:ok, game} ->
        {:noreply,
         socket
         |> assign(:game, game)
         |> assign(:ended?, ended?(game))
         |> assign(:render_win, render_win(game))
         |> assign(:render_grid, render_grid(game))}

      {:error, _error} ->
        {:noreply, socket}
    end
  end

  defp ended?({:game, _grid, _mark} = game) do
    case @tictactoe.win(game) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  end

  defp render_win({:game, _grid, _mark} = game) do
    case @tictactoe.win(game) do
      {:ok, :x} -> "Game! X 🎉"
      {:ok, :o} -> "Game! O 🎉"
      {:error, _} -> nil
    end
  end

  defp render_grid({:game, grid, _mark} = _game) do
    for x <- [1, 2, 3],
        y <- [1, 2, 3] do
      case Map.get(grid, {x, y}) do
        {:some, :x} -> {x, y, "X", "mark-x"}
        {:some, :o} -> {x, y, "O", "mark-o"}
        :none -> {x, y, nil, nil}
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
