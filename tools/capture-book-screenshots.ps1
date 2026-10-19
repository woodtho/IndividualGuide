param(
  [Parameter(Mandatory=$true)][string]$Runtime,
  [string]$PracticeParent = [System.IO.Path]::GetPathRoot($PSScriptRoot),
  [switch]$Resume
)
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$runtimePath = (Resolve-Path -LiteralPath $Runtime).Path
$reference = Get-Content -LiteralPath (Join-Path $root 'docs/book/data/app-reference.json') -Raw | ConvertFrom-Json
$description = Join-Path $runtimePath 'R/library/IndividualGuide/DESCRIPTION'
if (!(Test-Path -LiteralPath $description)) { throw 'Choose resources/runtime from the installed public Windows release.' }
$version = ((Select-String -LiteralPath $description -Pattern '^Version:').Line -replace '^Version:\s*','').Trim()
if ($version -ne $reference.package_version) { throw "This book requires Individual Guide $($reference.package_version); the supplied runtime is $version." }
$electron = Join-Path $root 'tools/desktop/node_modules/electron/dist/electron.exe'
if (!(Test-Path -LiteralPath $electron)) { throw 'Run npm ci in tools/desktop before capturing the book.' }
$parent = (Resolve-Path -LiteralPath $PracticeParent).Path
if ($parent -match '[\\/]Users[\\/]') { throw 'Choose a writable practice parent outside a user profile, so screenshots contain no personal paths.' }
$tag = [guid]::NewGuid().ToString('N').Substring(0,8)
$practice = Join-Path $parent "IG-Book-$tag"
$scratch = Join-Path ([System.IO.Path]::GetTempPath()) "ig-book-$tag"
foreach ($directory in @($practice,$scratch)) {
  if (Test-Path -LiteralPath $directory) { throw "The owned capture directory already exists: $directory" }
  New-Item -ItemType Directory -Path $directory | Out-Null
}
$appDirectory = Join-Path $scratch 'app'
$profile = Join-Path $scratch 'profile'
New-Item -ItemType Directory -Path $appDirectory | Out-Null
Get-ChildItem -LiteralPath (Join-Path $root 'tools/desktop') -File |
  Where-Object {$_.Extension -in @('.cjs','.html','.json')} |
  ForEach-Object {Copy-Item -LiteralPath $_.FullName -Destination $appDirectory}
Copy-Item -LiteralPath (Join-Path $root 'tools/desktop/assets') -Destination (Join-Path $appDirectory 'assets') -Recurse
$entry = Join-Path $appDirectory 'main.cjs'
$main = [System.IO.File]::ReadAllText($entry)
if (($main.Split(@("require('./product-smoke.cjs')"),[System.StringSplitOptions]::None)).Length -ne 2) { throw 'The desktop capture hook changed; review it before capturing.' }
$main = $main.Replace("require('./product-smoke.cjs')","require('./capture-book.cjs')")
[System.IO.File]::WriteAllText($entry,$main,[System.Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $root 'tools/capture-book-screenshots.cjs') -Destination (Join-Path $appDirectory 'capture-book.cjs')
Copy-Item -LiteralPath (Join-Path $root 'inst/examples/query-joins/outputs/state-statistics.csv') -Destination $practice
$result = Join-Path $scratch 'capture-result.json'
$evidenceDirectory = Join-Path $root 'artifacts/book-review'
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
$handoff = @{scratch=$scratch;app=$appDirectory;profile=$profile;practice=$practice;result=$result}
[System.IO.File]::WriteAllText((Join-Path $evidenceDirectory 'capture-handoff.json'),($handoff | ConvertTo-Json),[System.Text.UTF8Encoding]::new($false))
$env:IG_RUNTIME_OVERRIDE = $runtimePath
$env:IG_BOOK_ROOT = $root
$env:IG_BOOK_PRACTICE = $practice
$env:IG_BOOK_RESUME = if ($Resume) {'1'} else {'0'}
Remove-Item Env:ELECTRON_RUN_AS_NODE -ErrorAction SilentlyContinue
$arguments = @($appDirectory,'--smoke-product',"--smoke-result=$result","--data-dir=$profile") | ForEach-Object {'"' + $_ + '"'}
$process = Start-Process -FilePath $electron -ArgumentList $arguments -WorkingDirectory $root -WindowStyle Hidden -PassThru `
  -RedirectStandardOutput (Join-Path $scratch 'stdout.log') -RedirectStandardError (Join-Path $scratch 'stderr.log')
$process.WaitForExit()
if (!(Test-Path -LiteralPath $result)) { throw "Capture did not produce a result. Inspect $scratch" }
$evidence = Get-Content -LiteralPath $result -Raw | ConvertFrom-Json
if (!$evidence.ok -or !$evidence.checks.allTaskPanels) { throw "Capture failed: $($evidence.error). Inspect $scratch" }
Write-Output "Captured $($evidence.screenshots) real application views and reviewed $($evidence.taskPanels) task forms."
Write-Output "Evidence: $scratch"
Write-Output "Public practice files: $practice"
