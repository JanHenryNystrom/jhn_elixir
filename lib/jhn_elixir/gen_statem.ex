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
defmodule JhnElixir.GenStatem do
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
    Gen.start(:gen_statem, module, init_arg, options)
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
  @spec cast(server, term) :: :ok
  # --------------------
  def cast(server, message) do
    Gen.cast(server, message)
  end

  # --------------------
  @spec reply(reply_action | [reply_action]) :: :ok
  # --------------------
  def reply({:reply, from, reply}) do
    reply(from, reply)
  end
  def reply(reply_actions) do
    for {:reply, from, reply} <- reply_actions do
      reply(from, reply)
    end
    :ok
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

  @callback callback_mode() :: callback_mode | [callback_mode | :state_enter]

  @callback init(init_arg :: term) ::
    {:ok, state, data}
    | {:ok, state, data, actions :: action | [action]}
    | :ignore
    | {:stop, reason :: any}
      when state: atom, data: any

  @callback terminate(reason, state :: term) :: term
      when reason: :normal | :shutdown | {:shutdown, term} | term

  @callback code_change(old_vsn, state :: term, extra :: term) ::
    {:ok, new_state :: term}
    | {:error, reason :: term}
      when old_vsn: term | {:down, term}

  @callback format_status(reason, pdict_and_state :: list) :: term
      when reason: :normal | :terminate

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

  @type reply_action :: {:reply, from, term}

  @type callback_mode :: :state_functions | :handle_event_function

  @type action :: :postpone | {:postpone, boolean} |
                  {:next_event, event_type, term} |
                  :hibernate | {:hibernate, boolean} |
                  timeout_action | reply_action

  @type event_type :: external_event_type | timeout_event_type | :internal

  @type external_event_type :: {:call, from} | :cast | :info

  @type timeout_event_type :: :timeout | {:timeout, term} | :state_timeout

  @type timeout_action :: term

  # ====================
  # Macros
  # ====================

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour JhnElixir.GenStatem

      def child_spec(init_arg) do
        default = %{id: __MODULE__,
                    start: {__MODULE__, :start, [init_arg]}}
        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      # TODO: Remove this on v2.0
      @before_compile JhnElixir.GenStatem

      def callback_mode() do
        :state_functions
      end

      def handle_event(event, content, state, data) do
        Gen.unexpected(__MODULE__, :event, event)
        :keep_state_and_data
      end

      def terminate(_, _) do
        :ok
      end

      def code_change(_, state, _) do
        {:ok, state}
      end

      defoverridable child_spec: 1,
                     callback_mode: 0,
                     handle_event: 4,
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

end
