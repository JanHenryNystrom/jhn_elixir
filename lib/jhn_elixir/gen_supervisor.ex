defmodule JhnElixir.Supervisor do

  alias JhnElixir.Gen

  # ====================
  # API
  # ====================

  # --------------------
  @spec start(any, options) :: on_start
  # --------------------
  def start(children, options \\ []) do
    name = case Keyword.get(options, :name) do
             nil -> :self
             name -> name
           end
    init_args = {children, options}
    Gen.start(:gen_server, :supervisor, {name, __MODULE__, init_args}, options)
  end

  # --------------------
  @spec stop(server, reason :: term, timeout) :: :ok
  # --------------------
  def stop(server, reason \\ :normal, timeout \\ :infinity) do
    Gen.stop(server, reason, timeout)
  end

  # --------------------
  @spec start_child(server, child_spec) :: on_child_start
  # --------------------
  def start_child(server, spec) do
    Gen.call(server, {:start_child, child(spec)}, :infinity)
  end

  # --------------------
  @spec get_childspec(server, id :: id) :: {:ok, child_spec} | {:error, term}
  # --------------------
  def get_childspec(server, id) do
    Gen.call(server, {:get_childspec, id}, :infinity)
  end

  # --------------------
  @spec terminate_child(server, id :: id) :: :ok | {:error, term}
  # --------------------
  def terminate_child(server, id) do
    Gen.call(server, {:terminate_child, id}, :infinity)
  end

 # --------------------
  @spec restart_child(server, id :: id) :: :ok | {:error, term}
  # --------------------
  def restart_child(server, id) do
    Gen.call(server, {:restart_child, id}, :infinity)
  end

  # --------------------
  @spec delete_child(server, id :: id) :: :ok | {:error, term}
  # --------------------
  def delete_child(server, id) do
    Gen.call(server, {:delete_child, id}, :infinity)
  end

  # --------------------
  @spec which_children(server) :: child_desc
  # --------------------
  def which_children(server) do
    Gen.call(server, :which_children, 5000)
  end

  # ====================
  # Supervisor callback
  # ====================

  # --------------------
  @spec init({[child_spec], options}) :: :ok | {:error, term}
  # --------------------
  def init({children, options}) do
    strategy = Keyword.get(options, :strategy, :one_for_one)
    intensity = Keyword.get(options, :max_restarts, 0)
    period = Keyword.get(options, :max_seconds, 1)
    flags = %{strategy: strategy, intensity: intensity, period: period}
    {:ok, {flags, Enum.map(children, &child/1)}}
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

  @optional_callbacks init: 1

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

  @type id :: pid | term

  @type on_child_start :: {:ok, pid} |
                          {:ok, pid, term} |
                          {:error, start_child_error}

  @type start_child_error :: :already_present | {:already_present, term} | term

  @type child_spec :: module | {module, term} | :supervisor.child_spec

  @type child_desc :: [{:undefined | id,
                        :undefined | :restarting | pid,
                        :worker | :supervisor,
                        [module] | :dynamic}]

  # ====================
  # Macros
  # ====================

  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour Supervisor

      def child_spec(init_arg) do
        default = %{id: __MODULE__,
                    start: {__MODULE__, :start_link, [init_arg]}}
        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end
      defoverridable child_spec: 1
    end
  end

  # ====================
  # Internal functions
  # ====================

  defp child(module) when is_atom(module) do
    child({module, :no_arg})
  end
  defp child({module, arg}) do
    module.child_spec(arg)
  end
  defp child(map) when is_map(map) do
    map
  end
  defp child({_, _, _, _, _, _} = tuple) do
    tuple
  end

end