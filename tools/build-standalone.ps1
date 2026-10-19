param(
  [string]$RHome = '',
  [string]$Pandoc = (Join-Path $env:LOCALAPPDATA 'Pandoc\pandoc.exe'),
  [switch]$SkipRuntime,
  [switch]$SkipNpm,
  [ValidateSet('installer','portable')][string]$Target = 'installer',
  [string]$RuntimeDirectory = '',
  [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
function Invoke-BuildCommand([string]$FilePath, [object[]]$CommandArguments) {
  # Windows PowerShell otherwise treats harmless native stderr messages as
  # terminating errors. Preserve the output and use the process exit status.
  $previousErrorPreference = $ErrorActionPreference
  try {
    $ErrorActionPreference = 'Continue'
    & $FilePath @CommandArguments 2>&1 | ForEach-Object { $_.ToString() }
    $commandExit = $LASTEXITCODE
  } finally { $ErrorActionPreference = $previousErrorPreference }
  if ($commandExit -ne 0) { throw "Build command failed with exit code ${commandExit}: $FilePath $CommandArguments" }
}
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildRoot = Join-Path $projectRoot 'build'
$desktopRoot = Join-Path $PSScriptRoot 'desktop'
if (!$RHome) {
  $rOnPath = Get-Command Rscript.exe -ErrorAction SilentlyContinue
  if ($rOnPath) { $RHome = (& $rOnPath.Source --vanilla -e 'cat(R.home())') }
  else {
    $releaseR = Get-ChildItem (Join-Path $env:ProgramFiles 'R') -Directory -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending | Select-Object -First 1
    if ($releaseR) { $RHome = $releaseR.FullName }
  }
}
if (!$RHome) { throw 'Install R and add Rscript to PATH, or supply -RHome.' }
if (!$RuntimeDirectory) {
  $RuntimeDirectory = if ($SkipRuntime) { Join-Path $buildRoot 'staging/runtime' }
    else { Join-Path $buildRoot ('staging/runtime-' + (Get-Date -Format 'yyyyMMdd-HHmmss')) }
}
$RuntimeDirectory = [IO.Path]::GetFullPath($RuntimeDirectory)
if (!$RuntimeDirectory.StartsWith($buildRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'RuntimeDirectory must stay under this project build folder.'
}
if (!$OutputDirectory) { $OutputDirectory = $buildRoot }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$rscript = Join-Path $RHome 'bin\Rscript.exe'
if (!(Test-Path -LiteralPath $rscript)) { throw "Rscript not found: $rscript" }
if (!(Test-Path -LiteralPath $Pandoc)) { throw "Pandoc not found: $Pandoc" }
New-Item -ItemType Directory -Path $buildRoot -Force | Out-Null
$env:LC_ALL = 'English_Canada.utf8'
$env:LANG = 'English_Canada.utf8'
Push-Location $projectRoot
try {
  if ($SkipRuntime) { Invoke-BuildCommand $rscript @('--vanilla', 'tools/check-runtime-lock.R', (Join-Path $RuntimeDirectory 'R/library')) }
  else { Invoke-BuildCommand $rscript @('--vanilla', 'tools/check-runtime-lock.R') }
  Invoke-BuildCommand $rscript @('--vanilla', 'tools/build-metadata.R')
} finally { Pop-Location }
& (Join-Path $desktopRoot 'create-splash.ps1')
if (!$SkipRuntime) {
  Invoke-BuildCommand $rscript @('--vanilla', (Join-Path $PSScriptRoot 'prepare-standalone.R'), $projectRoot, $Pandoc, $RuntimeDirectory)
}
Push-Location $projectRoot
try {
  Invoke-BuildCommand $rscript @('--vanilla', 'tools/build-metadata.R', $RuntimeDirectory)
  Copy-Item -LiteralPath inst/build-info.json -Destination (Join-Path $RuntimeDirectory 'R/library/IndividualGuide/build-info.json') -Force
  Invoke-BuildCommand $rscript @('--vanilla', 'tools/verify-desktop-runtime.R', $RuntimeDirectory, (Join-Path $OutputDirectory 'runtime-source-verification.json'))
  $runtimeCheck = Join-Path $buildRoot ('runtime-check-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
  New-Item -ItemType Directory -Path $runtimeCheck -Force | Out-Null
  $previousRuntimeRHome = $env:R_HOME
  try {
    $env:R_HOME = Join-Path $RuntimeDirectory 'R'
    Invoke-BuildCommand (Join-Path $RuntimeDirectory 'R/bin/x64/Rscript.exe') @('--vanilla', 'tools/test-runtime-startup.R', $RuntimeDirectory, $runtimeCheck)
  } finally { $env:R_HOME = $previousRuntimeRHome }
} finally { Pop-Location }
Push-Location $desktopRoot
try {
  if (!$SkipNpm) {
    if (Test-Path -LiteralPath 'package-lock.json') { Invoke-BuildCommand 'npm.cmd' @('ci', '--no-audit', '--no-fund') }
    else { Invoke-BuildCommand 'npm.cmd' @('install', '--no-audit', '--no-fund') }
  }
  $assetRoot = Join-Path $desktopRoot 'assets'
  $iconOutputs = @('icon.png','icon.ico') | ForEach-Object { Join-Path $assetRoot $_ }
  $iconInputs = @((Join-Path $assetRoot 'icon.svg'), (Join-Path $desktopRoot 'create-icon.cjs'))
  $renderIcon = @($iconOutputs | Where-Object { !(Test-Path -LiteralPath $_) }).Count -gt 0
  if (!$renderIcon) {
    $oldestOutput = ($iconOutputs | ForEach-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc } | Sort-Object | Select-Object -First 1)
    $renderIcon = @($iconInputs | Where-Object { (Get-Item -LiteralPath $_).LastWriteTimeUtc -gt $oldestOutput }).Count -gt 0
  }
  if ($renderIcon) {
    $electronRenderer = Join-Path $desktopRoot 'node_modules/electron/dist/electron.exe'
    if (!(Test-Path -LiteralPath $electronRenderer)) {
      # Electron 44 downloads its binary on demand, rather than during npm ci.
      Invoke-BuildCommand 'node.exe' @((Join-Path $desktopRoot 'node_modules/electron/install.js'))
    }
    if (!(Test-Path -LiteralPath $electronRenderer)) { throw 'The pinned Electron icon renderer was not installed.' }
    $previousElectronNode = $env:ELECTRON_RUN_AS_NODE
    try {
    Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
    $iconOutput = Join-Path $buildRoot 'icon-render.log'
    $iconErrors = Join-Path $buildRoot 'icon-render-errors.log'
    $iconProcess = Start-Process -FilePath $electronRenderer -ArgumentList ('"{0}"' -f (Join-Path $desktopRoot 'create-icon.cjs')) -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $iconOutput -RedirectStandardError $iconErrors
    if ($iconProcess.ExitCode -ne 0) { throw ('Creating the application icon failed. ' + (Get-Content -LiteralPath $iconErrors -Raw)) }
    } finally { $env:ELECTRON_RUN_AS_NODE = $previousElectronNode }
  } else { Write-Output 'Reusing unchanged application icon assets.' }
  $env:CSC_IDENTITY_AUTO_DISCOVERY = 'false'
  Invoke-BuildCommand 'node.exe' @((Join-Path $desktopRoot 'build.cjs'), "--target=$Target", "--runtime=$RuntimeDirectory", "--output=$OutputDirectory")
} finally { Pop-Location }
$executables = Get-ChildItem -LiteralPath $OutputDirectory -Filter 'IndividualGuide-*-Windows-x64.exe' -File
foreach ($executable in $executables) {
  $hash = (Get-FileHash -LiteralPath $executable.FullName -Algorithm SHA256).Hash
  Set-Content -LiteralPath ($executable.FullName + '.sha256') -Value ('{0}  {1}' -f $hash, $executable.Name) -Encoding ascii
  Write-Output ('Built {0} ({1:N1} MB)' -f $executable.FullName, ($executable.Length / 1MB))
}
Copy-Item -LiteralPath (Join-Path $desktopRoot 'BUILD-README.md') -Destination (Join-Path $OutputDirectory 'README.md') -Force
