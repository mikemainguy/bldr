#!/bin/bash

set -e

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" && pwd)"
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

ln -sf "$SCRIPTS_DIR/setup.sh" "$BIN_DIR/bldr-setup"
ln -sf "$SCRIPTS_DIR/configure.sh" "$BIN_DIR/bldr-configure"
ln -sf "$SCRIPTS_DIR/register-runner.sh" "$BIN_DIR/bldr-register"
ln -sf "$SCRIPTS_DIR/uninstall.sh" "$BIN_DIR/bldr-uninstall"

echo "Symlinks created in $BIN_DIR:"
ls -l "$BIN_DIR"/bldr-*
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    echo "WARNING: $BIN_DIR is not in your PATH. Add it to your shell profile to use bldr-* commands globally."
fi 