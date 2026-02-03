#!/bin/bash
set -euo pipefail

echo "=== MiniDLNA Watcher Uninstaller ==="
echo

PLIST_PATH="$HOME/Library/LaunchAgents/minidlna-watcher.plist"

# Stop and unload service
echo "Stopping service..."
launchctl unload "$PLIST_PATH" 2>/dev/null || true
pkill -f "watch-dlna.sh" 2>/dev/null || true
sleep 1
echo "  Service stopped"

# Remove plist
if [ -f "$PLIST_PATH" ]; then
  rm "$PLIST_PATH"
  echo "  Removed: $PLIST_PATH"
fi

# Clean up state
rm -rf /tmp/minidlna_watcher 2>/dev/null || true

echo
echo "=== Uninstall complete ==="
echo
echo "Note: The install directory and logs were NOT removed."
echo "To fully remove, delete the install directory manually:"
echo "  rm -rf ~/.config/minidlna"
