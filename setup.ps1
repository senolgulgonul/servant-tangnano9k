# Creates the Servant / Tang Nano 9K working tree and runs the Gowin build.
#
# Version 0.3.0
#
# Run from the folder this script sits in:
#
#   powershell -ExecutionPolicy Bypass -File .\setup.ps1
#
# Add -NoBuild to only lay out the tree, or -Load to program the board
# afterwards with openFPGALoader.

param(
    [string]$Root = "D:\docs\ostim\digital\gowin\serv_tn9k",
    [switch]$NoBuild,
    [switch]$Load
)

$ErrorActionPreference = "Stop"

Write-Host "Root: $Root"
New-Item -ItemType Directory -Force -Path $Root, "$Root\src" | Out-Null

# --- SERV sources ----------------------------------------------------------
if (Test-Path "$Root\serv\.git") {
    Write-Host "serv already cloned, skipping"
} else {
    Write-Host "Cloning olofk/serv"
    git clone --depth 1 https://github.com/olofk/serv.git "$Root\serv"
}

# --- Our files -------------------------------------------------------------
Copy-Item "$PSScriptRoot\servant\servant_tangnano9k.v" "$Root\src\" -Force
Copy-Item "$PSScriptRoot\data\tangnano9k.cst"       "$Root\src\" -Force
Copy-Item "$PSScriptRoot\build.tcl"            "$Root\"     -Force
Copy-Item "$Root\serv\sw\blinky.hex"           "$Root\"     -Force

# GowinSynthesis resolves $readmemh relative to its own working directory,
# which is not the source directory. Pin the memory image to an absolute path
# so it cannot silently load nothing and leave you debugging a dark LED.
$hex = ("$Root\blinky.hex") -replace '\\', '/'
$top = "$Root\src\servant_tangnano9k.v"
(Get-Content $top) -replace 'parameter memfile = "[^"]*"', "parameter memfile = `"$hex`"" |
    Set-Content $top
Write-Host "memfile pinned to $hex"

if ($NoBuild) { Write-Host "Tree ready, skipping build."; exit 0 }

# --- Locate gw_sh ----------------------------------------------------------
$gwsh = Get-Command gw_sh.exe -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Source
if (-not $gwsh) {
    $gwsh = Get-ChildItem -Path "C:\Gowin", "D:\Gowin" -Filter gw_sh.exe `
                          -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
}
if (-not $gwsh) {
    throw "gw_sh.exe not found. Pass its folder on PATH, or edit this script."
}
Write-Host "Using $gwsh"

# --- Build -----------------------------------------------------------------
Push-Location $Root
& $gwsh "$Root\build.tcl"
$rc = $LASTEXITCODE
Pop-Location

$fs = "$Root\impl\pnr\servant_tangnano9k.fs"
if ($rc -ne 0 -or -not (Test-Path $fs)) {
    throw "Build failed. Check $Root\impl\gwsynthesis\*.log first."
}

# The most common silent failure is the memory image not loading at all, which
# leaves the RAM zeroed and the LED dark. Confirm synthesis actually read it.
$synlog = Get-ChildItem "$Root\impl\gwsynthesis" -Filter *.log -ErrorAction SilentlyContinue |
          Select-Object -First 1
if ($synlog -and -not (Select-String -Path $synlog.FullName -Pattern 'Preloading' -Quiet)) {
    Write-Warning "No 'Preloading' line in the synthesis log. The RAM may be empty."
}

Write-Host "Bitstream: $fs"

if ($Load) {
    openFPGALoader -b tangnano9k $fs
}
