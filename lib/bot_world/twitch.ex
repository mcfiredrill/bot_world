defmodule BotWorld.Twitch do
  @moduledoc """
  Manages the bot's connection to Twitch: the OAuth handshake that links a
  broadcaster's account, and the credentials used to drive EventSub.
  """

  import Ecto.Query, warn: false

  require Logger

  alias BotWorld.Repo
  alias BotWorld.Twitch.{Credential, Helix}

  @token_url "https://id.twitch.tv/oauth2/token"
  @authorize_url "https://id.twitch.tv/oauth2/authorize"
  @scopes ~w(moderator:read:followers channel:read:subscriptions bits:read channel:read:redemptions)

  def scopes, do: @scopes

  def config, do: Map.new(Application.get_env(:bot_world, :twitch, []))

  def enabled?, do: !!config()[:enabled]

  @doc """
  The single connected broadcaster's credential, if any.
  """
  def get_credential do
    Repo.one(from c in Credential, order_by: [asc: c.id], limit: 1)
  end

  @doc """
  Builds the Twitch authorization URL a user is redirected to in order to
  grant the scopes the bot needs.
  """
  def authorize_url(state) do
    cfg = config()

    query =
      URI.encode_query(%{
        client_id: cfg.client_id,
        redirect_uri: cfg.redirect_uri,
        response_type: "code",
        scope: Enum.join(@scopes, " "),
        state: state
      })

    "#{@authorize_url}?#{query}"
  end

  @doc """
  Completes the OAuth handshake for `code`, fetches the authorizing Twitch
  user, and stores/updates their credential for `user`.
  """
  def connect(user, code, request_fun \\ &default_request/1) do
    with {:ok, token} <- exchange_code(code, request_fun),
         {:ok, twitch_user} <- Helix.get_current_user(token["access_token"], config().client_id, request_fun) do
      upsert_credential(user, %{
        twitch_user_id: twitch_user["id"],
        twitch_login: twitch_user["login"],
        access_token: token["access_token"],
        refresh_token: token["refresh_token"],
        scopes: token["scope"] || [],
        expires_at: expires_at_from(token["expires_in"])
      })
    end
  end

  @doc """
  Returns a valid (refreshing if necessary) access token for `credential`.
  """
  def fresh_access_token(%Credential{} = credential, request_fun \\ &default_request/1) do
    if expiring_soon?(credential) do
      with {:ok, token} <- refresh_token(credential.refresh_token, request_fun),
           {:ok, credential} <-
             credential
             |> Credential.changeset(%{
               access_token: token["access_token"],
               refresh_token: token["refresh_token"] || credential.refresh_token,
               expires_at: expires_at_from(token["expires_in"])
             })
             |> Repo.update() do
        {:ok, credential.access_token}
      end
    else
      {:ok, credential.access_token}
    end
  end

  @doc """
  Builds the config `BotWorld.Twitch.EventSubClient` and `Helix` need,
  refreshing the stored access token first if it's close to expiring.
  """
  def event_sub_config(request_fun \\ &default_request/1) do
    case get_credential() do
      nil ->
        {:error, :not_connected}

      credential ->
        with {:ok, access_token} <- fresh_access_token(credential, request_fun) do
          {:ok,
           %{
             client_id: config().client_id,
             oauth_token: access_token,
             broadcaster_id: credential.twitch_user_id
           }}
        end
    end
  end

  defp upsert_credential(user, attrs) do
    attrs = Map.put(attrs, :user_id, user.id)

    (Repo.get_by(Credential, user_id: user.id) || %Credential{})
    |> Credential.changeset(attrs)
    |> Repo.insert_or_update()
  end

  defp exchange_code(code, request_fun) do
    cfg = config()

    token_request(
      %{
        client_id: cfg.client_id,
        client_secret: cfg.client_secret,
        code: code,
        grant_type: "authorization_code",
        redirect_uri: cfg.redirect_uri
      },
      request_fun
    )
  end

  defp refresh_token(refresh_token, request_fun) do
    cfg = config()

    token_request(
      %{
        client_id: cfg.client_id,
        client_secret: cfg.client_secret,
        grant_type: "refresh_token",
        refresh_token: refresh_token
      },
      request_fun
    )
  end

  defp token_request(params, request_fun) do
    headers = [{"content-type", "application/x-www-form-urlencoded"}]
    body = URI.encode_query(params)

    :post
    |> Finch.build(@token_url, headers, body)
    |> request_fun.()
    |> handle_token_response()
  end

  defp handle_token_response({:ok, %Finch.Response{status: status, body: body}}) when status in 200..299 do
    {:ok, Jason.decode!(body)}
  end

  defp handle_token_response({:ok, %Finch.Response{status: status, body: body}}) do
    Logger.warning("Twitch OAuth token request failed (#{status}): #{body}")
    {:error, {status, body}}
  end

  defp handle_token_response({:error, reason}) do
    Logger.warning("Twitch OAuth token request error: #{inspect(reason)}")
    {:error, reason}
  end

  defp expiring_soon?(%Credential{expires_at: expires_at}) do
    DateTime.diff(expires_at, DateTime.utc_now()) < 300
  end

  defp expires_at_from(expires_in) do
    DateTime.utc_now() |> DateTime.add(expires_in, :second) |> DateTime.truncate(:second)
  end

  defp default_request(request), do: Finch.request(request, BotWorld.Finch)

  @doc """
  (Re)starts the EventSub client under its dynamic supervisor, using the
  currently stored credential. Safe to call repeatedly, e.g. after a fresh
  OAuth connect.
  """
  def connect_event_sub do
    case Process.whereis(BotWorld.Twitch.EventSubClient) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(BotWorld.Twitch.ClientSupervisor, pid)
    end

    DynamicSupervisor.start_child(BotWorld.Twitch.ClientSupervisor, BotWorld.Twitch.EventSubClient)
  end

  @doc """
  Starts the EventSub client at boot if a broadcaster is already connected.
  """
  def maybe_connect_event_sub do
    if enabled?() and get_credential() do
      connect_event_sub()
    end

    :ok
  end
end
