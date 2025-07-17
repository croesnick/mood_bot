# This file is responsible for configuring your application and its
# dependencies.
#
# This configuration file is loaded before any dependency and is restricted to
# this project.
import Config

# Load environment variables from .env file for development
if Mix.env() in [:dev, :test] do
  try do
    Dotenv.load()
  rescue
    # Ignore if dotenv fails or .env doesn't exist
    _ -> :ok
  end
end

# Enable the Nerves integration with Mix
Application.start(:nerves_bootstrap)

# Customize non-Elixir parts of the firmware. See
# https://hexdocs.pm/nerves/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1751257577"

if Mix.target() == :host do
  import_config "host.exs"
else
  import_config "target.exs"
end
