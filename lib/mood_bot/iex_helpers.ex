defmodule MoodBot.IExHelpers do
  @moduledoc """
  Convenient helper functions for use in IEx sessions on MoodBot devices.

  This module provides shortcuts for common operations like WiFi configuration,
  display control, and system information.

  ## Usage

  These functions are automatically available in IEx sessions on target devices.
  Simply call them directly:

      iex> wifi_scan()
      iex> wifi_connect("MyNetwork", "MyPassword")
      iex> display_mood(:happy)
      iex> system_info()
  """

  @doc "Initialize the e-ink display."
  @spec display_init() :: :ok | {:error, binary()}
  def display_init do
    result = MoodBot.Display.init_display()

    case result do
      :ok ->
        IO.puts("✓ Display initialized")

      {:error, reason} ->
        IO.puts("✗ Failed to initialize display: #{reason}")
    end

    result
  end

  @doc "Get display status with visual indicators."
  @spec display_status() :: map()
  def display_status do
    status = MoodBot.Display.status()

    state_icon =
      case status.display_state do
        :ready -> "✓"
        :initialized -> "✓"
        :error -> "✗"
        _ -> "⚠️"
      end

    IO.puts("Display Status: #{state_icon} #{status.display_state}")
    IO.puts("  Initialized: #{status.initialized}")

    status
  end

  @doc "Clear the e-ink display to white."
  @spec display_clear() :: :ok | {:error, any()}
  def display_clear do
    result = MoodBot.Display.clear()

    case result do
      :ok ->
        IO.puts("✓ Display cleared")

      {:error, reason} ->
        IO.puts("✗ Failed to clear display: #{inspect(reason)}")
    end

    result
  end

  @doc "Display a mood on the e-ink display (:happy, :affirmation, :skeptic, :surprised, :angry, :crying)."
  @spec display_mood(atom()) :: :ok | {:error, binary()}
  def display_mood(mood)
      when mood in [:happy, :affirmation, :skeptic, :surprised, :angry, :crying] do
    mood_file = MoodBot.Moods.file_path(mood)

    result =
      with {:ok, image_data} <- MoodBot.Images.Bitmap.load_pbm(mood_file),
           :ok <- MoodBot.Display.display_image(image_data) do
        :ok
      end

    case result do
      :ok ->
        IO.puts("✓ Displaying mood: #{mood}")

      {:error, reason} ->
        IO.puts("✗ Failed to display mood: #{reason}")
    end

    result
  end

  @doc "Run comprehensive display demo (black → white → elixir logo → bitmap samples → clear)."
  @spec display_demo() :: :ok | {:error, binary()}
  def display_demo do
    all_white_image = :binary.copy(<<0xFF>>, div(128 * 296, 8))
    all_black_image = :binary.copy(<<0x00>>, div(128 * 296, 8))

    # Find some sample PBM files to use
    sample_images = [
      Path.join(:code.priv_dir(:mood_bot), "assets/moods/robot-face-approval.pbm")
    ]

    IO.puts("🖼️  Starting comprehensive display demo...")

    with :ok <- display_init(),
         :ok <- display_clear(),
         # Show programmatic images first
         :ok <- demo_step("all black", MoodBot.Display.display_image(all_black_image)),
         :ok <- Process.sleep(2_000),
         :ok <- demo_step("all white", MoodBot.Display.display_image(all_white_image)),
         :ok <- Process.sleep(2_000),
         # Show actual bitmap files
         :ok <- demo_loaded_images(sample_images),
         :ok <- demo_step("all white", MoodBot.Display.display_image(all_white_image)),
         :ok <- display_clear() do
      IO.puts("✓ Comprehensive display demo finished with PNG and bitmap files! 🎉")
    else
      {:error, reason} ->
        IO.puts("✗ Demo sequence failed 😞 Reason: #{reason}")
    end
  end

  @spec demo_step(binary(), any()) :: any()
  defp demo_step(description, operation) do
    IO.puts("  📺 Displaying: #{description}")
    operation
  end

  @spec demo_loaded_images(list(binary())) :: :ok
  defp demo_loaded_images([]), do: :ok

  defp demo_loaded_images([image_path | rest]) do
    case MoodBot.Images.Bitmap.load_pbm(image_path) do
      {:ok, image_data} ->
        filename = Path.basename(image_path)

        with :ok <- demo_step("PBM file: #{filename}", MoodBot.Display.display_image(image_data)),
             :ok <- Process.sleep(3_000) do
          demo_loaded_images(rest)
        end

      {:error, reason} ->
        IO.puts("  ⚠️  Skipping #{image_path}: #{reason}")
        demo_loaded_images(rest)
    end
  end

  @doc "Speak text using Azure TTS and play through audio output."
  @spec speak(String.t()) :: :ok | {:error, String.t()}
  def speak(text) do
    result = MoodBot.TTS.Runner.speak(text)

    case result do
      :ok ->
        IO.puts("✓ Speech completed")

      {:error, reason} ->
        IO.puts("✗ Failed to speak: #{reason}")
    end

    result
  end

  @doc "Chat with the language model"
  def chat(prompt) when is_binary(prompt) do
    chat(:smollm_2_360m, prompt)
  end

  @doc "Chat with a specific language model"
  def chat(model_name, prompt) when is_atom(model_name) and is_binary(prompt) do
    MoodBot.LanguageModels.Api.load_model(model_name)
    result = MoodBot.LanguageModels.Api.generate(model_name, prompt, &IO.write/1)
    IO.puts(inspect(result))
  end

  def chat_hello_codebeam_2025 do
    user_prompt =
      "Hallo MoodBot! Du bist gerade live auf der Konferenz Code BEAM Europe. Bitte stell dich kurz vor!"

    prompt_llama = """
      <|begin_of_text|><|start_header_id|>system<|end_header_id|>

      #{MoodBot.Controller.system_prompt()}<|eot_id|>

      <|start_header_id|>user<|end_header_id|>

      #{user_prompt}<|eot_id|>
    """

    chat(:llama_3_2_1b, prompt_llama)

    prompt_smollm = """
      <|im_start|>system
      #{MoodBot.Controller.system_prompt()}<|im_end|>

      <|im_start|>user
      #{user_prompt}<|im_end|>
    """

    chat(:smollm_2_360m, prompt_smollm)
  end

  @doc "Analyze sentiment of German text"
  def analyze_sentiment(text) when is_binary(text) do
    result = MoodBot.SentimentAnalysis.analyze(text)

    case result do
      {:ok, sentiment} ->
        sentiment_icon =
          case sentiment do
            :happy -> "😊"
            :affirmation -> "👍"
            :skeptic -> "🤨"
            :surprised -> "😮"
            :angry -> "😠"
            :crying -> "😢"
          end

        IO.puts("✓ Sentiment: #{sentiment} #{sentiment_icon}")

      {:error, reason} ->
        IO.puts("✗ Failed to analyze sentiment: #{inspect(reason)}")
    end

    result
  end

  @doc "Start recording audio (button press simulation)"
  def record_start do
    result = MoodBot.STT.Manager.start_recording()

    case result do
      :ok ->
        IO.puts("✓ Recording started. Use record_stop() to stop and transcribe.")

      {:error, reason} ->
        IO.puts("✗ Failed to start recording: #{inspect(reason)}")
    end

    result
  end

  @doc "Stop recording and transcribe audio"
  def record_stop do
    result = MoodBot.STT.Manager.stop_recording()

    case result do
      {:ok, text} ->
        IO.puts("✓ Transcription: #{text}")

      {:error, reason} ->
        IO.puts("✗ Failed to stop recording: #{inspect(reason)}")
    end

    result
  end

  @doc "Show network status for all interfaces with visual indicators."
  @spec network_status() :: map()
  def network_status do
    status = MoodBot.NetworkMonitor.get_status()

    IO.puts("Network Status:")

    Enum.each(status, fn {interface, info} ->
      connection_icon = connection_icon(info.connection)

      signal_info =
        if Map.has_key?(info, :signal) and info.signal,
          do: " #{signal_to_bars(info.signal)}",
          else: ""

      IO.puts("  #{interface}: #{connection_icon} #{info.state} #{signal_info}")
      if info.ip, do: IO.puts("    IP: #{info.ip}")
      if Map.get(info, :ssid), do: IO.puts("    SSID: #{info.ssid}")
    end)

    primary = MoodBot.NetworkMonitor.get_primary_interface()
    internet = MoodBot.NetworkMonitor.has_internet?()

    IO.puts("\nPrimary Interface: #{primary || "none"}")
    IO.puts("Internet Access: #{if internet, do: "✓ Yes", else: "✗ No"}")

    status
  end

  @doc "Scan for available WiFi networks (shows top 10)."
  @spec wifi_scan() :: list(map())
  def wifi_scan do
    networks = MoodBot.WiFiConfig.scan()

    if length(networks) > 0 do
      IO.puts("Available WiFi networks:")

      networks
      # Show top 10 networks
      |> Enum.take(10)
      |> Enum.each(fn network ->
        signal_bars = signal_to_bars(network.signal_percent)
        IO.puts("  #{network.ssid} #{signal_bars} (#{network.signal_percent}%)")
      end)
    else
      IO.puts("No WiFi networks found")
    end

    networks
  end

  @doc "Connect to a WiFi network (persistent)."
  @spec wifi_connect(binary(), binary()) :: {:ok, binary()} | {:error, binary()}
  def wifi_connect(ssid, password) do
    result = MoodBot.WiFiConfig.configure_wifi(ssid, password)

    case result do
      {:ok, message} ->
        IO.puts("✓ #{message}")
        IO.puts("  Use wifi_status() to check connection status")

      {:error, reason} ->
        IO.puts("✗ Failed to connect: #{reason}")
    end

    result
  end

  @doc "Connect to a WiFi network temporarily (won't persist after reboot)."
  @spec wifi_connect_temp(binary(), binary()) :: {:ok, binary()} | {:error, binary()}
  def wifi_connect_temp(ssid, password) do
    result = MoodBot.WiFiConfig.configure_wifi_temporary(ssid, password)

    case result do
      {:ok, message} ->
        IO.puts("✓ #{message} (temporary)")
        IO.puts("  Use wifi_status() to check connection status")

      {:error, reason} ->
        IO.puts("✗ Failed to connect: #{reason}")
    end

    result
  end

  @doc "Get current WiFi status with visual indicators."
  @spec wifi_status() :: map()
  def wifi_status do
    status = MoodBot.WiFiConfig.status()

    case status.state do
      :configured ->
        connection_icon =
          case status.connection do
            :internet -> "🌐"
            :lan -> "🔗"
            _ -> "⚠️"
          end

        IO.puts("WiFi Status: #{connection_icon} #{status.state}")
        IO.puts("  Network: #{status.ssid}")
        IO.puts("  Signal: #{signal_to_bars(status.signal_percent)} (#{status.signal_percent}%)")
        IO.puts("  Connection: #{status.connection}")

      :unconfigured ->
        IO.puts("WiFi Status: ⚪ Not configured")
        IO.puts("  Use wifi_scan() to find networks")
        IO.puts("  Use wifi_connect(ssid, password) to connect")

      other ->
        IO.puts("WiFi Status: #{other}")
    end

    status
  end

  @doc "Disconnect from WiFi."
  @spec wifi_disconnect() :: {:ok, binary()} | {:error, binary()}
  def wifi_disconnect do
    result = MoodBot.WiFiConfig.disable_wifi()

    case result do
      {:ok, message} ->
        IO.puts("✓ #{message}")

      {:error, reason} ->
        IO.puts("✗ Failed to disconnect: #{reason}")
    end

    result
  end

  @doc "Show system information (hostname, target, interfaces, memory)."
  @spec system_info() :: map()
  def system_info do
    hostname = :inet.gethostname() |> elem(1) |> to_string()

    # Get network interfaces (target-aware)
    interfaces =
      if runtime_target() == :host do
        ["eth0", "wlan0"]
      else
        VintageNet.all_interfaces()
      end

    # Get memory info
    memory = :erlang.memory()

    info = %{
      hostname: hostname,
      target: runtime_target(),
      interfaces: interfaces,
      memory: %{
        total: memory[:total],
        processes: memory[:processes],
        system: memory[:system]
      }
    }

    IO.puts("System Information:")
    IO.puts("  Hostname: #{hostname}")
    IO.puts("  Target: #{runtime_target()}")
    IO.puts("  Interfaces: #{Enum.join(interfaces, ", ")}")
    IO.puts("  Memory: #{format_bytes(memory[:total])}")

    info
  end

  # Runtime-safe target detection
  @spec runtime_target() :: :host | :target
  defp runtime_target do
    case Code.ensure_loaded(VintageNet) do
      {:module, VintageNet} -> :target
      {:error, _} -> :host
    end
  end

  @doc "Debug GPIO pins and show their status (display pins: DC:22, RST:11, BUSY:18, CS:24)."
  @spec gpio_debug() :: map()
  def gpio_debug do
    IO.puts("GPIO Backend Info:")
    backend_info = Circuits.GPIO.backend_info()
    IO.inspect(backend_info)

    IO.puts("\nAvailable GPIOs:")
    available_gpios = Circuits.GPIO.enumerate()
    available_gpios |> Enum.take(10) |> Enum.each(&IO.inspect/1)

    IO.puts("\nDisplay pins status (DC:22, RST:11, BUSY:18, CS:24):")

    [11, 18, 22, 24]
    |> Enum.each(fn pin ->
      status =
        case Circuits.GPIO.status(pin) do
          {:ok, info} -> info
          {:error, reason} -> "Error: #{inspect(reason)}"
        end

      IO.puts("  GPIO #{pin}: #{inspect(status)}")
    end)

    %{
      backend: backend_info,
      available_count: length(available_gpios),
      display_pins: [11, 18, 22, 24]
    }
  end

  @doc "Show help for MoodBot IEx commands."
  @spec help() :: :ok
  def help do
    IO.puts("""
    MoodBot Helper Commands:

    📶 WiFi Commands:
      wifi_scan()                          - Scan for WiFi networks
      wifi_connect(ssid, password)         - Connect to WiFi network (persistent)
      wifi_connect_temp(ssid, password)    - Connect to WiFi network (temporary)
      wifi_status()                        - Show WiFi status
      wifi_disconnect()                    - Disconnect from WiFi

    🌐 Network Commands:
      network_status()                     - Show all network interfaces status

    📺 Display Commands:
      display_init()                       - Initialize the display
      display_demo()                       - Comprehensive demo (black → white → elixir logo → bitmap samples → clear)
      display_mood(:happy)                 - Show mood (:happy, :affirmation, :skeptic, :surprised, :angry, :crying)
      display_clear()                      - Clear the display to white
      display_fill_black()                 - Fill the display with black
      display_status()                     - Show display status

    🔊 TTS Commands:
      speak("Hello world")                 - Speak text using Azure TTS

    ✨ Language Model Commands:
      chat("Hello, how are you?")          - Chat with the language model

    🧠 Sentiment Analysis Commands:
      analyze_sentiment("Das ist toll!")   - Analyze German text sentiment

    🎤 Voice Commands:
      record_start()                       - Start recording audio
      record_stop()                        - Stop recording and transcribe

    🔧 System Commands:
      system_info()                        - Show system information
      gpio_debug()                         - Debug GPIO pins and show status
      help()                               - Show this help

    For more detailed help on any function, use: h(function_name)
    Example: h(wifi_connect)
    """)
  end

  # Private helper functions

  @spec connection_icon(atom()) :: binary()
  defp connection_icon(connection) do
    case connection do
      :internet -> "🌐"
      :lan -> "🔗"
      :disconnected -> "🔴"
      :unavailable -> "⚪"
      _ -> "⚠️"
    end
  end

  @spec signal_to_bars(integer() | any()) :: binary()
  defp signal_to_bars(signal_percent) when is_integer(signal_percent) do
    cond do
      signal_percent >= 75 -> "▰▰▰▰"
      signal_percent >= 50 -> "▰▰▰▱"
      signal_percent >= 25 -> "▰▰▱▱"
      signal_percent >= 10 -> "▰▱▱▱"
      true -> "▱▱▱▱"
    end
  end

  defp signal_to_bars(_), do: "▱▱▱▱"

  @spec format_bytes(non_neg_integer()) :: binary()
  defp format_bytes(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} bytes"
    end
  end
end
