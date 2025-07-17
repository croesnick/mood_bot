defmodule MoodBot.NetworkMonitor do
  @moduledoc """
  Monitors network interface status changes and provides callbacks for network events.

  This module subscribes to VintageNet property changes and can trigger actions
  based on network connectivity changes, signal strength changes, and interface
  state transitions.

  ## Usage

  The NetworkMonitor is automatically started as part of the supervision tree
  on target devices. It will log network events and can be configured to
  trigger custom actions.

  ## Events

  The following network events are monitored:
  - Interface state changes (configured, deconfigured, etc.)
  - Connection status changes (internet, lan, disconnected)
  - Signal strength changes (WiFi only)
  - IP address changes

  ## Examples

      iex> MoodBot.NetworkMonitor.get_status()
      %{
        eth0: %{state: :configured, connection: :internet, ip: "192.168.1.100"},
        wlan0: %{state: :configured, connection: :internet, ip: "192.168.1.101", signal: 75}
      }

      iex> MoodBot.NetworkMonitor.get_primary_interface()
      "eth0"
  """

  use GenServer
  require Logger

  @interfaces ["eth0", "wlan0", "usb0"]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Get current status of all monitored network interfaces.
  """
  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @doc """
  Get the primary (highest priority) network interface currently connected.
  """
  def get_primary_interface do
    GenServer.call(__MODULE__, :get_primary_interface)
  end

  @doc """
  Check if the device has internet connectivity.
  """
  def has_internet? do
    GenServer.call(__MODULE__, :has_internet)
  end

  @doc """
  Subscribe to network events.
  Process will receive messages of the form: {:network_event, event_type, interface, details}
  """
  def subscribe do
    GenServer.call(__MODULE__, {:subscribe, self()})
  end

  @doc """
  Unsubscribe from network events.
  """
  def unsubscribe do
    GenServer.call(__MODULE__, {:unsubscribe, self()})
  end

  # Server implementation

  @impl true
  def init(_opts) do
    target = Mix.target()

    # Only start monitoring on target devices
    if target != :host do
      # Subscribe to VintageNet property changes for all interfaces
      Enum.each(@interfaces, fn interface ->
        VintageNet.subscribe(["interface", interface, "state"])
        VintageNet.subscribe(["interface", interface, "connection"])
        VintageNet.subscribe(["interface", interface, "addresses"])

        # WiFi-specific subscriptions
        if interface == "wlan0" do
          VintageNet.subscribe(["interface", interface, "wifi", "signal_percent"])
          VintageNet.subscribe(["interface", interface, "wifi", "access_points"])
        end
      end)

      Logger.info(
        "NetworkMonitor: Started monitoring interfaces: #{Enum.join(@interfaces, ", ")}"
      )
    else
      Logger.info("NetworkMonitor: Running on host, network monitoring disabled")
    end

    state = %{
      interfaces: %{},
      subscribers: MapSet.new(),
      target: target
    }

    # Get initial status
    {:ok, update_all_interfaces(state)}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    {:reply, state.interfaces, state}
  end

  @impl true
  def handle_call(:get_primary_interface, _from, state) do
    primary = find_primary_interface(state.interfaces)
    {:reply, primary, state}
  end

  @impl true
  def handle_call(:has_internet, _from, state) do
    has_internet =
      state.interfaces
      |> Map.values()
      |> Enum.any?(&(&1.connection == :internet))

    {:reply, has_internet, state}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    new_subscribers = MapSet.put(state.subscribers, pid)
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end

  @impl true
  def handle_call({:unsubscribe, pid}, _from, state) do
    new_subscribers = MapSet.delete(state.subscribers, pid)
    {:reply, :ok, %{state | subscribers: new_subscribers}}
  end

  @impl true
  def handle_info(
        {VintageNet, ["interface", interface, "state"], _old_value, new_value, _metadata},
        state
      ) do
    Logger.info("NetworkMonitor: #{interface} state changed to #{inspect(new_value)}")

    new_state = update_interface_property(state, interface, :state, new_value)
    broadcast_event(:state_change, interface, %{state: new_value})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        {VintageNet, ["interface", interface, "connection"], _old_value, new_value, _metadata},
        state
      ) do
    Logger.info("NetworkMonitor: #{interface} connection changed to #{inspect(new_value)}")

    new_state = update_interface_property(state, interface, :connection, new_value)
    broadcast_event(:connection_change, interface, %{connection: new_value})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        {VintageNet, ["interface", interface, "addresses"], _old_value, new_value, _metadata},
        state
      ) do
    ip_address = extract_ip_address(new_value)
    Logger.info("NetworkMonitor: #{interface} IP address changed to #{inspect(ip_address)}")

    new_state = update_interface_property(state, interface, :ip, ip_address)
    broadcast_event(:ip_change, interface, %{ip: ip_address})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        {VintageNet, ["interface", interface, "wifi", "signal_percent"], _old_value, new_value,
         _metadata},
        state
      ) do
    Logger.debug("NetworkMonitor: #{interface} signal strength changed to #{inspect(new_value)}%")

    new_state = update_interface_property(state, interface, :signal, new_value)
    broadcast_event(:signal_change, interface, %{signal: new_value})

    {:noreply, new_state}
  end

  @impl true
  def handle_info(
        {VintageNet, ["interface", interface, "wifi", "access_points"], _old_value, new_value,
         _metadata},
        state
      ) do
    current_ssid = extract_current_ssid(new_value)
    Logger.debug("NetworkMonitor: #{interface} connected to SSID: #{inspect(current_ssid)}")

    new_state = update_interface_property(state, interface, :ssid, current_ssid)
    broadcast_event(:ssid_change, interface, %{ssid: current_ssid})

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove crashed subscriber
    new_subscribers = MapSet.delete(state.subscribers, pid)
    {:noreply, %{state | subscribers: new_subscribers}}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private functions

  defp update_all_interfaces(state) do
    if state.target == :host do
      # Mock data for host environment
      interfaces = %{
        "eth0" => %{state: :host_environment, connection: :unavailable, ip: nil},
        "wlan0" => %{
          state: :host_environment,
          connection: :unavailable,
          ip: nil,
          signal: nil,
          ssid: nil
        }
      }

      %{state | interfaces: interfaces}
    else
      # Get real status from VintageNet
      interfaces =
        @interfaces
        |> Enum.map(fn interface ->
          status = get_interface_status(interface)
          {interface, status}
        end)
        |> Map.new()

      %{state | interfaces: interfaces}
    end
  end

  defp get_interface_status(interface) do
    if Mix.target() == :host do
      %{
        state: :host_environment,
        connection: :unavailable,
        ip: nil,
        signal: nil,
        ssid: nil
      }
    else
      properties = VintageNet.get_by_prefix(["interface", interface])

      base_status = %{
        state: get_in(properties, ["interface", interface, "state"]) || :unconfigured,
        connection: get_in(properties, ["interface", interface, "connection"]) || :disconnected,
        ip: extract_ip_address(get_in(properties, ["interface", interface, "addresses"]))
      }

      # Add WiFi-specific properties
      if interface == "wlan0" do
        Map.merge(base_status, %{
          signal: get_in(properties, ["interface", interface, "wifi", "signal_percent"]),
          ssid:
            extract_current_ssid(
              get_in(properties, ["interface", interface, "wifi", "access_points"])
            )
        })
      else
        base_status
      end
    end
  end

  defp update_interface_property(state, interface, property, value) do
    current_interface = Map.get(state.interfaces, interface, %{})
    updated_interface = Map.put(current_interface, property, value)
    updated_interfaces = Map.put(state.interfaces, interface, updated_interface)

    %{state | interfaces: updated_interfaces}
  end

  defp extract_ip_address(addresses) when is_list(addresses) do
    addresses
    |> Enum.find(&(&1.family == :inet))
    |> case do
      %{address: {a, b, c, d}} -> "#{a}.#{b}.#{c}.#{d}"
      _ -> nil
    end
  end

  defp extract_ip_address(_), do: nil

  defp extract_current_ssid(access_points) when is_list(access_points) do
    case access_points do
      [%{ssid: ssid} | _] -> ssid
      _ -> nil
    end
  end

  defp extract_current_ssid(_), do: nil

  defp find_primary_interface(interfaces) do
    # Priority order: internet-connected eth0, then wlan0, then any connected interface
    interfaces
    |> Enum.filter(fn {_interface, status} -> status.connection in [:internet, :lan] end)
    |> Enum.sort_by(fn {interface, status} ->
      cond do
        status.connection == :internet && interface == "eth0" -> 1
        status.connection == :internet && interface == "wlan0" -> 2
        status.connection == :internet -> 3
        status.connection == :lan && interface == "eth0" -> 4
        status.connection == :lan && interface == "wlan0" -> 5
        true -> 6
      end
    end)
    |> case do
      [{interface, _status} | _] -> interface
      [] -> nil
    end
  end

  defp broadcast_event(event_type, interface, details) do
    GenServer.cast(__MODULE__, {:broadcast, event_type, interface, details})
  end

  @impl true
  def handle_cast({:broadcast, event_type, interface, details}, state) do
    Enum.each(state.subscribers, fn pid ->
      send(pid, {:network_event, event_type, interface, details})
    end)

    {:noreply, state}
  end
end
