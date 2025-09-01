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

## Remote Debugging with SSH MCP for Nerves

### Challenge: Interactive IEx vs Non-Interactive SSH Commands

**Problem:** Nerves debugging typically uses interactive IEx sessions with Toolshed helpers like `wifi_status()`, `ifconfig`, etc. However, SSH MCP executes discrete commands without maintaining IEx session state.

**Solution:** Use direct Elixir function calls without `iex -e` wrapper - this approach is simpler and more reliable than complex evaluation patterns.

### SSH MCP Server Setup

**Repository:** <https://github.com/tufantunc/ssh-mcp>

**Capabilities:**

- MCP-compliant server for executing shell commands over SSH
- Secure authentication (password or SSH key)
- Configurable command timeouts
- Direct integration with Claude Code for automated debugging

### Working Direct Function Call Patterns

**Network Overview:**

```bash
VintageNet.info()
```

**WiFi Interface Status:**

```bash
VintageNet.get("interface.wlan0.state")
```

**WiFi Configuration:**

```bash
VintageNet.get_configuration("wlan0")
```

**Available WiFi Networks:**

```bash
VintageNet.scan("wlan0")
```

**All Network Interfaces:**

```bash
VintageNet.all_interfaces()
```

**System Information:**

```bash
:os.type()
System.version()
```

**Application Status:**

```bash
Application.started_applications() |> Enum.map(fn {name, _desc, _vsn} -> name end)
```

**MoodBot WiFi Status (when application is running):**

```bash
MoodBot.WiFiConfig.status()
```

### What Doesn't Work

**❌ `iex -e '...' --no-halt` patterns:**

- Causes compilation errors
- Adds unnecessary complexity
- Not compatible with SSH MCP execution

**❌ Complex try/rescue patterns:**

- Don't properly handle errors in this context
- Add unnecessary verbosity

**❌ `IO.inspect` wrappers:**

- Not needed - direct function returns work better
- Functions already return properly formatted data

### Key Advantages

1. **Simple and Reliable:** Direct function calls without complex evaluation wrappers
2. **No File Transfers:** Commands are self-contained, no need to upload debugging modules
3. **SSH MCP Compatible:** Each command is discrete and can be executed via MCP
4. **No State Dependency:** Each execution is independent, no session state required
5. **Direct Integration:** Works seamlessly with Claude Code for automated debugging

### Best Practices

- Use direct function calls instead of `iex -e` wrappers
- Functions return data directly - no need for `IO.inspect`
- Test commands manually first before integrating with SSH MCP automation
- Keep commands simple and focused on single operations
- Use VintageNet functions for network debugging (always available)
- Check if MoodBot application is running before calling MoodBot-specific functions

## GPIO Pin Debugging on Nerves

### Challenge: Misleading "GPIO Busy" Errors

**Problem:** Hardware initialization errors often show "GPIO busy" messages that suggest pins are unavailable, but the actual issue may be elsewhere in the hardware abstraction layer.

**Solution:** Use `circuits_gpio` built-in diagnostics to distinguish between actual pin conflicts and hardware logic errors.

### Simple GPIO Debugging Pattern

**Add a debugging function to your IEx helpers:**

```elixir
def gpio_debug do
  IO.puts("GPIO Backend Info:")
  backend_info = Circuits.GPIO.backend_info()
  IO.inspect(backend_info)
  
  IO.puts("\nAvailable GPIOs:")
  available_gpios = Circuits.GPIO.enumerate()
  available_gpios |> Enum.take(10) |> Enum.each(&IO.inspect/1)
  
  IO.puts("\nDisplay pins status (DC:22, RST:11, BUSY:18, CS:24):")
  [11, 18, 22, 24] |> Enum.each(fn pin ->
    status = 
      case Circuits.GPIO.status(pin) do
        {:ok, info} -> info
        {:error, reason} -> "Error: #{inspect(reason)}"
      end
    IO.puts("  GPIO #{pin}: #{inspect(status)}")
  end)
end
```

### Key Insights from MoodBot GPIO Debugging

1. **"GPIO busy" doesn't mean pins are unavailable** - It often means they're properly claimed by `circuits_gpio`
2. **Pin status shows actual configuration**: direction (input/output), pull mode, consumer
3. **Real hardware errors occur in the HAL layer** - not in GPIO claiming
4. **Case clause errors indicate missing value handling** - e.g., busy pin returning `0` with no case clause

### Successful Debugging Workflow

