#!/bin/bash
# Script to build a Debian (.deb) package for Speed Share on Linux.
# Run this script on your Linux build machine with the Flutter SDK installed.

# Exit immediately if a command exits with a non-zero status
set -e

# Change directory to the repository root
cd "$(dirname "$0")/.."

echo "=== Building Speed Share Linux Release ==="
flutter build linux --release

# Packaging Variables
APP_NAME="speedshare"
VERSION="1.0.0"
DEB_DIR="installers"
BUILD_DIR="build/linux/x64/release/bundle"
TEMP_DIR="${DEB_DIR}/deb_temp"

echo "=== Creating Debian Package Structure ==="
# Clean up any existing temp files or old packages
rm -rf "${TEMP_DIR}"
rm -f "${DEB_DIR}/${APP_NAME}_amd64.deb"

# Recreate folders
mkdir -p "${TEMP_DIR}/DEBIAN"
mkdir -p "${TEMP_DIR}/usr/bin"
mkdir -p "${TEMP_DIR}/usr/share/applications"
mkdir -p "${TEMP_DIR}/usr/share/pixmaps"
mkdir -p "${TEMP_DIR}/usr/share/speedshare"

# 1. Create DEBIAN/control file
echo "Writing control file..."
cat <<EOT > "${TEMP_DIR}/DEBIAN/control"
Package: ${APP_NAME}
Version: ${VERSION}
Architecture: amd64
Maintainer: Navin Kumar Verma <navin280123@github.com>
Description: Speed Share - High-speed local network file sharing and storage sync.
Section: utils
Priority: optional
Depends: libc6, libgtk-3-0, libglib2.0-0
EOT

# 2. Create launcher wrapper script
echo "Writing launcher script..."
cat <<EOT > "${TEMP_DIR}/usr/bin/speedshare"
#!/bin/sh
exec /usr/share/speedshare/speedsharemob "\$@"
EOT
chmod +x "${TEMP_DIR}/usr/bin/speedshare"

# 3. Create desktop launcher entry
echo "Writing desktop entry..."
cat <<EOT > "${TEMP_DIR}/usr/share/applications/speedshare.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Speed Share
Comment=High-speed local network file sharing and storage sync
Exec=speedshare
Icon=speedshare
Terminal=false
Categories=Utility;FileTransfer;
EOT

# 4. Copy build bundle files
echo "Copying compiled binaries and assets..."
cp -r ${BUILD_DIR}/* "${TEMP_DIR}/usr/share/speedshare/"

# 5. Copy app icon
echo "Copying app icon to pixmaps..."
cp assets/icon.png "${TEMP_DIR}/usr/share/pixmaps/speedshare.png"

# 6. Build the debian package
echo "Compiling deb package..."
dpkg-deb --build "${TEMP_DIR}" "${DEB_DIR}/${APP_NAME}_amd64.deb"

# Clean up
rm -rf "${TEMP_DIR}"

echo "=== Linux installer created successfully at ${DEB_DIR}/${APP_NAME}_amd64.deb ==="
