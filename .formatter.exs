[
  inputs:
    Enum.flat_map(
      [
        "{mix,.formatter}.exs",
        "{config,lib,test}/**/*.{ex,exs}",
        "rootfs_overlay/etc/iex.exs"
      ],
      &Path.wildcard(&1, match_dot: true)
    ) --
      ["lib/mood_bot/display/hal_lut.ex"]
]
