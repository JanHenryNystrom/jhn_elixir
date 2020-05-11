defmodule GenManagedTest do
  use ExUnit.Case, async: true

  defmodule Stack do
    use JhnElixir.GenServer

    def start(stack) do
      JhnElixir.GenServer.start(__MODULE__, stack)
    end

    def init(args) do
      {:ok, args}
    end

    def handle_call(:pop, _, [h | t]) do
      {:reply, h, t}
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


  test "start" do

    {:ok, pid} = JhnElixir.Managed.start(Stack, name: :stacks)

    {:links, links} = Process.info(self(), :links)
    assert pid in links

    {:ok, pid} = JhnElixir.Managed.add(:stacks, :stack_one, [[:hello]])

    assert JhnElixir.GenServer.call(pid, :pop) == :hello
    assert JhnElixir.GenServer.cast(pid, {:push, :world}) == :ok
    assert JhnElixir.GenServer.call(pid, :pop) == :world

    assert JhnElixir.Managed.lookup(:stacks, :stack_one) == {:ok, pid}

    assert JhnElixir.Managed.remove(:stacks, :stack_one) == :ok
  end

end
