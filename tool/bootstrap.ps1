# Windows only for the current milestone; reuse the installed Flutter SDK.
[CmdletBinding()]
param(
  [ValidateSet('windows')]
  [string]$Target = 'windows'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$localFlutterBin = Join-Path $projectRoot '.toolchain/flutter/bin'
if (Test-Path (Join-Path $localFlutterBin 'flutter.bat')) {
  $env:PATH = $localFlutterBin + [IO.Path]::PathSeparator + $env:PATH
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter is missing. Use one Windows Flutter SDK (Dart is included); no WSL SDK or emulator is needed. See README.md.'
}
function Invoke-Flutter {
  & flutter --no-version-check --suppress-analytics @args
  if ($LASTEXITCODE -ne 0) { throw "Flutter command failed with exit code $LASTEXITCODE" }
}
Push-Location $projectRoot
try {
  Invoke-Flutter --version
  # Generate only the selected missing runner; do not fetch packages in staging.
  if (-not (Test-Path $Target)) {
    $staging = Join-Path ([System.IO.Path]::GetTempPath()) ('lifeos_scaffold_' + [guid]::NewGuid().ToString('N'))
    try {
      Invoke-Flutter create --empty --no-pub "--platforms=$Target" --project-name=lifeos --org=local.lifeos $staging
      Copy-Item (Join-Path $staging $Target) $Target -Recurse
      if (-not (Test-Path '.metadata')) { Copy-Item (Join-Path $staging '.metadata') '.metadata' }
    } finally {
      if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    }
  }
  # Capture package errors so the specific symlink-privilege error can be fixed
  # with project-local junctions; other package failures still stop the build.
  $previousPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    $packageOutput = & flutter --no-version-check --suppress-analytics pub get 2>&1
    $packageExitCode = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previousPreference }
  $packageOutput | ForEach-Object { Write-Host $_ }
  if ($packageExitCode -ne 0) {
    if (($packageOutput -join "`n") -notmatch 'Building with plugins requires symlink support') {
      throw "Flutter package resolution failed with exit code $packageExitCode"
    }
    & (Join-Path $PSScriptRoot 'windows-plugin-links.ps1')
    Invoke-Flutter pub get
  }
  & (Join-Path $PSScriptRoot 'windows-plugin-links.ps1')
  & dart format lib test
  if ($LASTEXITCODE -ne 0) { throw 'Dart formatting failed.' }
  Invoke-Flutter analyze
  Invoke-Flutter test
  Write-Host 'Checks passed. Run: flutter run -d windows'
} finally {
  Pop-Location
}
