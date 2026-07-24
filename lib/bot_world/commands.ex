defmodule BotWorld.Commands do
  @moduledoc """
  The Commands context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias BotWorld.{Repo, S3, Trigger}

  @overlay_topic "overlay:playback"

  def overlay_topic, do: @overlay_topic

  @eventsub_trigger_types %{
    "channel.follow" => "twitch_follow",
    "channel.subscribe" => "twitch_subscribe",
    "channel.cheer" => "twitch_bits",
    "channel.channel_points_custom_reward_redemption.add" => "twitch_point_redeem"
  }

  def trigger_type_for_eventsub_type(eventsub_type) do
    Map.get(@eventsub_trigger_types, eventsub_type)
  end

  def random_command_for_trigger_type(type) do
    Trigger
    |> where([t], t.type == ^type)
    |> join(:inner, [t], c in assoc(t, :command))
    |> select([t, c], c)
    |> Repo.all()
    |> case do
      [] -> {:error, :no_command}
      commands -> {:ok, Enum.random(commands)}
    end
  end

  def dispatch_event(eventsub_type, _event_payload) do
    case trigger_type_for_eventsub_type(eventsub_type) do
      nil ->
        Logger.info("BotWorld.Commands: no trigger type mapping for #{eventsub_type}")
        :ok

      trigger_type ->
        case random_command_for_trigger_type(trigger_type) do
          {:ok, command} ->
            broadcast_play(command)
            :ok

          {:error, :no_command} ->
            Logger.info("BotWorld.Commands: no command configured for trigger type #{trigger_type}")
            :ok
        end
    end
  end

  defp broadcast_play(command) do
    Phoenix.PubSub.broadcast(
      BotWorld.PubSub,
      @overlay_topic,
      {:play_command,
       %{
         media_type: command.media_type,
         url: S3.public_url(command.s3_key),
         name: command.name
       }}
    )
  end
end
