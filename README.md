# MiniDLNA Watcher

Auto-refreshes MiniDLNA cache when new video downloads complete.

## Features

- Monitors specified directories for new folders (downloads)
- Waits for download activity to stop (configurable timeout)
- Checks if videos are already in MiniDLNA database before restarting
- Only restarts MiniDLNA when new videos need indexing
- Runs as a launchd service (auto-starts on login)

## Requirements

- macOS
- Homebrew with:
  - `minidlna` - the DLNA server
  - `fswatch` - file system watcher
- `sqlite3` (included in macOS)

## Installation

1. **Install dependencies:**
   ```bash
   brew install minidlna fswatch
   ```

2. **Edit configuration:**
   ```bash
   cp config.sh.example config.sh
   nano config.sh
   ```

   Configure:
   - `MINIDLNA_CONF` - path to minidlna.conf (recommended - auto-reads media_dir and db_dir)
   - `MINIDLNA_CACHE_DIR` - where minidlna stores its database (ignored if MINIDLNA_CONF is set)
   - `MEDIA_DIRS` - directories to watch for new downloads (ignored if MINIDLNA_CONF is set)
   - `INSTALL_DIR` - where to install the watcher script
   - `INACTIVITY_TIMEOUT` - seconds to wait after last file activity
   - `HOMEBREW_PREFIX` - path to homebrew binaries

3. **Run installer:**
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

## Configuration

Edit `config.sh` before installation:

```bash
# Path to minidlna.conf - automatically reads media_dir and db_dir
MINIDLNA_CONF="/opt/homebrew/etc/minidlna.conf"

# Manual configuration (only used if MINIDLNA_CONF is not set or file doesn't exist)
MINIDLNA_CACHE_DIR="/path/to/minidlna/cache"
MEDIA_DIRS=(
    "/path/to/your/downloads"
    "/path/to/your/media"
)

# Installation directory
INSTALL_DIR="$HOME/.config/minidlna"

# Wait time after last activity (seconds)
INACTIVITY_TIMEOUT=60

# Homebrew path (Apple Silicon: /opt/homebrew/bin, Intel: /usr/local/bin)
HOMEBREW_PREFIX="/opt/homebrew/bin"
```

The recommended approach is to set `MINIDLNA_CONF` to your minidlna.conf path. The installer will automatically extract `media_dir` and `db_dir` values from it.

## Usage

### Service Commands

```bash
# Check status
launchctl list | grep minidlna

# View logs
tail -f ~/.config/minidlna/fswatch.log

# Stop service
launchctl stop minidlna-watcher

# Start service
launchctl start minidlna-watcher

# Disable (won't start on login)
launchctl unload ~/Library/LaunchAgents/minidlna-watcher.plist

# Enable
launchctl load ~/Library/LaunchAgents/minidlna-watcher.plist
```

### Log Files

- `fswatch.log` - events and status messages
- `fswatch.err` - error messages
- `fswatch.out` - stdout (usually empty)

## How It Works

1. `fswatch` monitors media directories recursively
2. When a new top-level folder is created, tracking begins
3. File updates reset a countdown timer
4. When no activity for `INACTIVITY_TIMEOUT` seconds:
   - Check if video files (.mkv, .mp4) exist in MiniDLNA database
   - If new videos found: delete cache and restart MiniDLNA
   - If all videos indexed: skip restart

## Uninstallation

```bash
chmod +x uninstall.sh
./uninstall.sh

# Optionally remove all files
rm -rf ~/.config/minidlna
```

## Troubleshooting

**Service won't start:**
- Check `fswatch.err` for errors
- Verify `fswatch` is installed: `which fswatch`
- Verify paths in config.sh are correct

**Videos not being detected:**
- Check `fswatch.log` for DEBUG messages
- Ensure media directories are mounted
- Verify folder structure (only top-level folders are tracked)

**Unnecessary restarts:**
- Check if MiniDLNA database path is correct
- Verify `files.db` exists in cache directory
