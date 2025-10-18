# Button GPIO Integration Plan

## Overview

Integrate physical button press detection using GPIO pins on Raspberry Pi with the Circuits library.

## Final Decision: GPIO 27 (Physical Pin 13)

**Selected Pin**: GPIO 27, Physical Pin 13

**Rationale**:

- GPIO 17 (originally considered) is already used by e-ink display RST pin
- GPIO 27 is adjacent to Pin 11, making wiring simple
- Verified safe for general purpose I/O on all RPi models (3/4/5)
- No conflicts with display (GPIO 25, 17, 24, 18) or SPI pins

## Wiring

```
Button → GPIO 27 (Physical Pin 13)
Button → GND (Physical Pin 9)
```

**Pull-up resistor**: Internal (configured via Circuits.GPIO)

## Circuits Library Integration

### Dependencies

Already in `mix.exs`:

- `circuits_gpio ~> 2.0` - GPIO access (targets: embedded only)

### Button Detection Module

Create: `lib/mood_bot/button.ex`

**Features**:

- GenServer monitoring GPIO pin 27
- Software debouncing (50ms)
- Falling edge detection (button press on pull-up)
- Direct integration with `MoodBot.Controller.handle_button_press/0`

### Debouncing Strategy

**Software debouncing**:

1. On GPIO interrupt: start debounce timer (50ms)
2. Ignore subsequent interrupts during debounce period
3. After debounce: call `MoodBot.Controller.handle_button_press()`

**Why 50ms**:

- Typical mechanical bounce duration: 5-50ms
- 50ms provides margin while remaining responsive
- Industry standard for button debouncing

## Integration with Controller

### Communication Pattern

**Button → Controller**:

```elixir
# Button GenServer detects press (after debounce)
MoodBot.Controller.handle_button_press()
```

**No changes needed** in Controller - already has `handle_button_press/0` API

### State Coordination

- Button module is stateless (simple GPIO bridge)
- Controller owns all application state
- Controller's state machine handles recording/processing logic

## Configuration

Add to `config/target.exs`:

```elixir
# Button GPIO configuration
config :mood_bot, MoodBot.Button,
  gpio_pin: {"gpiochip0", 27},  # GPIO 27, Physical Pin 13
  debounce_ms: 50
```

**Note on gpiochip**: Uses `gpiochip0` for consistency with display config. Works on RPi 3/4/5 via compatibility layer.

## Implementation Tasks

1. **Create `lib/mood_bot/button.ex`**
   - GenServer with GPIO initialization in `init/1`
   - Configure GPIO 27 as input with pull-up
   - Set interrupt on falling edge (`:falling`)
   - Implement debounce timer logic
   - Call `MoodBot.Controller.handle_button_press/0` after debounce

2. **Add configuration** to `config/target.exs`
   - GPIO pin: `{"gpiochip0", 27}`
   - Debounce: `50` ms

3. **Update supervision tree** in `lib/mood_bot/application.ex`
   - Add `{MoodBot.Button, []}` to `target_children` (NOT host children)
   - Position after Controller (dependency)

4. **Error handling**
   - Log GPIO initialization failures
   - Graceful degradation: system still usable via IEx manual calls
   - Supervisor restart: `:transient` strategy

## Technical Details

### GPIO Pin Properties

- **Voltage**: 3.3V logic level
- **Direction**: Input with internal pull-up
- **Edge**: Falling (button press pulls to GND)
- **Debounce**: Software (50ms timer)

### Raspberry Pi Compatibility

- **RPi 3/4**: Native `gpiochip0`, GPIO 27 verified safe
- **RPi 5**: Uses `gpiochip4` internally, but `gpiochip0` works via compatibility layer
- **40-pin header**: GPIO 27 is Physical Pin 13 on all models

### Safety Considerations

- ⚠️ **Never connect 5V to GPIO pins** - 3.3V logic only
- ✅ Use internal pull-up (no external resistor needed)
- ✅ Button between GPIO and GND (safe, simple)

## Testing Strategy

### Development (Host)

- Button module only starts on target (embedded systems)
- Use `MoodBot.Controller.handle_button_press()` directly in IEx for testing

### Hardware (Target)

1. **Physical button test**: Press and verify Controller logs "Button press - starting recording"
2. **Debounce test**: Rapid presses should be filtered (only one press per 50ms)
3. **Pipeline test**: Full interaction flow (record → transcribe → sentiment → LLM → TTS)
4. **Long press test**: Hold button, verify only one press registered

### Unit Tests (Future)

- Mock `Circuits.GPIO` for debounce logic testing
- Test edge case: button pressed before debounce timer expires

## Error Handling

### GPIO Initialization Failure

- Log error with reason
- Continue boot (graceful degradation)
- System remains usable via manual `handle_button_press/0` calls in IEx

### Supervisor Strategy

- Restart policy: `:transient` (restart on abnormal exit only)
- Max restarts: 3 in 5 seconds (supervisor default)
- If button fails permanently: system continues without physical button

## Future Enhancements

- Multi-button support (different GPIO pins, different actions)
- Long press detection (timer-based, different behavior)
- LED indicator for button press feedback (visual confirmation)
- Button combinations (press multiple buttons for special actions)
- Host simulation: MockButton GenServer for development testing

## References

- [Circuits.GPIO Documentation](https://hexdocs.pm/circuits_gpio)
- [RPi GPIO Pinout - Interactive](https://pinout.xyz)
- [RPi 5 GPIO Pinout](https://pinout.ai/raspberry-pi-5)
- [Raspberry Pi Documentation](https://www.raspberrypi.com/documentation/)
