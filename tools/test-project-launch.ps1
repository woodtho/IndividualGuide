param([Parameter(Mandatory=$true)][string]$Executable, [Parameter(Mandatory=$true)][string]$Project, [switch]$CheckAssociation, [switch]$Recovery)
$ErrorActionPreference = 'Stop'
$Executable = (Resolve-Path -LiteralPath $Executable).Path
$Project = (Resolve-Path -LiteralPath $Project).Path
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runRoot = Join-Path $projectRoot ('build\tests\project-launch-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$profile = Join-Path $runRoot 'User Data'
New-Item -ItemType Directory -Force -Path $profile | Out-Null
$preferences = '{"recent":[],"window":{"x":30,"y":40,"width":1100,"height":760,"maximized":true}}'
[IO.File]::WriteAllText((Join-Path $profile 'desktop-settings.json'), $preferences, [Text.UTF8Encoding]::new($false))
if($Recovery) {
  $recoveryFolder=Join-Path $profile 'recovery'
  New-Item -ItemType Directory -Force -Path $recoveryFolder | Out-Null
  Copy-Item -LiteralPath $Project -Destination (Join-Path $recoveryFolder 'recovery.igpx')
}
$resultFile = Join-Path $runRoot 'result.json'
$variables = @('IG_RUNTIME_OVERRIDE','ELECTRON_RUN_AS_NODE','R_HOME','R_LIBS_USER','RSTUDIO_PANDOC')
$previous = @{}
foreach($variable in $variables) { $previous[$variable] = [Environment]::GetEnvironmentVariable($variable,'Process') }
try {
  Remove-Item Env:IG_RUNTIME_OVERRIDE -ErrorAction SilentlyContinue
  Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
  $env:R_HOME='C:\No-host-R'; $env:R_LIBS_USER='C:\No-host-packages'; $env:RSTUDIO_PANDOC='C:\No-host-Pandoc'
  $arguments = @('--smoke-startup', ('"--smoke-result={0}"' -f $resultFile), ('"--data-dir={0}"' -f $profile), ('"{0}"' -f $Project))
  if($Recovery) { $arguments += '--smoke-recovery-discard' }
  $process = Start-Process -FilePath $Executable -ArgumentList $arguments -PassThru -WindowStyle Hidden
} finally {
  foreach($variable in $variables) { [Environment]::SetEnvironmentVariable($variable,$previous[$variable],'Process') }
}
if (!$process.WaitForExit(240000)) { throw "Project launch timed out. Inspect $profile\logs\startup.log" }
$result = Get-Content -LiteralPath $resultFile -Raw -Encoding UTF8 | ConvertFrom-Json
if ($process.ExitCode -ne 0 -or !$result.ok -or !$result.checks.openProjectArgument) { throw 'Opening the project argument failed.' }
if($Recovery -and !$result.checks.recoveryBeforeProjectOpening) { throw 'Recovery protection was not verified.' }
if (!$result.windowState.maximized -or $result.windowState.bounds.width -gt 1100 -or $result.windowState.bounds.height -gt 760) { throw 'Saved window state was not restored.' }
if(Get-Process -Id $result.desktop.rPid -ErrorAction SilentlyContinue) { throw 'The backend survived closing.' }
if($CheckAssociation) {
  $association = Get-Item -LiteralPath 'HKCU:\Software\Classes\.igpx'
  $programId = $association.GetValue('')
  $command = (Get-Item -LiteralPath ('HKCU:\Software\Classes\' + $programId + '\shell\open\command')).GetValue('')
  if (!$command.Contains($Executable) -or !$command.Contains('%1')) { throw 'The installed project association is incorrect.' }
  [IO.File]::WriteAllText((Join-Path $runRoot 'association.json'), (@{extension='.igpx';programId=$programId;command=$command;ok=$true}|ConvertTo-Json), [Text.UTF8Encoding]::new($false))
}
Write-Output ('Project launch and restored window state passed: ' + $resultFile)
