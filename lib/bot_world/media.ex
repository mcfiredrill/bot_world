defmodule BotWorld.Media do
  @moduledoc """
  The Media context.
  """

  import Ecto.Query, warn: false
  require Logger
  alias BotWorld.Accounts.User
  alias BotWorld.{MediaGroup, MediaItem, Repo, S3, Trigger}

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

  def list_media_items(%User{id: user_id}) do
    MediaItem
    |> where([c], c.user_id == ^user_id)
    |> order_by([c], asc: c.name)
    |> preload(media_groups: :triggers)
    |> Repo.all()
  end

  def get_media_item!(%User{id: user_id}, id, preloads \\ []) do
    MediaItem
    |> Repo.get_by!(id: id, user_id: user_id)
    |> Repo.preload(preloads)
  end

  def change_media_item(%MediaItem{} = media_item, attrs \\ %{}),
    do: MediaItem.changeset(media_item, attrs)

  def create_media_item(%User{id: user_id}, attrs) do
    %MediaItem{user_id: user_id}
    |> MediaItem.changeset(attrs)
    |> validate_s3_key_owner(user_id)
    |> Repo.insert()
  end

  def delete_media_item(%User{} = user, id) do
    user
    |> get_media_item!(id, media_groups: [:media_items, :triggers])
    |> Repo.delete()
  end

  def random_media_item_for_trigger_type(%User{id: user_id}, type) do
    Trigger
    |> where([t], t.user_id == ^user_id and t.type == ^type)
    |> join(:inner, [t], g in assoc(t, :media_group))
    |> join(:inner, [_t, g], c in assoc(g, :media_items))
    |> select([_t, _g, c], c)
    |> Repo.all()
    |> case do
      [] -> {:error, :no_media_item}
      media_items -> {:ok, Enum.random(media_items)}
    end
  end

  def dispatch_event(user_or_id, eventsub_type, event_payload) do
    user_id = user_id(user_or_id)

    case trigger_type_for_eventsub_type(eventsub_type) do
      nil ->
        Logger.info("BotWorld.Media: no trigger type mapping for #{eventsub_type}")
        :ok

      trigger_type ->
        case matching_media_item_for_event(user_id, trigger_type, event_payload) do
          {:ok, media_item} ->
            Logger.info("BotWorld.Media: playing #{media_item.name} for #{trigger_type}")
            broadcast_play(user_id, media_item)
            :ok

          {:error, :no_media_item} ->
            Logger.info(
              "BotWorld.Media: no media item configured for trigger type #{trigger_type}"
            )

            :ok
        end
    end
  end

  defp matching_media_item_for_event(user_id, trigger_type, event_payload) do
    Trigger
    |> where([t], t.user_id == ^user_id and t.type == ^trigger_type)
    |> preload([:media_item, media_group: :media_items])
    |> Repo.all()
    |> filter_matching_triggers(trigger_type, event_payload)
    |> case do
      [] -> {:error, :no_media_item}
      matches -> matches |> Enum.random() |> media_item_for_trigger()
    end
  end

  defp filter_matching_triggers(triggers, "twitch_point_redeem", event_payload) do
    reward_name = get_in(event_payload, ["reward", "title"])

    case Enum.filter(triggers, &matches_reward_name?(&1.reward_name, reward_name)) do
      [] -> Enum.filter(triggers, &blank?(&1.reward_name))
      specific_matches -> specific_matches
    end
  end

  defp filter_matching_triggers(triggers, "twitch_bits", event_payload) do
    bits = event_payload["bits"]

    case Enum.filter(triggers, fn trigger ->
           not is_nil(trigger.bits_amount) and trigger.bits_amount == bits
         end) do
      [] -> Enum.filter(triggers, &is_nil(&1.bits_amount))
      specific_matches -> specific_matches
    end
  end

  defp filter_matching_triggers(triggers, _type, _event_payload), do: triggers

  defp media_item_for_trigger(%Trigger{media_item: %MediaItem{} = media_item}),
    do: {:ok, media_item}

  defp media_item_for_trigger(%Trigger{media_group: %MediaGroup{media_items: []}}),
    do: {:error, :no_media_item}

  defp media_item_for_trigger(%Trigger{media_group: %MediaGroup{media_items: media_items}}),
    do: {:ok, Enum.random(media_items)}

  defp matches_reward_name?(trigger_reward_name, _event_reward_name)
       when trigger_reward_name in [nil, ""],
       do: false

  defp matches_reward_name?(trigger_reward_name, event_reward_name) do
    normalize_reward_name(trigger_reward_name) == normalize_reward_name(event_reward_name)
  end

  defp normalize_reward_name(nil), do: nil
  defp normalize_reward_name(value), do: value |> String.trim() |> String.downcase()

  defp blank?(value), do: value in [nil, ""]

  defp broadcast_play(_user_id, media_item) do
    Phoenix.PubSub.broadcast(
      BotWorld.PubSub,
      @overlay_topic,
      {:play_media_item,
       %{
         media_type: media_item.media_type,
         url: S3.public_url(media_item.s3_key),
         name: media_item.name
       }}
    )
  end

  defp validate_s3_key_owner(changeset, user_id) do
    expected_prefix = "users/#{user_id}/"

    Ecto.Changeset.validate_change(changeset, :s3_key, fn :s3_key, s3_key ->
      if String.starts_with?(s3_key, expected_prefix),
        do: [],
        else: [s3_key: "must belong to the authenticated user"]
    end)
  end

  defp user_id(%User{id: id}), do: id
  defp user_id(id) when is_integer(id), do: id
end
