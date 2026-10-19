param([Parameter(Mandatory=$true)][string]$ReleaseFolder,
      [Parameter(Mandatory=$true)][string]$EvidenceFolder,[string]$PreviousInstaller)
$ErrorActionPreference = 'Stop'
# Installation, association and uninstall checks are allowed only in an
# explicitly isolated test account. Never run them against a user's desktop.
if ($env:USERNAME -ne 'WDAGUtilityAccount' -and $env:IG_ISOLATED_RELEASE_TEST -ne '1') {
  throw 'Run in Windows Sandbox or an isolated CI account with IG_ISOLATED_RELEASE_TEST=1.'
}
$ReleaseFolder = (Resolve-Path -LiteralPath $ReleaseFolder).Path
New-Item -ItemType Directory -Path $EvidenceFolder -Force | Out-Null
$setups = @(Get-ChildItem -LiteralPath $ReleaseFolder -Filter 'IndividualGuide-*-Setup-Windows-x64.exe' -File)
if ($setups.Count -ne 1) { throw 'Provide a release folder containing exactly one installer.' }
$setup = $setups[0]
$install = Join-Path $env:LOCALAPPDATA 'Programs\IndividualGuide Release Test'
$executable = Join-Path $install 'IndividualGuide.exe'
if (Test-Path -LiteralPath $executable) { throw 'Use a fresh test account; a release test installation already exists.' }
$report = [ordered]@{ ok=$false; account=$env:USERNAME; checks=[ordered]@{}; installer=$setup.Name }
function Install-Release([string]$Installer = $setup.FullName) {
  $p = Start-Process -FilePath $Installer -ArgumentList @('/S',('/D=' + $install)) -WindowStyle Hidden -PassThru -Wait
  if ($p.ExitCode -ne 0 -or !(Test-Path -LiteralPath $executable)) { throw 'Silent installation failed.' }
}
function Run-Check([string]$Mode,[string]$Name,[string]$Profile) {
  $result = Join-Path $EvidenceFolder ($Name + '.json')
  $p = Start-Process -FilePath $executable -ArgumentList @($Mode,('"--smoke-result={0}"' -f $result),('"--data-dir={0}"' -f $Profile)) -WindowStyle Hidden -PassThru
  if (!$p.WaitForExit(480000)) {
    & (Join-Path $env:SystemRoot 'System32\taskkill.exe') /PID $p.Id /T /F | Out-Null
    throw "Timed out: $Name"
  }
  if ($p.ExitCode -ne 0) {
    # Preserve the failing suite's own diagnostics in the CI evidence artifact.
    foreach ($relative in @('logs/startup.log','product-failure.png','product-failure.txt')) {
      $diagnostic = Join-Path $Profile $relative
      if (Test-Path -LiteralPath $diagnostic) {
        Copy-Item -LiteralPath $diagnostic -Destination (Join-Path $EvidenceFolder ($Name + '-' + (Split-Path $relative -Leaf))) -Force
      }
    }
    $detail = if (Test-Path -LiteralPath $result) { (Get-Content -LiteralPath $result -Raw -Encoding UTF8 | ConvertFrom-Json).error } else { 'No result file.' }
    throw "Failed: $Name. $detail"
  }
  if (!(Test-Path -LiteralPath $result)) { throw "Failed: $Name. No result file." }
  $value = Get-Content -LiteralPath $result -Raw -Encoding UTF8 | ConvertFrom-Json
  if (!$value.ok) { throw "Failed: $Name. $($value.error)" }
  if (Get-Process -Id $value.desktop.rPid -ErrorAction SilentlyContinue) { throw 'R survived desktop shutdown.' }
}
try {
  $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
  $env:R_HOME = 'C:\No-Host-R'; $env:R_LIBS_USER = 'C:\No-Host-Library'; $env:RSTUDIO_PANDOC = 'C:\No-Host-Pandoc'
  Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
  Remove-Item Env:IG_RUNTIME_OVERRIDE -ErrorAction SilentlyContinue
  if ($PreviousInstaller) { Install-Release (Resolve-Path -LiteralPath $PreviousInstaller).Path; $report.upgradeScenario='previous release to current' }
  else { Install-Release; $report.upgradeScenario='in-place reinstall; provide PreviousInstaller for a version upgrade' }
  $report.checks.install = $true
  $profile = Join-Path $env:APPDATA 'Individual Guide'
  Run-Check '--smoke-test' 'workflow' (Join-Path $profile 'workflow')
  Run-Check '--smoke-lifecycle' 'lifecycle' (Join-Path $profile 'lifecycle')
  Run-Check '--smoke-console' 'console' (Join-Path $profile 'console')
  Run-Check '--smoke-examples' 'examples' (Join-Path $profile 'examples')
  Run-Check '--smoke-restart' 'restart' (Join-Path $profile 'restart')
  $report.checks.offlineWorkflows = $true
  $association = Get-ItemProperty -LiteralPath 'Registry::HKEY_CURRENT_USER\Software\Classes\.igpx' -ErrorAction Stop
  $class = $association.'(default)'
  $command = (Get-ItemProperty -LiteralPath ("Registry::HKEY_CURRENT_USER\Software\Classes\$class\shell\open\command")).'(default)'
  if (!$command.Contains($executable) -or !$command.Contains('%1')) { throw 'Project association does not launch this installation.' }
  $report.checks.fileAssociation = $true
  $shortcuts = @(Get-ChildItem -LiteralPath ([Environment]::GetFolderPath('Desktop')) -Filter '*Individual Guide*.lnk' -File)
  $shortcuts += @(Get-ChildItem -LiteralPath ([Environment]::GetFolderPath('StartMenu')) -Filter '*Individual Guide*.lnk' -File -Recurse)
  if ($shortcuts.Count -lt 2) { throw 'Desktop or Start menu shortcut missing.' }
  $report.checks.shortcuts = $true
  $sentinel = Join-Path $profile 'keep-user-data.txt'; 'preserve profile' | Set-Content -LiteralPath $sentinel
  $saved = @(Get-ChildItem -LiteralPath $profile -Filter '*.igpx' -File -Recurse)
  if (!$saved.Count) { throw 'Lifecycle suite did not save a real project.' }
  $hash = (Get-FileHash -LiteralPath $saved[0].FullName).Hash
  Install-Release
  if (!(Test-Path -LiteralPath $sentinel) -or (Get-FileHash -LiteralPath $saved[0].FullName).Hash -ne $hash) { throw 'Upgrade changed user files.' }
  Run-Check '--smoke-startup' 'after-upgrade' (Join-Path $profile 'startup')
  Run-Check '--smoke-product' 'product' (Join-Path $profile 'product')
  $report.checks.upgradePreservesProject = $true
  $uninstallers = @(Get-ChildItem -LiteralPath $install -Filter '*Uninstall*.exe' -File)
  if ($uninstallers.Count -ne 1) { throw 'Uninstaller missing.' }
  $p = Start-Process -FilePath $uninstallers[0].FullName -ArgumentList '/S' -WindowStyle Hidden -Wait -PassThru
  $deadline = (Get-Date).AddSeconds(60)
  while ((Test-Path -LiteralPath $executable) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }
  if (Test-Path -LiteralPath $executable) { throw 'Uninstall did not remove the executable.' }
  if (!(Test-Path -LiteralPath $sentinel) -or !(Test-Path -LiteralPath $saved[0].FullName)) { throw 'Uninstall removed user data.' }
  $report.checks.uninstallPreservesUserData = $true; $report.ok = $true
} catch { $report.error = $_.Exception.Message; throw }
finally { $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $EvidenceFolder 'clean-machine.json') -Encoding UTF8 }
