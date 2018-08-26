defmodule DrabTestApp.NakedCommander do
  @moduledoc false
  import Drab.Core

  use Drab.Commander, modules: []
  onload(:page_loaded)

  def page_loaded(socket) do
    DrabTestApp.IntegrationCase.add_page_loaded_indicator(socket)
    DrabTestApp.IntegrationCase.add_pid(socket)
  end

  defhandler run_handler_test(socket, payload) do
    exec_js!(
      socket,
      "document.getElementById('run_handler_test').innerHTML = '#{inspect(payload)}';"
    )

    exec_js!(
      socket,
      "document.getElementById('run_handler_test').payload = #{encode_js(payload)};"
    )
  end

  defhandler empty_handler(_, _), do: :nothing

  defhandler run_handler_test(socket, payload, argument) do
    argument = argument || "empty"
    argument = if is_map(argument), do: "map", else: argument

    exec_js!(
      socket,
      "document.getElementById('run_handler_test').innerHTML = 'with argument: #{argument}';"
    )

    exec_js!(
      socket,
      "document.getElementById('run_handler_test').payload = #{encode_js(payload)};"
    )
  end
end
