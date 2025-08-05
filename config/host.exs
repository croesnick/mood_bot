import Config

# Add configuration that is only needed when running on the host here.

# Display configuration for development
config :mood_bot, MoodBot.Display,
  # Enable bitmap saving in development for visual debugging
  save_bitmaps: true,
  # Required GPIO configuration (MockHAL doesn't use these but validation requires them)
  spi_device: "spidev0.0",
  dc_gpio: {"gpiochip0", 25},
  rst_gpio: {"gpiochip0", 17},
  busy_gpio: {"gpiochip0", 24},
  pwr_gpio: {"gpiochip0", 18}

config :mood_bot, MoodBot.Display.Driver, hal_module: MoodBot.Display.MockHAL

config :nerves_runtime,
  kv_backend:
    {Nerves.Runtime.KVBackend.InMemory,
     contents: %{
       # The KV store on Nerves systems is typically read from UBoot-env, but
       # this allows us to use a pre-populated InMemory store when running on
       # host for development and testing.
       #
       # https://hexdocs.pm/nerves_runtime/readme.html#using-nerves_runtime-in-tests
       # https://hexdocs.pm/nerves_runtime/readme.html#nerves-system-and-firmware-metadata

       "nerves_fw_active" => "a",
       "a.nerves_fw_architecture" => "generic",
       "a.nerves_fw_description" => "N/A",
       "a.nerves_fw_platform" => "host",
       "a.nerves_fw_version" => "0.0.0"
     }}
