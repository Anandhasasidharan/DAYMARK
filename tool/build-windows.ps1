# Build and validate only the Windows application. Does not install a toolchain.
[CmdletBinding()]
param([switch]$Run)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$releaseRootPath = [IO.Path]::GetFullPath((Join-Path $projectRoot 'build/windows')) + [IO.Path]::DirectorySeparatorChar
$running = Get-Process lifeos -ErrorAction SilentlyContinue | Where-Object {
  $_.Path -and $_.Path.StartsWith($releaseRootPath, [StringComparison]::OrdinalIgnoreCase)
}
if ($running) { throw 'Close LifeOS before rebuilding. The running app has been left open and its data has not been changed.' }
Push-Location $projectRoot
try {
  & (Join-Path $PSScriptRoot 'bootstrap.ps1') -Target windows
  if ($LASTEXITCODE -ne 0) { throw 'Setup or checks failed; the release was not built.' }
  & flutter --no-version-check --suppress-analytics build windows --release
  if ($LASTEXITCODE -ne 0) { throw 'Windows compilation failed. See the compiler output above.' }
  $releaseRoot = Join-Path $projectRoot 'build/windows'
  $executables = @(Get-ChildItem $releaseRoot -Filter 'lifeos.exe' -Recurse |
    Where-Object { $_.Directory.Name -eq 'Release' -and $_.Directory.Parent.Name -eq 'runner' })
  if ($executables.Count -ne 1) { throw 'Expected one release executable. Check build/windows for the output.' }
  $executable = $executables[0]
  if (-not (Test-Path (Join-Path $executable.Directory.FullName 'data'))) { throw 'The release data folder is missing.' }
  if (-not (Test-Path (Join-Path $executable.Directory.FullName 'flutter_windows.dll'))) { throw 'The Flutter runtime DLL is missing.' }
  Write-Host "Windows release built: $($executable.FullName)"
  Write-Host 'Keep the entire Release folder together. No duplicate ZIP or installer was created.'
  if ($Run) { Start-Process -FilePath $executable.FullName -WorkingDirectory $executable.Directory.FullName }
} finally { Pop-Location }
