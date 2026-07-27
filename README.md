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
---

## 📸 Screenshots

<!-- Add your platform screenshots below -->

### 🤖 Android
<img width="411" height="921" alt="Screenshot 2026-07-27 at 11 14 34 AM" src="https://github.com/user-attachments/assets/19bea07e-9781-4e15-a630-803de5f07b3d" />
<img width="410" height="922" alt="Screenshot 2026-07-27 at 11 15 37 AM" src="https://github.com/user-attachments/assets/2a8e8cb7-aa70-42d4-b922-c030e2cc97e0" />
<img width="411" height="925" alt="Screenshot 2026-07-27 at 11 15 04 AM" src="https://github.com/user-attachments/assets/10352704-954b-4248-8bbf-2292038c5356" />
<img width="411" height="921" alt="Screenshot 2026-07-27 at 11 16 01 AM" src="https://github.com/user-attachments/assets/84e925c6-a4ec-445f-a235-3bd63435dce6" />

<!-- ![Android Screenshot](url_or_path_to_android_screenshot.png) -->

### 🍎 iOS
<img width="1206" height="2622" alt="simulator_screenshot_B75FAFB7-2E14-4055-B53C-B4161B2AA7F6" src="https://github.com/user-attachments/assets/96dbfa0e-0e7e-4831-813f-b3ea9da94bb4" />
<img width="1206" height="2622" alt="simulator_screenshot_9BEF2ADA-9A28-4981-BF63-FB0092B57AEF" src="https://github.com/user-attachments/assets/4c4e9959-ea4f-4250-8cb8-04e5705a2552" />
<img width="1206" height="2622" alt="simulator_screenshot_7F656374-734E-416E-BBE9-679DBAC9932D" src="https://github.com/user-attachments/assets/4f414b8e-5161-4b18-98e9-e37883f0ae91" />
<img width="1206" height="2622" alt="simulator_screenshot_25AC9F33-F512-4D55-9F6C-92263D58B515" src="https://github.com/user-attachments/assets/a68f582b-394b-4619-af3e-55fa7748d444" />

<!-- ![iOS Screenshot](url_or_path_to_ios_screenshot.png) -->

### 💻 macOS
<img width="800" height="627" alt="Screenshot 2026-07-27 at 11 07 52 AM" src="https://github.com/user-attachments/assets/63948047-adc3-4a9d-ba47-7c38ed786502" />
<img width="800" height="630" alt="Screenshot 2026-07-27 at 11 08 41 AM" src="https://github.com/user-attachments/assets/1783727b-9104-481f-82bb-562d5bdaee02" />
<img width="802" height="630" alt="Screenshot 2026-07-27 at 11 08 21 AM" src="https://github.com/user-attachments/assets/b955cabd-f2ce-4013-9508-2b5db3131311" />
<img width="800" height="630" alt="Screenshot 2026-07-27 at 11 17 01 AM" src="https://github.com/user-attachments/assets/9e87d8d1-4c7d-4ca6-b3aa-82f545403f78" />

<!-- ![macOS Screenshot](url_or_path_to_macos_screenshot.png) -->

### 🪟 Windows
<!-- ![Windows Screenshot](url_or_path_to_windows_screenshot.png) -->

### 🐧 Linux
<!-- ![Linux Screenshot](url_or_path_to_linux_screenshot.png) -->

---
## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
