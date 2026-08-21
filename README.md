# BotWorld

## run minio:

```
  mkdir -p /tmp/bot-world-minio

  MINIO_ROOT_USER=minioadmin \
  MINIO_ROOT_PASSWORD=minioadmin \
  minio server /tmp/bot-world-minio --console-address ":9001"
```

  Then use:

- S3 endpoint: http://localhost:9000
- Admin console: http://localhost:9001
- Login: minioadmin / minioadmin

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

  * Official website: https://www.phoenixframework.org/
  * Guides: https://hexdocs.pm/phoenix/overview.html
  * Docs: https://hexdocs.pm/phoenix
  * Forum: https://elixirforum.com/c/phoenix-forum
  * Source: https://github.com/phoenixframework/phoenix
