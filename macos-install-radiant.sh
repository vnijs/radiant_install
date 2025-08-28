#!/bin/bash

# Radiant Installation Script for macOS
# Use the following command to run the latest version of this script:
# curl -sSL https://raw.githubusercontent.com/vnijs/radiant_install/main/macos-install-radiant.sh | bash

set -e  # Exit on any error

echo "Rady School of Managment @ UCSD"
echo "Radiant-for-R Installer for macOS"
echo "======================================="
echo ""

# Check macOS version
echo "🔍 Checking system compatibility..."
macos_version=$(sw_vers -productVersion)
if [[ $(echo "$macos_version 10.15" | tr " " "\n" | sort -V | head -n1) != "10.15" ]]; then
    echo "❌ This installer requires macOS 10.15 (Catalina) or later"
    echo "   Your version: $macos_version"
    exit 1
fi
echo "✅ macOS $macos_version - compatible"
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
echo "📁 Working in temporary directory: $TEMP_DIR"
echo ""

# Function to check if command succeeded
check_success() {
    if [ $? -eq 0 ]; then
        echo "✅ $1 successful"
    else
        echo "❌ $1 failed"
        exit 1
    fi
}

# Check and Install R
echo "🔧 Step 1: Checking R installation..."

# Get current R version if installed
CURRENT_R_VERSION=""
if command -v R &> /dev/null; then
    CURRENT_R_VERSION=$(R --version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
    echo "   Current R version: $CURRENT_R_VERSION"
fi

# Get latest R version from CRAN
echo "   Checking latest R version from CRAN..."
LATEST_R_VERSION=$(curl -s "https://cloud.r-project.org/bin/macosx/" | grep -o 'R-[0-9]\+\.[0-9]\+\.[0-9]\+' | head -n1 | cut -d'-' -f2)
echo "   Latest R version: $LATEST_R_VERSION"

if [[ "$CURRENT_R_VERSION" == "$LATEST_R_VERSION" ]]; then
    echo "✅ R is already up to date (version $CURRENT_R_VERSION)"
else
    if [[ -n "$CURRENT_R_VERSION" ]]; then
        echo "   R update available: $CURRENT_R_VERSION → $LATEST_R_VERSION"
    fi
    echo "   Downloading R installer from CRAN..."

    # Check if we're on Intel Mac and adjust URL
    if [[ $(uname -m) == "x86_64" ]]; then
        R_PKG_URL="https://cloud.r-project.org/bin/macosx/big-sur-x86_64/base/R-release.pkg"
    else
        R_PKG_URL="https://cloud.r-project.org/bin/macosx/big-sur-arm64/base/R-release.pkg"
    fi

    curl -L -o "R-installer.pkg" "$R_PKG_URL"
    check_success "R download"

    echo "   Installing R (requires admin password)..."
    sudo installer -pkg "R-installer.pkg" -target /
    check_success "R installation"
fi
echo ""

# Check and Install RStudio
echo "🔧 Step 2: Checking RStudio installation..."

# Get current RStudio version if installed
CURRENT_RSTUDIO_VERSION=""
if [ -d "/Applications/RStudio.app" ]; then
    CURRENT_RSTUDIO_VERSION=$(defaults read /Applications/RStudio.app/Contents/Info CFBundleShortVersionString 2>/dev/null)
    echo "   Current RStudio version: $CURRENT_RSTUDIO_VERSION"
fi

# Get latest RStudio version from Posit
echo "   Checking latest RStudio version from Posit..."
RSTUDIO_PAGE=$(curl -s "https://posit.co/download/rstudio-desktop/")
RSTUDIO_URL="https:$(echo "$RSTUDIO_PAGE" | grep -o '//download1\.rstudio\.org/electron/macos/RStudio-[^"]*\.dmg' | head -n1)"
LATEST_RSTUDIO_VERSION=$(echo "$RSTUDIO_URL" | sed 's/.*RStudio-//' | sed 's/\.dmg//' | sed 's/-/+/')
echo "   Latest RStudio version: $LATEST_RSTUDIO_VERSION"

if [[ "$CURRENT_RSTUDIO_VERSION" == "$LATEST_RSTUDIO_VERSION" ]]; then
    echo "✅ RStudio is already up to date (version $CURRENT_RSTUDIO_VERSION)"
else
    if [[ -n "$CURRENT_RSTUDIO_VERSION" ]]; then
        echo "   RStudio update available: $CURRENT_RSTUDIO_VERSION → $LATEST_RSTUDIO_VERSION"
    fi
    echo "   Downloading RStudio from Posit..."

    curl -L -o "RStudio.dmg" "$RSTUDIO_URL"
    check_success "RStudio download"

    echo "   Mounting and installing RStudio..."
    hdiutil attach "RStudio.dmg" -quiet
    RSTUDIO_VOLUME=$(ls /Volumes/ | grep RStudio | head -n1)

    if [ -n "$RSTUDIO_VOLUME" ]; then
        # Try to copy without sudo first
        if cp -R "/Volumes/$RSTUDIO_VOLUME/RStudio.app" /Applications/ 2>/dev/null; then
            echo "   RStudio installed to /Applications/"
        else
            echo "   Installing RStudio (requires admin password)..."
            sudo cp -R "/Volumes/$RSTUDIO_VOLUME/RStudio.app" /Applications/
        fi

        hdiutil detach "/Volumes/$RSTUDIO_VOLUME" -quiet
        check_success "RStudio installation"
    else
        echo "❌ Could not find RStudio volume"
        exit 1
    fi
fi
echo ""

# Install R packages
echo "🔧 Step 3: Installing Radiant and R packages..."
echo "   This may take several minutes..."

# Download R script for package installation
echo "   Downloading package installation script..."
curl -L -o "install_packages.R" "https://raw.githubusercontent.com/vnijs/radiant_install/main/install_packages.R"
check_success "Download package script"

# Run R script
/usr/local/bin/R --slave --no-restore --file=install_packages.R
check_success "R packages installation"
echo ""

# Install TinyTeX
echo "🔧 Step 4: Installing TinyTeX for PDF reports..."
echo "   This enables PDF generation in Radiant reports..."

# Download R script for TinyTeX installation
echo "   Downloading TinyTeX installation script..."
curl -L -o "install_tinytex.R" "https://raw.githubusercontent.com/vnijs/radiant_install/main/install_tinytex.R"
check_success "Download TinyTeX script"

/usr/local/bin/R --slave --no-restore --file=install_tinytex.R
check_success "TinyTeX installation"
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
echo "   1. Open RStudio from Applications folder"
echo "   2. In RStudio, go to: Addins → Start radiant or type 'radiant::radiant()' in the console window in Rstudio"
echo "   3. Radiant will open in your web browser"
echo ""
