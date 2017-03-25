defmodule DrabTestApp.CoreTest do
  use DrabTestApp.IntegrationCase

  defp core_index do
    core_url(DrabTestApp.Endpoint, :core)
  end

  defp begin do
    core_index() |> navigate_to()
    find_element(:id, "page_loaded_indicator") # wait for a page to load
  end

  defp click_and_wait(button_id) do
    button = find_element(:id, button_id)
    button |> click()
    button |> wait_for_enable()
  end

  defp standard_test(test_name) do
    click_and_wait("#{test_name}_button")
    out = find_element(:id, "#{test_name}_out")
    assert visible_text(out) == test_name        
  end

  test "Drab.Core functions" do
    begin()

    # test execjs and broadcastjs
    standard_test("core1")
    standard_test("core2")

    # this session value should be visible
    session_value = find_element(:id, "test_session_value1")
    assert visible_text(session_value) == "test session value 1"

    # and this one not, as it is not listed in `access_session`
    session_value = find_element(:id, "test_session_value2")
    assert visible_text(session_value) == ""

    # test if the store is set up correctly
    click_and_wait("set_store_button")
    click_and_wait("get_store_button")

    store_value = find_element(:id, "store1_out")
    assert visible_text(store_value) == "test store value"
  end

  ### TODO: find out how to make persistent store test (not working in chromedriver by default)

end