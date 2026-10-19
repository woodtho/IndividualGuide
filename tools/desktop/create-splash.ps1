$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$assetRoot = Join-Path $PSScriptRoot 'assets'
New-Item -ItemType Directory -Path $assetRoot -Force | Out-Null
$bitmap = New-Object System.Drawing.Bitmap(560, 170)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$titleFont = New-Object System.Drawing.Font('Segoe UI', 18, [System.Drawing.FontStyle]::Bold)
$bodyFont = New-Object System.Drawing.Font('Segoe UI', 10)
$titleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(239, 241, 249))
$bodyBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 188, 207))
try {
  $graphics.Clear([System.Drawing.Color]::FromArgb(23, 26, 39))
  $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $graphics.DrawString('Preparing Individual Guide', $titleFont, $titleBrush, 24, 24)
  $graphics.DrawString("Unpacking the bundled R and browser runtime...`nThis can take a few minutes. The workspace opens automatically.", $bodyFont, $bodyBrush, 26, 76)
  $bitmap.Save((Join-Path $assetRoot 'preparing.bmp'), [System.Drawing.Imaging.ImageFormat]::Bmp)
} finally {
  $bodyBrush.Dispose(); $titleBrush.Dispose(); $bodyFont.Dispose(); $titleFont.Dispose()
  $graphics.Dispose(); $bitmap.Dispose()
}
