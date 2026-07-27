# 🔐 Cybe Security App

A comprehensive **cross-platform mobile security suite** for Android & iOS, built with **Flutter**.

![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Features

| Module | Description | Platform |
|--------|-------------|----------|
| 🔑 **Password Manager** | AES-256 encrypted vault, generator, strength meter | Android + iOS |
| 📡 **Wi-Fi Scanner** | Security rating, evil twin detection, open network alerts | Android + iOS |
| 📁 **File Vault** | AES-256-GCM file encryption, sandboxed storage | Android + iOS |
| 🎣 **Phishing Checker** | URL heuristic + Google Safe Browsing analysis | Android + iOS |
| 🔍 **Vulnerability Scanner** | Root detection, OS version, permissions audit | Android + iOS |
| 🔌 **USB Monitor** | Device detection, trust/block, connection history | Android (iOS: guidance) |
| 📊 **Network Dashboard** | Live latency chart, DNS lookup, connection info | Android + iOS |

---

## Setup

### Prerequisites
- Flutter SDK (see below)
- Android Studio (for Android) or Xcode (for iOS)
- Physical device or emulator

### 1. Install Flutter (if not installed)
```powershell
# Already downloaded to:
# C:\Users\<YOU>\flutter\

# Add to PATH:
$env:PATH += ";C:\Users\$env:USERNAME\flutter\bin"
```

### 2. Initialize the project
```powershell
# From the project directory:
.\setup.ps1
```

Or manually:
```powershell
$flutter = "C:\Users\$env:USERNAME\flutter\bin\flutter.bat"
& $flutter create --org com.cybe --project-name cybe_app --platforms android,ios .
& $flutter pub get
```

### 3. Create asset directories
```powershell
mkdir assets\animations, assets\images, assets\icons, assets\fonts
```

### 4. Configure API Keys (optional)
Edit `lib/core/constants/app_constants.dart`:
```dart
static const String safeBrowsingApiKey = 'YOUR_GOOGLE_SAFE_BROWSING_API_KEY';
```
Get a free key at: https://console.cloud.google.com/apis/library/safebrowsing.googleapis.com

### 5. Run the app
```powershell
& $flutter devices        # List available devices
& $flutter run            # Run on connected device
& $flutter run -d <id>    # Run on specific device
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
    ├── dashboard/     # Home with security score
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
- **Key storage**: iOS Keychain / Android Keystore via `flutter_secure_storage`
- **Authentication**: Master password + biometrics (Face ID / Fingerprint)
- **State management**: BLoC pattern (no sensitive data in UI state)

## Build for Production

```powershell
# Android APK
& $flutter build apk --release --obfuscate --split-debug-info=./debug-info/

# iOS
& $flutter build ios --release --obfuscate --split-debug-info=./debug-info/
```

---

*Built with Flutter · Secured with AES-256 · Designed for privacy*
