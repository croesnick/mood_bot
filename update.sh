#!/usr/bin/env bash

set -euo pipefail

./run-in-vm.sh "mix deps.get && mix firmware && mix upload moodbot.run"

sleep 15s
ssh -t moodbot.run
