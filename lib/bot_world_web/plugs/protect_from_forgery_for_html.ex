defmodule BotWorldWeb.Plugs.ProtectFromForgeryForHtml do
  @behaviour Plug

  def init(opts), do: Plug.CSRFProtection.init(opts)

  def call(conn, opts) do
    conn = maybe_put_json_format(conn)

    if Phoenix.Controller.get_format(conn) == "json" do
      conn
    else
      Plug.CSRFProtection.call(conn, opts)
    end
  end

  defp maybe_put_json_format(conn) do
    if json_content_type?(conn) do
      Phoenix.Controller.put_format(conn, "json")
    else
      conn
    end
  end

  defp json_content_type?(conn) do
    conn
    |> Plug.Conn.get_req_header("content-type")
    |> Enum.any?(&String.starts_with?(&1, "application/json"))
  end
end
