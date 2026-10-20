param([Parameter(Mandatory=$true)][string]$Installer,[string]$EvidenceDirectory='artifacts/i18n')
$ErrorActionPreference='Stop'
Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;
public static class IgLanguageCombo {
  private delegate bool EnumCallback(IntPtr h,IntPtr parameter);
  [DllImport("user32.dll")] private static extern bool EnumWindows(EnumCallback callback,IntPtr parameter);
  [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr parent,EnumCallback callback,IntPtr parameter);
  [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr h,out uint process);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr h,StringBuilder text,int length);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
  [DllImport("user32.dll",CharSet=CharSet.Unicode,EntryPoint="SendMessageW")] public static extern IntPtr Text(IntPtr h,uint m,IntPtr w,StringBuilder l);
  public static IntPtr[] Find(int process) {
    var found=new List<IntPtr>();
    EnumWindows((window,p)=>{
      uint owner;GetWindowThreadProcessId(window,out owner);
      if(owner!=(uint)process)return true;
      EnumChildWindows(window,(child,q)=>{
        var name=new StringBuilder(256);GetClassName(child,name,256);
        if(name.ToString()=="ComboBox"){found.Add(window);found.Add(child);return false;}
        return true;
      },IntPtr.Zero);
      return found.Count==0;
    },IntPtr.Zero);
    return found.ToArray();
  }
}
'@
$executable=(Resolve-Path -LiteralPath $Installer).Path
$evidence=[IO.Path]::GetFullPath((Join-Path (Get-Location) $EvidenceDirectory))
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$target=Join-Path ([IO.Path]::GetTempPath()) ('ig-language-chooser-'+[guid]::NewGuid().ToString('N'))
$process=Start-Process -FilePath $executable -ArgumentList "/D=$target" -WindowStyle Hidden -PassThru
try {
  $deadline=(Get-Date).AddSeconds(30);$found=@()
  do {
    $found=@([IgLanguageCombo]::Find($process.Id))
    if($found.Count -lt 2){Start-Sleep -Milliseconds 100}
  } while($found.Count -lt 2 -and (Get-Date) -lt $deadline -and !$process.HasExited)
  if($found.Count -lt 2){throw 'The installer language chooser has no language list.'}
  $handle=$found[1]
  $count=[IgLanguageCombo]::SendMessage($handle,0x146,[IntPtr]::Zero,[IntPtr]::Zero).ToInt32()
  $languages=@(for($index=0;$index -lt $count;$index++){
    $buffer=[Text.StringBuilder]::new(512)
    [IgLanguageCombo]::Text($handle,0x148,[IntPtr]$index,$buffer) | Out-Null
    $buffer.ToString()
  })
  $frenchName='Fran'+[char]0xE7+'ais (Canada)'
  if($languages.Count -ne 2 -or $languages -notcontains 'English' -or $languages -notcontains $frenchName){
    throw ('Unexpected installer languages: '+($languages -join ', '))
  }
  [IgLanguageCombo]::SendMessage($found[0],0x10,[IntPtr]::Zero,[IntPtr]::Zero) | Out-Null
  if(!$process.WaitForExit(10000)){throw 'The cancelled installer did not exit.'}
  if(Test-Path -LiteralPath (Join-Path $target 'installation-language.json')){throw 'Cancelling the chooser installed a preference.'}
  @{ok=$true;installerSha256=(Get-FileHash -LiteralPath $executable -Algorithm SHA256).Hash.ToLower();languages=$languages;cancelLeftNoInstallation=$true} |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $evidence 'installer-chooser-verification.json') -Encoding UTF8
  Write-Output "The real installer chooser offers English and $frenchName; cancelling leaves no installation."
} finally {
  if(!$process.HasExited){$process.Kill();$process.WaitForExit()}
}
