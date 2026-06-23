# Speed Share ⚡

[![Flutter Version](https://img.shields.io/badge/Flutter-^3.7.2-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Speed Share** is a high-speed, secure, and completely offline file-sharing and storage synchronization application built using Flutter. It allows seamless, cross-platform file transfers and directory synchronization over local Wi-Fi or mobile hotspots—**zero internet or mobile data usage required.**

---

## ✨ Features

* **🚀 Blazing-Fast Speeds:** Transfer large files, 4K videos, photos, and documents at maximum Wi-Fi bandwidth speeds, far outperforming Bluetooth.
* **🌐 Zero Internet Required:** Operate entirely within your local network (off-grid). No third-party servers, cloud storage, or internet connections are used.
* **📂 Remote Storage Browser & Sync:** Turn your device into a local storage server. Share specific directories and let authorized devices on the network browse, search, and download files using a secure 6-digit access code.
* **📲 True Cross-Platform:** Connect and transfer seamlessly across Android, iOS, macOS, Windows, and Linux.
* **🔒 Secure & Private:** All communication is localized. Access is restricted using secure, dynamically generated connection codes to prevent unauthorized browsing.
* **🎨 Modern UI/UX:** Clean, elegant dark-themed interface built with the Poppins font, custom Material 3 widgets, responsive layouts, and fluid micro-animations.

---

## 🛠️ Technical Architecture

Speed Share operates using peer-to-peer (P2P) local networking patterns:

1. **Service Discovery (UDP Broadcast):** Devices announce their presence on the local subnet by broadcasting UDP packets (on port `8083`). This allows instances of Speed Share to automatically discover each other without manual IP entry.
2. **File Server (HTTP Server):** When sharing files or directories, the sending device spins up a lightweight, local HTTP server (`HttpServer` from `dart:io` on port `8082`).
3. **File Transfer (HTTP Clients):** The receiving device requests the files via HTTP GET requests. High-speed streams pipe file bytes directly from host disk to receiver disk, showing real-time progress bars.

---

## 📁 Project Structure

The core logic of the application resides in the `lib/` directory:

* [`main.dart`](lib/main.dart): The application entry point, setting up the global dark theme, Material 3 preferences, and loading the Poppins typography.
* [`MainScreen.dart`](lib/MainScreen.dart): The home dashboard and responsive layout container (switching between a `BottomNavigationBar` on mobile and a `NavigationRail` on desktop).
* [`FileSenderScreen.dart`](lib/FileSenderScreen.dart): Handles file selection, sender server instantiation, and peer connection management.
* [`ReceiveScreen.dart`](lib/ReceiveScreen.dart): Manages discovery socket listening, incoming file downloads, and manual IP connections.
* [`SyncScreen.dart`](lib/SyncScreen.dart): Implements the remote storage browser, directory sharing, and access token validation.
* [`PermissionManager.dart`](lib/PermissionManager.dart): Manages platform-specific run-time permissions (e.g., storage access on Android 11+ and iOS photo library access).

---

## 🚀 Getting Started

### Prerequisites

Ensure you have the Flutter SDK installed and configured on your machine.

* Flutter SDK: `^3.7.2`
* Dart SDK: `^3.7.0`

### Installation & Run

1. **Clone the repository:**
   ```bash
   git clone https://github.com/navin280123/speedsharemob.git
   cd speedsharemob
   ```

2. **Fetch dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   # Run on any connected device/simulator
   flutter run
   ```

### Build Installers

Release installers for all supported platforms can be generated using standard Flutter build tools:

* **Android (Split APKs):**
  ```bash
  flutter build apk --split-per-abi
  ```
* **macOS:**
  ```bash
  flutter build macos --release
  ```

Build artifacts (including the macOS `.dmg`, Windows `.exe` installer, and Android `.apk` files) are stored in the [`/installers`](installers/) directory at the root of the project.

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
