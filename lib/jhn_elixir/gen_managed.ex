##==============================================================================
## Copyright 2020 Jan Henry Nystrom <JanHenryNystrom@gmail.com>
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
## http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##==============================================================================

defmodule JhnElixir.Managed do
  Module.register_attribute __MODULE__, :copyright, persist: true
  @copyright "(C) 2020, Jan Henry Nystrom <JanHenryNystrom@gmail.com>"
  use JhnElixir.Supervisor
  alias JhnElixir.Managed.Manager

  # ====================
  # API
  # ====================

  # --------------------
  @spec add(atom, term, term) :: {:ok, pid} | {:error, term}
  # --------------------
  def add(managed, id, init_data) do
    GenServer.call(managed, {:add, id, init_data})
  end

  # --------------------
  @spec remove(atom, term) :: :ok | {:error, term}
  # --------------------
  def remove(managed, id) do
    GenServer.call(managed, {:remove, id})
  end

  # --------------------
  @spec lookup(atom, term) :: {:ok, pid} | nil
  # --------------------
  def lookup(managed, id) do
    GenServer.call(managed, {:lookup, id})
  end

  # ====================
  # Management API
  # ====================

  # --------------------
  @spec start(module, [option]) :: on_start
  # --------------------
  def start(module, options \\ []) do
    name = Keyword.get(options, :name)
    children = [{Manager, name},
                {JhnElixir.Managed.Supervisor, {name, module}}]
    JhnElixir.Supervisor.start(children, strategy: :rest_for_one)
  end

  # ====================
  # Types
  # ====================

  @type on_start :: {:ok, pid} |
                    :ignore |
                    {:error, {:already_started, pid} | term}

  @type option :: {:name, atom} | {:hibernate_after, timeout}

end

defmodule JhnElixir.Managed.Manager do
  Module.register_attribute __MODULE__, :copyright, persist: true
  @copyright "(C) 2020, Jan Henry Nystrom <JanHenryNystrom@gmail.com>"
  @moduledoc false
  use JhnElixir.GenServer
  alias JhnElixir.Supervisor
  require Logger

  # ====================
  # API
  # ====================

  # ====================
  # Management API
  # ====================

  # --------------------
  @spec start([option]) :: on_start
  # --------------------
  def start(options) do
    JhnElixir.GenServer.start(__MODULE__, :no_arg, options)
  end

  # ====================
  # Supervisor API
  # ====================

  # --------------------
  @spec supervisor(atom, pid) :: :ok
  # --------------------

  def supervisor(name, pid) do
    JhnElixir.GenServer.cast(name, {:supervisor, pid})
  end

  # ====================
  # Supervisor callback
  # ====================
  def child_spec(name) do
    default = %{id: __MODULE__,
                start: {__MODULE__, :start, [[name: name]]}}
    Supervisor.child_spec(default, [])
  end

  # ====================
  # GenServer callbacks
  # ====================
  def init(:no_arg) do
    Process.flag(:trap_exit, true)
    {:ok, %{:managed => []}}
  end

  def handle_call({:add, id, data}, _, state) do
    case List.keymember?(state[:managed], id, 0) do
      true -> {:reply, {:error, :already_managed}, state}
      false ->
        {:ok, pid} = Supervisor.start_child(state[:supervisor], data)
        try do
          Process.link(pid)
        catch _, _ ->
            {:reply, {:error, :died_on_start}, state}
        else
          _ ->
            state = Map.put(state, :managed, [{id, pid} | state[:managed]])
          {:reply, {:ok, pid}, state}
        end
    end
  end
  def handle_call({:remove, id}, _, state) do
    case List.keyfind(state[:managed], id, 0) do
      nil -> {:reply, {:error, :not_managed}, state}
      {_, pid} ->
        :ok = Supervisor.terminate_child(state[:supervisor], pid)
        state = Map.put(state, :managed, List.keydelete(state[:managed], id, 0))
        {:reply, :ok, state}
    end
  end
  def handle_call({:lookup, id}, _, state) do
    case List.keyfind(state[:managed], id, 0) do
      {_, pid} -> {:reply, {:ok, pid}, state}
      _ -> {:reply, nil, state}
    end
  end

  def handle_info({:EXIT, pid, reason}, state) do
    case {List.keyfind(state[:managed], pid, 1), reason} do
      {nil, _} -> {:noreply, state}
      {{_, _}, :normal} -> {:noreply, state}
      {{_, _}, :shutdown} -> {:noreply, state}
      {{id, _}, _} ->
        Logger.warn("Manged #{inspect(id)} exited #{inspect(reason)}")
        state = Map.put(state, :managed, List.keydelete(state[:managed], id, 0))
        {:noreply, state}
    end
  end

  def handle_cast({supervisor, pid}, state) do
    {:noreply, Map.put(state, supervisor, pid)}
  end

  # ====================
  # Types
  # ====================

  @type on_start :: {:ok, pid} |
                    :ignore |
                    {:error, {:already_started, pid} | term}

  @type option :: {:name, atom} | {:hibernate_after, timeout}

end

defmodule JhnElixir.Managed.Supervisor do
  Module.register_attribute __MODULE__, :copyright, persist: true
  @copyright "(C) 2020, Jan Henry Nystrom <JanHenryNystrom@gmail.com>"
  @moduledoc false
  use JhnElixir.Supervisor
  alias JhnElixir.Managed.Manager

  # ====================
  # Management API
  # ====================

  # --------------------
  @spec start(atom, module) :: on_start
  # --------------------
  def start(manager, module) do
    options = [strategy: :simple_one_for_one]
    {:ok, pid} =
      JhnElixir.Supervisor.start({__MODULE__, {module, options}})
    Manager.supervisor(manager, pid)
    {:ok, pid}
  end

  # ====================
  # Supervisor callback
  # ====================

  def init({module, options}) do
    default = %{id: __MODULE__, start: {module, :start, []}}
    child = JhnElixir.Supervisor.child_spec(default, [])
    JhnElixir.Supervisor.init([child], options)
  end

  def child_spec({name, module}) do
    default = %{id: __MODULE__,
                start: {__MODULE__, :start, [name, module]},
                type: :supervisor,
                shutdown: :infinity}
    JhnElixir.Supervisor.child_spec(default, [])
  end

  # ====================
  # Types
  # ====================

  @type on_start :: {:ok, pid} |
                    :ignore |
                    {:error, {:already_started, pid} | term}

end
