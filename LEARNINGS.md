# Loose collection of learnings

- After flasing the sd card and booting the pi with it, the pi still does not appear in my Wifi. How to debug that?

## Nerves Conditional Compilation Patterns

### Problem: VintageNet only available on target, not host

When developing Nerves applications, certain dependencies like VintageNet (networking) are only available on embedded targets, not during host development. This causes compilation warnings and prevents clean development workflows.

### Best Practices for Target-Specific Code

1. **Mix.target() Pattern (Recommended)**
   - Use `Mix.target()` in supervision trees and configuration
   - Provide different implementations for `:host` vs target hardware
   - Example: `defp children(:host), do: []` vs `defp children(_target), do: [...]`

2. **Configuration-Based Approach**
   - Use target-specific config files (`config/host.exs` vs `config/target.exs`)
   - Only include networking dependencies for targets: `targets: @all_targets`

3. **Avoid Code.ensure_loaded? for This Use Case**
   - While `Code.ensure_loaded?` works, it's not idiomatic for Nerves
   - Better suited for optional dependencies, not target-specific ones

4. **Nerves Pack Philosophy**
   - Use `nerves_pack` which bundles VintageNet only for targets
   - Host development focuses on business logic, not hardware interfaces

### Implementation Strategy

- Restructure modules to be target-aware from the start
- Host implementations return informative messages about needing hardware
- Target implementations use hardware libraries normally
- Never use `@compile {:no_warn_undefined, ...}` as an escape hatch

## Deep Understanding of Nerves Interface Configuration

### Architecture Overview

**Core Components:**

- **nerves_pack**: Meta-package that brings together all networking services (VintageNet, SSH, mDNS, Time, Logging)
- **vintage_net**: Core networking configuration system that replaces `nerves_network`
- **nerves_ssh**: SSH daemon management with subsystems (replaces `nerves_firmware_ssh`)
- **mdns_lite**: mDNS service discovery for `.local` hostnames
- **nerves_time**: NTP time synchronization with RTC support
- **vintage_net_ethernet/wifi**: Technology-specific implementations

**Configuration Hierarchy:**
VintageNet uses a three-tier configuration system:

1. Application config (`config.exs`) - safe defaults
2. Persisted configuration - runtime changes saved to disk
3. Runtime configuration - temporary changes via `VintageNet.configure/2`

### Best Practices & Key Patterns

**Configuration Strategy:**

- **Always provide safe defaults** in application config for all network interfaces
- **Use runtime configuration** for user-specific settings (WiFi credentials, static IPs)
- **Configurations are persisted automatically** unless `persist: false` is specified
- **VintageNet completely tears down and rebuilds** interfaces on configuration changes

**Network Interface Priority:**
Default routing priority (handled by `VintageNet.Route.DefaultMetric`):

1. Internet-connected interfaces over LAN-connected interfaces
2. Wired Ethernet > WiFi > Mobile > Other interfaces
3. Interface weight derived from index (eth0 = 0, eth1 = 1, etc.)

**Security Patterns:**

- **SSH uses public key authentication by default** (much safer than passwords)
- **Host keys are auto-generated** and stored in `/data/nerves_ssh`
- **Supports Ed25519 and RSA host keys** with automatic fallback
- **Username/password auth stores passwords in clear text** (not recommended)

### Do's and Don'ts

**DO:**

- **Set regulatory domain** for WiFi compliance: `config :vintage_net, regulatory_domain: "US"`
- **Use `shoehorn` to start nerves_pack early** for network reliability
- **Configure mDNS hostnames** for easy device discovery (`nerves.local`)
- **Use generic WiFi configurations** for WPA2/WPA3 compatibility
- **Monitor network status** via `VintageNet.subscribe/1`
- **Use MAC address callbacks** for device-specific addresses
- **Validate configurations** with `VintageNet.configuration_valid?/2`
- **Use `persist: false`** for temporary configurations
- **Enable WPA3 support** in Buildroot even if not using it

**DON'T:**

- **Hardcode WiFi credentials** in application config
- **Use password authentication** for SSH unless absolutely necessary
- **Ignore regulatory domain settings** (can make APs invisible)
- **Attempt incremental network modifications** (VintageNet doesn't support this)
- **Use deprecated `nerves_network` patterns**
- **Call `restart_ntp` too frequently** (violates NTP Pool terms of service)
- **Forget to supervise SSH daemon** properly

### Common Configuration Patterns

**Ethernet DHCP:**

```elixir
config :vintage_net,
  config: [
    {"eth0", %{type: VintageNetEthernet, ipv4: %{method: :dhcp}}}
  ]
```

**WiFi Generic (WPA2/WPA3 Compatible):**

```elixir
VintageNetWiFi.Cookbook.generic("NetworkName", "password")
```

**SSH Configuration:**

```elixir
config :nerves_ssh,
  authorized_keys: [File.read!(Path.join(System.user_home!(), ".ssh/id_rsa.pub"))],
  port: 22,
  shell: :elixir,
  system_dir: "/data/nerves_ssh"
```

**mDNS Setup:**

```elixir
config :mdns_lite,
  hosts: [:hostname, "nerves"],
  ttl: 120,
  services: [
    %{protocol: "ssh", transport: "tcp", port: 22},
    %{protocol: "sftp-ssh", transport: "tcp", port: 22}
  ]
```

### Troubleshooting Guidelines

**Debugging Network Issues:**

- **Use `VintageNet.info/0`** for overall interface status
- **Subscribe to property changes** for real-time monitoring
- **Check `VintageNet.get_configuration/1`** for normalized configs
- **Use `VintageNet.configuration_valid?/2`** for validation
- **Monitor properties** via `VintageNet.get_by_prefix/1`

**Common Issues:**

- **WiFi not appearing**: Check regulatory domain and hardware support
- **SSH connection refused**: Verify authorized keys and host key generation
- **Time sync issues**: Check NTP servers and network connectivity
- **mDNS not working**: Verify network interface is up and multicast enabled

### Technology-Specific Notes

**VintageNet Features:**

- **Internet connectivity monitoring** and automatic failover
- **Predictable network interface names** (no more random eth0/eth1)
- **Support for multiple simultaneous connections** with automatic prioritization
- **Configuration persistence** with obfuscation for sensitive data

**SSH Subsystems:**

- **SFTP subsystem** enabled by default
- **Firmware update subsystem** via `ssh_subsystem_fwup`
- **Custom subsystems** can be added dynamically
- **IEx shell** with configurable options

**Time Synchronization:**

- **Automatic NTP synchronization** with configurable servers
- **RTC support** via behavior pattern
- **File-based time approximation** for devices without RTC
- **Graceful handling** of network disconnections

**Key Insight:** VintageNet's approach of complete teardown/rebuild simplifies state management while the persistence layer ensures configurations survive reboots. This differs significantly from incremental state machine approaches used in previous networking libraries.
