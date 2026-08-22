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
    |> join(:inner, [t], g in assoc(t, :media_group))
    |> join(:inner, [_t, g], c in assoc(g, :commands))
    |> select([_t, _g, c], c)
    |> Repo.all()
    |> case do
      [] -> {:error, :no_command}
      commands -> {:ok, Enum.random(commands)}
    end
  end

  def dispatch_event(eventsub_type, event_payload) do
    case trigger_type_for_eventsub_type(eventsub_type) do
      nil ->
        Logger.info("BotWorld.Commands: no trigger type mapping for #{eventsub_type}")
        :ok

      trigger_type ->
        case matching_command_for_event(trigger_type, event_payload) do
          {:ok, command} ->
            Logger.info("BotWorld.Commands: playing #{command.name} for #{trigger_type}")
            broadcast_play(command)
            :ok

          {:error, :no_command} ->
            Logger.info(
              "BotWorld.Commands: no command configured for trigger type #{trigger_type}"
            )

            :ok
        end
    end
  end

  defp matching_command_for_event(trigger_type, event_payload) do
    Trigger
    |> where([t], t.type == ^trigger_type)
    |> join(:inner, [t], g in assoc(t, :media_group))
    |> join(:inner, [_t, g], c in assoc(g, :commands))
    |> select([t, _g, c], {t, c})
    |> Repo.all()
    |> filter_matching_triggers(trigger_type, event_payload)
    |> case do
      [] -> {:error, :no_command}
      matches -> {:ok, matches |> Enum.random() |> elem(1)}
    end
  end

  defp filter_matching_triggers(triggers, "twitch_point_redeem", event_payload) do
    reward_name = get_in(event_payload, ["reward", "title"])

    case Enum.filter(triggers, fn {t, _c} -> matches_reward_name?(t.reward_name, reward_name) end) do
      [] -> Enum.filter(triggers, fn {t, _c} -> blank?(t.reward_name) end)
      specific_matches -> specific_matches
    end
  end

  defp filter_matching_triggers(triggers, "twitch_bits", event_payload) do
    bits = event_payload["bits"]

    case Enum.filter(triggers, fn {t, _c} ->
           not is_nil(t.bits_amount) and t.bits_amount == bits
         end) do
      [] -> Enum.filter(triggers, fn {t, _c} -> is_nil(t.bits_amount) end)
      specific_matches -> specific_matches
    end
  end

  defp filter_matching_triggers(triggers, _type, _event_payload), do: triggers

  defp matches_reward_name?(trigger_reward_name, _event_reward_name)
       when trigger_reward_name in [nil, ""],
       do: false

  defp matches_reward_name?(trigger_reward_name, event_reward_name) do
    normalize_reward_name(trigger_reward_name) == normalize_reward_name(event_reward_name)
  end

  defp normalize_reward_name(nil), do: nil
  defp normalize_reward_name(value), do: value |> String.trim() |> String.downcase()

  defp blank?(value), do: value in [nil, ""]

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
