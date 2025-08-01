defmodule MoodBot.WiFiConfig do
  @moduledoc """
  Helper module for configuring WiFi on MoodBot devices.

  This module provides various methods to configure WiFi at runtime,
  including environment variables, interactive setup, and persistence.

  Note: WiFi configuration is only available on target hardware, not on host.
  """

  require Logger

  # Store target at compile time since Mix.target() is not available at runtime
  @target Mix.target()

  @doc """
  Configure WiFi using environment variables.

  Looks for WIFI_SSID and WIFI_PSK environment variables and configures
  the WiFi interface if both are present.

  ## Examples

      # Set environment variables before starting
      # export WIFI_SSID="MyNetwork"
      # export WIFI_PSK="MyPassword"

      iex> MoodBot.WiFiConfig.configure_from_env()
      {:ok, "WiFi configured for MyNetwork"}

      # If environment variables are not set
      iex> MoodBot.WiFiConfig.configure_from_env()
      {:error, "WIFI_SSID and WIFI_PSK environment variables not set"}
  """
  def configure_from_env do
    case {System.get_env("WIFI_SSID"), System.get_env("WIFI_PSK")} do
      {ssid, psk} when is_binary(ssid) and is_binary(psk) ->
        Logger.info("WiFi: Configuring from environment variables")
        configure_wifi_impl(@target, ssid, psk, persist: true)

      _ ->
        {:error, "WIFI_SSID and WIFI_PSK environment variables not set"}
    end
  end

  @doc """
  Configure WiFi with explicit SSID and password.

  ## Examples

      iex> MoodBot.WiFiConfig.configure_wifi("MyNetwork", "MyPassword")
      {:ok, "WiFi configured for MyNetwork"}
  """
  def configure_wifi(ssid, psk) when is_binary(ssid) and is_binary(psk) do
    configure_wifi_impl(@target, ssid, psk, persist: true)
  end

  @doc """
  Configure WiFi with explicit SSID and password without persistence.

  This is useful for temporary connections that shouldn't survive a reboot.

  ## Examples

      iex> MoodBot.WiFiConfig.configure_wifi_temporary("GuestNetwork", "TempPassword")
      {:ok, "WiFi configured temporarily for GuestNetwork"}
  """
  def configure_wifi_temporary(ssid, psk) when is_binary(ssid) and is_binary(psk) do
    configure_wifi_impl(@target, ssid, psk, persist: false)
  end

  @doc """
  Remove WiFi configuration and disable the interface.

  ## Examples

      iex> MoodBot.WiFiConfig.disable_wifi()
      {:ok, "WiFi disabled"}
  """
  def disable_wifi do
    disable_wifi_impl(@target)
  end

  @doc """
  Get current WiFi status and configuration.

  ## Examples

      iex> MoodBot.WiFiConfig.status()
      %{
        interface: "wlan0",
        state: :configured,
        connection: :internet,
        ssid: "MyNetwork",
        frequency: 2437,
        signal_percent: 67
      }
  """
  def status do
    status_impl(@target)
  end

  @doc """
  Scan for available WiFi networks.

  ## Examples

      iex> MoodBot.WiFiConfig.scan()
      [
        %{ssid: "MyNetwork", frequency: 2437, signal_percent: 67},
        %{ssid: "NeighborNetwork", frequency: 2462, signal_percent: 45}
      ]
  """
  def scan do
    scan_impl(@target)
  end

  @doc """
  Try to automatically configure WiFi from environment variables on startup.

  This function is meant to be called during application startup to
  automatically configure WiFi if environment variables are available.
  """
  def auto_configure do
    case configure_from_env() do
      {:ok, message} ->
        Logger.info("WiFi: #{message}")
        :ok

      {:error, _reason} ->
        Logger.info(
          "WiFi: No environment variables found, WiFi available for manual configuration"
        )

        :ok
    end
  end

  # Target-specific implementations

  # Host implementation - returns informative messages
  defp configure_wifi_impl(:host, ssid, _psk, _opts) do
    Logger.info("WiFi: Host environment detected, WiFi configuration not available")
    {:error, "WiFi configuration only available on target hardware, not host. SSID: #{ssid}"}
  end

  # Target implementation - uses VintageNet with modern generic configuration
  defp configure_wifi_impl(_target, ssid, psk, opts) do
    # Use modern generic configuration that supports WPA2/WPA3 compatibility
    config = VintageNetWiFi.Cookbook.generic(ssid, psk)

    # Validate configuration before applying
    case VintageNet.configuration_valid?("wlan0", config) do
      true ->
        case VintageNet.configure("wlan0", config, opts) do
          :ok ->
            persistence_msg = if opts[:persist] == false, do: " (temporary)", else: ""

            Logger.info(
              "WiFi: Successfully configured for network: #{ssid} (WPA2/WPA3 compatible)#{persistence_msg}"
            )

            {:ok, "WiFi configured for #{ssid}"}

          {:error, reason} ->
            Logger.error("WiFi: Failed to configure: #{inspect(reason)}")
            {:error, "WiFi configuration failed: #{inspect(reason)}"}
        end

      false ->
        Logger.error("WiFi: Invalid configuration for network: #{ssid}")
        {:error, "Invalid WiFi configuration"}
    end
  end

  # Host implementation - returns informative message
  defp disable_wifi_impl(:host) do
    Logger.info("WiFi: Host environment detected, WiFi control not available")
    {:error, "WiFi control only available on target hardware, not host"}
  end

  # Target implementation - uses VintageNet
  defp disable_wifi_impl(_target) do
    case VintageNet.deconfigure("wlan0") do
      :ok ->
        Logger.info("WiFi: Disabled")
        {:ok, "WiFi disabled"}

      {:error, reason} ->
        Logger.error("WiFi: Failed to disable: #{inspect(reason)}")
        {:error, "Failed to disable WiFi: #{inspect(reason)}"}
    end
  end

  # Host implementation - returns mock status
  defp status_impl(:host) do
    %{
      interface: "wlan0",
      state: :host_environment,
      connection: :unavailable,
      ssid: nil,
      frequency: nil,
      signal_percent: nil,
      message: "WiFi status only available on target hardware"
    }
  end

  # Target implementation - uses VintageNet
  defp status_impl(_target) do
    case VintageNet.get_configuration("wlan0") do
      %{type: VintageNetWiFi} ->
        properties = VintageNet.get_by_prefix(["interface", "wlan0"])
        properties_map = Enum.into(properties, %{})

        %{
          interface: "wlan0",
          state: Map.get(properties_map, ["interface", "wlan0", "state"]),
          connection: Map.get(properties_map, ["interface", "wlan0", "connection"]),
          ssid: get_current_ssid(properties_map),
          frequency: Map.get(properties_map, ["interface", "wlan0", "wifi", "frequency"]),
          signal_percent:
            Map.get(properties_map, ["interface", "wlan0", "wifi", "signal_percent"])
        }

      _ ->
        %{interface: "wlan0", state: :unconfigured}
    end
  end

  # Host implementation - returns empty list with message
  defp scan_impl(:host) do
    Logger.info("WiFi: Host environment detected, WiFi scanning not available")
    []
  end

  # Target implementation - uses VintageNet
  defp scan_impl(_target) do
    case VintageNet.scan("wlan0") do
      {:ok, access_points} ->
        access_points
        |> Enum.map(fn ap ->
          # Convert signal_dbm to signal_percent using a simple conversion
          # Good signal: -30 dBm = 100%, Poor signal: -90 dBm = 0%
          signal_percent = dbm_to_percent(ap.signal_dbm)

          %{
            ssid: ap.ssid,
            frequency: ap.frequency,
            signal_percent: signal_percent,
            flags: ap.flags
          }
        end)
        |> Enum.sort_by(& &1.signal_percent, :desc)

      {:error, reason} ->
        Logger.error("WiFi: Scan failed: #{inspect(reason)}")
        []
    end
  end

  # Private helper functions

  defp get_current_ssid(properties_map) do
    case Map.get(properties_map, ["interface", "wlan0", "wifi", "access_points"]) do
      [%{ssid: ssid} | _] -> ssid
      _ -> nil
    end
  end

  # Convert dBm to percentage
  # This uses a simple linear conversion where:
  # - -30 dBm = 100% (excellent signal)
  # - -90 dBm = 0% (poor signal)
  defp dbm_to_percent(dbm) when is_number(dbm) do
    # Clamp between -90 and -30 dBm
    clamped_dbm = max(-90, min(-30, dbm))
    # Convert to percentage (0-100)
    percentage = round((clamped_dbm + 90) / 60 * 100)
    max(1, min(100, percentage))
  end

  defp dbm_to_percent(_), do: 0
end
