defmodule AshGleam.CodegenTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  test "manifest includes ash_gleam resources, ffi exports, and gleam actions" do
    manifest = AshGleam.manifest(otp_app: :ash_gleam)
    resource_key = inspect(AshGleam.TestTodo)
    domain_key = inspect(AshGleam.TestDomain)

    assert manifest.resources[resource_key].gleam_type == "Todo"
    assert manifest.resources[resource_key].module_name == "todo_item"

    assert [
             %{ffi_name: :list_todos, kind: :read},
             %{ffi_name: :create_todo, kind: :create},
             %{ffi_name: :get_todo, kind: :get},
             %{ffi_name: :first_completed_todo, kind: :get},
             %{ffi_name: :destroy_todo, kind: :destroy},
             %{ffi_name: :create_project, kind: :create},
             %{ffi_name: :get_project, kind: :get}
           ] = manifest.domains[domain_key].ffi

    assert Enum.any?(manifest.actions, &(&1.action_name == :add))
    assert Enum.any?(manifest.actions, &(&1.action_name == :mark_completed))
  end

  test "codegen writes manifest, gleam modules, and elixir bridge modules" do
    tmp = Path.join(System.tmp_dir!(), "ash_gleam_codegen_#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf(tmp) end)

    assert :ok = AshGleam.codegen(otp_app: :ash_gleam, output: tmp)

    assert File.exists?(AshGleam.Info.manifest_path(output: tmp))

    gleam_src = AshGleam.Info.gleam_dir(output: tmp)

    assert File.exists?(Path.join(gleam_src, "todo_item.gleam"))
    assert File.exists?(Path.join(gleam_src, "list_todos.gleam"))
    assert File.exists?(Path.join(gleam_src, "create_todo.gleam"))
    assert File.exists?(Path.join(gleam_src, "get_todo.gleam"))
    assert File.exists?(Path.join(gleam_src, "first_completed_todo.gleam"))
    assert File.exists?(Path.join(gleam_src, "destroy_todo.gleam"))
    assert File.read!(Path.join(gleam_src, "todo_item.gleam")) =~ "pub type Todo"

    assert File.read!(Path.join(gleam_src, "list_todos.gleam")) =~
             "pub fn run(builder: ListTodos)"

    assert File.read!(Path.join(gleam_src, "list_todos.gleam")) =~
             "import #{AshGleam.Info.gleam_module_prefix(output: tmp)}/todo_item."

    bridge_path =
      Path.join(AshGleam.Info.elixir_dir(output: tmp), "ash_gleam/test_domain/generated.ex")

    assert File.exists?(bridge_path)
    assert File.read!(bridge_path) =~ "defmodule AshGleam.TestDomain.Generated do"
  end

  test "codegen emits Gleam union types for constrained atom fields" do
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
            type_name "TicTacToe"
            module_name("tic_tac_toe")
          end

          attributes do
            uuid_primary_key :id

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

            attribute :board, {:array, :atom} do
              public? true
              allow_nil? true
              constraints items: [one_of: [:x, :o, :empty]]
            end
          end
        end
      end

    compiled = Code.compile_quoted(quoted)
    assert length(compiled) >= 2

    tmp = Path.join(System.tmp_dir!(), "ash_gleam_codegen_atoms_#{suffix}")

    on_exit(fn ->
      File.rm_rf(tmp)

      Application.put_env(
        :ash_gleam,
        :ash_domains,
        Application.get_env(:ash_gleam, :default_ash_domains)
      )
    end)

    Application.put_env(:ash_gleam, :ash_domains, [domain])

    assert :ok = AshGleam.codegen(otp_app: :ash_gleam, output: tmp)

    gleam_src = AshGleam.Info.gleam_dir(output: tmp)
    generated = File.read!(Path.join(gleam_src, "tic_tac_toe.gleam"))
    current_player_types = File.read!(Path.join(gleam_src, "current_player.gleam"))
    assert File.read!(Path.join(gleam_src, "board.gleam"))
    winner_types = File.read!(Path.join(gleam_src, "winner.gleam"))

    refute generated =~
             """
             pub type CurrentPlayer {
               X
               O
             }
             """

    refute generated =~
             """
             pub type Winner {
               X
               O
               Draw
             }
             """

    assert generated =~
             "import #{AshGleam.Info.gleam_module_prefix(output: tmp)}/current_player.{type CurrentPlayer}"

    assert generated =~
             "import #{AshGleam.Info.gleam_module_prefix(output: tmp)}/winner.{type Winner}"

    assert generated =~ "current_player: CurrentPlayer"
    assert generated =~ "winner: Option(Winner)"

    assert current_player_types =~
             """
             pub type CurrentPlayer {
               X
               O
             }
             """

    assert winner_types =~
             """
             pub type Winner {
               X
               O
               Draw
             }
             """
  end

  test "codegen de-duplicates reusable sum type modules across resources and actions" do
    suffix = System.unique_integer([:positive])
    domain = Module.concat([AshGleam, Dynamic, :"ReusableEnumDomain#{suffix}"])
    mark = Module.concat([AshGleam, Dynamic, :"Mark#{suffix}"])
    resource_one = Module.concat([AshGleam, Dynamic, :"ReusableEnumResourceOne#{suffix}"])
    resource_two = Module.concat([AshGleam, Dynamic, :"ReusableEnumResourceTwo#{suffix}"])

    quoted =
      quote do
        defmodule unquote(mark) do
          use AshSumType

          variant :a
          variant :b
          variant :c
        end

        defmodule unquote(domain) do
          use Ash.Domain, otp_app: :ash_gleam

          resources do
            resource unquote(resource_one)
            resource unquote(resource_two)
          end
        end

        defmodule unquote(resource_one) do
          use Ash.Resource,
            otp_app: :ash_gleam,
            domain: unquote(domain),
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshGleam.Resource, AshGleam.Actions]

          ets do
            private? true
          end

          gleam do
            type_name "ReusableOne"
            module_name("reusable_one")

            actions do
              action :next_mark, unquote(mark) do
                run &:test_gleam.next_mark/0
              end
            end
          end

          attributes do
            uuid_primary_key :id
            attribute :primary_mark, unquote(mark), public?: true
            attribute :secondary_mark, unquote(mark), public?: true
          end
        end

        defmodule unquote(resource_two) do
          use Ash.Resource,
            otp_app: :ash_gleam,
            domain: unquote(domain),
            data_layer: Ash.DataLayer.Ets,
            extensions: [AshGleam.Resource]

          ets do
            private? true
          end

          gleam do
            type_name "ReusableTwo"
            module_name("reusable_two")
          end

          attributes do
            uuid_primary_key :id
            attribute :mark, unquote(mark), public?: true
          end
        end
      end

    compiled = Code.compile_quoted(quoted)
    assert length(compiled) >= 4

    tmp = Path.join(System.tmp_dir!(), "ash_gleam_codegen_reusable_enum_#{suffix}")

    on_exit(fn ->
      File.rm_rf(tmp)

      Application.put_env(
        :ash_gleam,
        :ash_domains,
        Application.get_env(:ash_gleam, :default_ash_domains)
      )
    end)

    Application.put_env(:ash_gleam, :ash_domains, [domain])

    assert :ok = AshGleam.codegen(otp_app: :ash_gleam, output: tmp)

    gleam_src = AshGleam.Info.gleam_dir(output: tmp)
    enum_path = Path.join(gleam_src, "ash_gleam/dynamic/mark#{suffix}.gleam")
    resource_one_source = File.read!(Path.join(gleam_src, "reusable_one.gleam"))
    resource_two_source = File.read!(Path.join(gleam_src, "reusable_two.gleam"))

    assert File.exists?(enum_path)

    assert File.read!(enum_path) =~
             """
             pub type Mark#{suffix} {
               A
               B
               C
             }
             """

    assert resource_one_source =~
             """
             /ash_gleam/dynamic/mark#{suffix}.{
               type Mark#{suffix},
             }
             """

    assert resource_two_source =~
             """
             /ash_gleam/dynamic/mark#{suffix}.{
               type Mark#{suffix},
             }
             """

    assert [enum_path] ==
             Path.wildcard(Path.join(gleam_src, "**/mark#{suffix}.gleam"))
  end

  test "codegen emits reusable union modules once and references them from resources" do
    suffix = System.unique_integer([:positive])
    domain = Module.concat([AshGleam, Dynamic, :"ReusableUnionDomain#{suffix}"])
    player = Module.concat([AshGleam, Dynamic, :"Player#{suffix}"])
    winner = Module.concat([AshGleam, Dynamic, :"Winner#{suffix}"])
    resource = Module.concat([AshGleam, Dynamic, :"ReusableUnionResource#{suffix}"])

    quoted =
      quote do
        defmodule unquote(player) do
          use AshSumType

          variant :x
          variant :o
        end

        defmodule unquote(winner) do
          use AshSumType

          variant :draw

          variant :player do
            field :player, unquote(player), allow_nil?: false
          end
        end

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
            extensions: [AshGleam.Resource, AshGleam.Actions]

          ets do
            private? true
          end

          gleam do
            type_name "ReusableWinner"
            module_name("reusable_winner")
          end

          attributes do
            uuid_primary_key :id
            attribute :winner, unquote(winner), public?: true
          end
        end
      end

    compiled = Code.compile_quoted(quoted)
    assert length(compiled) >= 4

    tmp = Path.join(System.tmp_dir!(), "ash_gleam_codegen_reusable_union_#{suffix}")

    on_exit(fn ->
      File.rm_rf(tmp)

      Application.put_env(
        :ash_gleam,
        :ash_domains,
        Application.get_env(:ash_gleam, :default_ash_domains)
      )
    end)

    Application.put_env(:ash_gleam, :ash_domains, [domain])

    assert :ok = AshGleam.codegen(otp_app: :ash_gleam, output: tmp)

    gleam_src = AshGleam.Info.gleam_dir(output: tmp)
    winner_path = Path.join(gleam_src, "ash_gleam/dynamic/winner#{suffix}.gleam")
    player_path = Path.join(gleam_src, "ash_gleam/dynamic/player#{suffix}.gleam")
    resource_source = File.read!(Path.join(gleam_src, "reusable_winner.gleam"))

    assert File.exists?(winner_path)
    assert File.exists?(player_path)

    assert File.read!(winner_path) =~
             """
             pub type Winner#{suffix} {
               Draw
               Player(player: Player#{suffix})
             }
             """

    assert resource_source =~
             """
             /ash_gleam/dynamic/winner#{suffix}.{
               type Winner#{suffix},
             }
             """

    assert [winner_path] ==
             Path.wildcard(Path.join(gleam_src, "**/winner#{suffix}.gleam"))
  end

  test "resource validation rejects atom fields without one_of constraint" do
    suffix = System.unique_integer([:positive])
    domain = Module.concat([AshGleam, Dynamic, :"InvalidAtomDomain#{suffix}"])
    resource = Module.concat([AshGleam, Dynamic, :"InvalidAtomResource#{suffix}"])

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

  test "codegen emits Gleam union types for constrained arrays of atoms" do
    suffix = System.unique_integer([:positive])
    domain = Module.concat([AshGleam, Dynamic, :"AtomArrayDomain#{suffix}"])
    resource = Module.concat([AshGleam, Dynamic, :"AtomArrayResource#{suffix}"])

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
            type_name "BoardState"
            module_name("board_state")
          end

          attributes do
            uuid_primary_key :id

            attribute :board, {:array, :atom} do
              public? true
              allow_nil? false
              constraints items: [one_of: [:x, :o, :empty]]
            end
          end
        end
      end

    compiled = Code.compile_quoted(quoted)
    assert length(compiled) >= 2

    tmp = Path.join(System.tmp_dir!(), "ash_gleam_codegen_atom_arrays_#{suffix}")

    on_exit(fn ->
      File.rm_rf(tmp)

      Application.put_env(
        :ash_gleam,
        :ash_domains,
        Application.get_env(:ash_gleam, :default_ash_domains)
      )
    end)

    Application.put_env(:ash_gleam, :ash_domains, [domain])

    assert :ok = AshGleam.codegen(otp_app: :ash_gleam, output: tmp)

    gleam_src = AshGleam.Info.gleam_dir(output: tmp)
    generated = File.read!(Path.join(gleam_src, "board_state.gleam"))
    board_types = File.read!(Path.join(gleam_src, "board.gleam"))

    assert generated =~
             "import #{AshGleam.Info.gleam_module_prefix(output: tmp)}/board.{type Board}"

    assert generated =~ "board: List(Board)"

    assert board_types =~
             """
             pub type Board {
               X
               O
               Empty
             }
             """
  end

  test "test env codegen defaults write under test/generated/ash_gleam" do
    # on_exit(fn -> File.rm_rf!(AshGleam.Info.output_dir()) end)

    File.rm_rf!(AshGleam.Info.output_dir())

    assert :ok = AshGleam.codegen(otp_app: :ash_gleam)

    assert File.exists?("#{AshGleam.Info.manifest_path()}")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/todo_item.gleam")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/list_todos.gleam")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/create_todo.gleam")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/get_todo.gleam")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/first_completed_todo.gleam")
    assert File.exists?("#{AshGleam.Info.gleam_dir()}/destroy_todo.gleam")
    assert File.exists?("#{AshGleam.Info.elixir_dir()}/ash_gleam/test_domain/generated.ex")

    assert File.read!("#{AshGleam.Info.gleam_dir()}/list_todos.gleam") =~
             "import #{AshGleam.Info.gleam_module_prefix()}/todo_item."
  end
end
