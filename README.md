# 🔐 Cybe Security Suite

[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-blue?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.x%20%7C%20Dart-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)
[![Release](https://img.shields.io/github/v/release/cyberlog69/Cybe-App?style=for-the-badge&logo=github)](https://github.com/cyberlog69/Cybe-App/releases/latest)
[![FOSS](https://img.shields.io/badge/FOSS-No%20Firebase%20%7C%20No%20GMS-brightgreen?style=for-the-badge)](FOSS_COMPLIANCE.md)
[![F-Droid Ready](https://img.shields.io/badge/F--Droid-Ready-blue?style=for-the-badge&logo=fdroid)](fastlane/metadata/android/en-US/full_description.txt)

A high-performance, open-source, offline-first cyber-security suite built with **Flutter**, running natively on **Android, iOS, Windows, macOS, and Linux**.

Cybe provides: encrypted password & key management, RFC 6238 2FA TOTP token generation, dark web breach monitoring, off-grid peer-to-peer mesh messaging (**BitMesh**), real-time Man-in-the-Middle & ARP spoofing threat detection, encrypted DNS-over-HTTPS shield, cellular mobile network protection, cross-platform antivirus & malware engine, hidden camera & bug detection, malicious QR inspection, anti-coercion self-destruct panic wiping, live CISA/NVD cyber threat intelligence, app permission risk auditing, system security log streams, and in-app cross-platform update checker.

> **Privacy First**: No analytics, no telemetry, no Firebase, no Google Play Services (GMS), no advertising SDKs. All data stays on your device, encrypted at rest.

---

## 📦 Download & Install

| Platform | Download |
|:---|:---|
| 📱 **Android** | [APK — GitHub Releases](https://github.com/cyberlog69/Cybe-App/releases/latest) |
| 🪟 **Windows** | [ZIP — GitHub Releases](https://github.com/cyberlog69/Cybe-App/releases/latest) |
| 🐧 **Linux** | Build from source: `flutter build linux --release` |
| 🍎 **macOS** | Build from source: `flutter build macos --release` |

> The in-app update checker automatically notifies you of new releases on all platforms.

---

## 🌟 Feature Modules (27-Module Security Suite)

| Icon | Module | Description | Platforms |
|:---:|:---|:---|:---:|
| 🔑 | **Password Manager** | AES-256 encrypted local vault, category filters, health audit & master key protection. | All |
| 🎲 | **PassGen Generator** | Offline Diceware Passphrase (~500 EFF wordlist) & Password Generator with entropy calculator & GPU crack time estimator. | All |
| 🔑 | **2FA Authenticator** | RFC 6238 TOTP 2FA code generator, 30s countdown ring, tap-to-copy & camera QR import. Per-device isolated seed store. | All |
| 🌐 | **Dark Web Monitor** | Privacy-preserving k-Anonymity SHA-1 password breach check (HaveIBeenPwned API) + email domain leak auditor. | All |
| 🔒 | **Secret Notes** | AES-256 encrypted notepad for recovery seeds, API keys & confidential notes with category chips & pinning. | All |
| 📁 | **Encrypted File Vault** | AES-256-GCM authenticated file encryption with background Isolate thread execution for sensitive documents & photos. | All |
| 📡 | **BitMesh Off-Grid Messaging** | Dual-transport P2P mesh: BLE (mobile-to-mobile) + LAN UDP/TCP (phone-to-PC). AES-256-GCM encrypted chat, auto-discovery < 500ms, discovered peers viewer. | Android • iOS • Windows • macOS • Linux |
| 🛡️ | **Wi-Fi Threat Shield (MitM)** | Real-time ARP spoofing detector, SSL stripping HTTPS TLS probe, DNS hijacking check, cyber radar UI & 10s auto-shield. Native `arp -a` on Windows. | Android • Windows • Linux |
| 🌐 | **Encrypted DNS Shield (DoH)** | Cloudflare (1.1.1.1), Google (8.8.8.8), OpenDNS (208.67.222.222) DNS-over-HTTPS resolver. `.ovpn` file importer & profile manager. | All |
| 📶 | **Cellular Network Protection** | Extends MitM threat detection to 4G/5G/LTE mobile data connections alongside Wi-Fi. | Android |
| 🦠 | **Antivirus & Malware Scanner** | 4-layer proprietary heuristic engine: SHA-256 hash matching, YARA-style pattern heuristics, double-extension spoofing detection (`.pdf.exe`), ransomware extension guard. Quick/Full/Custom scan modes. | All |
| 🛡️ | **Vulnerability & System Audit** | 13 deep OS hardening checks: Root/Jailbreak, emulator, security patch staleness, Biometric/PAM authentication, ADB developer mode, location permissions exposure. | All |
| 📁 | **Quarantine Vault** | Encrypted `.cybe_quarantine` isolation for infected files. Restore, inspect, or permanently destroy malware payloads. | All |
| 📸 | **Anti-Spyware Suite** | Magnetometer EMF bug detector, high-contrast IR pinhole lens glint finder & LAN subnet IP camera port scanner. | Android • iOS • All (Camera/LAN) |
| 🔍 | **Malicious QR Inspector** | Live camera viewport & gallery image picker, URL shortener unmasking (`bit.ly`), raw IP check, executable alert & Cyrillic homograph detector. | All |
| 🚨 | **Encrypted Duress Panic Wipe** | Anti-coercion defense: entering emergency Duress PIN triggers silent DOD 5220.22-M multi-pass vault & key destruction while opening a deceptive clean app. | All |
| 📰 | **Cyber Threat Intel & CVEs** | Live CISA Known Exploited Vulnerabilities (KEV) catalog API, NVD zero-day updates, CVSS v3.1 rating & offline Hive caching. | All |
| 📱 | **App Permission Guard** | Android `PackageManager` analysis, weighted risk score (0–100), threat badges (📷 🎙️ 📍 💬 👥), 1-tap System Settings navigation & OS sandbox fallback. | Android (Native) • All |
| 📜 | **System Security Logs** | Real-time security event log stream, Hive persistence, severity filtering, inspector dialog & text export. | All |
| 🔗 | **Phishing URL Checker** | URL heuristic analysis, brand typosquatting detector & live web link preview. | All |
| 🖧 | **LAN Port Scanner** | TCP socket probing across common ports (FTP, SSH, Telnet, HTTP, HTTPS, SMB, UPnP, RDP), latency benchmarking & vulnerability alerts. | All |
| 🔑 | **SSH & API Key Vault** | Dedicated vault for SSH keys (RSA/Ed25519) and cloud API tokens with automatic SHA-256 key fingerprinting. | All |
| 🔌 | **USB Security Monitor** | Real-time USB device connection history, trust/block policies, hardware interface event logging. Native: Android, Windows (`lsusb`), Linux, macOS. | Android • Windows • Linux • macOS |
| 📊 | **Network Dashboard** | Real-time connection quality inspection, Wi-Fi SSID / local IP / Gateway monitoring, latency chart & DNS Lookup tool. | All |
| 📶 | **Wi-Fi Threat Radar** | Detects open AP risks, weak WEP/WPA ciphers, and Evil Twin access point suspects. | All |
| 💾 | **Secure Clipboard Manager** | In-app 10-item memory-only clipboard history with auto-wipe on app lock/minimize. | All |
| ⚙️ | **Settings & Update Checker** | Material You theme switcher, auto-lock timeout, biometric preferences, Duress PIN, encrypted `.cybe` backup export/restore, and in-app cross-platform GitHub update checker. | All |

---

## 🔄 In-App Update Checker

Cybe includes a **FOSS-compatible, cross-platform update checker** that queries the GitHub Releases API directly — no GMS, no Play Store SDK required.

| Platform | Asset auto-detected |
|:---|:---|
| 📱 Android | `*.apk` |
| 🪟 Windows | `*-windows.zip` / `*.zip` / `*.exe` |
| 🐧 Linux | `*-linux.tar.gz` / `*.tar.gz` |
| 🍎 macOS | `*-macos.dmg` / `*.dmg` |

- **Background check**: Silent auto-check once every 24 hours on dashboard open.
- **Manual check**: **Settings → App Updates → Check for Updates**.
- **Update sheet**: Gradient banner, full changelog from GitHub Release notes, platform-specific **Download** button, and **View on GitHub** link.

To trigger a notification for users, simply publish a new **GitHub Release** with a higher version tag (e.g. `v1.1.0`) and attach the platform binaries named as above.

---

## 🏗️ Technical Architecture

```
lib/
├── main.dart                        # App entrypoint, Hive init, MultiBlocProvider
├── core/
│   ├── theme/                       # AppTheme — Material You M3 dynamic color system
│   ├── router/                      # Declarative GoRouter navigation (27 feature routes)
│   ├── constants/                   # Secure storage keys & Hive box names
│   ├── utils/                       # CryptoUtils (AES-256-CBC/GCM, PBKDF2, RSA, SHA-256)
│   └── widgets/                     # ResponsiveCenter, GlassCard, status chips
└── features/
    ├── auth/                        # Master password hash, biometric lock & DuressWipeService
    ├── password_manager/            # Encrypted password vault BLoC, PassGen & Health Audit
    ├── totp/                        # RFC 6238 TOTP 2FA code generator & QR scanner
    ├── breach_monitor/              # k-Anonymity SHA-1 password breach check
    ├── secret_notes/                # AES-256 encrypted notes BLoC
    ├── file_vault/                  # Isolate background AES-256-GCM file vault
    ├── ble_mesh/                    # BitMesh: BLE + LAN dual-transport P2P mesh
    ├── wifi_scanner/                # Wi-Fi Threat Shield, DoH DNS resolver, OVPN manager
    ├── antivirus/                   # Antivirus engine, QuarantineService & AntivirusThreat models
    ├── vulnerability_scan/          # Unified Vulnerability & Antivirus Security Suite (3-tab)
    ├── spyware_detector/            # Anti-Spyware: Magnetometer EMF, IR Glint & LAN IP Cam scanner
    ├── qr_inspector/                # Malicious QR Code Inspector
    ├── threat_intel/                # Cyber Threat Intel — CISA KEV / NVD zero-day feed
    ├── app_audit/                   # App Permission & Privacy Guard
    ├── security_logs/               # Security event log stream & logcat reader
    ├── phishing_checker/            # URL heuristic analysis & web safety preview
    ├── port_scanner/                # Subnet TCP socket port scanner & fingerprinter
    ├── ssh_keys/                    # SSH key & API token vault with SHA-256 fingerprints
    ├── usb_monitor/                 # USB host device listener (Android, Windows, Linux, macOS)
    ├── network_dashboard/           # Connectivity BLoC, latency charts & DNS tool
    ├── clipboard_manager/           # Memory-only clipboard history & auto-wipe
    └── settings/                    # Settings BLoC, update checker, Duress PIN & .cybe backup
```

---

## 🚀 Build & Deployment

### Prerequisites

| Platform | Required Tools | Min SDK |
|:---|:---|:---|
| **Android** | Flutter SDK 3.x+, JDK 17, Android SDK | API 24 (Android 7.0+) |
| **Windows** | Visual Studio 2022 — Desktop C++ workload | Windows 10 x64 |
| **iOS** | Xcode 15+, CocoaPods | iOS 13.0+ |
| **macOS** | Xcode 15+, CocoaPods | macOS 11.0+ |
| **Linux** | `clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev` | GTK 3.24+ |

### Setup

```bash
git clone https://github.com/cyberlog69/Cybe-App.git
cd Cybe-App
flutter pub get
flutter doctor
```

### 📱 Android

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

adb install build/app/outputs/flutter-apk/app-release.apk
```

### 🪟 Windows

```bash
flutter config --enable-windows-desktop
flutter build windows --release
# Output: build/windows/x64/runner/Release/cybe_app.exe
```

### 🐧 Linux

```bash
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev
flutter config --enable-linux-desktop
flutter build linux --release
# Output: build/linux/x64/release/bundle/cybe_app
```

### 🍎 macOS

```bash
flutter config --enable-macos-desktop
flutter build macos --release
# Output: build/macos/Build/Products/Release/cybe_app.app
```

### 🍏 iOS

```bash
cd ios && pod install && cd ..
flutter build ipa --release
```

---

## 🔒 Security & Cryptography Design

| Layer | Implementation |
|:---|:---|
| **Vault Encryption** | AES-256-CBC with random IV per item |
| **File Vault Encryption** | AES-256-GCM authenticated tag encryption in background Dart Isolates |
| **Anti-Coercion Panic Wipe** | DOD 5220.22-M multi-pass zero-fill + 64-byte random key destruction |
| **Key Derivation** | PBKDF2-SHA256 — 100,000 iterations |
| **Dark Web Lookups** | k-Anonymity: only 5-char SHA-1 prefix queried; plaintext never leaves device |
| **Hardware Secure Storage** | Android KeyStore · iOS Keychain · Windows Credential Manager · macOS Keychain |
| **BitMesh Encryption** | AES-256-GCM per-channel with PBKDF2 key derivation; BLE + LAN dual transport |
| **DNS Privacy** | Cloudflare/Google/OpenDNS DNS-over-HTTPS (DoH) encrypted resolver |
| **Antivirus Engine** | SHA-256 hash matching + YARA-style heuristics + double-extension spoofing detection + ransomware extension guard |
| **Memory Safety** | Ephemeral in-app clipboard with automatic wipe on lock/minimize |

---

## 🟢 FOSS Compliance

Cybe is fully open-source and complies with [F-Droid inclusion requirements](FOSS_COMPLIANCE.md):

- ✅ **No Firebase** — zero Firebase dependencies
- ✅ **No GMS / Play Services** — works on de-Googled Android (CalyxOS, GrapheneOS, DivestOS)
- ✅ **No analytics or telemetry** — no crash reporting, no ad SDKs
- ✅ **MIT licensed** — see [LICENSE](LICENSE)
- ✅ **Command-line buildable** — no proprietary IDE required
- ✅ **F-Droid metadata** — Fastlane structure in [`fastlane/metadata/android/en-US/`](fastlane/metadata/android/en-US/)
- ✅ **Real source code** — this repository contains the complete, up-to-date Flutter source

---

## 📄 License

Distributed under the **MIT License** — see [`LICENSE`](LICENSE) for details.

---

*Built with Flutter · AES-256-GCM Encryption · BitMesh Dual-Transport P2P · FOSS · No GMS · F-Droid Ready*
