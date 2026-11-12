# Flutter accepts these project-local junctions without system-wide Developer Mode.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$metadataPath = Join-Path $projectRoot '.flutter-plugins-dependencies'
if (-not (Test-Path $metadataPath)) { throw 'Run Flutter package resolution before preparing Windows plugin links.' }
$metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
$linkRoot = Join-Path $projectRoot 'windows/flutter/ephemeral/.plugin_symlinks'
New-Item -ItemType Directory -Path $linkRoot -Force | Out-Null
foreach ($plugin in $metadata.plugins.windows) {
  if ($plugin.name -notmatch '^[a-zA-Z0-9_]+$') { throw 'Invalid Windows plugin name.' }
  $target = [IO.Path]::GetFullPath([string]$plugin.path).TrimEnd('\')
  if (-not (Test-Path -LiteralPath $target -PathType Container)) { throw "Plugin source is missing: $($plugin.name)" }
  $linkPath = Join-Path $linkRoot $plugin.name
  $existing = Get-Item -LiteralPath $linkPath -Force -ErrorAction SilentlyContinue
  if ($existing) {
    if ($existing.LinkType -notin @('Junction','SymbolicLink')) { throw "A non-link already exists at $linkPath; preserve it and inspect it manually." }
    $currentTarget = [IO.Path]::GetFullPath([string]@($existing.Target)[0]).TrimEnd('\')
    if ($currentTarget -eq $target) { continue }
    # Delete only the link itself, never its target directory.
    $existing.Delete()
  }
  New-Item -ItemType Junction -Path $linkPath -Target $target | Out-Null
}
Write-Host 'Windows plugin directory links are ready.'
