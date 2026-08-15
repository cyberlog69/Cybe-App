# Cybe BitMesh Relay Launcher (PowerShell / Windows)
param (
    [string]$Alias = "CybeRelay-$env:COMPUTERNAME",
    [int]$Port = 42101,
    [string]$AnalyzeDir = "..\..",
    [string]$Repo = "cyberlog69/Cybe-App",
    [int]$Interval = 15,
    [switch]$Daemon
)

Write-Host "Checking Dart SDK..." -ForegroundColor Cyan
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
    Write-Host "Error: Dart SDK not found on PATH. Please ensure Flutter/Dart SDK is installed." -ForegroundColor Red
    exit 1
}

Push-Location $PSScriptRoot
try {
    Write-Host "Getting dependencies..." -ForegroundColor DarkGray
    dart pub get | Out-Null

    $argsList = @(
        "run", "bin/cybe_relay.dart",
        "--alias", $Alias,
        "--port", "$Port",
        "--analyze-dir", $AnalyzeDir,
        "--github-repo", $Repo,
        "--interval", "$Interval"
    )

    if ($Daemon) {
        $argsList += "--daemon"
    }

    Write-Host "Launching Cybe BitMesh Relay Node..." -ForegroundColor Green
    & dart $argsList
} finally {
    Pop-Location
}
