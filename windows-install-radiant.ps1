# Radiant Installation Script for Windows
# Rady @ UCSD - Automated installer for R, RStudio, and Radiant packages on Windows

# Require Administrator privileges
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires Administrator privileges. Restarting as Administrator..." -ForegroundColor Yellow
    # Add -NoExit to keep the admin window open
    Start-Process powershell.exe "-NoExit -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Rady @ UCSD Radiant Installer for Windows" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Set error action preference
$ErrorActionPreference = "Stop"

# Create temp directory
$TEMP_DIR = New-TemporaryFile | ForEach-Object { Remove-Item $_; New-Item -ItemType Directory -Path $_ }
Set-Location $TEMP_DIR
Write-Host "Working in temporary directory: $TEMP_DIR" -ForegroundColor Gray
Write-Host ""

# Function to check success
function Check-Success {
    param($Message)
    if ($LASTEXITCODE -eq 0 -or $?) {
        Write-Host "[OK] $Message successful" -ForegroundColor Green
    } else {
        Write-Host "[ERROR] $Message failed" -ForegroundColor Red
        exit 1
    }
}

# Get system drive (usually C:)
$SystemDrive = $env:SystemDrive

# Check and Install R
Write-Host "Step 1: Checking R installation..." -ForegroundColor Yellow

# Get current R version if installed
$CurrentRVersion = $null
$RPath = "$SystemDrive\R\R-*\bin\R.exe"
$RInProgramFiles = $false

