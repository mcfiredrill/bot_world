defmodule BotWorldWeb.OverlayLiveTest do
  use BotWorldWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias BotWorld.Media

  defp overlay_token, do: Application.get_env(:bot_world, :overlay)[:token]

  test "plays a media_item broadcast over pubsub", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/overlay/#{overlay_token()}")

    payload = %{media_type: "audio", url: "http://example.com/sfx.mp3", name: "airhorn"}
    Phoenix.PubSub.broadcast(BotWorld.PubSub, Media.overlay_topic(), {:play_media_item, payload})

    assert_push_event(view, "play_media_item", ^payload)
  end

  test "redirects home when the token is wrong", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/overlay/wrong-token")
  end
end
