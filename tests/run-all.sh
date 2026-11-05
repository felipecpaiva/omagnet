#!/usr/bin/env bash
# All omagnet checks. The pure ones run anywhere with Lua 5.5; the live one needs Hyprland with
# omagnet loaded, kitty and write access to /dev/uinput. Usage: bash tests/run-all.sh [--no-live]
set -e
cd "$(dirname "$0")/.."
lua prototype/test_geometry.lua
lua prototype/test_config.lua
[ "${1:-}" = "--no-live" ] || python3 tests/live.py
