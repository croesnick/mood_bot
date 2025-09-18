#!/usr/bin/env bash

set -euo pipefail

# See: https://github.com/vittoriabitton/nx_hailo/tree/main/nx_hailo
# Run the command passed as arguments with required environment variables
ssh moodbot.build bash --login <<EOF
  set -euo pipefail
  export MIX_TARGET=rpi5
  export XLA_TARGET_PLATFORM=aarch64-linux-gnu
  export EXLA_FORCE_REBUILD=false
  export EVISION_PREFER_PRECOMPILED=true

  # Run the command that was passed to this script
  $@
EOF
