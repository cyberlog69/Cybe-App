# 🔐 Cybe Security Suite

[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Web-blue?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.x%20%7C%20Dart-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Security](https://img.shields.io/badge/Encryption-AES--256--GCM%20%7C%20RSA--2048%20%7C%20PBKDF2-brightgreen?style=for-the-badge&logo=shield)](https://github.com/cyberlog69/Cybe-App)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

A high-performance, cross-platform cyber-security suite built with **Flutter**, designed to run natively on **Android, iOS, Windows, macOS, Linux, and Web**. 

Cybe offers offline-first encrypted password & developer key management, 2FA TOTP token generation, dark web breach monitoring, off-grid peer-to-peer BLE mesh messaging with LAN fallback (**BitMesh**), LAN port scanning, encrypted file vaults, and cryptographically secure password & Diceware passphrase generation (**pass-gen**).

---

## 🌟 Key Features & 16-Module Security Suite

| Icon | Module | Description | Supported Platforms |
|:---:|:---|:---|:---:|
| 🔑 | **Password Manager** | AES-256 encrypted local vault, category filters, fast search, health audit & master key protection. | All Platforms |
| 🎲 | **PassGen Generator** | Offline Diceware Passphrase (~500 EFF wordlist) & Password Generator with entropy calculator and GPU crack time estimator. | All Platforms |
| 🛡️ | **2FA Authenticator** | RFC 6238 TOTP 2FA code generator, 30s countdown ring, tap-to-copy & camera QR import (`mobile_scanner`). | All Platforms |
| 🌐 | **Dark Web Monitor** | Privacy-preserving k-Anonymity SHA-1 password breach check (HaveIBeenPwned API) + email domain leak auditor. | All Platforms |
| 🔒 | **Secret Notes** | Dedicated AES-256 encrypted notepad for recovery seeds, API keys & confidential notes with category chips & pinning. | All Platforms |
| 📁 | **Encrypted File Vault** | AES-256-GCM authenticated file encryption with Isolate background thread execution for sensitive documents & photos. | All Platforms |
| 📡 | **BitMesh Off-Grid Messaging** | Dual-transport P2P mesh: BLE (mobile-to-mobile) + LAN UDP/TCP (phone-to-PC). AES-256-GCM encrypted chat, group rooms & auto-discovery. | Android • iOS • Windows • macOS • Linux |
| 🔗 | **Phishing & QR Scanner** | URL threat heuristic analysis, brand typosquatting detector & live camera QR code safety analyzer. | All Platforms |
| 🔍 | **Vulnerability Audit** | 13 deep checks: Root/Jailbreak, security patch staleness, permission exposure (Camera/Mic/Location/Contacts), clipboard sensitivity. | All Platforms |
| 🖧 | **LAN Port Scanner** | TCP socket probing across common ports (FTP, SSH, Telnet, HTTP, HTTPS, SMB, UPnP, RDP), latency benchmarking & vulnerability alerts. | All Platforms |
| 🔑 | **SSH & API Key Vault** | Dedicated vault for SSH keys (RSA/Ed25519) and cloud API tokens with automatic SHA-256 key fingerprinting. | All Platforms |
| 🔌 | **USB Security Monitor** | Real-time USB device connection history, trust/block policies, and hardware interface event logging. | Android • Windows • Linux • macOS |
| 📊 | **Network Dashboard** | Real-time connection quality inspection, Wi-Fi SSID / local IP / Gateway monitoring, latency tracking chart & DNS Lookup tool. | All Platforms |
| 📶 | **Wi-Fi Threat Radar** | Detects open AP risks, weak WEP/WPA ciphers, and Evil Twin access point suspects. | All Platforms |
| 💾 | **Secure Clipboard Manager** | In-app 10-item memory-only clipboard history with auto-wipe on app lock/minimize. | All Platforms |
| ⚙️ | **Settings & Portable Backup** | Material You dynamic theme switcher, auto-lock timeout, biometric preferences, and encrypted `.cybe` vault backup export/restore. | All Platforms |

---

## 🏗️ Technical Architecture

```
lib/
├── main.dart                  # Application entrypoint, SettingsBloc & MultiBlocProvider
├── core/
│   ├── theme/                 # AppTheme with Material You M3 dynamic color system
│   ├── router/                # Declarative GoRouter navigation (16 feature routes)
│   ├── constants/             # App-wide constants & Hive storage box names
│   ├── utils/                 # CryptoUtils (AES-256-CBC/GCM, PBKDF2, RSA, SHA-256)
│   └── widgets/               # ResponsiveCenter, GlassCard, status chips
└── features/
    ├── auth/                  # Master password hash, setup & biometric lock
    ├── password_manager/      # Encrypted password vault BLoC, PassGen & Health Audit
    ├── totp/                  # RFC 6238 2FA TOTP code generator & QR scanner
    ├── breach_monitor/        # k-Anonymity SHA-1 password breach check service & UI
    ├── secret_notes/          # AES-256 encrypted notes BLoC, service & screen
    ├── file_vault/            # Isolate background AES-256-GCM file vault
    ├── ble_mesh/              # BitMesh: BLE + LAN dual-transport mesh
    │   ├── models/
    │   │   ├── mesh_message.dart    # JSON-serializable mesh packet
    │   │   ├── peer_info.dart       # Shared peer model (BLE + LAN)
    │   │   └── bitmesh_group_model.dart
    │   ├── services/
    │   │   ├── mesh_service_interface.dart  # Common transport interface
    │   │   ├── ble_mesh_service.dart        # BLE GATT transport
    │   │   ├── lan_mesh_service.dart        # LAN UDP/TCP transport
    │   │   ├── composite_mesh_service.dart  # Auto-selects BLE + LAN
    │   │   ├── mesh_crypto.dart            # AES-256-GCM channel crypto
    │   │   └── ble_mesh_service.dart
    │   └── screens/
    │       └── ble_mesh_screen.dart
    ├── phishing_checker/      # URL heuristic analysis & camera QR code safety preview
    ├── vulnerability_scan/    # 13 deep device risk assessment checks
    ├── port_scanner/          # Subnet TCP socket port scanner & service fingerprinter
    ├── ssh_keys/              # Developer SSH key & API token vault with SHA-256 fingerprints
    ├── usb_monitor/           # USB host device listener, BLoC & Hive history
    ├── network_dashboard/     # Connectivity BLoC, latency charts & DNS tool
    ├── wifi_scanner/          # Wi-Fi threat scanner & Evil Twin detector
    ├── clipboard_manager/     # Ephemeral in-app clipboard history & auto-wipe
    ├── security_logs/         # Centralized security audit log stream & alert badges
    └── settings/              # Settings BLoC, theme mode, `.cybe` encrypted backup/restore
```

---

## 🚀 Prerequisites & System Requirements

| Target Platform | Required Host OS | Required Build Tools | Minimum SDK Version |
|:---|:---|:---|:---|
| **Android** | Windows, macOS, Linux | Flutter SDK 3.x+, Android Studio, JDK 17, Android SDK | API Level 24 (Android 7.0+) |
| **Windows** | Windows 10/11 | Visual Studio 2022 with "Desktop C++ workload" | Windows 10 (x64 / ARM64) |
| **iOS** | macOS | Xcode 15+, CocoaPods | iOS 13.0+ |
| **macOS** | macOS | Xcode 15+, CocoaPods | macOS 11.0 (Big Sur)+ |
| **Linux** | Linux | `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev` | GTK 3.24+ |
| **Web** | Any | Flutter Web SDK | Modern browsers (Chrome, Edge, Safari, Firefox) |

---

## 🛠️ Step-by-Step Deployment Instructions

### 1. General Repository Setup

Clone the repository and install Flutter dependencies:

```bash
git clone https://github.com/cyberlog69/Cybe-App.git
cd Cybe-App
flutter pub get
```

Verify environment readiness:
```bash
flutter doctor
```

---

### 📱 2. Android Deployment (APK & Google Play AAB)

#### A. Configure Environment
Set `ANDROID_HOME` environment variable:
- **Windows (PowerShell)**:
  ```powershell
  $env:ANDROID_HOME="C:\Users\$env:USERNAME\AppData\Local\Android\Sdk"
  [Environment]::SetEnvironmentVariable("ANDROID_HOME", $env:ANDROID_HOME, "User")
  ```
- **macOS / Linux**:
  ```bash
  export ANDROID_HOME=$HOME/Library/Android/sdk
  export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
  ```

#### B. Accept Android Licenses
```bash
flutter doctor --android-licenses
```

#### C. Biometric Setup Note (`FlutterFragmentActivity`)
This app utilizes `FlutterFragmentActivity` in `android/app/src/main/kotlin/com/cybe/cybe_app/MainActivity.kt` to ensure complete compatibility with `local_auth` biometrics (Fingerprint/Face Unlock).

#### D. Build Release APK (Standalone Sideloading)
```bash
flutter build apk --release
```
- **Output Location**: `build/app/outputs/flutter-apk/app-release.apk`
- **Install on Device via USB**:
  ```bash
  adb install build/app/outputs/flutter-apk/app-release.apk
  ```

#### E. Build Android App Bundle (Google Play Store Release)
```bash
flutter build appbundle --release
```
- **Output Location**: `build/app/outputs/bundle/release/app-release.aab`

---

### 💻 3. Windows Desktop Deployment (.exe Executable & Installer)

#### A. Prerequisites
Install [Visual Studio 2022](https://visualstudio.microsoft.com/vs/) with the **Desktop development with C++** workload enabled (MSVC v143, C++ CMake tools for Windows).

#### B. Enable Windows Platform
```bash
flutter config --enable-windows-desktop
```

#### C. Build Windows Release Executable
```bash
flutter build windows --release
```
- **Output Location**: `build/windows/x64/runner/Release/`
- **Executable**: `cybe_app.exe` along with required DLL runtime libraries.

---

### 🍏 4. iOS Deployment (iPhone & iPad App Store / TestFlight)

#### A. CocoaPods Setup
```bash
cd ios
pod install
cd ..
```

#### B. Xcode Build & Signing
```bash
open ios/Runner.xcworkspace
flutter build ipa --release
```

---

### 🖥️ 5. macOS Desktop Deployment (.app & .dmg)

```bash
flutter config --enable-macos-desktop
flutter build macos --release
```
- **Output Location**: `build/macos/Build/Products/Release/cybe_app.app`

---

### 🐧 6. Linux Desktop Deployment (Debian / Ubuntu / Snap)

```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev
flutter config --enable-linux-desktop
flutter build linux --release
```
- **Output Location**: `build/linux/x64/release/bundle/cybe_app`

---

### 🌐 7. Web Deployment (Progressive Web App)

```bash
flutter config --enable-web
flutter build web --release --web-renderer canvaskit
```
- **Output Location**: `build/web/`

---

## 🔒 Security & Cryptography Design

- **Vault Encryption**: AES-256-CBC with random IV per item.
- **File Vault Encryption**: AES-256-GCM authenticated tag encryption executed inside background Dart Isolates.
- **Key Derivation**: Master password derived via PBKDF2-SHA256 (100,000 iterations).
- **Dark Web Lookups**: Privacy-preserving k-Anonymity (only 5 SHA-1 hash prefix characters queried; plaintext password never leaves device).
- **Secure Hardware Storage**: Android EncryptedSharedPreferences, iOS Keychain, Windows Credential Manager.
- **Off-Grid P2P Encryption (BitMesh)**: AES-256-GCM channel encryption with PBKDF2 key derivation. Dual transport: BLE (phone-to-phone) and LAN UDP/TCP (phone-to-PC over WiFi).
- **Memory Safety**: Ephemeral in-app clipboard buffer with automatic wipe on app lock or minimize.

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.

*Built with Flutter · Secured with AES-256 · Dual-Transport Mesh (BLE + LAN) · Cross-Platform Desktop & Mobile*
