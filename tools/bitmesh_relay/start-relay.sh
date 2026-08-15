#!/usr/bin/env bash
# Cybe BitMesh Relay Launcher (Linux / macOS)

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR"

if ! command -v dart &> /dev/null; then
    echo "Error: Dart SDK not found in PATH."
    exit 1
fi

dart pub get > /dev/null

echo "Launching Cybe BitMesh Relay Daemon on Linux..."
dart run bin/cybe_relay.dart "$@"
