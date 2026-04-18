defmodule AshGleam.MathBridge do
  use AshGleam.GleamBridge

  gleam do
    consume do
      function :add_in_gleam, :integer do
        argument :a, :integer, allow_nil?: false
        argument :b, :integer, allow_nil?: false

        run &:test_gleam.add/2
      end

      function :round_trip_add, :integer do
        argument :a, :integer, allow_nil?: false
        argument :b, :integer, allow_nil?: false

        run &:test_gleam.round_trip_add/2
      end
    end

    expose do
      function :add, :integer do
        argument :a, :integer, allow_nil?: false
        argument :b, :integer, allow_nil?: false

        run fn a, b -> {:ok, a + b} end
      end

      function :greet, :string do
        argument :name, :string, allow_nil?: false

        run fn name -> "Hello, #{name}!" end
      end
    end
  end
end
