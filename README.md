# Speed Share ⚡

[![Flutter Version](https://img.shields.io/badge/Flutter-^3.7.2-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Speed Share** is a high-speed, secure, and completely offline file-sharing and storage synchronization application built using Flutter. It allows seamless, cross-platform file transfers and directory synchronization over local Wi-Fi or mobile hotspots—**zero internet or mobile data usage required.**

<img width="1536" height="1024" alt="Speed Share Preview" src="https://github.com/user-attachments/assets/856c99f5-4906-4dda-8549-9d92f7d48726" />

---

## 📥 Downloads

Download pre-built binaries and installers directly for your platform:

| Platform | Download Link |
| :--- | :--- |
| **🤖 Android** | [Download Universal APK](installers/app-release.apk) ([ARM64](installers/app-arm64-v8a-release.apk) \| [ARMv7](installers/app-armeabi-v7a-release.apk) \| [x86_64](installers/app-x86_64-release.apk)) |
| **🖥️ Windows** | [Download Setup (.exe)](installers/SpeedShare_Windows_Setup.exe) |
| **🍏 macOS** | [Download DMG](installers/Speed%20Share.dmg) |
| **🐧 Linux** | [Download Package (.deb)](installers/speedshare_amd64.deb) |

> 🏷️ All release binaries can also be downloaded from [GitHub Releases](https://github.com/navin280123/speedsharemob/releases).

---

## 📸 Screenshots

<!-- Add your platform screenshots below -->

### 🤖 Android
<!-- ![Android Screenshot](url_or_path_to_android_screenshot.png) -->

### 🍎 iOS
<!-- ![iOS Screenshot](url_or_path_to_ios_screenshot.png) -->

### 💻 macOS
<!-- ![macOS Screenshot](url_or_path_to_macos_screenshot.png) -->

### 🪟 Windows
<!-- ![Windows Screenshot](url_or_path_to_windows_screenshot.png) -->

### 🐧 Linux
<!-- ![Linux Screenshot](url_or_path_to_linux_screenshot.png) -->

---

## ✨ Features

* **🚀 Blazing-Fast Speeds:** Transfer large files, 4K videos, photos, and documents at maximum Wi-Fi bandwidth speeds, far outperforming Bluetooth.
* **🌐 Zero Internet Required:** Operate entirely within your local network (off-grid). No third-party servers, cloud storage, or internet connections are used.
* **📂 Remote Storage Browser & Sync:** Turn your device into a local storage server. Share specific directories and let authorized devices on the network browse, search, and download files using a secure 6-digit access code.
* **📲 True Cross-Platform:** Connect and transfer seamlessly across Android, iOS, macOS, Windows, and Linux.
* **🔒 Secure & Private:** All communication is localized. Access is restricted using secure, dynamically generated connection codes to prevent unauthorized browsing.
* **🎨 Responsive & Modern UI/UX:** Dark & light mode support built with Material 3, responsive layouts (`BottomNavigationBar` on mobile, `NavigationRail` on desktop), and fluid micro-animations.
* **⚙️ Advanced Configuration:** Customize your device name on the network, configure custom server ports (`8080`/`8082`), select custom download directories, and toggle transfer history saving.
* **🔔 Notifications & Progress:** Real-time transfer progress tracking and local background notifications.

---

## 🛠️ Technical Architecture

Speed Share operates using peer-to-peer (P2P) local networking patterns:

1. **Service Discovery (UDP Broadcast):** Devices announce their presence on the local subnet by broadcasting UDP packets (on port `8083`). This allows instances of Speed Share to automatically discover each other without manual IP entry.
2. **File Server (HTTP Server):** When sharing files or directories, the sending device spins up a lightweight, local HTTP server (`HttpServer` from `dart:io` on port `8082` / `8080`).
3. **File Transfer (HTTP Clients):** The receiving device requests the files via HTTP GET requests. High-speed streams pipe file bytes directly from host disk to receiver disk, showing real-time progress bars.

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

Release installers for all supported platforms can be generated using standard build tools:

* **Android (Split APKs):**
  ```bash
  flutter build apk --split-per-abi
  ```
* **Windows (Setup .exe via Inno Setup):**
  ```bash
  flutter build windows --release
  iscc inno_setup.iss
  ```
* **macOS (.dmg):**
  ```bash
  flutter build macos --release
  hdiutil create -volname "Speed Share" -srcfolder "build/macos/Build/Products/Release/Speed Share.app" -ov -format UDZO "installers/Speed Share.dmg"
  ```
* **Linux (.deb package):**
  ```bash
  bash installers/create_linux_installer.sh
  ```

Build artifacts are stored in the [`/installers`](installers/) directory at the root of the project.

---

## 🔄 Automated CI/CD Pipeline

Speed Share includes a multi-platform GitHub Actions build pipeline (`.github/workflows/build.yml`). 
* Supports manual triggering (`workflow_dispatch`) to build Android APKs, Windows Setup (`.exe`), macOS (`.dmg`), or Linux (`.deb`) packages on-demand.
* Automatically commits and updates compiled installer binaries back to the [`/installers`](installers/) folder in the repository.

---

## 🔒 Privacy & Security

Speed Share is built with privacy at its core:
* **Zero Telemetry / Data Collection:** No personal data, transfer logs, or metrics are sent outside your local network.
* **Direct Peer-to-Peer:** All data remains strictly on your local subnet.
* For more details, see our [Privacy Policy](privacy-policy.md).

---

## 👨‍💻 Developer & Contact

**Speed Share** is developed by **Navin Kumar Verma**.

* 🐙 **GitHub:** [@navin280123](https://github.com/navin280123)
* 💼 **LinkedIn:** [Navin Kumar Verma](https://www.linkedin.com/in/navin-kumar-verma/)
* 📸 **Instagram:** [@navin.2801](https://www.instagram.com/navin.2801/)
* 📧 **Email:** [kumarnavinverma7@gmail.com](mailto:kumarnavinverma7@gmail.com)

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
