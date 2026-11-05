#!/usr/bin/env bash
# All omagnet checks. The pure ones run anywhere with Lua 5.5; the live one needs Hyprland with
# omagnet loaded, kitty and write access to /dev/uinput. Usage: bash tests/run-all.sh [--no-live]
set -e
cd "$(dirname "$0")/.."
# Hyprland embeds Lua 5.5; 5.4 accepts code that 5.5 rejects, so a pass on 5.4 proves little.
lua -e 'assert(_VERSION == "Lua 5.5", "run these tests with Lua 5.5, like Hyprland (found " .. _VERSION .. ")")'
lua prototype/test_geometry.lua
lua prototype/test_config.lua
[ "${1:-}" = "--no-live" ] || python3 tests/live.py
