defmodule BotWorldWeb.UserJWT do
  alias BotWorld.Accounts.UserToken
  alias BotWorldWeb.Endpoint

  @header %{"alg" => "HS256", "typ" => "JWT"}

  def sign(session_token) when is_binary(session_token) do
    now = System.os_time(:second)

    payload =
      %{
        "exp" => now + UserToken.session_validity_in_days() * 24 * 60 * 60,
        "iat" => now,
        "token" => Base.url_encode64(session_token, padding: false)
      }

    header_segment = encode_segment(@header)
    payload_segment = encode_segment(payload)
    signature_segment = sign_segments(header_segment, payload_segment)

    Enum.join([header_segment, payload_segment, signature_segment], ".")
  end

  def verify(token) when is_binary(token) do
    with [header_segment, payload_segment, signature_segment] <-
           String.split(token, ".", parts: 3),
         {:ok, @header} <- decode_segment(header_segment),
         true <- valid_signature?(header_segment, payload_segment, signature_segment),
         {:ok, %{"exp" => exp, "token" => encoded_session_token}} <-
           decode_segment(payload_segment),
         true <- exp > System.os_time(:second),
         {:ok, session_token} <- Base.url_decode64(encoded_session_token, padding: false) do
      {:ok, session_token}
    else
      _ -> :error
    end
  end

  def verify(_token), do: :error

  defp valid_signature?(header_segment, payload_segment, signature_segment) do
    expected_signature = sign_segments(header_segment, payload_segment)

    byte_size(expected_signature) == byte_size(signature_segment) and
      Plug.Crypto.secure_compare(expected_signature, signature_segment)
  end

  defp sign_segments(header_segment, payload_segment) do
    :crypto.mac(:hmac, :sha256, secret(), "#{header_segment}.#{payload_segment}")
    |> Base.url_encode64(padding: false)
  end

  defp encode_segment(data) do
    data
    |> Jason.encode!()
    |> Base.url_encode64(padding: false)
  end

  defp decode_segment(segment) do
    with {:ok, decoded} <- Base.url_decode64(segment, padding: false),
         {:ok, json} <- Jason.decode(decoded) do
      {:ok, json}
    end
  end

  defp secret do
    Endpoint.config(:secret_key_base) ||
      Application.fetch_env!(:bot_world, BotWorldWeb.Endpoint)[:secret_key_base] ||
      raise "missing endpoint secret_key_base for JWT signing"
  end
end
