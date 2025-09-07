# Radiant Uninstall Script for Windows
# This script removes R, RStudio, and all associated files

# Require Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Restarting as Administrator..." -ForegroundColor Yellow
    Start-Process powershell.exe "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Rady School of Management @ UCSD" -ForegroundColor Cyan
Write-Host "Radiant-for-R Uninstaller for Windows" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "WARNING: This will completely remove R, RStudio, and all R packages" -ForegroundColor Red
Write-Host ""

# Ask for confirmation
$confirmation = Read-Host "Are you sure you want to uninstall? Type 'yes' to confirm"
if ($confirmation -ne 'yes') {
    Write-Host "Uninstall cancelled." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "Starting uninstallation process..." -ForegroundColor Yellow
Write-Host ""

# Set error action preference
$ErrorActionPreference = "SilentlyContinue"

# Get system drive
$SystemDrive = $env:SystemDrive

# Function to remove items with feedback
function Remove-ItemSafely {
    param(
        [string]$Path,
        [string]$Description
    )
    
    if (Test-Path $Path) {
        Write-Host "   Removing $Description..." -ForegroundColor Gray
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Host "   [OK] Removed: $Description" -ForegroundColor Green
        } catch {
            Write-Host "   [WARNING] Could not remove: $Description" -ForegroundColor Yellow
        }
    }
}

# 1. Stop any running R or RStudio processes
Write-Host "Step 1: Stopping R and RStudio processes..." -ForegroundColor Yellow

# Stop RStudio
Get-Process rstudio -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process rsession -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process rsession-utf8 -ErrorAction SilentlyContinue | Stop-Process -Force

# Stop R
Get-Process Rgui -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process Rterm -ErrorAction SilentlyContinue | Stop-Process -Force
Get-Process R -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "[OK] Processes stopped" -ForegroundColor Green
Write-Host ""

# 2. Uninstall RStudio
Write-Host "Step 2: Removing RStudio..." -ForegroundColor Yellow

# Check for RStudio uninstaller in multiple locations
$RStudioUninstallers = @(
    "${env:ProgramFiles}\RStudio\Uninstall.exe",
    "${env:ProgramFiles(x86)}\RStudio\Uninstall.exe",
    "${env:LocalAppData}\Programs\RStudio\Uninstall.exe"
)

$foundUninstaller = $false
foreach ($uninstaller in $RStudioUninstallers) {
    if (Test-Path $uninstaller) {
        Write-Host "   Running RStudio uninstaller..." -ForegroundColor Gray
        Start-Process -FilePath $uninstaller -ArgumentList "/S" -Wait
        $foundUninstaller = $true
        break
    }
}

if (-not $foundUninstaller) {
    # Manual removal if uninstaller not found
    Write-Host "   No uninstaller found, removing manually..." -ForegroundColor Yellow
    Remove-ItemSafely "${env:ProgramFiles}\RStudio" "RStudio program files"
    Remove-ItemSafely "${env:ProgramFiles(x86)}\RStudio" "RStudio program files (x86)"
    Remove-ItemSafely "${env:LocalAppData}\Programs\RStudio" "RStudio local installation"
}

# Remove RStudio user data
Remove-ItemSafely "$env:APPDATA\RStudio" "RStudio user data"
Remove-ItemSafely "$env:LOCALAPPDATA\RStudio" "RStudio local data"
Remove-ItemSafely "$env:LOCALAPPDATA\RStudio-Desktop" "RStudio desktop data"

# Remove RStudio from Start Menu
Remove-ItemSafely "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\RStudio" "RStudio Start Menu shortcuts"
Remove-ItemSafely "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\RStudio" "RStudio user Start Menu shortcuts"

Write-Host "[OK] RStudio removed" -ForegroundColor Green
Write-Host ""

# 3. Uninstall R
Write-Host "Step 3: Removing R..." -ForegroundColor Yellow

# Look for R installations
$RInstallations = @()

# Check in C:\R
if (Test-Path "$SystemDrive\R") {
    $RInstallations += Get-ChildItem "$SystemDrive\R" -Directory | Where-Object { $_.Name -like "R-*" }
}

