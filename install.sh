#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$SCRIPT_DIR"

echo "=== MiniDLNA Watcher Installer ==="
echo

# Load configuration
if [ ! -f "config.sh" ]; then
  echo "ERROR: config.sh not found. Please copy config.sh.example and edit it."
  exit 1
fi
source config.sh

# Parse minidlna.conf if specified
if [ -n "${MINIDLNA_CONF:-}" ] && [ -f "$MINIDLNA_CONF" ]; then
  echo "Reading configuration from $MINIDLNA_CONF..."

  # Extract db_dir (cache directory)
  MINIDLNA_CACHE_DIR=$(grep -E "^db_dir=" "$MINIDLNA_CONF" | cut -d'=' -f2- | tr -d ' ')
  if [ -z "$MINIDLNA_CACHE_DIR" ]; then
    echo "ERROR: db_dir not found in $MINIDLNA_CONF"
    exit 1
  fi

  # Extract media_dir entries (may have type prefix like "V,/path")
  MEDIA_DIRS=()
  while IFS= read -r line; do
    # Remove "media_dir=" prefix and any type prefix (A,V,P,)
    dir=$(echo "$line" | cut -d'=' -f2- | sed 's/^[AVP],//')
    MEDIA_DIRS+=("$dir")
  done < <(grep -E "^media_dir=" "$MINIDLNA_CONF")

  if [ ${#MEDIA_DIRS[@]} -eq 0 ]; then
    echo "ERROR: No media_dir entries found in $MINIDLNA_CONF"
    exit 1
  fi

  echo "  Found cache dir: $MINIDLNA_CACHE_DIR"
  echo "  Found ${#MEDIA_DIRS[@]} media dir(s)"
  echo
elif [ -n "${MINIDLNA_CONF:-}" ]; then
  echo "WARNING: MINIDLNA_CONF set but file not found: $MINIDLNA_CONF"
  echo "         Using manual configuration from config.sh"
  echo
fi

# Validate configuration
echo "Configuration:"
echo "  Cache dir:    $MINIDLNA_CACHE_DIR"
echo "  Media dirs:   ${MEDIA_DIRS[*]}"
echo "  Install dir:  $INSTALL_DIR"
echo "  Timeout:      ${INACTIVITY_TIMEOUT}s"
echo "  Homebrew:     $HOMEBREW_PREFIX"
echo

# Check dependencies
echo "Checking dependencies..."
if [ ! -x "$HOMEBREW_PREFIX/fswatch" ]; then
  echo "ERROR: fswatch not found at $HOMEBREW_PREFIX/fswatch"
  echo "Install with: brew install fswatch"
  exit 1
fi
if [ ! -x "$HOMEBREW_PREFIX/brew" ]; then
  echo "ERROR: brew not found at $HOMEBREW_PREFIX/brew"
  exit 1
fi
if ! command -v sqlite3 &>/dev/null; then
  echo "ERROR: sqlite3 not found"
  exit 1
fi
echo "  All dependencies OK"
echo

# Check media directories exist
echo "Checking media directories..."
for dir in "${MEDIA_DIRS[@]}"; do
  if [ ! -d "$dir" ]; then
    echo "WARNING: Media directory not found: $dir"
    echo "         (It may be an external drive that's not mounted)"
  else
    echo "  OK: $dir"
  fi
done
echo

# Create install directory
echo "Creating install directory..."
mkdir -p "$INSTALL_DIR"
echo "  Created: $INSTALL_DIR"

# Format MEDIA_DIRS for the script
MEDIA_DIRS_FORMATTED=""
for dir in "${MEDIA_DIRS[@]}"; do
  MEDIA_DIRS_FORMATTED+="\"$dir\" "
done

# Generate watch-dlna.sh from template
echo "Generating watch-dlna.sh..."
sed -e "s|{{CACHE_DIR}}|$MINIDLNA_CACHE_DIR|g" \
    -e "s|{{MEDIA_DIRS}}|$MEDIA_DIRS_FORMATTED|g" \
    -e "s|{{INACTIVITY_TIMEOUT}}|$INACTIVITY_TIMEOUT|g" \
    -e "s|{{HOMEBREW_PREFIX}}|$HOMEBREW_PREFIX|g" \
    watch-dlna.sh.template > "$INSTALL_DIR/watch-dlna.sh"
chmod +x "$INSTALL_DIR/watch-dlna.sh"
echo "  Created: $INSTALL_DIR/watch-dlna.sh"

# Generate plist from template
echo "Generating launchd plist..."
PLIST_DIR="$HOME/Library/LaunchAgents"
mkdir -p "$PLIST_DIR"
sed -e "s|{{INSTALL_DIR}}|$INSTALL_DIR|g" \
    minidlna-watcher.plist.template > "$PLIST_DIR/minidlna-watcher.plist"
echo "  Created: $PLIST_DIR/minidlna-watcher.plist"

# Stop existing service if running
echo "Stopping existing service (if any)..."
launchctl unload "$PLIST_DIR/minidlna-watcher.plist" 2>/dev/null || true
pkill -f "watch-dlna.sh" 2>/dev/null || true
sleep 1

# Load and start service
echo "Starting service..."
launchctl load "$PLIST_DIR/minidlna-watcher.plist"
sleep 2

# Verify
if launchctl list | grep -q minidlna-watcher; then
  echo
  echo "=== Installation complete ==="
  echo
  echo "Service is running. Logs:"
  echo "  Events: $INSTALL_DIR/fswatch.log"
  echo "  Errors: $INSTALL_DIR/fswatch.err"
  echo
  echo "Commands:"
  echo "  Status:  launchctl list | grep minidlna"
  echo "  Stop:    launchctl stop minidlna-watcher"
  echo "  Start:   launchctl start minidlna-watcher"
  echo "  Disable: launchctl unload ~/Library/LaunchAgents/minidlna-watcher.plist"
  echo "  Logs:    tail -f $INSTALL_DIR/fswatch.log"
else
  echo "ERROR: Service failed to start. Check $INSTALL_DIR/fswatch.err"
  exit 1
fi
