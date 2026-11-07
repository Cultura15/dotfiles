# @ Jesson
# Removes Jarvis voice from your profiles and logon startup, and stops the listener.
# Usage: .\uninstall.ps1 [-Purge]   (-Purge also deletes the built exe, downloaded models and Piper)

[CmdletBinding()]
param([switch]$Purge)

$ErrorActionPreference = 'Stop'

$root          = $PSScriptRoot
$documentsDir  = [Environment]::GetFolderPath('MyDocuments')
$profileMarker = '# jarvis-voice'
$profilePaths  = @(
    (Join-Path $documentsDir 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $documentsDir 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)
$startupLink   = Join-Path ([Environment]::GetFolderPath('Startup')) 'Jarvis Voice.lnk'
$purgeDirs     = @('bin', 'piper', 'listener\bin', 'listener\obj')
$modelsDir     = Join-Path $root 'models'
$utf8NoBom     = New-Object Text.UTF8Encoding($false)


# 1. Stop the listener
Get-Process Jarvis.Listener -ErrorAction SilentlyContinue | Stop-Process -Force

# 2. Remove the profile line
foreach ($profilePath in $profilePaths) {
    if (-not (Test-Path $profilePath)) {
        continue
    }

    $lines = [IO.File]::ReadAllLines($profilePath)
    $kept  = @($lines | Where-Object { $_ -notmatch $profileMarker })

    if ($kept.Count -ne $lines.Count) {
        [IO.File]::WriteAllLines($profilePath, [string[]]$kept, $utf8NoBom)
        Write-Host "Removed from $profilePath"
    }
}

# 3. Remove the logon shortcut
if (Test-Path $startupLink) {
    Remove-Item $startupLink
    Write-Host 'Removed logon shortcut'
}

# 4. Delete build output and downloads (optional)
if ($Purge) {
    foreach ($dir in $purgeDirs) {
        $path = Join-Path $root $dir
        if (Test-Path $path) {
            Remove-Item -Recurse -Force $path
            Write-Host "Deleted $path"
        }
    }
    Get-ChildItem $modelsDir -Filter *.bin -ErrorAction SilentlyContinue | Remove-Item -Force
}

Write-Host 'Jarvis voice uninstalled. Open a new shell for it to take effect.'