# Check in Program Files
if (Test-Path "$env:ProgramFiles\R") {
    $RInstallations += Get-ChildItem "$env:ProgramFiles\R" -Directory | Where-Object { $_.Name -like "R-*" }
}

# Try to uninstall each R version found
foreach ($RDir in $RInstallations) {
    $uninstaller = Join-Path $RDir.FullName "unins000.exe"
    if (Test-Path $uninstaller) {
        Write-Host "   Uninstalling R from $($RDir.FullName)..." -ForegroundColor Gray
        Start-Process -FilePath $uninstaller -ArgumentList "/VERYSILENT" -Wait
    }
}

# Manual removal of R directories
Remove-ItemSafely "$SystemDrive\R" "R installation directory"
Remove-ItemSafely "$env:ProgramFiles\R" "R in Program Files"

# Remove R from PATH
Write-Host "   Removing R from system PATH..." -ForegroundColor Gray
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$NewPath = ($CurrentPath -split ';' | Where-Object { $_ -notlike "*\R\R-*" -and $_ -notlike "*\R-*\bin*" }) -join ';'
if ($CurrentPath -ne $NewPath) {
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "Machine")
    Write-Host "   [OK] R removed from PATH" -ForegroundColor Green
}

Write-Host "[OK] R removed" -ForegroundColor Green
Write-Host ""

# 4. Remove R packages and libraries
Write-Host "Step 4: Removing R packages and libraries..." -ForegroundColor Yellow

# Remove user R libraries
Remove-ItemSafely "$env:USERPROFILE\Documents\R" "user R libraries"
Remove-ItemSafely "$env:LOCALAPPDATA\R" "R local data"
Remove-ItemSafely "$env:USERPROFILE\.Rprofile" "R profile"
Remove-ItemSafely "$env:USERPROFILE\.Rhistory" "R history"
Remove-ItemSafely "$env:USERPROFILE\.RData" "R data files"
Remove-ItemSafely "$env:USERPROFILE\.Renviron" "R environment settings"

Write-Host "[OK] R packages and libraries removed" -ForegroundColor Green
Write-Host ""

# 5. Remove TinyTeX
Write-Host "Step 5: Removing TinyTeX..." -ForegroundColor Yellow

# Check common TinyTeX locations
$TinyTeXPaths = @(
    "$env:APPDATA\TinyTeX",
    "$env:USERPROFILE\AppData\Roaming\TinyTeX",
    "$env:ProgramData\TinyTeX"
)

$tinyTexFound = $false
foreach ($path in $TinyTeXPaths) {
    if (Test-Path $path) {
        Remove-ItemSafely $path "TinyTeX"
        $tinyTexFound = $true
    }
}

# Remove TinyTeX from PATH
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")
$NewPath = ($CurrentPath -split ';' | Where-Object { $_ -notlike "*TinyTeX*" }) -join ';'
if ($CurrentPath -ne $NewPath) {
    [Environment]::SetEnvironmentVariable("Path", $NewPath, "User")
    Write-Host "   [OK] TinyTeX removed from PATH" -ForegroundColor Green
}

if ($tinyTexFound) {
    Write-Host "[OK] TinyTeX removed" -ForegroundColor Green
} else {
    Write-Host "   TinyTeX not found" -ForegroundColor Gray
}
Write-Host ""

# 6. Remove PhantomJS
Write-Host "Step 6: Removing PhantomJS..." -ForegroundColor Yellow

$PhantomJSPath = "$env:LOCALAPPDATA\Programs\PhantomJS"
if (Test-Path $PhantomJSPath) {
    Remove-ItemSafely $PhantomJSPath "PhantomJS"
    Write-Host "[OK] PhantomJS removed" -ForegroundColor Green
} else {
    Write-Host "   PhantomJS not found" -ForegroundColor Gray
}
Write-Host ""

