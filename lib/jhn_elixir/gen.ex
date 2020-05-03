defmodule JhnElixir.Gen do

  require Logger

  # ====================
  # API
  # ====================

  def start(behaviour, module, init_arg, options) do
    {link, options} = Keyword.pop(options, :link, :link)
    case Keyword.pop(options, :name) do
      {nil, opts} ->
        :gen.start(behaviour, link, module, init_arg, opts)
      {global = {:global, _}, opts} ->
        :gen.start(behaviour, link, global, module, init_arg, opts)
      {via = {:via, _, _}, opts} ->
        :gen.start(behaviour, link, via, module, init_arg, opts)
      {name, opts} ->
        :gen.start(behaviour, link, {:local, name}, module, init_arg, opts)
    end
  end

  def stop(server, reason, timeout) do
    :proc_lib.stop(server, reason, timeout)
  end

  def call(server, request, timeout) do
    :gen.call(server, :"$gen_call", request, timeout)
  end

  def cast(server, message) do
    try do
      do_cast(server, {:"$gen_cast", message})
    catch
      _, _ -> :ok
    end
    :ok
  end

  def reply(from, reply) do
    :gen.reply(from, reply)
  end

  def unexpected(module, type, message) do
    me = self()
    id = case Process.info(me, :registered_name) do
           {_, []} -> me
           {_, name} -> name
         end
    Logger.warn("#{module}, #{inspect(id)} Unexpected #{inspect(type)} #{inspect(message)}}")
  end

  # ====================
  # Internal functions
  # ====================

  defp do_cast({:global, name}, message) do
    :global.send(name, message)
  end
  defp do_cast({:via, module, name}, message) do
    module.send(name, message)
  end
  defp do_cast(server, message) do
    :erlang.send(server, message)
  end


end
