#!/bin/bash

# Radiant Installation Script for Arch Linux
# Use the following command to run the latest version of this script:
# curl -sSL https://raw.githubusercontent.com/vnijs/radiant_install/main/linux-arch-install-radiant.sh | bash

set -e # Exit on any error

echo "Rady School of Management @ UCSD"
echo "Radiant-for-R Installer for Arch Linux"
echo "======================================="
echo ""

# Check if running on Arch Linux
if [ ! -f /etc/arch-release ]; then
  echo "❌ This installer is designed for Arch Linux"
  exit 1
fi
echo "✅ Arch Linux detected"
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
echo "📁 Working in temporary directory: $TEMP_DIR"
echo ""

# Install R
echo "🔧 Step 1: Installing R..."
sudo pacman -S --needed --noconfirm r
echo "✅ R installed"
echo ""

# Install build dependencies for R packages
echo "🔧 Step 2: Installing R build dependencies..."
sudo pacman -S --needed --noconfirm base-devel gcc-fortran cmake \
  libpng libjpeg-turbo libtiff \
  curl openssl libxml2 \
  cairo pango
echo "✅ Build dependencies installed"
echo ""

# Install RStudio from AUR
echo "🔧 Step 3: Installing RStudio..."

# Check for AUR helper
if ! command -v yay &>/dev/null && ! command -v paru &>/dev/null; then
  echo "   Installing yay AUR helper..."
  git clone https://aur.archlinux.org/yay.git
  cd yay
  makepkg -si --noconfirm
  cd "$TEMP_DIR"
fi

# Use available AUR helper
if command -v paru &>/dev/null; then
  AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
  AUR_HELPER="yay"
else
  echo "❌ No AUR helper found"
  exit 1
fi

echo "   Installing RStudio from AUR..."
$AUR_HELPER -S --needed --noconfirm rstudio-desktop-bin
echo "✅ RStudio installed"
echo ""

# Install R packages
echo "🔧 Step 4: Installing Radiant and R packages..."
echo "   This may take several minutes..."
curl -L -o "install_packages.R" "https://raw.githubusercontent.com/vnijs/radiant_install/main/install_packages.R"
R --slave --no-restore --file=install_packages.R
echo "✅ R packages installed"
echo ""

# Install TinyTeX
echo "🔧 Step 5: Installing TinyTeX for PDF reports..."
curl -L -o "install_tinytex.R" "https://raw.githubusercontent.com/vnijs/radiant_install/main/install_tinytex.R"
R --slave --no-restore --file=install_tinytex.R
echo "✅ TinyTeX installed"
echo ""

# Cleanup
cd /
rm -rf "$TEMP_DIR"
echo "🧹 Cleaned up temporary files"
echo ""

# Final instructions
echo "🎉 Installation Complete!"
echo "======================="
echo ""
echo "✅ R installed"
echo "✅ RStudio installed"
echo "✅ Radiant packages installed"
echo "✅ TinyTeX installed for PDF reports"
echo ""
echo "📋 Next Steps:"
echo "   1. Open RStudio from your application menu or run 'rstudio' in terminal"
echo "   2. In RStudio, go to: Addins → Start radiant or type 'radiant::radiant()' in the console window in Rstudio"
echo "   3. Radiant will open in your web browser"
echo ""
