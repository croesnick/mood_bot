import Config

# Use Ringlogger as the logger backend and remove :console.
# See https://hexdocs.pm/ring_logger/readme.html for more information on
# configuring ring_logger.

config :logger, backends: [RingLogger]

# Use shoehorn to start the main application. See the shoehorn
# library documentation for more control in ordering how OTP
# applications are started and handling failures.

config :shoehorn,
  init: [:nerves_runtime, :nerves_pack],
  app: Mix.Project.config()[:app]

# Erlinit can be configured without a rootfs_overlay. See
# https://github.com/nerves-project/erlinit/ for more information on
# configuring erlinit.

# Advance the system clock on devices without real-time clocks.
config :nerves, :erlinit, update_clock: true

# Configure the device for SSH IEx prompt access and firmware updates
#
# * See https://hexdocs.pm/nerves_ssh/readme.html for general SSH configuration
# * See https://hexdocs.pm/ssh_subsystem_fwup/readme.html for firmware updates

keys =
  System.user_home!()
  |> Path.join(".ssh/id_{rsa,ecdsa,ed25519}.pub")
  |> Path.wildcard()

# If no SSH keys are found, nerves_ssh will still start but users will need to
# add authorized keys at runtime or use password authentication
authorized_keys =
  if keys == [] do
    raise "No SSH public keys found in ~/.ssh/id_rsa.pub, ~/.ssh/id_ecdsa.pub, or ~/.ssh/id_ed25519.pub. " <>
          "Please generate a key pair using `ssh-keygen` and add it to your .ssh directory."
  else
    Enum.map(keys, &File.read!/1)
  end

config :nerves_ssh,
  authorized_keys: authorized_keys

# Configure the network using VintageNet
# VintageNet is Nerves' modern networking library that handles all network types:
# WiFi, Ethernet, cellular, USB networking, and Access Point mode
#
# Regulatory domain is set via REGULATORY_DOMAIN environment variable (defaults to "DE")
# Set your 2-letter country code E.g., "US", "DE", "GB" in .env file or export REGULATORY_DOMAIN=US
#
# See https://github.com/nerves-networking/vintage_net for more information
config :vintage_net,
  regulatory_domain: System.get_env("REGULATORY_DOMAIN", "DE"),
  config: [
    {"usb0", %{type: VintageNetDirect}},
    {"eth0",
     %{
       type: VintageNetEthernet,
       ipv4: %{method: :dhcp}
     }},
    # WiFi available - configure at runtime
    {"wlan0", %{type: VintageNetWiFi}}
  ]

config :mdns_lite,
  # The `hosts` key specifies what hostnames mdns_lite advertises.  `:hostname`
  # advertises the device's hostname.local. For the official Nerves systems, this
  # is "nerves-<4 digit serial#>.local".  The `"nerves"` host causes mdns_lite
  # to advertise "nerves.local" for convenience. If more than one Nerves device
  # is on the network, it is recommended to delete "nerves" from the list
  # because otherwise any of the devices may respond to nerves.local leading to
  # unpredictable behavior.

  hosts: [:hostname, "nerves"],
  ttl: 120,

  # Advertise the following services over mDNS.
  services: [
    %{
      protocol: "ssh",
      transport: "tcp",
      port: 22
    },
    %{
      protocol: "sftp-ssh",
      transport: "tcp",
      port: 22
    },
    %{
      protocol: "epmd",
      transport: "tcp",
      port: 4369
    }
  ]

# Configure the e-ink display
config :mood_bot, MoodBot.Display,
  spi_device: "spidev0.0",
  # Data/Command pin (GPIO 22)
  dc_pin: 22,
  # Reset pin (GPIO 11)
  rst_pin: 11,
  # Busy signal pin (GPIO 18)
  busy_pin: 18,
  # Chip Select pin (GPIO 24)
  cs_pin: 24

# Import target specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
# Uncomment to use target specific configurations

# import_config "#{Mix.target()}.exs"
