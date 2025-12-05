import Config

# Add configuration that is only needed when running on the host here.

# Configure logger to display metadata in console output during development
config :logger, :default_formatter,
  format: "$time [$level] $message | $metadata\n",
  metadata: [
    :duration_ms,
    :repo,
    :pid,
    :name,
    :error,
    :api_name,
    :serving_name,
    :model_config,
    :config,
    :message
  ]

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

config :mood_bot, MoodBot.Display.Driver,
  hal_module: MoodBot.Display.MockHAL,
  spi_device: "mock_spi",
  gpio: %{
    dc_gpio: {"mock", 0},
    rst_gpio: {"mock", 0},
    busy_gpio: {"mock", 0},
    pwr_gpio: {"mock", 0}
  }

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

# config :nx, default_backend: Nx.BinaryBackend
config :nx, default_backend: EXLA.Backend
config :nx, :default_defn_options, compiler: EXLA

# Language models configuration for development
# Use smaller models for faster loading during development
config :mood_bot, :language_models,
  llama_3_2_1b: [
    repo: {:hf, "meta-llama/Llama-3.2-1B-Instruct", auth_token: System.get_env("HF_TOKEN")},
    generation_config: [max_new_tokens: 250]
  ],
  smollm_2_1_7b: [
    repo: {:hf, "HuggingFaceTB/SmolLM2-1.7B-Instruct", auth_token: System.get_env("HF_TOKEN")},
    generation_config: [max_new_tokens: 250]
  ],
  smollm_2_360m: [
    repo: {:hf, "HuggingFaceTB/SmolLM2-360M-Instruct", auth_token: System.get_env("HF_TOKEN")},
    generation_config: [max_new_tokens: 250]
  ],
  smollm_2_135m: [
    repo: {:hf, "HuggingFaceTB/SmolLM2-135M-Instruct", auth_token: System.get_env("HF_TOKEN")},
    generation_config: [max_new_tokens: 250]
  ]
