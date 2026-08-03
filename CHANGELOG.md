# CHANGELOG - Cybe App Release v1.0.0

## 🚀 Release Summary: Cybe Security & Threat Intelligence Suite v1.0.0

We are proud to announce the **Cybe Security & Threat Intelligence Suite v1.0.0** production release across **Android**, **Windows**, and **Linux**!

---

### 🌟 New Features & Major Enhancements:

1. **Unified Vulnerability & Antivirus Security Suite**:
   - Merged Vulnerability Hardening Scanner with Multi-Engine Antivirus Malware Inspector into a unified security center (`/vulnerability` & `/antivirus`).
   - 4-layer file malware detection: SHA-256 Hashes, YARA-style Pattern Heuristics, Double-Extension Masking (`.pdf.exe`), and Ransomware Extension Protection.
   - Encrypted Quarantine Vault (`.cybe_quarantine`) to isolate, restore, or destroy infected payloads.

2. **Encrypted DNS Shield & OpenVPN Tunnel Manager**:
   - Cloudflare (`1.1.1.1`), Google (`8.8.8.8`), and OpenDNS (`208.67.222.222`) choice chips with DNS-over-HTTPS (DoH) encrypted resolution.
   - Native `.ovpn` file importer and profile manager (`SecureDnsVpnService`).
   - Extended protection to cover **Cellular Mobile Data (4G/5G/LTE)** and Wi-Fi networks across Windows, Linux, Android, macOS, and iOS!

3. **BitMesh Off-Grid Messenger Rewrite (Windows & Mobile Low Latency)**:
   - Multi-target UDP broadcast (`255.255.255.255`, `239.255.0.100`, subnet broadcast) with active IP sweep for < 500ms discovery.
   - Full-duplex TCP `HELLO` handshake resolving duplicate socket collisions across Windows, Linux, and Android.
   - Line-delimited TCP framing (`\n`) for sub-5ms chat latency.
   - Interactive **Discovered Mesh Peers Sheet** displaying peer names, aliases, IDs, and connection types (`Wi-Fi LAN Mesh` vs `BLE Mesh`).

4. **Linux & macOS Platform Enablement**:
   - Native Linux Wi-Fi scanner using `nmcli` and `iwlist`.
   - Native USB Security Monitor for Linux (`lsusb`) and macOS (`system_profiler`).
   - Linux user authentication & PAM security status.
   - Upgraded GTK compilation (`file_picker ^10.0.0`).

5. **2FA Authenticator Data Isolation**:
   - Removed legacy hardcoded demo seed keys, isolating individual user authenticator stores.

---

### 📦 Release Binaries:
- **Android Release APK**: `build/app/outputs/flutter-apk/app-release.apk` (77.5 MB)
- **Windows Executable Package**: `build/windows/x64/runner/Release/cybe_app.exe`
- **Linux Executable**: Build locally on Linux via `flutter build linux --release`
