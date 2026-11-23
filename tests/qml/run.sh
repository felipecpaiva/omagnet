#!/usr/bin/env bash
# QML behaviour tests for the helper processes. Uses stub Quickshell modules, so nothing runs and no shell is touched.
cd "$(dirname "$0")"
QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 exec qml6 -I stubs settings_store.test.qml
