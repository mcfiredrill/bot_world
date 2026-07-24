defmodule BotWorldWeb.OverlayLive do
  use Phoenix.LiveView, layout: false
  use BotWorldWeb, :verified_routes

  alias BotWorld.Commands

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    if token == overlay_token() do
      if connected?(socket) do
        Phoenix.PubSub.subscribe(BotWorld.PubSub, Commands.overlay_topic())
      end

      {:ok, assign(socket, :now_playing, nil)}
    else
      {:ok, redirect(socket, to: ~p"/")}
    end
  end

  @impl true
  def handle_info({:play_command, payload}, socket) do
    {:noreply,
     socket
     |> assign(:now_playing, payload)
     |> push_event("play_command", payload)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="overlay-root" phx-hook="OverlayPlayback"></div>
    """
  end

  defp overlay_token, do: Application.get_env(:bot_world, :overlay, [])[:token]
end
