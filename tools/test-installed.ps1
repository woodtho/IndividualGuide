param([Parameter(Mandatory=$true)][string]$Executable, [int]$StartupRuns = 3, [switch]$SkipWorkflow, [switch]$ExamplesOnly, [switch]$ConsoleOnly, [switch]$ProductOnly, [switch]$WorkflowOnly, [switch]$StartupOnly)
$ErrorActionPreference = 'Stop'
if (@($ExamplesOnly,$ConsoleOnly,$ProductOnly,$WorkflowOnly,$StartupOnly | Where-Object {$_}).Count -gt 1) { throw 'Choose one focused test suite.' }
$focused = $ExamplesOnly -or $ConsoleOnly -or $ProductOnly -or $WorkflowOnly -or $StartupOnly
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Executable = (Resolve-Path -LiteralPath $Executable).Path
$installRoot = Split-Path -Parent $Executable
$runtime = Join-Path $installRoot 'resources\runtime'
if (!(Test-Path -LiteralPath (Join-Path $runtime 'R\bin\x64\Rscript.exe'))) { throw 'The installed runtime is missing.' }
$runRoot = Join-Path $projectRoot ('build\tests\installed-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $runRoot -Force | Out-Null
$database = Join-Path $runtime 'R\library\IndividualGuide\R\IndividualGuide.rdb'
$initialHash = (Get-FileHash -LiteralPath $database -Algorithm SHA256).Hash
$initialWrite = (Get-Item -LiteralPath $database).LastWriteTimeUtc
function Invoke-InstalledCheck([string]$Name, [switch]$Startup, [switch]$Restart, [switch]$Menus, [switch]$Lifecycle, [switch]$Console, [switch]$Examples, [switch]$Product) {
  $resultFile = Join-Path $runRoot ($Name + '.json')
  $profileName = if ($Product) { 'Product User Data' } elseif ($Startup) { 'Startup User Data' } elseif ($Restart) { 'Restart User Data' } elseif ($Console) { 'Console User Data' } elseif ($Examples) { 'Examples User Data' } elseif ($Menus -or $Lifecycle) { 'Menus User Data' } else { 'Workflow User Data' }
  $dataRoot = Join-Path $runRoot $profileName
  $variables = @('PATH','R_HOME','R_LIBS','R_LIBS_USER','R_LIBS_SITE','RSTUDIO_PANDOC','ELECTRON_RUN_AS_NODE','IG_RUNTIME_OVERRIDE')
  $previous = @{}
  foreach ($variableName in $variables) { $previous[$variableName] = [Environment]::GetEnvironmentVariable($variableName, 'Process') }
  try {
    $env:PATH = (Join-Path $env:SystemRoot 'System32') + ';' + $env:SystemRoot
    $env:R_HOME = 'C:\No-Host-R-Available'
    $env:R_LIBS = 'C:\No-Host-Packages-Available'
    $env:R_LIBS_USER = 'C:\No-Host-Packages-Available'
    $env:R_LIBS_SITE = 'C:\No-Host-Packages-Available'
    $env:RSTUDIO_PANDOC = 'C:\No-Host-Pandoc-Available'
    Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
    Remove-Item Env:IG_RUNTIME_OVERRIDE -ErrorAction SilentlyContinue
    $mode = if ($Product) { '--smoke-product' } elseif ($Startup) { '--smoke-startup' } elseif ($Restart) { '--smoke-restart' } elseif ($Console) { '--smoke-console' } elseif ($Examples) { '--smoke-examples' } elseif ($Lifecycle) { '--smoke-lifecycle' } elseif ($Menus) { '--smoke-menus' } else { '--smoke-test' }
    $arguments = @($mode, ('"--smoke-result={0}"' -f $resultFile), ('"--data-dir={0}"' -f $dataRoot))
    if (!$Product -and !$Startup -and !$Restart -and !$Menus -and !$Lifecycle -and !$Console -and !$Examples) { $arguments += '--smoke-second-launch' }
    $launchedAt = [DateTimeOffset]::UtcNow
    $process = Start-Process -FilePath $Executable -ArgumentList $arguments -WindowStyle Hidden -PassThru -WorkingDirectory $runRoot
  } finally {
    foreach ($variableName in $variables) { [Environment]::SetEnvironmentVariable($variableName, $previous[$variableName], 'Process') }
  }
  $deadline = (Get-Date).AddMinutes(8)
  while (!$process.WaitForExit(1000)) {
    if ((Get-Date) -gt $deadline) {
      & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /PID $process.Id /T /F | Out-Null
      throw "Installed test timed out: $Name. Inspect $dataRoot\logs\startup.log"
    }
  }
  if (!(Test-Path -LiteralPath $resultFile)) { throw "No result: $Name. Inspect $dataRoot\logs\startup.log" }
  $result = Get-Content -LiteralPath $resultFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($process.ExitCode -ne 0 -or !$result.ok) { throw "Installed test failed: $Name. $($result.error)" }
  if (!$result.desktop.packaged -or $result.desktop.portableExecutable) { throw 'The test did not use the installed executable.' }
  if (![IO.Path]::GetFullPath($result.runtimeDirectory).Equals([IO.Path]::GetFullPath($runtime), [StringComparison]::OrdinalIgnoreCase)) { throw 'The test used another runtime.' }
  if (Get-Process -Id $result.desktop.rPid -ErrorAction SilentlyContinue) { throw 'The installed R backend survived closing.' }
  if ($Restart) {
    foreach ($backendId in $result.rPids) {
      if (Get-Process -Id $backendId -ErrorAction SilentlyContinue) { throw "An R backend survived restart/shutdown: $backendId" }
    }
    if (!$result.checks.crashRestart -or !$result.checks.failedRestartCanRetry -or !$result.checks.disconnectedRestart) { throw 'Required restart checks are missing.' }
  }
  if (@($result.checks.PSObject.Properties | Where-Object { $_.Value -ne $true }).Count) { throw 'A workflow check failed.' }
  if ($Menus -and (!$result.checks.nativeOpenPreservesImmediateEdits -or !$result.checks.nativeSaveAs -or !$result.checks.unsavedOpenCancel -or !$result.checks.diagnosticExport)) { throw 'Required desktop menu checks are missing.' }
  if (!$Product -and !$Startup -and !$Restart -and !$Menus -and !$Lifecycle -and !$Console -and !$Examples -and (!$result.checks.secondLaunch -or !$result.checks.freshCodeExecution -or !$result.checks.logFilePreview -or !$result.runtime.checks.pandoc)) { throw 'Required installed workflow checks are missing.' }
  if ($Product -and (!$result.checks.privateDesktopSession -or !$result.checks.savedVersionsUI -or !$result.checks.backgroundWholeFlow)) { throw 'Required product checks are missing.' }
  if ($Examples -and (!$result.checks.loadFromHelp -or !$result.checks.saveBeforeReplacement -or !$result.checks.separateWritableOutputs -or !$result.checks.reopenSavedCopy)) { throw 'Required example project checks are missing.' }
  if ($Console -and (!$result.checks.projectData -or !$result.checks.noBlankPlots -or !$result.checks.transcriptDownload -or !$result.checks.stopAndRestart -or !$result.checks.stableEditor)) { throw 'Required R console checks are missing.' }
  if ($Lifecycle -and (!$result.checks.saveOnClose -or !$result.checks.secondInstanceOpensProject -or !$result.checks.stopPreventsRemainingTasks -or !$result.checks.windowStatePersists -or !$result.checks.failedSaveKeepsWindow)) { throw 'Required project lifecycle checks are missing.' }
  if ($Startup) {
    $seconds = ([DateTimeOffset]::Parse($result.readyAt) - $launchedAt).TotalSeconds
    Write-Output ([pscustomobject]@{ run=$Name; processToWorkspaceSeconds=$seconds; electronToWorkspaceMilliseconds=$result.readyMilliseconds; backendStopped=$true })
  } elseif ($Restart) { Write-Host 'R crash recovery, disconnected restart, failed-start retry, cancellation, repeated requests and shutdown passed.' }
  elseif ($Product) { Write-Host 'Project versions, validation, run records, trust, private sessions and display scaling passed.' }
  elseif ($Console) { Write-Host 'R console data, history, plots, download, responsiveness, cancellation and reset passed.' }
  elseif ($Examples) { Write-Host 'Help examples, real data, logs, reruns, independent outputs, replacement protection and saved copies passed.' }
  elseif ($Menus -or $Lifecycle) { Write-Host 'Desktop menus, project lifecycle, recent projects, save-on-close, cancellation and window persistence passed.' }
  else { Write-Host 'Installed offline workflow, duplicate launch, previews, downloads, private R and shutdown passed.' }
}
if (!$focused) {
  if (!$SkipWorkflow) { Invoke-InstalledCheck 'workflow' }
  Invoke-InstalledCheck 'menus' -Lifecycle
}
if ($WorkflowOnly) { Invoke-InstalledCheck 'workflow' }
if (!$focused -or $ConsoleOnly) { Invoke-InstalledCheck 'console' -Console }
if (!$focused -or $ExamplesOnly) { Invoke-InstalledCheck 'examples' -Examples }
if (!$focused -or $ProductOnly) { Invoke-InstalledCheck 'product' -Product }
if (!$focused) { Invoke-InstalledCheck 'restart' -Restart }
$timings = @(for ($index=1; $index -le $StartupRuns; $index++) { Invoke-InstalledCheck "startup-$index" -Startup })
if ((Get-FileHash -LiteralPath $database -Algorithm SHA256).Hash -ne $initialHash -or (Get-Item -LiteralPath $database).LastWriteTimeUtc -ne $initialWrite) { throw 'The installed runtime changed between launches.' }
$workflowResult = if ((!$SkipWorkflow -and !$focused) -or $WorkflowOnly) { Join-Path $runRoot 'workflow.json' } else { $null }
$report = [ordered]@{ ok=$true; executable=$Executable; runtimeDirectory=$runtime; persistentRuntimeUnchanged=$true; startupRuns=$timings; workflowSkipped=($null -eq $workflowResult); examplesOnly=[bool]$ExamplesOnly; consoleOnly=[bool]$ConsoleOnly; productOnly=[bool]$ProductOnly; workflowOnly=[bool]$WorkflowOnly; startupOnly=[bool]$StartupOnly; workflowResult=$workflowResult;
  menuResult=$(if (!$focused) {Join-Path $runRoot 'menus.json'} else {$null});
  consoleResult=$(if (!$focused -or $ConsoleOnly) {Join-Path $runRoot 'console.json'} else {$null});
  examplesResult=$(if (!$focused -or $ExamplesOnly) {Join-Path $runRoot 'examples.json'} else {$null});
  productResult=$(if (!$focused -or $ProductOnly) {Join-Path $runRoot 'product.json'} else {$null});
  restartResult=$(if (!$focused) {Join-Path $runRoot 'restart.json'} else {$null}) }
[IO.File]::WriteAllText((Join-Path $runRoot 'result.json'), ($report | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
$timings | Format-Table -AutoSize
Write-Output ('Installed application passed. Results: ' + (Join-Path $runRoot 'result.json'))
