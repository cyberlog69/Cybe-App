# 🛰️ Cybe BitMesh Desktop Relay & GitHub Sync Daemon

A standalone, lightweight, cross-platform background service for **Windows** and **Linux** that acts as an off-grid **BitMesh LAN Relay Node**, monitors local folders, and checks for **GitHub updates / APK releases**.

---

## 🌟 Key Features

1. **BitMesh LAN Relay Node**
   - Discovers Android Cybe devices on the local Wi-Fi / Ethernet network via UDP Multicast (`239.255.0.100:42100`).
   - Automatically establishes framed TCP sockets with nearby mobile nodes.
   - Forwards encrypted and public mesh packets, manages hop counters, deduplicates messages, and extends the physical communication range between mobile devices.

2. **Local Folder & Security Analyzer**
   - Recursively audits local directories, calculates SHA-256 integrity hashes, and flags unencrypted credentials, API keys, or private key leaks.

3. **GitHub Release & APK Sync Engine**
   - Continuously monitors the repository (default: `cyberlog69/Cybe-App`) for new tags and releases.
   - Detects new APK releases, downloads updates locally, and broadcasts instant release alerts across the BitMesh network to connected Android devices.

---

## 🚀 Quick Start

### Windows (PowerShell)
```powershell
cd tools\bitmesh_relay
.\start-relay.ps1
```

### Linux (Bash)
```bash
cd tools/bitmesh_relay
chmod +x start-relay.sh
./start-relay.sh
```

### Manual Run (Dart)
```bash
cd tools/bitmesh_relay
dart pub get
dart run bin/cybe_relay.dart
```

---

## ⚙️ CLI Options & Flags

| Flag | Abbr | Default | Description |
|---|---|---|---|
| `--alias` | `-a` | `CybeRelay-[hostname]` | Node alias name on BitMesh |
| `--port` | `-p` | `42101` | TCP port for incoming mobile connections (0 for auto) |
| `--analyze-dir` | `-d` | `.` | Folder path to scan for integrity & security |
| `--github-repo` | `-r` | `cyberlog69/Cybe-App` | GitHub repository to monitor |
| `--interval` | `-i` | `15` | GitHub check interval (minutes) |
| `--daemon` | | `false` | Run non-interactively as a background service |

### Interactive Terminal Commands
While the relay is running interactively:
- Press **`b`** to broadcast a message to all connected mobile nodes.
- Press **`a`** to re-analyze the local folder.
- Press **`u`** to trigger an immediate GitHub update check.
- Press **`q`** to quit cleanly.

---

## 🐧 Linux Systemd Service Setup (Optional)

To run the relay permanently in the background on a Linux server/desktop:

Create `/etc/systemd/system/cybe-relay.service`:
```ini
[Unit]
Description=Cybe BitMesh Relay Node
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/path/to/Cybe-App/tools/bitmesh_relay
ExecStart=/usr/bin/dart run bin/cybe_relay.dart --daemon --alias "Linux-Relay"
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
sudo systemctl daemon-reload
sudo systemctl enable --now cybe-relay
sudo systemctl status cybe-relay
```
