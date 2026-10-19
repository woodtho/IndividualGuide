param([Parameter(Mandatory=$true)][string]$ReleaseFolder,[switch]$Launch)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$release = (Resolve-Path -LiteralPath $ReleaseFolder).Path
$folder = Join-Path $root ('build\sandbox-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$harness = Join-Path $folder 'harness'; $evidence = Join-Path $folder 'evidence'
New-Item -ItemType Directory -Path $harness,$evidence -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'test-clean-machine.ps1') -Destination $harness
$escape = { param($s) [Security.SecurityElement]::Escape($s) }
$xml = @"
<Configuration>
  <Networking>Disable</Networking><VGpu>Disable</VGpu><ClipboardRedirection>Disable</ClipboardRedirection>
  <MappedFolders>
    <MappedFolder><HostFolder>$(& $escape $release)</HostFolder><SandboxFolder>C:\Release</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>
    <MappedFolder><HostFolder>$(& $escape $harness)</HostFolder><SandboxFolder>C:\Harness</SandboxFolder><ReadOnly>true</ReadOnly></MappedFolder>
    <MappedFolder><HostFolder>$(& $escape $evidence)</HostFolder><SandboxFolder>C:\Evidence</SandboxFolder><ReadOnly>false</ReadOnly></MappedFolder>
  </MappedFolders>
  <LogonCommand><Command>powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Harness\test-clean-machine.ps1 -ReleaseFolder C:\Release -EvidenceFolder C:\Evidence</Command></LogonCommand>
</Configuration>
"@
$wsb = Join-Path $folder 'IndividualGuide.wsb'
$null = [xml]$xml
[IO.File]::WriteAllText($wsb,$xml,[Text.UTF8Encoding]::new($false))
Write-Output "Sandbox configuration: $wsb"
Write-Output "Evidence: $evidence"
if ($Launch) {
  $sandbox = Join-Path $env:SystemRoot 'System32\WindowsSandbox.exe'
  if (!(Test-Path -LiteralPath $sandbox)) { throw 'Windows Sandbox is not enabled on this computer. The configuration was created for an enabled Windows host.' }
  Start-Process -FilePath $sandbox -ArgumentList ('"{0}"' -f $wsb) -WindowStyle Hidden
}
