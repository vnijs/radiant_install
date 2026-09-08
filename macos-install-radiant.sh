#!/bin/bash

# Radiant Installation Script for macOS
# Use the following command to run the latest version of this script:
# curl -sSL https://raw.githubusercontent.com/vnijs/radiant_install/main/macos-install-radiant.sh | bash

set -e  # Exit on any error

echo "Rady School of Managment @ UCSD"
echo "Radiant-for-R Installer for macOS"
echo "======================================="
echo ""

version_at_least() {
    local version="$1"
    local minimum="$2"
    local IFS=.
    local version_parts minimum_parts i version_part minimum_part

    read -ra version_parts <<< "$version"
    read -ra minimum_parts <<< "$minimum"

    for ((i = 0; i < ${#minimum_parts[@]}; i++)); do
        version_part=${version_parts[i]:-0}
        minimum_part=${minimum_parts[i]:-0}

        if ((10#$version_part > 10#$minimum_part)); then
            return 0
        elif ((10#$version_part < 10#$minimum_part)); then
            return 1
        fi
    done

    return 0
}

# Check macOS version
echo "🔍 Checking system compatibility..."
macos_version=$(sw_vers -productVersion)
if ! version_at_least "$macos_version" "14.0"; then
    echo "❌ This installer requires macOS 14.0 (Sonoma) or later"
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

CRAN_R_FRAMEWORK="/Library/Frameworks/R.framework"
CRAN_R_FRAMEWORK_BIN="$CRAN_R_FRAMEWORK/Resources/bin/R"
CRAN_R_CLI="/usr/local/bin/R"
CRAN_RSCRIPT_CLI="/usr/local/bin/Rscript"

r_version() {
    "$1" --version 2>/dev/null | head -n1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || true
}

is_cran_r() {
    local r_bin="$1"
    local r_home

    if [ ! -x "$r_bin" ]; then
        return 1
    fi

    r_home=$("$r_bin" RHOME 2>/dev/null | head -n1 || true)
    [[ "$r_home" == "$CRAN_R_FRAMEWORK/Resources"* ]]
}

find_cran_r() {
    if is_cran_r "$CRAN_R_CLI"; then
        echo "$CRAN_R_CLI"
        return 0
    fi

    if [ -x "$CRAN_R_FRAMEWORK_BIN" ]; then
        echo "$CRAN_R_FRAMEWORK_BIN"
        return 0
    fi

    return 1
}

# Check and Install R
echo "🔧 Step 1: Checking R installation..."

# Get current CRAN R version if installed. RStudio on macOS expects the CRAN
# framework layout; an R from Homebrew, Nix, or another PATH entry is not enough.
CURRENT_R_VERSION=""
PATH_R=$(command -v R || true)
R_CMD=$(find_cran_r || true)

if [[ -n "$R_CMD" ]]; then
    CURRENT_R_VERSION=$(r_version "$R_CMD")
    echo "   Current CRAN R version: $CURRENT_R_VERSION"
    echo "   Current CRAN R path: $R_CMD"
elif [[ -n "$PATH_R" ]]; then
    echo "   Ignoring R found at $PATH_R"
    echo "   RStudio on macOS needs CRAN R under /Library/Frameworks/R.framework"
fi

# Get latest R version from CRAN
echo "   Checking latest R version from CRAN..."
CRAN_MACOS_URL="https://cloud.r-project.org/bin/macosx/"
CRAN_MACOS_PAGE=$(curl -fsSL "$CRAN_MACOS_URL")
if [[ $(uname -m) == "x86_64" ]]; then
    R_ARCH="x86_64"
else
    R_ARCH="arm64"
fi

# Take the HIGHEST version advertised for this architecture, not the first one
# on the page.
#
# CRAN publishes one build directory per macOS baseline and freezes the old one
# when a new baseline appears: big-sur-arm64 stopped at R 4.5.3 while
# sonoma-arm64 carries 4.6.x. If a frozen directory is ever listed above the
# current one, `head -n1` installs the stale release -- and because the version
# check would still report the newer one, the installed version could never
# match the detected one and the script would reinstall R on every single run.
# Sorting on the version keeps the choice independent of page order.
R_PKG_RELATIVE=$(printf "%s\n" "$CRAN_MACOS_PAGE" \
    | sed -n "s/.*href=\"\([^\"]*R-[0-9][0-9.]*-${R_ARCH}\.pkg\)\".*/\1/p" \
    | sed -E "s|^(.*R-([0-9]+\.[0-9]+\.[0-9]+)-${R_ARCH}\.pkg)$|\2\t\1|" \
    | sort -V | tail -n1 | cut -f2)

if [[ -z "$R_PKG_RELATIVE" ]]; then
    echo "❌ Could not determine R package URL"
    exit 1
fi

R_PKG_URL="${CRAN_MACOS_URL}${R_PKG_RELATIVE}"
if [[ "$R_PKG_RELATIVE" =~ R-([0-9]+\.[0-9]+\.[0-9]+)- ]]; then
    LATEST_R_VERSION="${BASH_REMATCH[1]}"
else
    LATEST_R_VERSION=""
fi
echo "   Latest R version: $LATEST_R_VERSION"
echo "   R package URL: $R_PKG_URL"

if [[ -z "$LATEST_R_VERSION" ]]; then
    echo "❌ Could not determine latest R version"
    exit 1
fi

if [[ "$CURRENT_R_VERSION" == "$LATEST_R_VERSION" ]]; then
    echo "✅ CRAN R is already up to date (version $CURRENT_R_VERSION)"
else
    if [[ -n "$CURRENT_R_VERSION" ]]; then
        echo "   R update available: $CURRENT_R_VERSION → $LATEST_R_VERSION"
    elif [[ -n "$PATH_R" ]]; then
        echo "   Installing CRAN R because the existing R is not in a location RStudio can use"
    fi
    echo "   Downloading R installer from CRAN..."

    curl -L -o "R-installer.pkg" "$R_PKG_URL"
    check_success "R download"

    echo "   Installing R (requires admin password)..."
    sudo installer -pkg "R-installer.pkg" -target /
    check_success "R installation"
fi

R_CMD=$(find_cran_r || true)
if [[ -z "$R_CMD" ]]; then
    echo "❌ CRAN R was not found after installation"
    echo "   Expected: $CRAN_R_FRAMEWORK_BIN or $CRAN_R_CLI"
    exit 1
fi

if [[ ! -d "$CRAN_R_FRAMEWORK" ]]; then
    echo "❌ R framework not found at $CRAN_R_FRAMEWORK"
    echo "   RStudio may not be able to discover R without the CRAN framework install"
    exit 1
fi

if [[ ! -x "$CRAN_R_CLI" ]]; then
    echo "   Warning: $CRAN_R_CLI was not found; using $R_CMD for package installation"
fi

echo "   Using R at $R_CMD"
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
RSTUDIO_URL=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://rstudio.org/download/latest/stable/desktop/mac/RStudio-latest.dmg")
LATEST_RSTUDIO_VERSION=$(echo "$RSTUDIO_URL" | sed -n 's/.*RStudio-\([0-9.]*\)-\([0-9]*\)\.dmg.*/\1+\2/p')
echo "   Latest RStudio version: $LATEST_RSTUDIO_VERSION"

if [[ -z "$RSTUDIO_URL" || -z "$LATEST_RSTUDIO_VERSION" ]]; then
    echo "❌ Could not determine latest RStudio version"
    exit 1
fi

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
"$R_CMD" --slave --no-restore --file=install_packages.R
check_success "R packages installation"
echo ""

# Install TinyTeX
echo "🔧 Step 4: Installing TinyTeX for PDF reports..."
echo "   This enables PDF generation in Radiant reports..."

# Download R script for TinyTeX installation
echo "   Downloading TinyTeX installation script..."
curl -L -o "install_tinytex.R" "https://raw.githubusercontent.com/vnijs/radiant_install/main/install_tinytex.R"
check_success "Download TinyTeX script"

"$R_CMD" --slave --no-restore --file=install_tinytex.R
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
