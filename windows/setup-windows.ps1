#Requires -Version 5.1
# ============================================================================
# setup-windows.ps1 — set up the Windows side of windows-dotfiles
#
# Run it from a normal (not admin) Windows PowerShell — see README for why:
#   Set-Location \\wsl.localhost\Ubuntu\home\pepw\windows-dotfiles\windows; & ([scriptblock]::Create((Get-Content .\setup-windows.ps1 -Raw)))
#
# What it does (safe to run again, e.g. after a git pull):
#   1. Copies .wezterm.lua and kanata.kbd into your Windows user profile.
#   2. Downloads kanata (checksum-verified), installs it to ~\bin\kanata.exe,
#      checks the config and (re)starts it.
#   3. Adds a Startup shortcut so kanata runs on login.
# ============================================================================

param(
  # kanata release to install. Bump this to upgrade on every machine.
  [string]$KanataVersion = "v1.12.0"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue" # Invoke-WebRequest is very slow with the progress bar on

# Empty when the script is loaded as text (see README); then use the current folder.
$repo = if ($PSScriptRoot) { $PSScriptRoot } else { $PWD.ProviderPath }
$startup = [Environment]::GetFolderPath("Startup")
$kanataExe = "$HOME\bin\kanata.exe"
# Where kanata looks by default, so kanata.exe also works when opened directly.
$kanataCfg = "$env:APPDATA\kanata\kanata.kbd"

function Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
function Note($text) { Write-Host "   $text" }

function Copy-Config($from, $to) {
  New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
  Copy-Item (Join-Path $repo $from) $to -Force
  Note "$from -> $to"
}

function New-StartupShortcut($name, $target, $arguments, $workDir) {
  $lnk = (New-Object -ComObject WScript.Shell).CreateShortcut("$startup\$name.lnk")
  $lnk.TargetPath = $target
  $lnk.Arguments = $arguments
  $lnk.WorkingDirectory = $workDir
  $lnk.Save()
  Note "Startup shortcut: $name.lnk"
}

# --- 1. Config files ---------------------------------------------------------
Step "Copying config files"
Copy-Config ".wezterm.lua" "$HOME\.wezterm.lua"
Copy-Config "kanata.kbd" $kanataCfg

# --- 2. kanata ---------------------------------------------------------------
Step "kanata $KanataVersion"
$versionFile = "$HOME\bin\kanata.version"
$installed = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() }

if ((Test-Path $kanataExe) -and $installed -eq $KanataVersion) {
  Note "Already installed: $kanataExe"
} else {
  $base = "https://github.com/jtroo/kanata/releases/download/$KanataVersion"
  $tmp = Join-Path ([IO.Path]::GetTempPath()) "kanata-$([guid]::NewGuid())"
  New-Item -ItemType Directory $tmp | Out-Null
  try {
    Note "Downloading windows-binaries-x64.zip"
    Invoke-WebRequest "$base/windows-binaries-x64.zip" -OutFile "$tmp\kanata.zip" -UseBasicParsing
    Invoke-WebRequest "$base/sha256sums" -OutFile "$tmp\sha256sums" -UseBasicParsing

    $line = Get-Content "$tmp\sha256sums" | Where-Object { $_ -match '\swindows-binaries-x64\.zip$' }
    $expected = ($line -split '\s+')[0]
    $actual = (Get-FileHash "$tmp\kanata.zip" -Algorithm SHA256).Hash
    if (-not $expected -or $actual -ne $expected) {
      throw "Checksum mismatch for windows-binaries-x64.zip (expected '$expected', got '$actual')"
    }
    Note "Checksum OK"

    # The tray-icon build: no console window, and no driver to install.
    Expand-Archive "$tmp\kanata.zip" "$tmp\unzipped" -Force
    Get-Process kanata -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
    New-Item -ItemType Directory -Force "$HOME\bin" | Out-Null
    Copy-Item "$tmp\unzipped\kanata_windows_gui_winIOv2_x64.exe" $kanataExe -Force
    Set-Content $versionFile $KanataVersion
    Note "Installed: $kanataExe"
  } finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$check = Start-Process $kanataExe -ArgumentList "--check", "-c", "`"$kanataCfg`"" -Wait -PassThru -WindowStyle Hidden
if ($check.ExitCode -ne 0) {
  throw "kanata says $kanataCfg is invalid. Run '$kanataExe --check -c $kanataCfg' to see why."
}
Note "Config OK"

New-StartupShortcut "kanata" $kanataExe "-c `"$kanataCfg`"" "$HOME\bin"

# Restart so a changed config takes effect. Launch through Explorer (like a
# double-click): started straight from here, kanata attaches to this console
# and dies when the terminal is closed.
Get-Process kanata -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 1
Start-Process explorer.exe "`"$startup\kanata.lnk`""
Note "kanata started (emergency exit: Left Ctrl + Space + Esc)"

Write-Host "`nDone." -ForegroundColor Green
