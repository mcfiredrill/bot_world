defmodule BotWorldWeb.TriggersControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.{MediaItem, Media, MediaGroup, Repo, Trigger}

  setup :register_and_log_in_user

  test "GET /triggers/bits-rewards lists only the user's bits rewards in amount order", %{
    conn: conn,
    user: user
  } do
    other_user = register_user()

    for {owner, name, type, amount} <- [
          {user, "Big cheer", "twitch_bits", 500},
          {user, "Small cheer", "twitch_bits", 100},
          {user, "Surprise", "twitch_bits", nil},
          {user, "Follow reward", "twitch_follow", nil},
          {other_user, "Private reward", "twitch_bits", 200}
        ] do
      item = Repo.insert!(%MediaItem{user_id: owner.id, name: name, s3_key: "clip.mp3"})

      %Trigger{user_id: owner.id}
      |> Trigger.changeset(%{
        name: name,
        type: type,
        bits_amount: amount,
        media_item_id: item.id
      })
      |> Repo.insert!()
    end

    body = conn |> get(~p"/triggers/bits-rewards") |> html_response(200)
    document = Floki.parse_document!(body)

    assert document |> Floki.find("#bits-rewards-text") |> Floki.text() ==
             "- 100 Bits: Small cheer\n- 500 Bits: Big cheer\n- Other Bits amounts: Surprise"

    refute body =~ "Follow reward"
    refute body =~ "Private reward"
  end

  test "GET /triggers/bits-rewards shows an empty state", %{conn: conn} do
    body = conn |> get(~p"/triggers/bits-rewards") |> html_response(200)
    assert body =~ "No Bits rewards configured yet"
  end

  test "GET /triggers/bits-rewards requires login" do
    conn = get(build_conn(), ~p"/triggers/bits-rewards")
    assert redirected_to(conn) == ~p"/users/log_in"
  end

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
