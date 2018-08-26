defmodule DrabTest do
  @moduledoc false

  use ExUnit.Case, ascync: true
  doctest Drab

  test "config" do
    assert Drab.Config.get(DrabTestApp.Endpoint, :disable_controls_while_processing) == true
    assert Drab.Config.get(DrabTestApp.Endpoint, :events_to_disable_while_processing) == ["click"]
    assert Drab.Config.get(DrabTestApp.Endpoint, :disable_controls_when_disconnected) == true
    assert Drab.Config.get(DrabTestApp.Endpoint, :socket) == "/socket"
    assert Drab.Config.get(DrabTestApp.Endpoint, :drab_store_storage) == :session_storage
  end

  describe "helpers" do
    test "callbacks_for" do
      handler_config = [{:run_before_each, []}, {:run_before_uppercase, [only: [:uppercase]]}]

      assert Drab.callbacks_for(:uppercase, handler_config) == [
               :run_before_each,
               :run_before_uppercase
             ]

      assert Drab.callbacks_for(:lowercase, handler_config) == [:run_before_each]

      handler_config = [{:run_before_each, []}, {:run_before_uppercase, [except: [:lowercase]]}]

      assert Drab.callbacks_for(:uppercase, handler_config) == [
               :run_before_each,
               :run_before_uppercase
             ]

      assert Drab.callbacks_for(:lowercase, handler_config) == [:run_before_each]

      assert Drab.callbacks_for(:anycase, handler_config) == [
               :run_before_each,
               :run_before_uppercase
             ]

      assert Drab.callbacks_for(:anycase, []) == []
    end

    test "application config" do
      assert Drab.Config.app_name(DrabTestApp.Endpoint) == :drab
    end

    def function() do
      :ok
    end
  end
end
