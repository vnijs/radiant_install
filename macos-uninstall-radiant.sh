#!/bin/bash

# Radiant Uninstall Script for macOS
# This script removes R, RStudio, and all associated files
# 
# To run this script:
# curl -sSL https://raw.githubusercontent.com/vnijs/radiant_install/main/macos-uninstall-radiant.sh | bash

echo "Rady School of Management @ UCSD"
echo "Radiant-for-R Uninstaller for macOS"
echo "======================================="
echo ""
echo "⚠️  WARNING: This will completely remove R, RStudio, and all R packages"
echo "⚠️  You will be prompted for your admin password to remove system files"
echo ""

echo "🔧 Starting uninstallation process..."
echo ""

# Function to remove items with feedback
remove_item() {
    local item="$1"
    local description="$2"
    
    if [ -e "$item" ]; then
        echo "   Removing $description..."
        sudo rm -rf "$item" 2>/dev/null || true
        if [ -e "$item" ]; then
            echo "   ⚠️  Could not remove: $description"
        else
            echo "   ✅ Removed: $description"
        fi
    fi
}

# 1. Remove RStudio
echo "Step 1: Removing RStudio..."
if [ -d "/Applications/RStudio.app" ]; then
    # Kill RStudio if running
    pkill -f RStudio 2>/dev/null
    
    # Remove app
    remove_item "/Applications/RStudio.app" "RStudio application"
    
    # Remove RStudio preferences and support files
    remove_item "$HOME/Library/Preferences/com.rstudio.*" "RStudio preferences"
    remove_item "$HOME/Library/Application Support/RStudio" "RStudio support files"
    remove_item "$HOME/Library/Saved Application State/com.rstudio.desktop.savedState" "RStudio saved state"
    remove_item "$HOME/.rstudio-desktop" "RStudio desktop settings"
    remove_item "$HOME/.config/rstudio" "RStudio config"
    
    echo "✅ RStudio removed"
else
    echo "   RStudio not found"
fi
echo ""

# 2. Remove R
echo "Step 2: Removing R..."

# Kill any R processes
pkill -f "/Library/Frameworks/R.framework" 2>/dev/null
pkill -f "/usr/local/bin/R" 2>/dev/null

# Remove R framework
remove_item "/Library/Frameworks/R.framework" "R framework"

# Remove R from /usr/local/bin
remove_item "/usr/local/bin/R" "R binary symlink"
remove_item "/usr/local/bin/Rscript" "Rscript symlink"

# Remove R GUI if present
remove_item "/Applications/R.app" "R GUI application"

# Remove R receipts
echo "   Removing installation receipts..."
sudo pkgutil --forget org.r-project.R.fw.pkg 2>/dev/null
sudo pkgutil --forget org.r-project.R.GUI.pkg 2>/dev/null
sudo pkgutil --forget org.r-project.arm64 2>/dev/null
sudo pkgutil --forget org.r-project.x86_64 2>/dev/null

echo "✅ R removed"
echo ""

# 3. Remove R packages and libraries
echo "Step 3: Removing R packages and libraries..."

# Remove user R libraries
remove_item "$HOME/Library/R" "user R libraries"
remove_item "$HOME/.Rprofile" "R profile"
remove_item "$HOME/.Rhistory" "R history"
remove_item "$HOME/.RData" "R data files"
remove_item "$HOME/.Renviron" "R environment settings"
remove_item "$HOME/.Rapp.history" "R app history"

# Remove system-wide R libraries
remove_item "/Library/Application Support/R" "system R libraries"

echo "✅ R packages and libraries removed"
echo ""

# 4. Remove TinyTeX
echo "Step 4: Removing TinyTeX..."

# Check if TinyTeX is installed
if command -v tlmgr &> /dev/null; then
    # Try to uninstall TinyTeX using R's tinytex uninstaller if available
    if [ -f "$HOME/Library/TinyTeX/bin/*/tlmgr" ]; then
        echo "   Removing TinyTeX installation..."
        remove_item "$HOME/Library/TinyTeX" "TinyTeX"
        
        # Remove TinyTeX from PATH
        if [ -f "$HOME/.zshrc" ]; then
            sed -i '' '/TinyTeX/d' "$HOME/.zshrc"
        fi
        if [ -f "$HOME/.bash_profile" ]; then
            sed -i '' '/TinyTeX/d' "$HOME/.bash_profile"
        fi
        if [ -f "$HOME/.profile" ]; then
            sed -i '' '/TinyTeX/d' "$HOME/.profile"
        fi
        
        echo "✅ TinyTeX removed"
    fi
else
    echo "   TinyTeX not found"
fi
echo ""

# 5. Remove PhantomJS (used by webshot package)
echo "Step 5: Removing PhantomJS..."
if [ -f "$HOME/Library/Application Support/PhantomJS/phantomjs" ]; then
    remove_item "$HOME/Library/Application Support/PhantomJS" "PhantomJS"
    echo "✅ PhantomJS removed"
else
    echo "   PhantomJS not found"
fi
echo ""

# 6. Clean up PATH environment
echo "Step 6: Cleaning up environment..."

# Remove R-related entries from PATH in shell config files
for config_file in "$HOME/.zshrc" "$HOME/.bash_profile" "$HOME/.profile"; do
    if [ -f "$config_file" ]; then
        # Backup the file
        cp "$config_file" "$config_file.backup"
        
        # Remove R-related PATH entries
        sed -i '' '/\/Library\/Frameworks\/R\.framework/d' "$config_file"
        sed -i '' '/\/usr\/local\/bin\/R/d' "$config_file"
        
        echo "   Cleaned $config_file"
    fi
done

echo "✅ Environment cleaned"
echo ""

# 7. Final cleanup
echo "Step 7: Final cleanup..."

# Clear R package cache
remove_item "$HOME/.R" "R package cache"

# Clear any temporary R files
remove_item "/tmp/Rtmp*" "R temporary files"
remove_item "$TMPDIR/Rtmp*" "R temporary files in TMPDIR"

echo "✅ Final cleanup complete"
echo ""

# Summary
echo "🎉 Uninstallation Complete!"
echo "=========================="
echo ""
echo "✅ RStudio removed"
echo "✅ R removed" 
echo "✅ R packages and libraries removed"
echo "✅ TinyTeX removed (if installed)"
echo "✅ PhantomJS removed (if installed)"
echo "✅ Environment variables cleaned"
echo ""
echo "📋 Notes:"
echo "   • Configuration file backups created with .backup extension"
echo "   • You may need to restart your terminal for PATH changes to take effect"
echo "   • Some hidden files may remain in your home directory"
echo ""
echo "To reinstall Radiant, run:"
echo "curl -sSL https://raw.githubusercontent.com/vnijs/radiant_install/main/macos-install-radiant.sh | bash"
echo ""