1. **Add gpio_debug() function** to your IEx helpers
2. **Test via SSH MCP**: `ssh nerves.local "ModuleName.gpio_debug()"`
3. **Check pin status** - look for proper claiming by "circuits_gpio"
4. **If pins are properly claimed**, look for errors in hardware abstraction layer
5. **Focus on the actual error location** - not misleading "GPIO busy" messages

### Example Findings

**What we thought:** GPIO pins 11, 18, 22, 24 were busy/unavailable
**Reality:** All pins properly claimed by circuits_gpio with correct direction
**Actual issue:** Case clause error in `gpio_read_busy/1` when busy pin returns `0`

This simple debugging approach saves hours of troubleshooting GPIO availability when the real issue is in hardware logic.

## SPI and CS GPIO Pin

> I don't understand that yet. CS is a specific GPIO pin. The Python epaper driver also controls it. Explain the issue to me, and point me to the docs (maybe circuits_gpio or circuits_spi) to understand the problem in depth before performing any changes.

⏺ You're absolutely right to want to understand this better. Let me explain the CS (Chip Select) GPIO conflict issue in detail.

**The Problem**

GPIO pin 8 is being claimed by two different systems:

1. SPI subsystem: When we open "spidev0.0", the Linux SPI driver automatically claims GPIO 8 as "spi0 CS0" (hardware chip select)
2. Our code: We're trying to manually open GPIO 8 as cs_gpio for manual control

This creates a conflict - you can't have both automatic AND manual control of the same pin.

Evidence from the Device

**GPIO 8 status shows it's already claimed**

```elixir
{8, {:ok, %{consumer: "spi0 CS0"}}}  # ← Already claimed by SPI subsystem
```

**Error when trying to start**

```elixir
{:already_open}  # ← This is Circuits.GPIO telling us pin 8 is unavailable
```

How SPI CS Works - Two Approaches

1. Hardware-Managed CS (spidev0.0)

   - Linux SPI driver automatically controls CS
   - CS goes low during transfer, high when idle
   - Pros: Automatic, precise timing
   - Cons: Less control over CS timing

2. Manual CS Control

   - Use a different GPIO pin (not pin 8)
   - Manually control CS in your code
   - Pros: Full control over CS timing
   - Cons: More complex, timing-sensitive

Documentation References

Circuits.SPI docs: <https://hexdocs.pm/circuits_spi/Circuits.SPI.html>

Key quote:
> "The chip select pin is handled automatically by the SPI driver when using spidev devices"

Circuits.GPIO docs: <https://hexdocs.pm/circuits_gpio/Circuits.GPIO.html>

The :already_open error occurs when trying to open a GPIO that's already claimed by another kernel driver.

Python Driver Comparison

The Python epaper driver likely uses one of these approaches:

1. Manual SPI: Uses /dev/mem or GPIO sysfs directly (bypasses spidev)
2. Different CS pin: Uses a GPIO pin other than the hardware CS
3. SPI device selection: Uses a different SPI device that doesn't auto-claim CS

Solutions

Option A: Use hardware CS (remove manual CS control)
Option B: Change to a different GPIO pin for manual CSOption C: Use a different SPI device configuration

Which approach would you prefer? I can show you the specific code changes once you decide on the direction.

> Question is: Do I _need_ to control CS for the eink display to work? Or could I just rely on spidev to handle CS?

⏺ Great question! Let me research this by looking at the e-ink display communication requirements and SPI timing.

⏺ hexdocs - fetch (MCP)(packageName: "circuits_spi")
  ⎿  Latest version of circuits_spi is 2.0.4
     ✓ Embeddings for circuits_spi 2.0.4 already exist, skipping fetch.
       Use --force to re-fetch and update embeddings.

⏺ hexdocs - search (MCP)(packageName: "circuits_spi", query: "chip select CS control automatic manual timing requirements", limit: 3)
  ⎿  Searching for "chip select CS control automatic manual timing requirements" in circuits_spi (latest versions only)...
     ✓ Found 3 results:
     … +92 lines (ctrl+r to expand)

⏺ Perfect! This confirms that you don't need manual CS control. According to Circuits.SPI docs:

  "All transactions will automatically set CS0. When using "spidev1.0" refers to SPI bus 1 and CS0. All transactions will automatically set CS0."

## image/vix cross-compilation does not just "work"

### Problem 1

Problem is: for vix, mix firmware tries to download precompiled binaries for macOS, while the target of is actually an RPi3

