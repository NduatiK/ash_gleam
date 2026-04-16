defmodule AshGleam.ValidationTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  test "resource validation rejects unsupported field types" do
    suffix = System.unique_integer([:positive])
    domain = Module.concat([AshGleam, Dynamic, :"UnsupportedDomain#{suffix}"])
    resource = Module.concat([AshGleam, Dynamic, :"UnsupportedResource#{suffix}"])

    quoted =
      quote do
        defmodule unquote(domain) do
          use Ash.Domain, otp_app: :ash_gleam

          resources do
            resource unquote(resource)
          end
        end

        defmodule unquote(resource) do
          use Ash.Resource,
            otp_app: :ash_gleam,
            domain: unquote(domain),
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshGleam.Resource]

          ets do
            private? true
          end

          gleam do
            type_name "Broken"
          end

          attributes do
            uuid_primary_key :id
            attribute :metadata, :map, public?: true
          end
        end
      end

    output =
      capture_io(:stderr, fn ->
        compiled = Code.compile_quoted(quoted)
        assert length(compiled) >= 2
      end)

    assert output =~ "Unsupported fields: metadata"
  end

  test "resource validation rejects atom fields without one_of constraints" do
    suffix = System.unique_integer([:positive])
    domain = Module.concat([AshGleam, Dynamic, :"AtomDomain#{suffix}"])
    resource = Module.concat([AshGleam, Dynamic, :"AtomResource#{suffix}"])

    quoted =
      quote do
        defmodule unquote(domain) do
          use Ash.Domain, otp_app: :ash_gleam

          resources do
            resource unquote(resource)
          end
        end

        defmodule unquote(resource) do
          use Ash.Resource,
            otp_app: :ash_gleam,
            domain: unquote(domain),
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshGleam.Resource]

          ets do
            private? true
          end

          gleam do
            type_name "BrokenAtom"
          end

          attributes do
            uuid_primary_key :id
            attribute :status, :atom, public?: true
          end
        end
      end

    output =
      capture_io(:stderr, fn ->
        compiled = Code.compile_quoted(quoted)
        assert length(compiled) >= 2
      end)

    assert output =~ "Unsupported fields: status"
  end

  test "gleam action validation rejects wrong run arity" do
    suffix = System.unique_integer([:positive])
    domain = Module.concat([AshGleam, Dynamic, :"WrongArityDomain#{suffix}"])
    resource = Module.concat([AshGleam, Dynamic, :"WrongArityResource#{suffix}"])

    quoted =
      quote do
        defmodule unquote(domain) do
          use Ash.Domain, otp_app: :ash_gleam

          resources do
            resource unquote(resource)
          end
        end

        defmodule unquote(resource) do
          use Ash.Resource,
            otp_app: :ash_gleam,
            domain: unquote(domain),
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshGleam.Actions]

          ets do
            private? true
          end

          attributes do
            uuid_primary_key :id
          end

          gleam_actions do
            action :broken, :integer do
              argument :a, :integer, allow_nil?: false
              argument :b, :integer, allow_nil?: false

              run &:test_gleam.mark_completed/1
            end
          end
        end
      end

    import ExUnit.CaptureIO

    capture_io(:stderr, fn ->
      compiled = Code.compile_quoted(quoted)

      assert length(compiled) >= 2
    end)

    assert {:error, %Spark.Error.DslError{message: message}} =
             AshGleam.Transformers.ValidateGleamActions.verify(resource)

    assert message =~ "arity matches the declared arguments"
  end

  test "gleam action validation rejects atom returns without one_of constraints" do
    suffix = System.unique_integer([:positive])
    domain = Module.concat([AshGleam, Dynamic, :"AtomReturnDomain#{suffix}"])
    resource = Module.concat([AshGleam, Dynamic, :"AtomReturnResource#{suffix}"])

    quoted =
      quote do
        defmodule unquote(domain) do
          use Ash.Domain, otp_app: :ash_gleam

          resources do
            resource unquote(resource)
          end
        end

        defmodule unquote(resource) do
          use Ash.Resource,
            otp_app: :ash_gleam,
            domain: unquote(domain),
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshGleam.Actions]

          ets do
            private? true
          end

          attributes do
            uuid_primary_key :id
          end

          gleam_actions do
            action :broken, :atom do
              run &:test_gleam.next_mark/0
            end
          end
        end
      end

    assert_raise RuntimeError,
                 ~r/atom return types require constraints like `constraints one_of:/,
                 fn ->
                   capture_io(:stderr, fn ->
                     Code.compile_quoted(quoted)
                   end)
                 end
  end

  test "gleam action validation rejects atom arguments without one_of constraints" do
    suffix = System.unique_integer([:positive])
    domain = Module.concat([AshGleam, Dynamic, :"AtomArgumentDomain#{suffix}"])
    resource = Module.concat([AshGleam, Dynamic, :"AtomArgumentResource#{suffix}"])

    quoted =
      quote do
        defmodule unquote(domain) do
          use Ash.Domain, otp_app: :ash_gleam

          resources do
            resource unquote(resource)
          end
        end

        defmodule unquote(resource) do
          use Ash.Resource,
            otp_app: :ash_gleam,
            domain: unquote(domain),
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshGleam.Actions]

          ets do
            private? true
          end

          attributes do
            uuid_primary_key :id
          end

          gleam_actions do
            action :broken, :integer do
              argument :mark, :atom, allow_nil?: false
              run &:erlang.abs/1
            end
          end
        end
      end

    assert_raise RuntimeError,
                 ~r/atom argument types require constraints like `constraints one_of:/,
                 fn ->
                   capture_io(:stderr, fn ->
                     Code.compile_quoted(quoted)
                   end)
                 end
  end
end