# 7. Remove 7-Zip (optional - ask user)
Write-Host "Step 7: 7-Zip..." -ForegroundColor Yellow
$remove7Zip = Read-Host "Do you want to remove 7-Zip as well? (yes/no)"
if ($remove7Zip -eq 'yes') {
    # Try uninstaller first
    $7ZipUninstallers = @(
        "${env:ProgramFiles}\7-Zip\Uninstall.exe",
        "${env:ProgramFiles(x86)}\7-Zip\Uninstall.exe"
    )
    
    $found7ZipUninstaller = $false
    foreach ($uninstaller in $7ZipUninstallers) {
        if (Test-Path $uninstaller) {
            Write-Host "   Running 7-Zip uninstaller..." -ForegroundColor Gray
            Start-Process -FilePath $uninstaller -ArgumentList "/S" -Wait
            $found7ZipUninstaller = $true
            break
        }
    }
    
    if (-not $found7ZipUninstaller) {
        Remove-ItemSafely "${env:ProgramFiles}\7-Zip" "7-Zip"
        Remove-ItemSafely "${env:ProgramFiles(x86)}\7-Zip" "7-Zip (x86)"
    }
    
    # Remove from PATH
    $CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $NewPath = ($CurrentPath -split ';' | Where-Object { $_ -notlike "*7-Zip*" }) -join ';'
    if ($CurrentPath -ne $NewPath) {
        [Environment]::SetEnvironmentVariable("Path", $NewPath, "Machine")
    }
    
    Write-Host "[OK] 7-Zip removed" -ForegroundColor Green
} else {
    Write-Host "   7-Zip kept" -ForegroundColor Gray
}
Write-Host ""

# 8. Clean registry (optional)
Write-Host "Step 8: Cleaning registry entries..." -ForegroundColor Yellow

# Remove R registry entries
$RRegistryPaths = @(
    "HKLM:\SOFTWARE\R-core",
    "HKCU:\Software\R-core",
    "HKLM:\SOFTWARE\WOW6432Node\R-core",
    "HKCU:\Software\RStudio"
)

foreach ($regPath in $RRegistryPaths) {
    if (Test-Path $regPath) {
        try {
            Remove-Item -Path $regPath -Recurse -Force
            Write-Host "   [OK] Removed registry: $regPath" -ForegroundColor Green
        } catch {
            Write-Host "   [WARNING] Could not remove registry: $regPath" -ForegroundColor Yellow
        }
    }
}

Write-Host "[OK] Registry cleaned" -ForegroundColor Green
Write-Host ""

# 9. Final cleanup
Write-Host "Step 9: Final cleanup..." -ForegroundColor Yellow

# Clear R temporary files
$tempPaths = @(
    "$env:TEMP\Rtmp*",
    "$env:TMP\Rtmp*",
    "$env:LOCALAPPDATA\Temp\Rtmp*"
)

foreach ($tempPath in $tempPaths) {
    Get-ChildItem -Path (Split-Path $tempPath) -Filter (Split-Path $tempPath -Leaf) -ErrorAction SilentlyContinue | 
        ForEach-Object { Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Host "[OK] Temporary files cleaned" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "Uninstallation Complete!" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host ""
Write-Host "[OK] RStudio removed" -ForegroundColor Green
Write-Host "[OK] R removed" -ForegroundColor Green
Write-Host "[OK] R packages and libraries removed" -ForegroundColor Green
Write-Host "[OK] TinyTeX removed (if installed)" -ForegroundColor Green
Write-Host "[OK] PhantomJS removed (if installed)" -ForegroundColor Green
Write-Host "[OK] Registry entries cleaned" -ForegroundColor Green
Write-Host ""
Write-Host "Notes:" -ForegroundColor Yellow
Write-Host "   - You may need to restart your computer for all changes to take effect" -ForegroundColor Gray
Write-Host "   - Some application data may remain in AppData folders" -ForegroundColor Gray
Write-Host ""
Write-Host "To reinstall Radiant, run:" -ForegroundColor Cyan
Write-Host "iwr -useb https://raw.githubusercontent.com/vnijs/radiant_install/main/windows-install-radiant.ps1 | iex" -ForegroundColor Gray
Write-Host ""

# Pause before closing
Write-Host "Press Enter to close this window..." -ForegroundColor Yellow
Read-Host