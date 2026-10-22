param([string]$Executable, [int]$TimeoutSeconds = 900, [switch]$Relocate)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$buildRoot = Join-Path $projectRoot 'build'
if (!$Executable) {
  $Executable = (Get-ChildItem -LiteralPath $buildRoot -Filter 'IndividualGuide-*-Windows-x64.exe' -File | Where-Object { $_.Name -notlike '*-Setup-*' } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
}
if (!$Executable -or !(Test-Path -LiteralPath $Executable)) { throw 'Build the executable first.' }
$runRoot = Join-Path $buildRoot ('tests\run-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$resultFile = Join-Path $runRoot 'result.json'
$dataRoot = Join-Path $runRoot 'User Data'
$launchExecutable = $Executable
$temporaryRoot = Join-Path ([IO.Path]::GetTempPath()) ('Individual Guide ' + [char]0x03A9 + '-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
if ($Relocate) {
  $portableRoot = Join-Path $runRoot ('Portable Path ' + [char]0x03A9)
  New-Item -ItemType Directory -Path $portableRoot,$temporaryRoot -Force | Out-Null
  $launchExecutable = Join-Path $portableRoot 'IndividualGuide.exe'
  Copy-Item -LiteralPath $Executable -Destination $launchExecutable
}
$variables = @('PATH', 'TEMP', 'TMP', 'R_HOME', 'R_LIBS', 'R_LIBS_USER', 'R_LIBS_SITE', 'RSTUDIO_PANDOC', 'ELECTRON_RUN_AS_NODE', 'IG_RUNTIME_OVERRIDE')
$previous = @{}
foreach ($name in $variables) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
  $env:PATH = (Join-Path $env:SystemRoot 'System32') + ';' + $env:SystemRoot
  $env:R_HOME = 'C:\No-Host-R-Available'
  $env:R_LIBS = 'C:\No-Host-Packages-Available'
  $env:R_LIBS_USER = 'C:\No-Host-Packages-Available'
  $env:R_LIBS_SITE = 'C:\No-Host-Packages-Available'
  $env:RSTUDIO_PANDOC = 'C:\No-Host-Pandoc-Available'
  if ($Relocate) { $env:TEMP = $temporaryRoot; $env:TMP = $temporaryRoot }
  Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
  Remove-Item Env:IG_RUNTIME_OVERRIDE -ErrorAction SilentlyContinue
  $arguments = @('--smoke-test', '--smoke-second-launch', ('"--smoke-result={0}"' -f $resultFile), ('"--data-dir={0}"' -f $dataRoot))
  $launchTime = Get-Date
  $process = Start-Process -FilePath $launchExecutable -ArgumentList $arguments -WorkingDirectory $runRoot -WindowStyle Hidden -PassThru
} finally {
  foreach ($name in $variables) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
}
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
while (!$process.WaitForExit(1000)) {
  if ((Get-Date) -gt $deadline) {
    # Terminate only the test executable and the descendants it started.
    & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /PID $process.Id /T /F | Out-Null
    throw "The standalone smoke test timed out. Inspect $dataRoot\logs\startup.log"
  }
}
if (!(Test-Path -LiteralPath $resultFile)) { throw "The executable exited without a smoke result. Inspect $dataRoot\logs\startup.log" }
$result = Get-Content -LiteralPath $resultFile -Raw -Encoding utf8 | ConvertFrom-Json
if (!$result.ok) { throw ('Standalone test failed: ' + $result.error + '. Details: ' + $resultFile) }
if ($process.ExitCode -ne 0) { throw ('Executable returned exit code ' + $process.ExitCode) }
if (!$result.desktop.packaged) { throw 'The test did not run a packaged executable.' }
if (!$result.desktop.portableExecutable) { throw 'The test did not run the single-file portable executable.' }
if (!$result.checks.unsavedClosePrompt -or !$result.checks.windowClosed) { throw 'The desktop close confirmation was not exercised.' }
if (!$result.checks.secondLaunch) { throw 'Opening the executable twice was not exercised.' }
# R.home() uses Windows 8.3 aliases for paths containing spaces/Unicode, while
# .libPaths() expands them. Compare the expanded private library and require
# the runtime home suffix instead of comparing two representations literally.
$expectedLibrary = [IO.Path]::GetFullPath((Join-Path $result.runtimeDirectory 'R/library')).Replace('\','/')
$expectedUserLibraryRoot = [IO.Path]::GetFullPath((Join-Path $dataRoot 'packages')).Replace('\','/') + '/'
if (!$result.runtime.library_paths[0].Replace('\','/').StartsWith($expectedUserLibraryRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'The app did not prioritize its IG-specific package library.' }
if (!(@($result.runtime.library_paths | ForEach-Object { $_.Replace('\','/') }) -contains $expectedLibrary) -or
    !$result.runtime.r_home.Replace('\','/').EndsWith('/runtime/R', [StringComparison]::OrdinalIgnoreCase)) { throw 'The executable used an R installation outside its bundle.' }
if (Get-Process -Id $result.desktop.rPid -ErrorAction SilentlyContinue) { throw 'The R process survived closing the app.' }
$firstLogLine = Get-Content -LiteralPath (Join-Path $dataRoot 'logs\startup.log') -TotalCount 1
$timings = [ordered]@{ launchedAt = $launchTime.ToUniversalTime().ToString('o'); totalSmokeSeconds = ((Get-Date)-$launchTime).TotalSeconds }
if ($firstLogLine -match ' startup (.+)$') {
  $shellTime = [DateTimeOffset]::Parse($Matches[1]).UtcDateTime
  $timings.exeToElectronStartupSeconds = ($shellTime - $launchTime.ToUniversalTime()).TotalSeconds
}
$timings | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runRoot 'timings.json') -Encoding utf8
Write-Output ('Standalone executable passed. Results: ' + $resultFile)
Write-Output ('Bundled R: ' + $result.runtime.r_home)
Write-Output ('Bundled packages: ' + $result.runtime.packages)
