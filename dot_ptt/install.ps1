# @ Jesson
# Builds the Jarvis voice listener, downloads the Whisper model and hooks it into your PowerShell profiles.
# Usage: .\install.ps1 [-Model tiny.en|base.en|small.en] [-SkipModel] [-SkipProfile] [-Startup] [-Piper]

[CmdletBinding()]
param(
    [ValidateSet('tiny.en', 'base.en', 'small.en')] [string]$Model = 'base.en',
    [switch]$SkipModel,
    [switch]$SkipProfile,
    [switch]$Startup,
    [switch]$Piper
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'

$root           = $PSScriptRoot
$configPath     = Join-Path $root 'config.json'
$projectPath    = Join-Path $root 'listener\Jarvis.Listener.csproj'
$binDir         = Join-Path $root 'bin'
$exePath        = Join-Path $binDir 'Jarvis.Listener.exe'
$listenerArgs   = @('--config', "`"$configPath`"")
$dotnetFallback = Join-Path $env:ProgramFiles 'dotnet\dotnet.exe'

$modelFile      = "ggml-$Model.bin"
$modelPath      = Join-Path $root "models\$modelFile"
$modelUrl       = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$modelFile"

$piperDir       = Join-Path $root 'piper'
$piperExe       = Join-Path $piperDir 'piper.exe'
$piperZipUrl    = 'https://github.com/rhasspy/piper/releases/download/2023.11.14-2/piper_windows_amd64.zip'
$piperZip       = Join-Path $env:TEMP "piper-$([guid]::NewGuid().ToString('N')).zip"
$piperUnzipDir  = "$piperZip.d"
$piperVoice     = 'en_GB-alan-medium'
$piperVoiceUrl  = 'https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_GB/alan/medium'
$piperFiles     = @("$piperVoice.onnx", "$piperVoice.onnx.json")

$documentsDir   = [Environment]::GetFolderPath('MyDocuments')
$profileScript  = Join-Path $root 'profile\jarvis-voice.ps1'
$profileMarker  = '# jarvis-voice'
$profileLine    = "`$jarvisVoice = '$profileScript'; if (Test-Path `$jarvisVoice) { . `$jarvisVoice }  $profileMarker"
$profilePaths   = @(
    (Join-Path $documentsDir 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path $documentsDir 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')
)
$startupLink    = Join-Path ([Environment]::GetFolderPath('Startup')) 'Jarvis Voice.lnk'
$utf8NoBom      = New-Object Text.UTF8Encoding($false)


function Write-Step([string]$Message) {
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Set-ConfigValue([string]$Name, [string]$Value) {
    $pattern = "(`"$Name`"\s*:\s*`")[^`"]*(`")"
    $json    = [IO.File]::ReadAllText($configPath)
    $updated = [regex]::Replace($json, $pattern, "`${1}$Value`${2}")

    if ($updated -ne $json) {
        [IO.File]::WriteAllText($configPath, $updated, $utf8NoBom)
    }
}

function Save-Download([string]$Url, [string]$Destination) {
    $partial = "$Destination.part"

    Write-Host "    downloading $Url"
    Invoke-WebRequest -Uri $Url -OutFile $partial -UseBasicParsing
    Move-Item -Force $partial $Destination
}


# 1. Find the .NET 10 SDK
$dotnet = (Get-Command dotnet -ErrorAction SilentlyContinue).Source
if (-not $dotnet -and (Test-Path $dotnetFallback)) {
    $dotnet = $dotnetFallback
}
if (-not $dotnet -or -not (& $dotnet --list-sdks | Select-String '^(1[0-9])\.')) {
    throw '.NET 10 SDK not found. Install it with: winget install Microsoft.DotNet.SDK.10'
}

# 2. Stop a running listener so the exe isn't locked
$running = @(Get-Process Jarvis.Listener -ErrorAction SilentlyContinue)
if ($running) {
    Write-Step 'Stopping running listener'
    foreach ($process in $running) {
        $process | Stop-Process -Force
        $process.WaitForExit(5000) | Out-Null
    }
}

# 3. Build
Write-Step 'Building listener'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_NOLOGO = '1'
& $dotnet publish $projectPath -c Release -o $binDir --nologo -v quiet
if ($LASTEXITCODE -ne 0) {
    throw 'Build failed.'
}

# 4. Whisper model
if (-not $SkipModel) {
    if (Test-Path $modelPath) {
        Write-Step "Model $modelFile already present"
    } else {
        Write-Step "Downloading Whisper model $modelFile"
        New-Item -ItemType Directory -Force (Split-Path $modelPath) | Out-Null
        Save-Download $modelUrl $modelPath
    }
    Set-ConfigValue 'model' "models/$modelFile"
}

# 5. Piper voice (optional)
if ($Piper) {
    if (-not (Test-Path $piperExe)) {
        Write-Step 'Downloading Piper'
        Save-Download $piperZipUrl $piperZip
        Expand-Archive -Path $piperZip -DestinationPath $piperUnzipDir -Force
        New-Item -ItemType Directory -Force $piperDir | Out-Null
        $unzippedExe = Get-ChildItem $piperUnzipDir -Recurse -Filter piper.exe | Select-Object -First 1
        Copy-Item -Recurse -Force (Join-Path $unzippedExe.DirectoryName '*') $piperDir
        Remove-Item -Recurse -Force $piperZip, $piperUnzipDir
    }
    foreach ($file in $piperFiles) {
        if (-not (Test-Path (Join-Path $piperDir $file))) {
            Write-Step "Downloading Piper voice $file"
            Save-Download "$piperVoiceUrl/$file" (Join-Path $piperDir $file)
        }
    }
    Set-ConfigValue 'piperModel' "piper/$piperVoice.onnx"
    Set-ConfigValue 'engine' 'piper'
}

# 6. PowerShell 7 and Windows PowerShell 5.1 profiles
if (-not $SkipProfile) {
    foreach ($profilePath in $profilePaths) {
        New-Item -ItemType Directory -Force (Split-Path $profilePath) | Out-Null
        $content = if (Test-Path $profilePath) { [IO.File]::ReadAllText($profilePath) } else { '' }

        if ($content -match $profileMarker) {
            Write-Step "Profile already set up: $profilePath"
            continue
        }

        Write-Step "Adding Jarvis voice to $profilePath"
        $separator = if ($content -and -not $content.EndsWith("`n")) { "`r`n" } else { '' }
        [IO.File]::AppendAllText($profilePath, "$separator$profileLine`r`n", $utf8NoBom)
    }
}

# 7. Logon startup (optional)
if ($Startup) {
    Write-Step 'Adding logon shortcut'
    $shortcut = (New-Object -ComObject WScript.Shell).CreateShortcut($startupLink)
    $shortcut.TargetPath       = $exePath
    $shortcut.Arguments        = $listenerArgs -join ' '
    $shortcut.WorkingDirectory = $binDir
    $shortcut.Save()
}

# 8. Start the listener
Write-Step 'Starting listener'
Start-Process -FilePath $exePath -ArgumentList $listenerArgs

Write-Host ''
Write-Host 'Done. Open a new PowerShell window, hold Right Ctrl, and say "Jarvis, let''s go".' -ForegroundColor Green
Write-Host 'Look for the microphone icon in the tray (you may need to drag it out of the overflow area).'