== Compilation error in file lib/vix/vips/flag.ex ==
** (UndefinedFunctionError) function Vix.Nif.nif_vips_flag_list/0 is undefined (module Vix.Nif is not available)
    Vix.Nif.nif_vips_flag_list()
    lib/vix/vips/flag.ex:5: Vix.Vips.FlagHelper.**before_compile**/1
    (stdlib 6.2.2.1) lists.erl:2146: :lists.foldl/3
    (stdlib 6.2.2.1) lists.erl:2151: :lists.foldl_1/3

11:03:32.068 [warning] The on_load function for module Elixir.Vix.Nif returned:
{:error,
 {:load_failed,
  ~c"Failed to load NIF library: 'dlopen(/Users/crntng/private/mood_bot/_build/rpi3_dev/lib/vix/priv/vix.so, 0x0002): tried: '/Users/crntng/private/mood_bot/_build/rpi3_dev/lib/vix/priv/vix.so' (slice is not valid mach-o file), '/System/Volumes/Preboot/Cryptexes/OS/Users/crntng/private/mood_bot/_build/rpi3_dev/lib/vix/priv/vix.so' (no such file), '/Users/crntng/private/mood_bot/_build/rpi3_dev/lib/vix/priv/vix.so' (slice is not valid mach-o file)'"}}

could not compile dependency :vix, "mix compile" failed. Errors may have been logged above. You can recompile this dependency with "mix deps.compile vix --force", update it with "mix deps.update vix" or clean it with "mix deps.clean vix"

---

Web Search("Vix Elixir NIF cross-compilation Nerves ARM RPi issue mach-o file slice not valid")

---

<https://github.com/akash-akya/vix/issues/130>

### Problem 2

After update to

```
{:image, "~> 0.62"},
# Nerves support was added just in time :)
# We just need to use the master branch of vix and override the version restriction imposed by image.
# See https://github.com/akash-akya/vix/issues/130
{:vix, git: "https://github.com/akash-akya/vix.git", branch: "master", override: true},
```

I get yet another error:

```shell
❯ MIX_TARGET=rpi3 mix firmware
==> nerves
==> mood_bot

Nerves environment
  MIX_TARGET:   rpi3
  MIX_ENV:      dev

==> vix
Error happened while installing vix from precompiled binary: "missing checksum.exs file".

Attempting to compile vix from source...
Setting up precompiled libvips...

13:03:25.267 [debug] Fetching https://github.com/akash-akya/sharp-libvips/releases/download/v1.2.0/sharp-libvips-darwin-arm64v8.tar.gz

13:03:26.978 [debug] Extracting to /Users/crntng/private/mood_bot/_build/rpi3_dev/lib/vix/priv/sharp-libvips-darwin-arm64v8.tar.gz
 CC     pipe.c
 CC     utils.c
 CC     vips_boxed.c
 CC     vips_foreign.c
 CC     vips_image.c
 CC     vips_interpolate.c
 CC     vips_operation.c
 CC     vix.c
 CC     g_boxed.c
 CC     g_object.c
 CC     g_param_spec.c
 CC     g_type.c
 CC     g_value.c
 LD     vix.so
armv7-nerves-linux-gnueabihf-gcc: error: unrecognized command-line option '-flat_namespace'
make[1]: *** [/Users/crntng/private/mood_bot/_build/rpi3_dev/lib/vix/priv/vix.so] Error 1
make: *** [compile] Error 2
could not compile dependency :vix, "mix compile" failed. Errors may have been logged above. You can recompile this dependency with "mix deps.compile vix --force", update it with "mix deps.update vix" or clean it with "mix deps.clean vix"
==> mood_bot
** (Mix) Could not compile with "make" (exit status: 2).
You need to have gcc and make installed. Try running the
commands "gcc --version" and / or "make --version". If these programs
are not installed, you will be prompted to install them.
```

## Playing audio via Nerves

- Starter talk: <https://www.youtube.com/watch?v=2IastDZCuFs>
- Membrane: <https://underjord.io/membrane-media-processing-and-liveview.html>
- Elixir for multimedia: <https://blog.swmansion.com/elixir-for-multimedia-a-practical-guide-for-developers-169adb0eb523>

## Random bits and pieces

- <https://wiki.alopex.li/NervesNotes#onboard-storage>

## Knowing the API helps a lot

Claude insisted on using `Image.compose/3`, while `Image.embed/4` would have been the right choice.

