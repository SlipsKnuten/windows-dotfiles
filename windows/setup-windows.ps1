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
#   4. Merges terminal.json (theme, font, colors) into Windows Terminal's
#      settings.json, leaving your profiles and other settings alone.
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

# Copies every key in $patch onto $target, recursing into objects. Color
# schemes and themes are lists, so those are replaced by name instead.
function Merge-Settings($target, $patch) {
  foreach ($p in $patch.PSObject.Properties) {
    $cur = $target.PSObject.Properties[$p.Name]
    if ($cur -and $cur.Value -is [PSCustomObject] -and $p.Value -is [PSCustomObject]) {
      Merge-Settings $cur.Value $p.Value
    } elseif ($cur -and $p.Name -in "schemes", "themes") {
      $names = @($p.Value | ForEach-Object { $_.name })
      $target.($p.Name) = @($cur.Value | Where-Object { $_.name -notin $names }) + @($p.Value)
    } else {
      $target | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
    }
  }
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

# --- 4. Windows Terminal ----------------------------------------------------
Step "Windows Terminal"
$utf8 = New-Object Text.UTF8Encoding $false # WT's file has no BOM; keep it that way
$wtFiles = @(
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
  "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
) | Where-Object { Test-Path $_ }

if (-not $wtFiles) {
  Note "settings.json not found. Open Windows Terminal once, then run this again."
}
foreach ($file in $wtFiles) {
  $patch = [IO.File]::ReadAllText((Join-Path $repo "terminal.json")) | ConvertFrom-Json
  # Windows PowerShell 5.1 can't parse comments, so drop whole-line // comments.
  $settings = ([IO.File]::ReadAllText($file) -replace '(?m)^\s*//.*$', '') | ConvertFrom-Json
  Merge-Settings $settings $patch
  Copy-Item $file "$file.bak" -Force
  [IO.File]::WriteAllText($file, ($settings | ConvertTo-Json -Depth 32), $utf8)
  Note "Updated $file (old version saved as settings.json.bak)"
}

Write-Host "`nDone." -ForegroundColor Green
