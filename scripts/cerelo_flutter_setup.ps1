#!/usr/bin/env pwsh
# Post-Flutter-Install Setup Script for Cerelo
# Run this once Flutter is installed and on PATH

param(
    [string]$FlutterPath = "C:\flutter",
    [string]$AndroidSdkPath = "$env:LOCALAPPDATA\Android\Sdk",
    [string]$JavaHome = "C:\Program Files\Java\jdk-17"
)

$env:PATH = "$FlutterPath\bin;$env:PATH"
$env:ANDROID_HOME = $AndroidSdkPath
$env:ANDROID_SDK_ROOT = $AndroidSdkPath
$env:JAVA_HOME = $JavaHome
$env:PATH = "$JavaHome\bin;$env:PATH"

Write-Host "=== CERELO PHASE 1: Flutter Doctor ===" -ForegroundColor Cyan
flutter doctor -v

Write-Host "`n=== CERELO PHASE 2: Android Licenses ===" -ForegroundColor Cyan
echo "y`ny`ny`ny`ny`ny`ny" | flutter doctor --android-licenses

Write-Host "`n=== CERELO PHASE 3: Scaffold Android Platforms ===" -ForegroundColor Cyan
Set-Location "c:\Users\User\Desktop\cerelo\apps\customer_app"
flutter create --org com.cerelo --project-name customer_app --platforms android --overwrite .
Write-Host "customer_app Android scaffolded" -ForegroundColor Green

Set-Location "c:\Users\User\Desktop\cerelo\apps\personnel_app"
flutter create --org com.cerelo --project-name personnel_app --platforms android --overwrite .
Write-Host "personnel_app Android scaffolded" -ForegroundColor Green

Write-Host "`n=== CERELO PHASE 4: pub get (all packages) ===" -ForegroundColor Cyan
$packages = @(
    "c:\Users\User\Desktop\cerelo\packages\cerelo_core",
    "c:\Users\User\Desktop\cerelo\packages\cerelo_api",
    "c:\Users\User\Desktop\cerelo\packages\cerelo_ui",
    "c:\Users\User\Desktop\cerelo\apps\customer_app",
    "c:\Users\User\Desktop\cerelo\apps\personnel_app"
)
foreach ($pkg in $packages) {
    Set-Location $pkg
    Write-Host "pub get: $pkg" -ForegroundColor Yellow
    flutter pub get
}

Write-Host "`n=== CERELO PHASE 5: flutter analyze ===" -ForegroundColor Cyan
foreach ($pkg in $packages) {
    Set-Location $pkg
    Write-Host "analyze: $pkg" -ForegroundColor Yellow
    flutter analyze
}

Write-Host "`n=== CERELO PHASE 6: flutter test (packages only) ===" -ForegroundColor Cyan
$testPkgs = @(
    "c:\Users\User\Desktop\cerelo\packages\cerelo_core",
    "c:\Users\User\Desktop\cerelo\packages\cerelo_api"
)
foreach ($pkg in $testPkgs) {
    Set-Location $pkg
    Write-Host "test: $pkg" -ForegroundColor Yellow
    flutter test
}

Write-Host "`n=== ALL PHASES COMPLETE ===" -ForegroundColor Green
