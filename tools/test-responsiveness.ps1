param(
  [string]$BaselineRef = 'HEAD',
  [string]$Rscript = 'C:/Program Files/R/R-4.6.1/bin/Rscript.exe',
  [switch]$SkipBrowser,
  [switch]$IncludeStartup
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location $projectRoot
$previousLocale = $env:LC_ALL
$previousLanguage = $env:LANG
try {
  $env:LC_ALL = 'English_Canada.utf8'; $env:LANG = 'English_Canada.utf8'
  $runId = 'responsiveness-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
  $runRoot = Join-Path $projectRoot ('artifacts/performance/responsiveness/' + $runId)
  $baseline = Join-Path $runRoot 'baseline-source'
  New-Item -ItemType Directory -Path $baseline -Force | Out-Null
  $baselineCommit = (git rev-parse --verify ($BaselineRef + '^{commit}')).Trim()
  if ($LASTEXITCODE -ne 0) { throw 'The baseline ref must identify a local commit.' }
  $archive = Join-Path $runRoot 'baseline.tar'
  git archive --format=tar "--output=$archive" $baselineCommit
  if ($LASTEXITCODE -ne 0) { throw 'Cannot freeze the baseline source.' }
  tar -xf $archive -C $baseline
  if ($LASTEXITCODE -ne 0) { throw 'Cannot extract the baseline source.' }
  function Invoke-Profile([string]$Name, [string]$Script, [string[]]$ScriptArguments, [string]$Executable = $Rscript) {
    Write-Host "Running $Name"
    # Freeze the driver too: Rscript can read a script incrementally, so editing
    # that file during a long measurement must not change the running program.
    $driver = Join-Path $runRoot ($Name + '.R')
    Copy-Item -LiteralPath $Script -Destination $driver
    $profileErrorPreference = $ErrorActionPreference
    try {
      # R warnings on stderr are log records; the process exit status decides
      # success. Windows PowerShell otherwise turns them into native errors.
      $ErrorActionPreference = 'Continue'
      & $Executable --vanilla $driver @ScriptArguments *> (Join-Path $runRoot ($Name + '.log'))
      $status = $LASTEXITCODE
    } finally { $ErrorActionPreference = $profileErrorPreference }
    $status | Set-Content -LiteralPath (Join-Path $runRoot ($Name + '.exit.txt'))
    if ($status -ne 0) { throw "$Name failed; see $runRoot/$Name.log" }
  }
  $workloads = 'invalidate_200|edit_first_200|pipeline_40|column_selectors_20|canvas_100|project_save_load_100k|environment_100|run_records_20|autosave_100k|filtered_console_5000'
  Invoke-Profile 'backend-before' 'tools/performance-benchmark.R' @($baseline, ($runId + '-before'), $workloads)
  if (!$SkipBrowser) { Invoke-Profile 'browser-before' 'tools/profile-responsiveness-browser.R' @($baseline, ($runId + '-before')) }
  Invoke-Profile 'backend-after' 'tools/performance-benchmark.R' @($projectRoot, ($runId + '-after'), $workloads)
  if (!$SkipBrowser) { Invoke-Profile 'browser-after' 'tools/profile-responsiveness-browser.R' @($projectRoot, ($runId + '-after'), '--check') }
  if (!$SkipBrowser) {
    Invoke-Profile 'autosave-before' 'tools/profile-responsiveness-browser.R' @($baseline, ($runId + '-autosave-before'), '--autosave-only')
    Invoke-Profile 'autosave-after' 'tools/profile-responsiveness-browser.R' @($projectRoot, ($runId + '-autosave-after'), '--autosave-only', '--check')
  }
  if ($IncludeStartup) {
    $runtime = Join-Path $projectRoot 'build/staging/runtime'
    $privateRscript = Join-Path $runtime 'R/bin/x64/Rscript.exe'
    $previousRhome = $env:R_HOME
    try {
      $env:R_HOME = Join-Path $runtime 'R'
      foreach ($trial in 1..3) { foreach ($mode in @('normal','eager')) {
        Invoke-Profile "startup-$mode-$trial" 'tools/performance-startup.R' @($runtime, $mode, (Join-Path $runRoot "startup-$mode-$trial.csv")) $privateRscript
      } }
    } finally { $env:R_HOME = $previousRhome }
  }
  [ordered]@{baselineCommit=$baselineCommit; checkoutCommit=(git rev-parse HEAD).Trim(); runId=$runId;
    browserExecuted=(!$SkipBrowser); autosaveExecuted=(!$SkipBrowser); startupExecuted=[bool]$IncludeStartup; sequential=$true;
    sourceChanges=(git status --porcelain | Out-String).Trim()} |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runRoot 'metadata.json') -Encoding UTF8
  Invoke-Profile 'comparison' 'tools/compare-responsiveness.R' @($runId)
  Write-Host "Results: $runRoot/comparison.md"
} finally {
  $env:LC_ALL = $previousLocale; $env:LANG = $previousLanguage
  Pop-Location
}
