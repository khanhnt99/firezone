# In this file, we load production configuration and secrets
# from environment variables. You can also hardcode secrets,
# although such is generally not recommended and you have to
# remember to add this file to your .gitignore.
import Config
alias FzCommon.{CLI, FzInteger, FzString}

# For releases, require that all these are set
database_name = System.fetch_env!("DATABASE_NAME")
database_user = System.fetch_env!("DATABASE_USER")
database_host = System.fetch_env!("DATABASE_HOST")
database_port = String.to_integer(System.fetch_env!("DATABASE_PORT"))
database_pool = String.to_integer(System.fetch_env!("DATABASE_POOL"))
database_ssl = FzString.to_boolean(System.fetch_env!("DATABASE_SSL"))
database_ssl_opts = Jason.decode!(System.fetch_env!("DATABASE_SSL_OPTS"))
database_parameters = Jason.decode!(System.fetch_env!("DATABASE_PARAMETERS"))
port = String.to_integer(System.fetch_env!("PHOENIX_PORT"))
url_host = System.fetch_env!("URL_HOST")
admin_email = System.fetch_env!("ADMIN_EMAIL")
default_admin_password = System.fetch_env!("DEFAULT_ADMIN_PASSWORD")
wireguard_interface_name = System.fetch_env!("WIREGUARD_INTERFACE_NAME")
wireguard_port = String.to_integer(System.fetch_env!("WIREGUARD_PORT"))
nft_path = System.fetch_env!("NFT_PATH")
wg_path = System.fetch_env!("WG_PATH")
egress_interface = System.fetch_env!("EGRESS_INTERFACE")
wireguard_public_key = System.fetch_env!("WIREGUARD_PUBLIC_KEY")
wireguard_dns = System.fetch_env!("WIREGUARD_DNS")
wireguard_allowed_ips = System.fetch_env!("WIREGUARD_ALLOWED_IPS")
wireguard_persistent_keepalive = System.fetch_env!("WIREGUARD_PERSISTENT_KEEPALIVE")
wireguard_ipv4_enabled = FzString.to_boolean(System.fetch_env!("WIREGUARD_IPV4_ENABLED"))
wireguard_ipv4_network = System.fetch_env!("WIREGUARD_IPV4_NETWORK")
wireguard_ipv4_address = System.fetch_env!("WIREGUARD_IPV4_ADDRESS")
wireguard_ipv6_enabled = FzString.to_boolean(System.fetch_env!("WIREGUARD_IPV6_ENABLED"))
wireguard_ipv6_network = System.fetch_env!("WIREGUARD_IPV6_NETWORK")
wireguard_ipv6_address = System.fetch_env!("WIREGUARD_IPV6_ADDRESS")
wireguard_mtu = System.fetch_env!("WIREGUARD_MTU")
wireguard_endpoint = System.fetch_env!("WIREGUARD_ENDPOINT")
telemetry_enabled = FzString.to_boolean(System.fetch_env!("TELEMETRY_ENABLED"))
telemetry_id = System.fetch_env!("TELEMETRY_ID")

telemetry_module =
  if telemetry_enabled do
    FzCommon.Telemetry
  else
    FzCommon.MockTelemetry
  end

connectivity_checks_enabled =
  FzString.to_boolean(System.fetch_env!("CONNECTIVITY_CHECKS_ENABLED")) &&
    System.get_env("CI") != "true"

connectivity_checks_interval =
  System.fetch_env!("CONNECTIVITY_CHECKS_INTERVAL")
  |> String.to_integer()
  |> FzInteger.clamp(60, 86_400)

# secrets
encryption_key = System.fetch_env!("DATABASE_ENCRYPTION_KEY")
secret_key_base = System.fetch_env!("SECRET_KEY_BASE")
live_view_signing_salt = System.fetch_env!("LIVE_VIEW_SIGNING_SALT")
cookie_signing_salt = System.fetch_env!("COOKIE_SIGNING_SALT")

# Password is not needed if using bundled PostgreSQL, so use nil if it's not set.
database_password = System.get_env("DATABASE_PASSWORD")

# XXX: Using to_atom here because this is trusted input and to_existing_atom
# won't work because we won't know the keys ahead of time.
ssl_opts = Keyword.new(database_ssl_opts, fn {k, v} -> {String.to_atom(k), v} end)
parameters = Keyword.new(database_parameters, fn {k, v} -> {String.to_atom(k), v} end)

# Database configuration
connect_opts = [
  database: database_name,
  username: database_user,
  hostname: database_host,
  port: database_port,
  pool_size: database_pool,
  ssl: database_ssl,
  ssl_opts: ssl_opts,
  parameters: parameters,
  queue_target: 500
]

if database_password do
  config(:fz_http, FzHttp.Repo, connect_opts ++ [password: database_password])
else
  config(:fz_http, FzHttp.Repo, connect_opts)
end

config :fz_http, FzHttp.Vault,
  ciphers: [
    default: {
      Cloak.Ciphers.AES.GCM,
      # In AES.GCM, it is important to specify 12-byte IV length for
      # interoperability with other encryption software. See this GitHub
      # issue for more details:
      # https://github.com/danielberkompas/cloak/issues/93
      #
      # In Cloak 2.0, this will be the default iv length for AES.GCM.
      tag: "AES.GCM.V1", key: Base.decode64!(encryption_key), iv_length: 12
    }
  ]

config :fz_http, FzHttpWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: port],
  url: [host: url_host, scheme: "http"],
  check_origin: ["//127.0.0.1", "//localhost", "//#{url_host}"],
  server: true,
  secret_key_base: secret_key_base,
  live_view: [
    signing_salt: live_view_signing_salt
  ]

config :fz_wall,
  nft_path: nft_path,
  egress_interface: egress_interface,
  wireguard_interface_name: wireguard_interface_name,
  cli: FzWall.CLI.Live

config :fz_vpn,
  wireguard_public_key: wireguard_public_key,
  wireguard_interface_name: wireguard_interface_name,
  wireguard_port: wireguard_port,
  cli: FzVpn.CLI.Live

config :fz_http,
  wireguard_dns: wireguard_dns,
  wireguard_allowed_ips: wireguard_allowed_ips,
  wireguard_persistent_keepalive: wireguard_persistent_keepalive,
  wireguard_ipv4_enabled: wireguard_ipv4_enabled,
  wireguard_ipv4_network: wireguard_ipv4_network,
  wireguard_ipv4_address: wireguard_ipv4_address,
  wireguard_ipv6_enabled: wireguard_ipv6_enabled,
  wireguard_ipv6_network: wireguard_ipv6_network,
  wireguard_ipv6_address: wireguard_ipv6_address,
  wireguard_mtu: wireguard_mtu,
  telemetry_module: telemetry_module,
  telemetry_id: telemetry_id,
  url_host: url_host,
  connectivity_checks_enabled: connectivity_checks_enabled,
  connectivity_checks_interval: connectivity_checks_interval,
  admin_email: admin_email,
  default_admin_password: default_admin_password
