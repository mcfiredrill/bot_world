defmodule BotWorldWeb.TriggersControllerTest do
  use BotWorldWeb.ConnCase, async: true

  alias BotWorld.{Command, Commands, MediaGroup, Repo, Trigger}

  setup :register_and_log_in_user

  test "POST /triggers/test/bits dispatches an arbitrary bits amount", %{conn: conn} do
    command =
      %Command{}
      |> Command.changeset(%{name: "cheer", s3_key: "sfx/cheer.mp3", media_type: "audio"})
      |> Repo.insert!()

    group =
      %MediaGroup{name: "Cheer clips"}
      |> Repo.preload(:commands)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:commands, [command])
      |> Repo.insert!()

    %Trigger{}
    |> Trigger.changeset(%{
      name: "250 bits",
      type: "twitch_bits",
      bits_amount: 250,
      media_group_id: group.id
    })
    |> Repo.insert!()

    Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())

    conn = post(conn, ~p"/triggers/test/bits", %{test_bits: %{bits: "250"}})

    assert redirected_to(conn) == ~p"/triggers"
    assert Phoenix.Flash.get(conn.assigns.flash, :info) == "Simulated a 250-bit cheer."
    assert_receive {:play_command, %{name: "cheer"}}
  end

  test "POST /triggers/test/bits rejects invalid amounts", %{conn: conn} do
    conn = post(conn, ~p"/triggers/test/bits", %{test_bits: %{bits: "12.5"}})

    assert redirected_to(conn) == ~p"/triggers"

    assert Phoenix.Flash.get(conn.assigns.flash, :error) ==
             "Bits must be a non-negative whole number."
  end
end
