# Cybe Security App — Flutter Setup Script
# Run this script in PowerShell after cloning completes

$FlutterBat = "$env:USERPROFILE\flutter\bin\flutter.bat"
$ProjectDir = "c:\Users\IN11867\Documents\Praveen\Projects\Cybe App"

Write-Host "=== Cybe App Setup ===" -ForegroundColor Cyan

# 1. Check Flutter
if (-not (Test-Path $FlutterBat)) {
    Write-Host "ERROR: Flutter not found at $FlutterBat" -ForegroundColor Red
    Write-Host "Please run: git clone https://github.com/flutter/flutter.git -b stable --depth 1 `"$env:USERPROFILE\flutter`""
    exit 1
}

Write-Host "Flutter found at: $FlutterBat" -ForegroundColor Green

# 2. Create Flutter project scaffold (keeps existing lib/ files)
Write-Host "`nCreating Flutter project scaffold..." -ForegroundColor Yellow
Set-Location $ProjectDir
& $FlutterBat create --org com.cybe --project-name cybe_app --platforms android,ios .

# 3. Create required asset directories
Write-Host "`nCreating asset directories..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "$ProjectDir\assets\animations" | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectDir\assets\images" | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectDir\assets\icons" | Out-Null
New-Item -ItemType Directory -Force -Path "$ProjectDir\assets\fonts" | Out-Null

# 4. Run flutter pub get
Write-Host "`nInstalling dependencies..." -ForegroundColor Yellow
& $FlutterBat pub get

# 5. Verify setup
Write-Host "`nRunning flutter doctor..." -ForegroundColor Yellow
& $FlutterBat doctor

Write-Host "`n=== Setup Complete! ===" -ForegroundColor Green
Write-Host "To run the app:" -ForegroundColor Cyan
Write-Host "  & '$FlutterBat' run"
Write-Host "To run on specific device:"
Write-Host "  & '$FlutterBat' devices   # list devices"
Write-Host "  & '$FlutterBat' run -d <device-id>"
