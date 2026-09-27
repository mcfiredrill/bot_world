defmodule BotWorld.Twitch do
  @moduledoc """
  Manages the bot's connection to Twitch: the OAuth handshake that links a
  broadcaster's account, and the credentials used to drive EventSub.
  """

  import Ecto.Query, warn: false

  require Logger

  alias BotWorld.Accounts.User
  alias BotWorld.Repo
  alias BotWorld.Twitch.{Credential, Helix}
  alias Ecto.Multi

  @token_url "https://id.twitch.tv/oauth2/token"
  @authorize_url "https://id.twitch.tv/oauth2/authorize"
  @scopes ~w(moderator:read:followers channel:read:subscriptions bits:read channel:read:redemptions)

  def scopes, do: @scopes

  def config, do: Map.new(Application.get_env(:bot_world, :twitch, []))

  def enabled?, do: !!config()[:enabled]

  def list_credentials do
    Repo.all(from c in Credential, order_by: [asc: c.id])
  end

  def get_credential(%User{id: user_id}), do: get_credential(user_id)

  def get_credential(user_id) do
    Repo.get_by(Credential, user_id: user_id)
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
  Authenticates a Twitch identity, returning its local user and credential.

  A returning Twitch user keeps the same local user even if their Twitch login
  has changed. On first authentication, the local user and Twitch credential
  are inserted atomically.
  """
  def authenticate(code) do
    request_fun = Application.get_env(:bot_world, :twitch_request_fun, &default_request/1)
    authenticate(code, request_fun)
  end

  def authenticate(code, request_fun) do
    with {:ok, token} <- exchange_code(code, request_fun),
         {:ok, twitch_user} <-
           Helix.get_current_user(token["access_token"], config().client_id, request_fun) do
      persist_identity(%{
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
  def event_sub_config(user_or_id, request_fun \\ &default_request/1) do
    case get_credential(user_or_id) do
      nil ->
        {:error, :not_connected}

      credential ->
        with {:ok, access_token} <- fresh_access_token(credential, request_fun) do
          {:ok,
           %{
             user_id: credential.user_id,
             client_id: config().client_id,
             oauth_token: access_token,
             broadcaster_id: credential.twitch_user_id
           }}
        end
    end
  end

  defp persist_identity(attrs) do
    case Repo.get_by(Credential, twitch_user_id: attrs.twitch_user_id) do
      nil -> create_identity(attrs)
      credential -> update_identity(credential, attrs)
    end
  end

  defp create_identity(attrs) do
    result =
      Multi.new()
      |> Multi.insert(:user, User.twitch_registration_changeset(%User{}))
      |> Multi.insert(:credential, fn %{user: user} ->
        Credential.changeset(%Credential{}, Map.put(attrs, :user_id, user.id))
      end)
      |> Repo.transaction()

    case result do
      {:ok, %{user: user, credential: credential}} ->
        {:ok, %{user: user, credential: credential}}

      {:error, :credential, changeset, _changes}
      when is_struct(changeset, Ecto.Changeset) ->
        recover_identity_race(changeset, attrs)

      {:error, _operation, reason, _changes} ->
        {:error, reason}
    end
  end

  # Two first-time callbacks for the same Twitch account can both observe no
  # credential. The unique twitch_user_id index chooses a winner; after the
  # losing transaction rolls back (including its user row), update the winner.
  defp recover_identity_race(changeset, attrs) do
    if unique_constraint_error?(changeset, :twitch_user_id) do
      case Repo.get_by(Credential, twitch_user_id: attrs.twitch_user_id) do
        nil -> {:error, changeset}
        credential -> update_identity(credential, attrs)
      end
    else
      {:error, changeset}
    end
  end

  defp update_identity(credential, attrs) do
    case credential |> Credential.changeset(attrs) |> Repo.update() do
      {:ok, credential} ->
        credential = Repo.preload(credential, :user)
        {:ok, %{user: credential.user, credential: credential}}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp unique_constraint_error?(changeset, field) do
    Enum.any?(changeset.errors, fn
      {^field, {_message, options}} -> options[:constraint] == :unique
      _error -> false
    end)
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

  defp handle_token_response({:ok, %Finch.Response{status: status, body: body}})
       when status in 200..299 do
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
  (Re)starts one user's EventSub client under the dynamic supervisor. Other
  users' clients are left untouched.
  """
  def connect_event_sub(%User{id: user_id}), do: connect_event_sub(user_id)

  def connect_event_sub(user_id) do
    if enabled?() do
      restart_event_sub(user_id)
    else
      :ok
    end
  end

  defp restart_event_sub(user_id) do
    case BotWorld.Twitch.EventSubClient.whereis(user_id) do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(BotWorld.Twitch.ClientSupervisor, pid)
    end

    DynamicSupervisor.start_child(
      BotWorld.Twitch.ClientSupervisor,
      {BotWorld.Twitch.EventSubClient, user_id: user_id}
    )
  end

  @doc """
  Starts an independent EventSub client at boot for every stored credential.
  """
  def maybe_connect_event_sub do
    if enabled?() do
      Enum.each(list_credentials(), fn credential ->
        connect_event_sub(credential.user_id)
      end)
    end

    :ok
  end
end
