defmodule Drab do
  require Logger

  @moduledoc """
  Drab allows to query and manipulate the User Interface directly from the Phoenix server backend.

  To enable it on the specific page you must find its controller and 
  enable Drab by `use Drab.Controller` there:

      defmodule DrabExample.PageController do
        use Example.Web, :controller
        use Drab.Controller 

        def index(conn, _params) do
          render conn, "index.html"
        end
      end   

  Notice that it will enable Drab on all the pages generated by `DrabExample.PageController`.

  All Drab functions (callbacks and event handlers) should be placed in a module called 'commander'. It is very
  similar to controller, but it does not render any pages - it works with the live page instead. Each controller with 
  enabled Drab should have the corresponding commander.

      defmodule DrabExample.PageCommander do
        use Drab.Commander

        onload :page_loaded

        # Drab Callbacks
        def page_loaded(socket) do
          socket |> update(:html, set: "Welcome to Phoenix+Drab!", on: "div.jumbotron h2")
          socket |> update(:html, 
                set: "Please visit <a href='https://tg.pl/drab'>Drab</a> page for more examples and description",
                on:  "div.jumbotron p.lead")
        end

        # Drab Events
        def button_clicked(socket, dom_sender) do
          socket |> update(:text, set: "alread clicked", on: this(dom_sender))
        end

      end

  Drab treats browser page as a database, allows you to read and change the data there. Please refer to `Drab.Query` documentation to 
  find out how `Drab.Query.select/2` or `Drab.Query.update/2` works.

  ## Modules

  Drab is modular. You may choose which modules to use in the specific Commander by using `:module` option
  in `use Drab.Commander` directive. By default, `Drab.Query` and `Drab.Modal` are loaded, but you may override it using 
  options with `use Drab.Commander` directive.

  Every module must have the corresponding javascript template, which is added to the client code in case the module is loaded.
  """

  use GenServer

  defstruct store: nil, session: nil, commander: nil

  @doc false
  def start_link(state) do
    GenServer.start_link(__MODULE__, state)
  end

  @doc false
  def init(state) do
    Process.flag(:trap_exit, true)
    {:ok, state}
  end

  @doc false
  def terminate(_reason, %Drab{store: store, session: session, commander: commander} = state) do
    if commander.__drab__().ondisconnect do
      # TODO: timeout
      :ok = apply(commander, 
            commander_config(commander).ondisconnect, 
            [store, session])
    end
    {:noreply, state}
  end

  @doc false
  def handle_info({:EXIT, pid, :normal}, state) when pid != self() do
    # ignore exits of the subprocesses
    {:noreply, state}
  end

  @doc false
  def handle_cast({:onconnect, socket}, %Drab{commander: commander} = state) do
    tasks = [Task.async(fn -> Drab.Core.save_session(socket, Drab.Core.session(socket)) end), 
             Task.async(fn -> Drab.Core.save_store(socket, Drab.Core.store(socket)) end)]
    Enum.each(tasks, fn(task) -> Task.await(task) end)

    onconnect = commander_config(commander).onconnect
    handle_callback(socket, commander, onconnect) #returns socket
    {:noreply, state}
  end

  @doc false
  def handle_cast({:onload, socket}, %Drab{commander: commander} = state) do
    onload = commander_config(commander).onload
    handle_callback(socket, commander, onload) #returns socket
    {:noreply, state}
  end

  @doc false
  def handle_cast({:update_store, store}, %Drab{session: session, commander: commander}) do
    {:noreply, %Drab{store: store, session: session, commander: commander}}
  end

  @doc false
  def handle_cast({:update_session, session}, %Drab{store: store, commander: commander}) do
    {:noreply, %Drab{store: store, session: session, commander: commander}}
  end

  @doc false
  # any other cast is an event handler
  def handle_cast({_, socket, payload, event_handler_function, reply_to}, state) do
    handle_event(socket, event_handler_function, payload, reply_to, state)
  end


  @doc false
  def handle_call(:get_store, _from, %Drab{store: store} = state) do
    {:reply, store, state}
  end

  @doc false
  def handle_call(:get_session, _from, %Drab{session: session} = state) do
    {:reply, session, state}
  end


  defp handle_callback(socket, commander, callback) do
    if callback do
      # TODO: rethink the subprocess strategies - now it is just spawn_link
      spawn_link fn -> 
        apply(commander, callback, [socket])
      end
    end
    socket
  end

  defp handle_event(socket, event_handler_function, payload, reply_to, %Drab{commander: commander_module} = state) do
    # TODO: rethink the subprocess strategies - now it is just spawn_link
    spawn_link fn -> 
      event_handler = String.to_existing_atom(event_handler_function)
      dom_sender = Map.delete(payload, "event_handler_function")  
      commander_cfg = commander_config(commander_module)    

      # run before_handlers first
      returns_from_befores = Enum.map(callbacks_for(event_handler, commander_cfg.before_handler), 
        fn callback_handler ->
          apply(commander_module, callback_handler, [socket, dom_sender])
        end)

      # if ANY of them fail (return false or nil), do not proceed
      unless Enum.any?(returns_from_befores, &(!&1)) do
        # run actuall event handler
        returned_from_handler = apply(commander_module, event_handler, [socket, dom_sender])
        Enum.map(callbacks_for(event_handler, commander_cfg.after_handler), 
          fn callback_handler ->
            apply(commander_module, callback_handler, [socket, dom_sender, returned_from_handler])
          end)
      end

      push_reply(socket, reply_to, commander_module, event_handler_function)
    end

    {:noreply, state}
  end

  # defp check_handler_existence!(commander_module, callback_handler) do
  #   unless function_exists?(commander_module, Atom.to_string(callback_handler)) do
  #     raise "Drab can't find handler callback: \"#{commander_module}.#{callback_handler}/2\"."
  #   end    
  # end

  defp push_reply(socket, reply_to, _, _) do
    Phoenix.Channel.push(socket, "event", %{
      finished: reply_to
    })
  end

  # defp push_reply(arg, _, commander_module, event_handler_function) do
  #   raise """
  #   Event handler (#{commander_module}.#{event_handler_function}) should return Phoenix.Socket.
  #   It actually returned: 
  #   #{inspect(arg)}
  #   """    
  # end

  @doc false
  # Returns the list of callbacks (before_handler, after_handler) defined in handler_config
  def callbacks_for(_, []) do
    []
  end

  def callbacks_for(event_handler_function, handler_config) do
    #:uppercase, [{:run_before_each, []}, {:run_before_uppercase, [only: [:uppercase]]}]
    Enum.map(handler_config, fn {callback_name, callback_filter} -> 
      case callback_filter do
        [] -> callback_name
        [only: handlers] -> 
          if event_handler_function in handlers, do: callback_name, else: false
        [except: handlers] -> 
          if event_handler_function in handlers, do: false, else: callback_name
        _ -> false
      end
    end) |> Enum.filter(&(&1)) |> Enum.reverse # as they are coming in reverse order
  end

  @doc false
  def get_store(pid) do
    GenServer.call(pid, :get_store)
  end

  @doc false
  def update_store(pid, new_store) do
    GenServer.cast(pid, {:update_store, new_store})
  end

  @doc false
  def get_session(pid) do
    GenServer.call(pid, :get_session)
  end

  @doc false
  def update_session(pid, new_session) do
    GenServer.cast(pid, {:update_session, new_session})
  end

  @doc false
  def function_exists?(module_name, function_name) do
    module_name.__info__(:functions) 
      |> Enum.map(fn {f, _} -> Atom.to_string(f) end)
      |> Enum.member?(function_name)
  end

  @doc false
  def push_and_wait_for_response(socket, pid, message, options \\ []) do
    push(socket, pid, message, options)
    receive do
      {:got_results_from_client, reply} ->
        reply
    # TODO: timeout
    end    
  end

  @doc false
  def push(socket, pid, message, options \\ []) do
    do_push_or_broadcast(socket, pid, message, options, &Phoenix.Channel.push/3)
  end

  @doc false
  def broadcast(socket, pid, message, options \\ []) do
    do_push_or_broadcast(socket, pid, message, options, &Phoenix.Channel.broadcast/3)
  end

  defp do_push_or_broadcast(socket, pid, message, options, function) do
    m = options |> Enum.into(%{}) |> Map.merge(%{sender: tokenize_pid(socket, pid)})
    function.(socket, message,  m)
  end

  @doc """
  Returns token made created from PID. See also `Drab.detokenize_pid/2`
  """
  def tokenize_pid(socket, pid) do
    myself = :erlang.term_to_binary(pid)
    Phoenix.Token.sign(socket, "sender", myself)
  end
 
  @doc """
  Returns PID decrypted from token. See also `Drab.tokenize_pid/2`
  """
  def detokenize_pid(socket, token) do
    {:ok, detokenized_pid} = Phoenix.Token.verify(socket, "sender", token)
    detokenized_pid |> :erlang.binary_to_term
  end

  # returns the commander name for the given controller (assigned in token)
  @doc false
  def get_commander(socket) do
    controller = socket.assigns.controller
    controller.__drab__()[:commander]
  end

  # returns the drab_pid from socket
  @doc false
  def pid(socket) do
    socket.assigns.drab_pid
  end

  # if module is commander or controller with drab enabled, it has __drab__/0 function with Drab configuration
  defp commander_config(module) do
    module.__drab__()
  end

  @doc """
  Returns map of Drab configuration options.
  
  All the config values may be override in `config.exs`, for example:

      config :drab, disable_controls_while_processing: false

  Configuration options:
  * `disable_controls_while_processing` (default: `true`) - after sending request to the server, sender will be 
    disabled until get the answer; warning: this behaviour is not broadcasted, so only the control in the current
    browers will be disabled
  * `events_to_disable_while_processing` (default: `["click"]`) - list of events which will be disabled when 
    waiting for server response
  * `disable_controls_when_disconnected` (default: `true`) - disables control when there is no connectivity
    between the browser and the server
  * `socket` (default: `"/drab/socket"`) - path to Drab socket
  * `drab_store_storage` (default: :session_storage) - where to keep the Drab Store - :memory, :local_storage or 
    :session_storage; data in memory is kept to the next page load, session storage persist until browser (or a tab) is
    closed, and local storage is kept forever
  """
  def config() do
    %{
      disable_controls_while_processing: Application.get_env(:drab, :disable_controls_while_processing, true),
      events_to_disable_while_processing: Application.get_env(:drab, :events_to_disable_while_processing, ["click"]),
      disable_controls_when_disconnected: Application.get_env(:drab, :disable_controls_when_disconnected, true),
      socket: Application.get_env(:drab, :socket, "/drab/socket"),
      drab_store_storage: Application.get_env(:drab, :drab_store_storage, :session_storage)
    }
  end
end
