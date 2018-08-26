use Mix.Config

# Configures the endpoint
config :drab, DrabTestApp.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "bP1ZF+DDZiAVGuIigj3UuAzBhDmxHSboH9EEH575muSET1g18BPO4HeZnggJA/7q",
  render_errors: [view: DrabTestApp.ErrorView, accepts: ~w(html json)],
  pubsub: [name: DrabTestApp.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :phoenix, :template_engines, drab: Drab.Live.Engine

config :drab, DrabTestApp.Endpoint,
  otp_app: :drab,
  templates_path: "priv/custom_templates",
  events_shorthands: ["click", "keyup", "keydown", "change", "mousedown"],
  live_conn_pass_through: %{
    assigns: %{
      current_user: true
    },
    private: %{
      phoenix_endpoint: true
    }
  }

config :drab, enable_live_scripts: true

config :drab, :phoenix_channel_options, log_handle_in: false

config :drab, :presence, id: [store: :current_user_id]

config :drab, DrabTestApp.Endpoint, access_session: [:another_session, :should_be_nil]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
