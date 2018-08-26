defmodule DrabTestApp.Broadcast5Commander do
  @moduledoc false

  use Drab.Commander, modules: [Drab.Query, Drab.Modal]

  onload(:page_loaded)
  onconnect(:connected)

  def page_loaded(socket) do
    exec_js!(socket, "window.$ = jQuery")

    socket
    |> Drab.Query.insert("<h3 id='page_loaded_indicator'>Page Loaded</h3>", after: "#begin")

    socket
    |> Drab.Query.insert(
      "<h5>Drab Broadcast Topic: #{__drab__().broadcasting |> inspect}</h5>",
      after: "#page_loaded_indicator"
    )

    p = inspect(socket.assigns.__drab_pid)
    pid_string = ~r/#PID<(?<pid>.*)>/ |> Regex.named_captures(p) |> Map.get("pid")
    Drab.Query.update(socket, :text, set: pid_string, on: "#drab_pid")
  end

  def connected(socket) do
    exec_js!(socket, "window.$ = jQuery")
    socket |> Drab.Query.update(:text, set: "", on: "#broadcast_out")
  end

  defhandler broadcast5(_, _) do
    [
      same_path("/tests/broadcast1"),
      same_controller(DrabTestApp.Broadcast2Controller),
      same_topic("my_topic")
    ]
    |> update!(:text, set: "Broadcasted Text to the all", on: "#broadcast_out")
  end
end
