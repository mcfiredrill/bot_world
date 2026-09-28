defmodule BotWorldWeb.TriggersControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.{MediaItem, Media, MediaGroup, Repo, Trigger}

  setup :register_and_log_in_user

  test "POST /triggers/test/bits dispatches an arbitrary bits amount", %{conn: conn, user: user} do
    media_item =
      %MediaItem{user_id: user.id}
      |> MediaItem.changeset(%{name: "cheer", s3_key: "sfx/cheer.mp3", media_type: "audio"})
      |> Repo.insert!()

    group =
      %MediaGroup{name: "Cheer clips", user_id: user.id}
      |> Repo.preload(:media_items)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:media_items, [media_item])
      |> Repo.insert!()

    %Trigger{user_id: user.id}
    |> Trigger.changeset(%{
      name: "250 bits",
      type: "twitch_bits",
      bits_amount: 250,
      media_group_id: group.id
    })
    |> Repo.insert!()

    Phoenix.PubSub.subscribe(BotWorld.PubSub, Media.overlay_topic())

    conn = post(conn, ~p"/triggers/test/bits", %{test_bits: %{bits: "250"}})

    assert redirected_to(conn) == ~p"/triggers"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Simulated a 250-bit cheer."
    assert_receive {:play_media_item, %{name: "cheer"}}
  end

  test "POST /triggers/test/bits rejects invalid amounts", %{conn: conn} do
    conn = post(conn, ~p"/triggers/test/bits", %{test_bits: %{bits: "12.5"}})

    assert redirected_to(conn) == ~p"/triggers"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Bits must be a non-negative whole number."
  end
end
