# 🔐 Cybe Security Suite

[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Web-blue?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Flutter](https://img.shields.io/badge/Flutter-3.x%20%7C%20Dart-02569B?style=for-the-badge&logo=flutter)](https://flutter.dev)
[![Security](https://img.shields.io/badge/Encryption-AES--256--GCM%20%7C%20RSA--2048-brightgreen?style=for-the-badge&logo=shield)](https://github.com/cyberlog69/Cybe-App)
[![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)](LICENSE)

A high-performance, cross-platform cyber-security suite built with **Flutter**, designed to run natively on **Android, iOS, Windows, macOS, Linux, and Web**. 

Cybe offers offline-first encrypted password management, off-grid peer-to-peer BLE mesh messaging (**BitMesh**), network vulnerability auditing, encrypted file vaults, and cryptographically secure password & Diceware passphrase generation (**pass-gen**).

---

## 🌟 Key Features & Module Overview

| Icon | Module | Description | Supported Platforms |
|:---:|:---|:---|:---:|
| 🔑 | **Password Manager** | AES-256 encrypted local vault, category filters, fast search & master key protection. | All Platforms |
| 🎲 | **PassGen Generator** | Offline Diceware Passphrase (~500 EFF wordlist) & Password Generator with entropy calculator and 100B/s GPU crack time estimator. | All Platforms |
| 📡 | **BitMesh Off-Grid Messaging** | Decentralized peer-to-peer Bluetooth Low Energy (BLE) mesh protocol with RSA-2048 identity handshake & AES-GCM encrypted chat. | Android • iOS • Windows • macOS • Linux |
| 🛡️ | **Biometric Unlock** | Fingerprint, Face ID, Touch ID, and Windows Hello authentication using `FlutterFragmentActivity` on Android. | Android • iOS • Windows • macOS |
| 📁 | **Encrypted File Vault** | AES-256-GCM authenticated file encryption for sensitive documents & photos. | All Platforms |
| 📊 | **Network Dashboard** | Real-time connection quality inspection, Wi-Fi SSID / local IP / Gateway monitoring, latency tracking chart & DNS Lookup tool. | All Platforms |
| 🔍 | **Vulnerability Audit** | OS security level, root/jailbreak detection, development mode detection, sandbox integrity check. | All Platforms |
| 🔌 | **USB Security Monitor** | Real-time USB device connection history, trust/block lists, and hardware interface policy management. | Android • Windows • Linux • macOS |

---

## 🏗️ Technical Architecture

```
lib/
├── main.dart                  # Application entrypoint & MultiBlocProvider
├── core/
│   ├── theme/                 # Dark cyberpunk theme & color tokens
│   ├── router/                # Declarative GoRouter navigation
│   ├── constants/             # App-wide constants & storage keys
│   ├── utils/                 # CryptoUtils (AES-256-CBC/GCM, PBKDF2, RSA)
│   └── widgets/               # ResponsiveCenter, GlassCard, status chips
└── features/
    ├── auth/                  # Master password hash, setup & biometric lock
    ├── ble_mesh/              # BitMesh BLE discovery, RSA handshake & P2P chat
    │   ├── models/            # MeshMessage, MeshPeer, HandshakePayload
    │   ├── services/          # BleMeshService (BLE Central & Peripheral)
    │   └── screens/           # BitMesh off-grid chat UI & peer scanner
    ├── dashboard/             # Dashboard Home, security score & About dialog
    ├── password_manager/      # Encrypted password vault BLoC & screens
    │   ├── services/          # PassGenService (EFF Diceware, CSPRNG, Entropy)
    │   └── widgets/           # PasswordGeneratorSheet (Dual-mode tabbed modal)
    ├── file_vault/            # AES-256-GCM file encryption & sandboxed vault
    ├── network_dashboard/     # Connectivity BLoC, latency charts & DNS tool
    ├── phishing_checker/      # URL heuristic analysis & domain verification
    ├── usb_monitor/           # USB host device listener & trust manager
    └── vulnerability_scan/    # Device health, root detection & OS build audit
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

Verify your environment readiness:
```bash
flutter doctor
```

---

### 📱 2. Android Deployment (APK & Google Play AAB)

#### A. Configure Environment
Set `ANDROID_HOME` environment variable pointing to your Android SDK:
- **Windows (PowerShell)**:
  ```powershell
  $env:ANDROID_HOME="C:\Users\$env:USERNAME\AppData\Local\Android\Sdk"
  [Environment]::SetEnvironmentVariable("ANDROID_HOME", $env:ANDROID_HOME, "User")
  ```
- **macOS / Linux (Bash/Zsh)**:
  ```bash
  export ANDROID_HOME=$HOME/Library/Android/sdk
  export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools
  ```

#### B. Accept Licenses
```bash
flutter doctor --android-licenses
```

#### C. Biometric Setup Note (`FlutterFragmentActivity`)
This app utilizes `FlutterFragmentActivity` in `android/app/src/main/kotlin/com/cybe/cybe_app/MainActivity.kt` to ensure complete compatibility with `local_auth` biometrics (Fingerprint/Face Unlock). No manual edits required.

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
- **Contents**: `cybe_app.exe` along with required DLL runtime libraries.

#### D. Create Standalone Windows Installer (Inno Setup)
1. Download & install [Inno Setup](https://jrsoftware.org/isinfo.php).
2. Point Inno Setup script to `build/windows/x64/runner/Release/`.
3. Compile into a single `CybeSecuritySetup.exe` installer for distribution.

---

### 🍏 4. iOS Deployment (iPhone & iPad App Store / TestFlight)

#### A. Prerequisites
Requires a macOS host with **Xcode 15+** installed and an active Apple Developer account.

#### B. CocoaPods Setup
```bash
cd ios
pod install
cd ..
```

#### C. Configure Signing & Capabilities in Xcode
1. Open project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select `Runner` in project navigator -> **Signing & Capabilities**.
3. Select your **Team** and set a unique **Bundle Identifier** (e.g. `com.yourdomain.cybeApp`).
4. Ensure `NSFaceIDUsageDescription` and `NSBluetoothAlwaysUsageDescription` are specified in `Info.plist`.

#### D. Build IPA Package
```bash
flutter build ipa --release
```
- **Output Location**: `build/ios/archive/Runner.xcarchive` and `build/ios/ipa/cybe_app.ipa`
- **Distribution**: Upload to **TestFlight** or **App Store Connect** using Xcode Organizer or Transporter.

---

### 🖥️ 5. macOS Desktop Deployment (.app & .dmg)

#### A. Prerequisites
macOS host with Xcode command line tools installed.

#### B. Enable macOS Platform
```bash
flutter config --enable-macos-desktop
```

#### C. Build macOS Release Binary
```bash
flutter build macos --release
```
- **Output Location**: `build/macos/Build/Products/Release/cybe_app.app`

#### D. Package into Installable Disk Image (.dmg)
Install `create-dmg`:
```bash
brew install create-dmg
create-dmg \
  --volname "Cybe Security" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "cybe_app.app" 200 190 \
  --hide-extension "cybe_app.app" \
  --app-drop-link 600 190 \
  "CybeSecurityInstaller.dmg" \
  "build/macos/Build/Products/Release/"
```

---

### 🐧 6. Linux Desktop Deployment (Debian / Ubuntu / Snap)

#### A. Install Required Build Dependencies
On Ubuntu / Debian:
```bash
sudo apt update
sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev
```

#### B. Enable Linux Platform
```bash
flutter config --enable-linux-desktop
```

#### C. Build Linux Release Binary
```bash
flutter build linux --release
```
- **Output Location**: `build/linux/x64/release/bundle/`
- **Run Standalone Binary**:
  ```bash
  ./build/linux/x64/release/bundle/cybe_app
  ```

---

### 🌐 7. Web Deployment (Progressive Web App)

#### A. Enable Web Platform
```bash
flutter config --enable-web
```

#### B. Build Web Bundle
```bash
flutter build web --release --web-renderer canvaskit
```
- **Output Location**: `build/web/`

#### C. Deploy to Cloud Run / Firebase / Nginx / Vercel
- **Firebase Hosting**:
  ```bash
  npm install -g firebase-tools
  firebase init hosting
  # Set public directory to: build/web
  firebase deploy
  ```
- **Nginx Web Server Configuration**:
  ```nginx
  server {
      listen 80;
      server_name security.yourdomain.com;
      root /var/www/cybe_app/build/web;
      index index.html;

      location / {
          try_files $uri $uri/ /index.html;
      }
  }
  ```

---

## 🔒 Security & Cryptography Design

- **Vault Storage Encryption**: AES-256-CBC with random IV per item.
- **File Encryption**: AES-256-GCM with authenticated tag validation.
- **Key Derivation**: Master password derived via PBKDF2-SHA256 (100,000 iterations).
- **Secure Storage**: Device Hardware Keystore (Android EncryptedSharedPreferences, iOS Keychain, Windows Credential Manager).
- **Off-Grid P2P Encryption (BitMesh)**: Ephemeral RSA-2048 handshake with AES-GCM transport layer.
- **Memory Safety**: Direct automatic clipboard auto-wiping (30-second security timer).

---

## ❓ Troubleshooting & FAQs

#### Q1: Biometric authentication throws `PlatformException(no_fragment_activity)` on Android
- **Fix**: Verify `android/app/src/main/kotlin/com/cybe/cybe_app/MainActivity.kt` extends `FlutterFragmentActivity` (already implemented).

#### Q2: Kotlin or Android Gradle Plugin (AGP) Version mismatch during build
- **Fix**: The project uses **AGP 8.11.1** and **Kotlin 2.2.20** configured in `android/settings.gradle.kts`. Use `jni: ^1.0.2` dependency override if needed.

#### Q3: Android build fails with `No Android SDK found`
- **Fix**: Set `ANDROID_HOME` pointing to your Android SDK directory and ensure `cmdline-tools;latest` is installed via Android Studio SDK Manager.

---

## 📄 License

Distributed under the **MIT License**. See `LICENSE` for more information.

*Built with Flutter · Secured with AES-256 · Off-Grid BLE Mesh · Cross-Platform Desktop & Mobile*