# Check if R is in Program Files (bad location)
if (Test-Path "$env:ProgramFiles\R\R-*\bin\R.exe") {
    $RInProgramFiles = $true
    Write-Host "[WARNING] R is installed in Program Files - this can cause problems!" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   R works best when installed in $SystemDrive\R instead of Program Files." -ForegroundColor Gray
    Write-Host "   This avoids permission issues with package installation." -ForegroundColor Gray
    Write-Host ""

    # Ask about R experience (auto-answer N in CI)
    $response = ""
    if ($env:CI -eq "true") {
        $response = "N"
        Write-Host "   CI Mode: Auto-answering 'N' to reinstall R in correct location" -ForegroundColor Gray
    } else {
        while ($response -notmatch "^[YyNn]$") {
            $response = Read-Host "   Have you used R successfully from this location before? (Y/N)"
        }
    }

    if ($response -match "^[Yy]$") {
        Write-Host "   Proceeding with existing R installation..." -ForegroundColor Gray
        $RInProgramFiles = $false  # User says it works, so don't force reinstall

        # Try to get version from Program Files location
        $RProgramFilesPath = Get-ChildItem "$env:ProgramFiles\R\R-*\bin\R.exe" | Select-Object -First 1
        if ($RProgramFilesPath) {
            # Use cmd to avoid PowerShell treating stderr as error
            $VersionOutput = cmd /c "`"$($RProgramFilesPath.FullName)`" --version 2>&1"
            # Join array output to string
            $VersionString = $VersionOutput -join " "
            if ($VersionString -match "R version (\d+\.\d+\.\d+)") {
                $CurrentRVersion = $matches[1]
                Write-Host "   Current R version: $CurrentRVersion (in Program Files)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "   R should be reinstalled in $SystemDrive\R for best results" -ForegroundColor Yellow
    }
}

# Check for R in correct location
if (Test-Path $RPath) {
    $RExe = Get-ChildItem $RPath | Select-Object -First 1
    if ($RExe) {
        # Use cmd to avoid PowerShell treating stderr as error
        $VersionOutput = cmd /c "`"$($RExe.FullName)`" --version 2>&1"
        # Join array output to string
        $VersionString = $VersionOutput -join " "
        if ($VersionString -match "R version (\d+\.\d+\.\d+)") {
            $CurrentRVersion = $matches[1]
            Write-Host "   Current R version: $CurrentRVersion (in $SystemDrive\R)" -ForegroundColor Gray
        }
    }
}

# Get latest R version from CRAN
Write-Host "   Checking latest R version from CRAN..." -ForegroundColor Gray
$ReleasePage = Invoke-WebRequest -Uri "https://cloud.r-project.org/bin/windows/base/release.html" -UseBasicParsing
$RURL = $null
$LatestRVersion = $null

# The release.html page redirects to the actual installer
# We need to get the redirect URL
try {
    $Response = Invoke-WebRequest -Uri "https://cloud.r-project.org/bin/windows/base/release.html" -MaximumRedirection 0 -ErrorAction SilentlyContinue
} catch {
    if ($_.Exception.Response.StatusCode -eq 302) {
        $RURL = $_.Exception.Response.Headers.Location.ToString()
        Write-Host "Redirect URL: $RURL"
        if ($RURL -match "R-(\d+\.\d+\.\d+)-win.exe") {
            $LatestRVersion = $matches[1]
            Write-Host "   Latest R version: $LatestRVersion" -ForegroundColor Gray
        }
    }
}

# Fallback if redirect didn't work
if (-not $RURL) {
    $CRANPage = Invoke-WebRequest -Uri "https://cloud.r-project.org/bin/windows/base/" -UseBasicParsing
    if ($CRANPage.Content -match 'href="(R-\d+\.\d+\.\d+-win.exe)"') {
        $RURL = "https://cloud.r-project.org/bin/windows/base/$($matches[1])"
        if ($matches[1] -match "R-(\d+\.\d+\.\d+)-win.exe") {
            $LatestRVersion = $matches[1]
            Write-Host "   Latest R version: $LatestRVersion" -ForegroundColor Gray
        }
    }
}

if ($CurrentRVersion -eq $LatestRVersion -and -not $RInProgramFiles) {
    Write-Host "[OK] R is already up to date (version $CurrentRVersion)" -ForegroundColor Green
} else {
    if ($RInProgramFiles) {
        Write-Host "   R needs to be reinstalled in the correct location" -ForegroundColor Yellow
        Write-Host "   Please uninstall R from Program Files first, then re-run this script" -ForegroundColor Red
        Write-Host ""
        Write-Host "   To uninstall R:" -ForegroundColor Yellow
        Write-Host "   1. Open Control Panel -> Programs -> Uninstall a program" -ForegroundColor Gray
        Write-Host "   2. Find R for Windows and uninstall it" -ForegroundColor Gray
        Write-Host "   3. Delete the folder: $env:USERPROFILE\Documents\R (if it exists)" -ForegroundColor Gray
        Write-Host "   4. Re-run this installer script" -ForegroundColor Gray
        Read-Host "Press Enter to exit"
        exit 1
    }

    if ($CurrentRVersion) {
        Write-Host "   R update available: $CurrentRVersion -> $LatestRVersion" -ForegroundColor Yellow
    }

    Write-Host "   Downloading R installer from CRAN..." -ForegroundColor Gray
    if (-not $RURL) {
        Write-Host "[ERROR] Could not determine R download URL" -ForegroundColor Red
        exit 1
    }
    Invoke-WebRequest -Uri $RURL -OutFile "R-installer.exe"
    Check-Success "R download"

    Write-Host "   Installing R to $SystemDrive\R..." -ForegroundColor Gray
    # Silent install with custom directory
    Start-Process -FilePath "R-installer.exe" -ArgumentList "/VERYSILENT /DIR=`"$SystemDrive\R\R-$LatestRVersion`"" -Wait
    Check-Success "R installation"

    # Add R to PATH if not already there
    $RBinPath = "$SystemDrive\R\R-$LatestRVersion\bin\x64"
    $CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($CurrentPath -notlike "*$RBinPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$RBinPath", "Machine")
        $env:Path = "$env:Path;$RBinPath"
        Write-Host "   Added R to system PATH" -ForegroundColor Gray
    }
}
Write-Host ""

# Check and Install RStudio
Write-Host "Step 2: Checking RStudio installation..." -ForegroundColor Yellow

# Get current RStudio version if installed
$CurrentRStudioVersion = $null
$RStudioExePath = "${env:ProgramFiles}\RStudio\rstudio.exe"
if (Test-Path $RStudioExePath) {
    $VersionInfo = (Get-Item $RStudioExePath).VersionInfo
    if ($VersionInfo.ProductVersion) {
        $CurrentRStudioVersion = $VersionInfo.ProductVersion
        Write-Host "   Current RStudio version: $CurrentRStudioVersion" -ForegroundColor Gray
    }
}

# Get latest RStudio version from Posit
Write-Host "   Checking latest RStudio version from Posit..." -ForegroundColor Gray
$RStudioPage = Invoke-WebRequest -Uri "https://posit.co/download/rstudio-desktop/" -UseBasicParsing
$pattern = '//download1\.rstudio\.org/electron/windows/RStudio-([\d\.]+)-(\d+)\.exe'
if ($RStudioPage.Content -match $pattern) {
    $RStudioURL = "https://download1.rstudio.org/electron/windows/RStudio-$($matches[1])-$($matches[2]).exe"
    # Build version string from pattern match
    $LatestRStudioVersion = "$($matches[1])+$($matches[2])"
    Write-Host "   Latest RStudio version: $LatestRStudioVersion" -ForegroundColor Gray
}

if ($CurrentRStudioVersion -and $LatestRStudioVersion -and ($CurrentRStudioVersion -eq $LatestRStudioVersion)) {
    Write-Host "[OK] RStudio is already up to date (version $CurrentRStudioVersion)" -ForegroundColor Green
} else {
    if (-not $LatestRStudioVersion) {
        Write-Host "[ERROR] Could not determine latest RStudio version" -ForegroundColor Red
        exit 1
    }
    
    if ($CurrentRStudioVersion) {
        Write-Host "   RStudio update available: $CurrentRStudioVersion -> $LatestRStudioVersion" -ForegroundColor Yellow
    } else {
        Write-Host "   RStudio not installed, will install version $LatestRStudioVersion" -ForegroundColor Yellow
    }

    Write-Host "   Downloading RStudio from Posit..." -ForegroundColor Gray
    if (-not $RStudioURL) {
        Write-Host "[ERROR] Could not determine RStudio download URL" -ForegroundColor Red
        exit 1
    }
    Invoke-WebRequest -Uri $RStudioURL -OutFile "RStudio-installer.exe"
    Check-Success "RStudio download"

    Write-Host "   Installing RStudio..." -ForegroundColor Gray
    Start-Process -FilePath "RStudio-installer.exe" -ArgumentList "/S" -Wait
    Check-Success "RStudio installation"
}
Write-Host ""

# Check and Install 7-Zip
Write-Host "Step 3: Checking 7-Zip installation..." -ForegroundColor Yellow

$7ZipInstalled = $false
$7ZipPaths = @(
    "${env:ProgramFiles}\7-Zip\7z.exe",
    "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
)

foreach ($path in $7ZipPaths) {
    if (Test-Path $path) {
        $7ZipInstalled = $true
        Write-Host "[OK] 7-Zip is already installed" -ForegroundColor Green
        break
    }
}

if (-not $7ZipInstalled) {
    Write-Host "   Downloading 7-Zip..." -ForegroundColor Gray
    $7ZipURL = "https://www.7-zip.org/a/7z2501-x64.exe"
    Invoke-WebRequest -Uri $7ZipURL -OutFile "7zip-installer.exe"
    Check-Success "7-Zip download"

    Write-Host "   Installing 7-Zip..." -ForegroundColor Gray
    Start-Process -FilePath "7zip-installer.exe" -ArgumentList "/S" -Wait
    Check-Success "7-Zip installation"

    # Add 7-Zip to PATH
    if (Test-Path "${env:ProgramFiles}\7-Zip") {
        $7ZipPath = "${env:ProgramFiles}\7-Zip"
    } else {
        $7ZipPath = "${env:ProgramFiles(x86)}\7-Zip"
    }

    $CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($CurrentPath -notlike "*$7ZipPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$7ZipPath", "Machine")
        $env:Path = "$env:Path;$7ZipPath"
        Write-Host "   Added 7-Zip to system PATH" -ForegroundColor Gray
    }
}
Write-Host ""

# Install R packages
Write-Host "Step 4: Installing Radiant and R packages..." -ForegroundColor Yellow
Write-Host "   This may take several minutes..." -ForegroundColor Gray

# Download R script for package installation
Write-Host "   Downloading package installation script..." -ForegroundColor Gray
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/vnijs/radiant_install/main/install_packages.R" -OutFile "install_packages.R"
Check-Success "Download package script"

# Find R executable
$RExePath = Get-ChildItem "$SystemDrive\R\R-*\bin\R.exe" | Select-Object -First 1
if ($RExePath) {
    & $RExePath.FullName --slave --no-restore --file=install_packages.R
    Check-Success "R packages installation"
} else {
    Write-Host "[ERROR] Could not find R executable" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Install TinyTeX
Write-Host "Step 5: Installing TinyTeX for PDF reports..." -ForegroundColor Yellow
Write-Host "   This enables PDF generation in Radiant reports..." -ForegroundColor Gray

# Download R script for TinyTeX installation
Write-Host "   Downloading TinyTeX installation script..." -ForegroundColor Gray
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/vnijs/radiant_install/main/install_tinytex.R" -OutFile "install_tinytex.R"
Check-Success "Download TinyTeX script"

& $RExePath.FullName --slave --no-restore --file=install_tinytex.R
Check-Success "TinyTeX installation"
Write-Host ""

# Cleanup
Set-Location $env:TEMP
Remove-Item -Path $TEMP_DIR -Recurse -Force
Write-Host "Cleaned up temporary files" -ForegroundColor Gray
Write-Host ""

# Final instructions
Write-Host "Installation Complete!" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host ""

# Pause at the end so user can see results
if ($env:CI -ne "true") {
    Write-Host ""
    Write-Host "Press Enter to close this window..." -ForegroundColor Yellow
    Read-Host
}