defmodule DrabTestApp.ElementTest do
  import Drab.Element
  import Phoenix.HTML
  use DrabTestApp.IntegrationCase

  defp element_index do
    element_url(DrabTestApp.Endpoint, :index)
  end

  setup do
    element_index() |> navigate_to()
    # wait for the Drab to initialize
    find_element(:id, "page_loaded_indicator")
    [socket: drab_socket()]
  end

  describe "Drab.Element" do
    test "query" do
      socket = drab_socket()
      assert query(socket, "#button1", "id") == {:ok, %{"#button1" => %{"id" => "button1"}}}

      assert query(socket, "#input1", [:id, :value]) ==
               {:ok, %{"#input1" => %{"id" => "input1", "value" => "input1 value"}}}

      assert query(socket, "#button1x", "id") == {:ok, %{}}
      assert query!(socket, "#button1", :id) == %{"#button1" => %{"id" => "button1"}}
      assert {:error, _} = query(socket, "<button1x", "id")
      assert_raise Drab.JSExecutionError, fn -> query!(socket, "<button1x", "id") end
    end

    test "query unnamed" do
      socket = drab_socket()
      {:ok, ret} = query(socket, "input", [:id, :value])
      assert ret |> Map.keys() |> Enum.count() == 3
      assert Enum.find(Map.keys(ret), fn x -> x == "#input1" end)
      assert Enum.find(Map.keys(ret), fn x -> x == "#input2" end)
      assert Enum.find(Map.keys(ret), fn x -> String.contains?(x, "[drab-id=") end)
      # drab-id should remain on the page
      assert ret == query!(socket, "input", [:id, :value])
    end

    test "query_one" do
      socket = drab_socket()
      assert query_one(socket, "#button1", "id") == {:ok, %{"id" => "button1"}}
      assert query_one!(socket, "#button1", "id") == %{"id" => "button1"}
      assert {:error, _} = query_one(socket, "input", :id)
      assert {:ok, nil} == query_one(socket, "nonexistent", :id)
      assert nil == query_one!(socket, "nonexistent", :id)
      assert_raise Drab.JSExecutionError, fn -> query_one!(socket, "input", :id) end
    end

    test "set_prop" do
      socket = drab_socket()

      assert {:ok, 1} ==
               set_prop(
                 socket,
                 "button",
                 style: %{"backgroundColor" => "red", "width" => "200px"}
               )

      {:ok, ret} = query_one(socket, "button", :style)
      assert ret["style"]["cssText"] == "background-color: red; width: 200px;"

      assert {:ok, 1} == set_prop(socket, "a", attributes: %{"href" => "https://tg.pl/drab"})
      {:ok, ret} = query_one(socket, "a", :attributes)
      assert ret["attributes"]["href"] == "https://tg.pl/drab"
    end

    test "set_prop - any property" do
      socket = drab_socket()
      assert {:ok, 1} == set_prop(socket, "button", p1: 1, p2: [1, 2], p3: %{jeden: 1})

      assert query!(
               socket,
               "button",
               [:p1, :p2, :p3] == %{
                 "#button1" => %{"p1" => 1, "p2" => [1, 2], "p3" => %{"jeden" => 1}}
               }
             )
    end

    test "broadcast_prop" do
      # not checking if it actually broadcasts
      socket = drab_socket()

      assert {:ok, :broadcasted} ==
               broadcast_prop(
                 socket,
                 "button",
                 style: %{"backgroundColor" => "red", "width" => "200px"}
               )

      {:ok, ret} = query_one(socket, "button", :style)
      assert ret["style"]["cssText"] == "background-color: red; width: 200px;"

      assert {:ok, :broadcasted} ==
               broadcast_prop(socket, "a", attributes: %{"href" => "https://tg.pl/drab"})

      {:ok, ret} = query_one(socket, "a", :attributes)
      assert ret["attributes"]["href"] == "https://tg.pl/drab"
    end

    test "set_style" do
      socket = drab_socket()

      assert {:ok, 1} ==
               set_style(socket, "button", %{"backgroundColor" => "red", "width" => "200px"})

      {:ok, ret} = query_one(socket, "button", :style)
      assert ret["style"]["cssText"] == "background-color: red; width: 200px;"

      assert {:ok, :broadcasted} ==
               broadcast_style(socket, "button", %{"backgroundColor" => "red", "width" => "200px"})

      {:ok, ret} = query_one(socket, "button", :style)
      assert ret["style"]["cssText"] == "background-color: red; width: 200px;"
    end

    test "set_attr" do
      socket = drab_socket()

      assert {:ok, 1} == set_attr(socket, "a", href: "https://tg.pl/drab")
      {:ok, ret} = query_one(socket, "a", :attributes)
      assert ret["attributes"]["href"] == "https://tg.pl/drab"

      assert {:ok, :broadcasted} == broadcast_attr(socket, "a", href: "https://tg.pl/drab")
      {:ok, ret} = query_one(socket, "a", :attributes)
      assert ret["attributes"]["href"] == "https://tg.pl/drab"
    end

    test "set_data" do
      socket = drab_socket()

      assert {:ok, 1} == set_data(socket, "button", foo: "bar")
      {:ok, ret} = query_one(socket, "button", :dataset)
      assert ret["dataset"]["foo"] == "bar"

      assert {:ok, :broadcasted} == broadcast_data(socket, "button", foo: "bar")
      {:ok, ret} = query_one(socket, "button", :dataset)
      assert ret["dataset"]["foo"] == "bar"
    end

    test "insert" do
      socket = drab_socket()

      assert {:ok, 1} == insert_html(socket, "button", :afterbegin, "<b>afterbegin</b> ")

      assert query_one!(
               socket,
               "button",
               :innerHTML) == %{"innerHTML" => "<b>afterbegin</b> \n  Button\n"}


      assert {:ok, 1} == insert_html(socket, "button", :beforeend, "<b>beforeend</b> ")

      assert query_one!(
               socket,
               "button",
               :innerText) == %{"innerText" => "afterbegin Button beforeend"}


      assert {:ok, :broadcasted} ==
               broadcast_insert(socket, "button", :beforebegin, "<p id='p1'></p>")

      assert {:ok, :broadcasted} ==
               broadcast_insert(socket, "button", :afterend, "<p id='p2'></p>")

      assert query_one!(
               socket,
               "button",
               :innerText) == %{"innerText" => "afterbegin Button beforeend"}


      assert query(socket, "#p1", :anything) == {:ok, %{"#p1" => %{}}}
      assert query(socket, "#p2", :anything) == {:ok, %{"#p2" => %{}}}
    end

    test "insert safe html", fixture do
      afterbegin = "<i>afterbegin</i>"
      safe = ~E"<b><%= afterbegin %></b>"
      assert {:ok, 1} == insert_html(fixture.socket, "button", :afterbegin, safe)

      assert query_one!(
               fixture.socket,
               "button",
               :innerHTML) == %{"innerHTML" => "<b>&lt;i&gt;afterbegin&lt;/i&gt;</b>\n  Button\n"}

    end

    test "adding an element with innerHTML should allow Drab events", fixture do
      test_inner_outer(fixture.socket, :innerHTML)
    end

    test "adding an element with outerHTML should allow Drab events", fixture do
      test_inner_outer(fixture.socket, :outerHTML)
    end
  end

  defp test_inner_outer(socket, property) do
    button = "<button id='inner_outer_button' drab='click:inner_outer_clicked'>injected</button>"
    set_prop(socket, "#inner_outer", [{property, button}])
    click_and_wait("inner_outer_button")

    out = find_element(:id, "inner_outer_out")
    assert visible_text(out) == "inner outer clicked"
  end

  test "set_html" do
    socket = drab_socket()
    html = "<p>Hello, World!</p>"
    assert {:ok, 1} == set_html(socket, "#my_element", html)
    assert %{"innerHTML" => html} == query_one!(socket, "#my_element", :innerHTML)

    assert {:ok, :broadcasted} == broadcast_html(socket, "#my_element", html)
    assert %{"innerHTML" => html} == query_one!(socket, "#my_element", :innerHTML)
  end

  test "set_html safe" do
    socket = drab_socket()
    hello = "<Hello, World>"
    html = ~E"<p><%= hello %></p>"
    assert {:ok, 1} == set_html(socket, "#my_element", html)

    assert %{"innerHTML" => "<p>&lt;Hello, World&gt;</p>"} ==
             query_one!(socket, "#my_element", :innerHTML)

    assert {:ok, :broadcasted} == broadcast_html(socket, "#my_element", html)

    assert %{"innerHTML" => "<p>&lt;Hello, World&gt;</p>"} ==
             query_one!(socket, "#my_element", :innerHTML)
  end
end
