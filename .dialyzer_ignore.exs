[
  # Ignore pattern match warnings for HAL initialization
  # This is a false positive because dialyzer can't see that different HAL modules
  # might be used at runtime (MockHAL vs RpiHAL)
  {"lib/mood_bot/display.ex", :pattern_match}
]