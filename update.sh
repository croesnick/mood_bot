#!/usr/bin/env sh

MIX_TARGET=rpi3 mix firmware
MIX_TARGET=rpi3 mix upload

sleep 15s

ssh moodbot.local
