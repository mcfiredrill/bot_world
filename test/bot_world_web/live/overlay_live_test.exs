defmodule BotWorldWeb.OverlayLiveTest do
  use BotWorldWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BotWorld.Commands

  defp overlay_token, do: Application.get_env(:bot_world, :overlay)[:token]

  test "plays a command broadcast over pubsub", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/overlay/#{overlay_token()}")

    payload = %{media_type: "audio", url: "http://example.com/sfx.mp3", name: "airhorn"}
    Phoenix.PubSub.broadcast(BotWorld.PubSub, Commands.overlay_topic(), {:play_command, payload})

    assert_push_event(view, "play_command", ^payload)
  end

  test "redirects home when the token is wrong", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/overlay/wrong-token")
  end
end
