defmodule BotWorldWeb.TriggersHTML do
  use BotWorldWeb, :html

  embed_templates "triggers_html/*"

  @doc """
  Formats trigger type for display.
  """
  def format_trigger_type(type) do
    type
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  @doc """
  Describes what a trigger matches on, for display purposes.
  """
  def format_trigger_match(%{type: "twitch_point_redeem", reward_name: reward_name})
      when reward_name not in [nil, ""] do
    "Reward: #{reward_name}"
  end

  def format_trigger_match(%{type: "twitch_bits", bits_amount: bits_amount})
      when not is_nil(bits_amount) do
    "#{bits_amount} bits"
  end

  def format_trigger_match(%{type: type}) when type in ["twitch_point_redeem", "twitch_bits"] do
    "Any"
  end

  def format_trigger_match(_trigger), do: "—"
end
