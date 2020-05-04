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
defmodule JhnElixir.GenServer do
  Module.register_attribute __MODULE__, :copyright, persist: true
  @copyright "(C) 2020, Jan Henry Nystrom <JanHenryNystrom@gmail.com>"
  alias JhnElixir.Gen
  alias JhnElixir.Supervisor

  # ====================
  # API
  # ====================

  # --------------------
  @spec start(module, any, options) :: on_start
  # --------------------
  def start(module, init_arg, options \\ []) do
    Gen.start(:gen_server, module, init_arg, options)
  end

  # --------------------
  @spec stop(server, reason :: term, timeout) :: :ok
  # --------------------
  def stop(server, reason \\ :normal, timeout \\ :infinity) do
    Gen.stop(server, reason, timeout)
  end

  # --------------------
  @spec call(server, term, timeout) :: term
  # --------------------
  def call(server, request, timeout \\ 5000) do
    Gen.call(server, request, timeout)
  end

  # --------------------
  @spec multi_call([node], name :: atom, term, timeout) ::
          {replies :: [{node, term}], bad_nodes :: [node]}
  # --------------------
  def multi_call(nodes\\[node()|Node.list()],name, req, timeout \\ :infinity) do
    :gen_server.multi_call(nodes, name, req, timeout)
  end

  # --------------------
  @spec cast(server, term) :: :ok
  # --------------------
  def cast(server, message) do
    Gen.cast(server, message)
  end

  # --------------------
  @spec abcast([node], name :: atom, term) :: :abcast
  # --------------------
  def abcast(nodes \\ [node() | Node.list()], name, message) do
    for node <- nodes do
      cast({name, node}, message)
    end
    :abcast
  end

  # --------------------
  @spec reply(from, term) :: :ok
  # --------------------
  def reply(from, reply) do
    Gen.reply(from, reply)
  end

  # ====================
  # Callbacks
  # ====================

  @callback init(init_arg :: term) ::
    {:ok, state}
    | {:ok, state, timeout | :hibernate | {:continue, term}}
    | :ignore
    | {:stop, reason :: any}
      when state: any

  @callback handle_call(request :: term, from, state :: term) ::
    {:reply, reply, new_state}
    | {:reply, reply, new_state, timeout | :hibernate | {:continue, term}}
    | {:noreply, new_state}
    | {:noreply, new_state, timeout | :hibernate | {:continue, term}}
    | {:stop, reason, reply, new_state}
    | {:stop, reason, new_state}
      when reply: term, new_state: term, reason: term

  @callback handle_cast(request :: term, state :: term) ::
    {:noreply, new_state}
    | {:noreply, new_state, timeout | :hibernate | {:continue, term}}
    | {:stop, reason :: term, new_state}
      when new_state: term

  @callback handle_info(msg :: :timeout | term, state :: term) ::
    {:noreply, new_state}
    | {:noreply, new_state, timeout | :hibernate | {:continue, term}}
    | {:stop, reason :: term, new_state}
      when new_state: term

  @callback handle_continue(continue :: term, state :: term) ::
    {:noreply, new_state}
    | {:noreply, new_state, timeout | :hibernate | {:continue, term}}
    | {:stop, reason :: term, new_state}
      when new_state: term

  @callback terminate(reason, state :: term) :: term
      when reason: :normal | :shutdown | {:shutdown, term} | term

  @callback code_change(old_vsn, state :: term, extra :: term) ::
    {:ok, new_state :: term}
    | {:error, reason :: term}
      when old_vsn: term | {:down, term}

  @callback format_status(reason, pdict_and_state :: list) :: term
      when reason: :normal | :terminate

  @optional_callbacks code_change: 3,
                      terminate: 2,
                      handle_info: 2,
                      handle_cast: 2,
                      handle_call: 3,
                      format_status: 2,
                      handle_continue: 2

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

  @type server :: pid | name | {atom, node}

  @type from :: {pid, tag :: term}

  # ====================
  # Macros
  # ====================

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour GenServer

      def child_spec(init_arg) do
        default = %{id: __MODULE__,
                    start: {__MODULE__, :start_link, [init_arg]}}
        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      # TODO: Remove this on v2.0
      @before_compile GenServer

      def handle_call(msg, _from, state) do
        Gen.unexpected(__MODULE__, :call, msg)
        {:noreply, state}
      end

      def handle_cast(msg, state) do
        Gen.unexpected(__MODULE__, :cast, msg)
        {:noreply, state}
      end

      def handle_info(msg, state) do
        Gen.unexpected(__MODULE__, :info, msg)
        {:noreply, state}
      end

      def terminate(_, _) do
        :ok
      end

      def code_change(_, state, _) do
        {:ok, state}
      end

      defoverridable child_spec: 1,
                     handle_call: 3,
                     handle_cast: 2,
                     handle_info: 2,
                     code_change: 3,
                     terminate: 2
    end
  end

  # ====================
  # Internal functions
  # ====================

end
