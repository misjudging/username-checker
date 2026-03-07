Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$dist = Join-Path $root "dist"
$scriptSource = Join-Path $root "username_checker.ps1"
$scriptDest = Join-Path $dist "username_checker.ps1"
$launcherDest = Join-Path $dist "username_checker.cmd"

if (-not (Test-Path -LiteralPath $scriptSource -PathType Leaf)) {
    throw "Missing source script: $scriptSource"
}

if (Test-Path -LiteralPath $dist) {
    Remove-Item -LiteralPath $dist -Recurse -Force
}

New-Item -ItemType Directory -Path $dist | Out-Null
Copy-Item -LiteralPath $scriptSource -Destination $scriptDest -Force

$launcher = @"
@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%username_checker.ps1" %*
exit /b %ERRORLEVEL%
"@

Set-Content -LiteralPath $launcherDest -Value $launcher -Encoding ASCII

Write-Host "Build complete."
Write-Host "Output:"
Write-Host " - $scriptDest"
Write-Host " - $launcherDest"
