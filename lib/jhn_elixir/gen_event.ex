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
defmodule JhnElixir.GenEvent do
  Module.register_attribute __MODULE__, :copyright, persist: true
  @copyright "(C) 2020, Jan Henry Nystrom <JanHenryNystrom@gmail.com>"
  alias JhnElixir.Gen
  alias JhnElixir.Supervisor

  # ====================
  # API
  # ====================

  # --------------------
  @spec start(options) :: on_start
  # --------------------
  def start(options \\ []) do
    Gen.start(:gen_event, 'no callback module', [], options)
  end

  # --------------------
  @spec stop(manager, reason :: term, timeout) :: :ok
  # --------------------
  def stop(manager, reason \\ :normal, timeout \\ :infinity) do
    Gen.stop(manager, reason, timeout)
  end

  # --------------------
  @spec notify(manager, term) :: :ok
  # --------------------
  def notify({:global, name}, event) do
    :global.send(name, {:notify, event})
  end
  def notify({:via, module, name}, event) do
    module.send(name, {:notify, event})
  end
  def notify(manager, event) do
    :erlang.send(manager, {:notify, event})
  end

  # --------------------
  @spec sync_notify(manager, term) :: :ok
  # --------------------
  def sync_notify(manager, event) do
    rpc(manager, {:sync_notify, event})
  end

  # --------------------
  @spec call(manager, handler, term, timeout) :: term
  # --------------------
  def call(manager, handler, request, timeout \\ 5000) do
    {:ok, result} = :gen.call(manager, self(), {:call, handler,request},timeout)
    result
  end

  # --------------------
  @spec add_handler(manager, handler, term) :: term
  # --------------------
  def add_handler(manager, handler, args) do
    rpc(manager, {:add_handler, handler, args})
  end

  # --------------------
  @spec add_sup_handler(manager, handler, term) :: term
  # --------------------
  def add_sup_handler(manager, handler, args) do
    rpc(manager, {:add_sup_handler, handler, args, self()})
  end

  # --------------------
  @spec delete_handler(manager, handler, term) :: term
  # --------------------
  def delete_handler(manager, handler, args) do
    rpc(manager, {:delete_handler, handler, args})
  end

  # --------------------
  @spec swap_handler(manager, {handler, term}, {handler, term}) :: term
  # --------------------
  def swap_handler(manager, {handler1, args1}, {handler2, args2}) do
    rpc(manager, {:swap_handler, handler1, args1, handler2, args2})
  end

  # --------------------
  @spec swap_sup_handler(manager, {handler, term}, {handler, term}) :: term
  # --------------------
  def swap_sup_handler(manager, {handler1, args1}, {handler2, args2}) do
    rpc(manager, {:swap_sup_handler, handler1, args1, handler2, args2, self()})
  end

  # --------------------
  @spec which_handlers(manager) :: [handler]
  # --------------------
  def which_handlers(manager) do
    rpc(manager, :which_handlers)
  end

  # ====================
  # Callbacks
  # ====================

  @callback init(init_arg :: term) ::
    {:ok, state}
    | {:ok, state, :hibernate}
    | {:error, term}
      when state: term

  @callback handle_call(request :: term, state :: term) ::
    {:ok, reply, new_state}
    | {:ok, reply, new_state, :hibernate}
    | {:swap_handler, reply, args1, new_state, handler2, args2}
    | {:remove_handler, reply}
      when reply: term,
           new_state: term,
           args1: term,
           args2: term,
           handler2: term

  @callback handle_event(event :: term, state :: term) ::
    {:ok, new_state}
    | {:ok, new_state, :hibernate}
    | {:swap_handler, args1, new_state, handler2, args2}
    | :remove_handler
      when new_state: term,
           args1: term,
           args2: term,
           handler2: term

  @callback handle_info(info :: term, state :: term) ::
    {:ok, new_state}
    | {:ok, new_state, :hibernate}
    | {:swap_handler, args1, new_state, handler2, args2}
    | :remove_handler
      when new_state: term,
           args1: term,
           args2: term,
           handler2: term

  @callback terminate(reason :: term, state :: term) :: term

  @callback code_change(old_vsn, state :: term, extra :: term) ::
    {:ok, new_state :: term}
    | {:error, reason :: term}
      when old_vsn: term | {:down, term}

  @callback format_status(reason, pdict_and_state :: list) :: term
      when reason: :normal | :terminate

  @optional_callbacks code_change: 3,
                      terminate: 2,
                      handle_info: 2,
                      handle_event: 2,
                      handle_call: 2,
                      format_status: 2

  # ====================
  # Types
  # ====================

  @type on_start :: {:ok, pid} |
                    :ignore |
                    {:error, {:already_started, pid} | term}

  @type name :: atom | {:global, term} | {:via, module, term}

  @type link :: :link | :nolink

  @type options :: [option]

  @type option ::
          {:name, name} |
          {:link, link} |
          {:debug, debug} |
          {:timeout, timeout} |
          {:spawn_opt, Process.spawn_opt()} |
          {:hibernate_after, timeout}

  @type debug :: [:trace | :log | :statistics | {:log_to_file, Path.t()}]

  @type manager :: pid | name | {atom, node}

  @type handler :: module | {module, term}

  @type from :: {pid, tag :: term}

  # ====================
  # Macros
  # ====================

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour JhnElixir.GenEvent

      def child_spec(_) do
        default = %{id: __MODULE__,
                    start: {__MODULE__, :start, []}}
        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      # TODO: Remove this on v2.0
      @before_compile JhnElixir.GenEvent

      @doc false
      def handle_call(_, state) do
        Gen.unexpected(__MODULE__, :call, msg)
        {:ok, {:error, :unsupported_call}, state}
      end

      @doc false
      def handle_event(_, state) do
        Gen.unexpected(__MODULE__, :event, msg)
        {:ok, state}
      end

      @doc false
      def handle_info(msg, state) do
        Gen.unexpected(__MODULE__, :info, msg)
        {:ok, state}
      end

      @doc false
      def terminate(_, _) do
        :ok
      end

      @doc false
      def code_change(_, state, _) do
        {:ok, state}
      end

      defoverridable child_spec: 1,
                     handle_call: 2,
                     handle_event: 2,
                     handle_info: 2,
                     code_change: 3,
                     terminate: 2
    end
  end

  defmacro __before_compile__(_) do
    :ok
  end

  # ====================
  # Internal functions
  # ====================

  defp rpc(manager, command) do
    {:ok, reply} = :gen.call(manager, self(), command, :infinity)
    reply
  end

end
