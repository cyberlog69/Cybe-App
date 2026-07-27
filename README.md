# 🔐 Cybe Security App

A comprehensive **cross-platform mobile & desktop security suite** for **Android, iOS, Windows, Linux, and macOS**, built with **Flutter**.

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20Linux%20%7C%20macOS-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Features & Platform Support

| Module | Description | Supported Platforms |
|--------|-------------|--------------------|
| 🔑 **Password Manager** | AES-256 encrypted vault, generator, strength meter | Android • iOS • Windows • Linux • macOS |
| 📡 **Wi-Fi Scanner** | Security rating, evil twin detection, open network alerts | Android • iOS (Desktop info on PC/Mac) |
| 📁 **File Vault** | AES-256-GCM file encryption, sandboxed storage | Android • iOS • Windows • Linux • macOS |
| 🎣 **Phishing Checker** | URL heuristic + Google Safe Browsing analysis | Android • iOS • Windows • Linux • macOS |
| 🔍 **Vulnerability Scanner** | Root/jailbreak, OS build, system lock, sandbox audit | Android • iOS • Windows • Linux • macOS |
| 🔌 **USB Monitor** | Device detection, trust/block, connection history | Android (iOS & Desktop security guidance) |
| 📊 **Network Dashboard** | Live latency chart, DNS lookup, connection info | Android • iOS • Windows • Linux • macOS |

---

## Setup & Running

### Prerequisites
- Flutter SDK 3.x+
- Platform build toolchains:
  - **Android**: Android Studio / SDK
  - **iOS / macOS**: Xcode (macOS host required)
  - **Windows**: Visual Studio 2022 (Desktop C++ workload)
  - **Linux**: `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`

### 1. Initialize the project
```powershell
$flutter = "C:\Users\$env:USERNAME\flutter\bin\flutter.bat"

# Generate platform scaffolds
& $flutter create --org com.cybe --project-name cybe_app --platforms android,ios,windows,linux,macos .
& $flutter pub get
```

### 2. Run the application

```powershell
# List available devices (Mobile & Desktop)
& $flutter devices

# Run on Windows Desktop
& $flutter run -d windows

# Run on macOS Desktop
& $flutter run -d macos

# Run on Linux Desktop
& $flutter run -d linux

# Run on Android / iOS
& $flutter run -d <device-id>
```

---

## Architecture

```
lib/
├── core/
│   ├── theme/         # Dark cyberpunk theme
│   ├── router/        # GoRouter navigation
│   ├── constants/     # App-wide constants
│   ├── utils/         # CryptoUtils (AES-256, PBKDF2)
│   └── widgets/       # Reusable components
└── features/
    ├── auth/          # Master password + biometrics
    ├── dashboard/     # Home with security score & About dialog
    ├── password_manager/
    ├── wifi_scanner/
    ├── file_vault/
    ├── phishing_checker/
    ├── vulnerability_scan/
    ├── usb_monitor/
    └── network_dashboard/
```

## Security Design

- **Encryption**: AES-256-GCM for files, AES-256-CBC for passwords
- **Key derivation**: PBKDF2-SHA256 (100,000 iterations)
- **Key storage**: Hardware Keystore / Keychain / Encrypted Storage via `flutter_secure_storage`
- **Authentication**: Master password + biometrics (Windows Hello / Touch ID / Face ID / Fingerprint)
- **State management**: BLoC pattern (no sensitive data in UI state)

## Build for Production

```powershell
# Android APK
& $flutter build apk --release

# Windows Executable (.exe)
& $flutter build windows --release

# macOS App (.app / .dmg)
& $flutter build macos --release

# Linux Executable
& $flutter build linux --release
```

---

*Built with Flutter · Secured with AES-256 · Multi-Platform Desktop & Mobile*
