defmodule GenServerTest do
  use ExUnit.Case, async: true

  defmodule Stack do
    use JhnElixir.GenServer

    def init(args) do
      {:ok, args}
    end

    def handle_call(:pop, _, [h | t]) do
      {:reply, h, t}
    end
    def handle_call(:noreply, _, h) do
      {:noreply, h}
    end

    def handle_cast({:push, element}, state) do
      {:noreply, [element | state]}
    end

    def terminate(_, _) do
      # There is a race condition if the agent is
      # restarted too fast and it is registered.
      try do
        self() |>
          Process.info(:registered_name) |>
          elem(1) |>
          Process.unregister()
      rescue
        _ -> :ok
      end

      :ok
    end
  end

  test "generates child_spec/1" do
    assert Stack.child_spec([:hello]) == %{
             id: Stack,
             start: {Stack, :start, [[:hello]]}
           }

    defmodule CustomStack do
      use JhnElixir.GenServer, id: :id,
                               restart: :temporary,
                               shutdown: :infinity,
                               start: {:foo, :bar, []}

      def init(args) do
        {:ok, args}
      end
    end

    assert CustomStack.child_spec([:hello]) == %{
             id: :id,
             restart: :temporary,
             shutdown: :infinity,
             start: {:foo, :bar, []}
           }
  end

  test "start/3 with via" do
    JhnElixir.GenServer.start(Stack,
                             [:hello],
                             name: {:via, :global, :via_stack})
    assert JhnElixir.GenServer.call({:via, :global, :via_stack}, :pop) == :hello
  end

  test "start/3 with global" do
    JhnElixir.GenServer.start(Stack, [:hello], name: {:global, :global_stack})
    assert JhnElixir.GenServer.call({:global, :global_stack}, :pop) == :hello
  end

  test "start/3 with local" do
    JhnElixir.GenServer.start(Stack, [:hello], name: :stack)
    assert JhnElixir.GenServer.call(:stack, :pop) == :hello
  end

  test "start/2, call/2 and cast/2" do
    {:ok, pid} = JhnElixir.GenServer.start(Stack, [:hello])

    {:links, links} = Process.info(self(), :links)
    assert pid in links

    assert JhnElixir.GenServer.call(pid, :pop) == :hello
    assert JhnElixir.GenServer.cast(pid, {:push, :world}) == :ok
    assert JhnElixir.GenServer.call(pid, :pop) == :world
    assert JhnElixir.GenServer.stop(pid) == :ok

    assert JhnElixir.GenServer.cast({:global, :foo}, {:push, :world}) == :ok
    assert JhnElixir.GenServer.cast({:via, :foo, :bar}, {:push, :world}) == :ok
    assert JhnElixir.GenServer.cast(:foo, {:push, :world}) == :ok
  end

  @tag capture_log: true
  test "call/3 exit messages" do
    name = :self
    Process.register(self(), name)
    :global.register_name(name, self())
    {:ok, pid} = JhnElixir.GenServer.start(Stack, [:hello])
    {:ok, stopped_pid} =
      JhnElixir.GenServer.start(Stack, [:hello], link: :nolink)
    JhnElixir.GenServer.stop(stopped_pid)

    assert catch_exit(JhnElixir.GenServer.call(name, :pop, 50)) ==
             :timeout

    assert catch_exit(JhnElixir.GenServer.call({:global, name}, :pop, 50)) ==
             :timeout

    assert catch_exit(JhnElixir.GenServer.call({:via, :global, name},
                                               :pop,
                                               50)) ==
             :timeout

    assert catch_exit(JhnElixir.GenServer.call(self(), :pop, 50)) ==
             :timeout

    assert catch_exit(JhnElixir.GenServer.call(pid, :noreply, 1)) ==
             :timeout

    assert catch_exit(JhnElixir.GenServer.call(nil, :pop, 50)) ==
             :noproc

    assert catch_exit(JhnElixir.GenServer.call(stopped_pid, :pop, 50)) ==
             :noproc

    assert catch_exit(JhnElixir.GenServer.call({:stack, :bogus_node},
                                               :pop,
                                               50)) ==
             {:nodedown, :bogus_node}
  end

  test "nil name" do
    {:ok, pid} = JhnElixir.GenServer.start(Stack, [:hello], name: nil)
    assert Process.info(pid, :registered_name) == {:registered_name, []}
  end

  test "start/2" do
    {:ok, pid} = JhnElixir.GenServer.start(Stack, [:hello], link: :nolink)
    {:links, links} = Process.info(self(), :links)
    refute pid in links
    JhnElixir.GenServer.stop(pid)
  end

  test "abcast/3", %{test: name} do
    {:ok, _} = JhnElixir.GenServer.start(Stack, [], name: name)

    assert JhnElixir.GenServer.abcast(name, {:push, :hello}) == :abcast
    assert JhnElixir.GenServer.call({name, node()}, :pop) == :hello

    assert JhnElixir.GenServer.abcast([node(), :foo@bar],
                                      name,
                                      {:push, :world}) == :abcast
    assert JhnElixir.GenServer.call(name, :pop) == :world
  end

  test "multi_call/4", %{test: name} do
    {:ok, _} = JhnElixir.GenServer.start(Stack, [:hello, :world], name: name)

    assert JhnElixir.GenServer.multi_call(name, :pop) ==
             {[{node(), :hello}], []}

    assert JhnElixir.GenServer.multi_call([node(), :foo@bar], name, :pop) ==
             {[{node(), :world}], [:foo@bar]}
  end

  test "stop/3", %{test: name} do
    {:ok, pid} = JhnElixir.GenServer.start(Stack, [], link: :nolink)
    assert JhnElixir.GenServer.stop(pid, :normal) == :ok

    stopped_pid = pid

    assert catch_exit(JhnElixir.GenServer.stop(stopped_pid)) ==
             :noproc

    assert catch_exit(JhnElixir.GenServer.stop(nil)) ==
             :noproc


    {:ok, _} = JhnElixir.GenServer.start(Stack, [], name: name, link: :nolink)
    assert JhnElixir.GenServer.stop(name, :normal) == :ok
  end
end

