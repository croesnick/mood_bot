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

  @doc """
  Scan for available WiFi networks.

  ## Examples

      iex> wifi_scan()
      [
        %{ssid: "MyNetwork", frequency: 2437, signal_percent: 67},
        %{ssid: "NeighborNetwork", frequency: 2462, signal_percent: 45}
      ]
  """
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

  @doc """
  Connect to a WiFi network.

  ## Examples

      iex> wifi_connect("MyNetwork", "MyPassword")
      {:ok, "WiFi configured for MyNetwork"}
  """
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

  @doc """
  Connect to a WPA2 Enterprise WiFi network.

  ## Examples

      iex> wifi_connect_enterprise("CorpNetwork", "username", "password")
      {:ok, "WiFi configured for CorpNetwork"}
  """
  @doc """
  Connect to a WiFi network temporarily (won't persist after reboot).

  ## Examples

      iex> wifi_connect_temp("GuestNetwork", "TempPassword")
      {:ok, "WiFi configured for GuestNetwork"}
  """
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

  @doc """
  Get current WiFi status.

  ## Examples

      iex> wifi_status()
      %{
        interface: "wlan0",
        state: :configured,
        connection: :internet,
        ssid: "MyNetwork",
        signal_percent: 67
      }
  """
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

  @doc """
  Disconnect from WiFi.

  ## Examples

      iex> wifi_disconnect()
      {:ok, "WiFi disabled"}
  """
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

  @doc """
  Display a mood on the e-ink display.

  ## Examples

      iex> display_mood(:happy)
      :ok
  """
  def display_mood(mood) when mood in [:happy, :sad, :neutral, :angry, :surprised] do
    result = MoodBot.Display.show_mood(mood)

    case result do
      :ok ->
        IO.puts("✓ Displaying mood: #{mood}")

      {:error, reason} ->
        IO.puts("✗ Failed to display mood: #{reason}")
    end

    result
  end

  @doc """
  Clear the e-ink display.

  ## Examples

      iex> display_clear()
      :ok
  """
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

  @doc """
  Fill the e-ink display with black.

  ## Examples

      iex> display_fill_black()
      :ok
  """
  def display_fill_black do
    result = MoodBot.Display.fill_black()

    case result do
      :ok ->
        IO.puts("✓ Display filled with black")

      {:error, reason} ->
        IO.puts("✗ Failed to fill display with black: #{reason}")
    end

    result
  end

  @doc """
  Get display status.

  ## Examples

      iex> display_status()
      %{initialized: true, display_state: :ready, ...}
  """
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

  @doc """
  Initialize the e-ink display.

  ## Examples

      iex> display_init()
      :ok
  """
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

  @doc """
  Show network status for all interfaces.

  ## Examples

      iex> network_status()
      %{
        eth0: %{state: :configured, connection: :internet, ip: "192.168.1.100"},
        wlan0: %{state: :configured, connection: :internet, ip: "192.168.1.101", signal: 75}
      }
  """
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

  @doc """
  Show system information.

  ## Examples

      iex> system_info()
      %{
        hostname: "nerves-1234",
        uptime: "2 days, 3 hours",
        memory: %{...},
        ...
      }
  """
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
  defp runtime_target do
    case Code.ensure_loaded(VintageNet) do
      {:module, VintageNet} -> :target
      {:error, _} -> :host
    end
  end

  @doc """
  Debug GPIO pins and show their status.

  ## Examples

      iex> gpio_debug()
  """
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

  @doc """
  Show help for MoodBot commands.

  ## Examples

      iex> help()
  """
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
      display_mood(:happy)                 - Show mood (:happy, :sad, :neutral, :angry, :surprised)
      display_clear()                      - Clear the display to white
      display_fill_black()                 - Fill the display with black
      display_status()                     - Show display status

    🔧 System Commands:
      system_info()                        - Show system information
      gpio_debug()                         - Debug GPIO pins and show status
      help()                               - Show this help

    For more detailed help on any function, use: h(function_name)
    Example: h(wifi_connect)
    """)
  end

  # Private helper functions

  defp connection_icon(connection) do
    case connection do
      :internet -> "🌐"
      :lan -> "🔗"
      :disconnected -> "🔴"
      :unavailable -> "⚪"
      _ -> "⚠️"
    end
  end

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

  defp format_bytes(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 1)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 1)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 1)} KB"
      true -> "#{bytes} bytes"
    end
  end
end
