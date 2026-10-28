[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [string]$GamePath,
    [string]$HackPath,
    [string]$ConfigPath,
    [switch]$Uninstall
)
$ErrorActionPreference='Stop'
$package=[IO.Path]::GetFullPath($PSScriptRoot)

if (-not $GamePath) {
    $steam=(Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { $steam='C:\Program Files (x86)\Steam' }
    $libraries=@($steam)
    $vdf=Join-Path $steam 'steamapps/libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        foreach ($match in [regex]::Matches((Get-Content -LiteralPath $vdf -Raw),'"path"\s+"([^"]+)"')) {
            $libraries+=$match.Groups[1].Value.Replace('\\','\')
        }
    }
    foreach ($library in ($libraries | Select-Object -Unique)) {
        $manifest=Join-Path $library 'steamapps/appmanifest_975370.acf'
        if (-not (Test-Path -LiteralPath $manifest)) { continue }
        $match=[regex]::Match((Get-Content -LiteralPath $manifest -Raw),'"installdir"\s+"([^"]+)"')
        if ($match.Success) { $GamePath=Join-Path $library ('steamapps/common/'+$match.Groups[1].Value);break }
    }
}
if (-not $GamePath) { throw 'Pass -GamePath with the directory containing Dwarf Fortress.exe.' }
$GamePath=[IO.Path]::GetFullPath($GamePath)
if (-not $HackPath) {
    $hook=Join-Path $GamePath 'dfhooks_dfhack.ini'
    if (Test-Path -LiteralPath $hook) { $HackPath=Split-Path ((Get-Content -LiteralPath $hook -Raw).Trim().Trim('"')) }
    if (-not $HackPath) { $HackPath=Join-Path $GamePath 'hack' }
}
$HackPath=[IO.Path]::GetFullPath($HackPath)
if (-not $ConfigPath) { $ConfigPath=Join-Path $GamePath 'dfhack-config' }
$ConfigPath=[IO.Path]::GetFullPath($ConfigPath)
$recordPath=Join-Path $ConfigPath 'worldmap-zoom-install.json'
$backupRoot=Join-Path $ConfigPath 'worldmap-zoom-backups'

if (Get-Process -Name 'Dwarf Fortress' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq (Join-Path $GamePath 'Dwarf Fortress.exe') }) {
    throw 'Close this Dwarf Fortress instance before installing or removing the native plugin.'
}

function Destination([string]$relative) {
    if ($relative.StartsWith('hack/')) { return [IO.Path]::GetFullPath((Join-Path $HackPath $relative.Substring(5))) }
    if ($relative.StartsWith('dfhack-config/')) { return [IO.Path]::GetFullPath((Join-Path $ConfigPath $relative.Substring(14))) }
    throw 'Unknown package path'
}
function Hash([string]$path) { return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
function WriteRecord($entries,[bool]$complete) {
    if ($PSCmdlet.ShouldProcess($recordPath,'Write installation record')) {
        New-Item -ItemType Directory -Path $ConfigPath -Force | Out-Null
        [ordered]@{version=$compat.modVersion;complete=$complete;gamePath=$GamePath;hackPath=$HackPath;configPath=$ConfigPath;files=@($entries)} |
            ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8
    }
}
$files=Get-Content -LiteralPath (Join-Path $package 'payload.json') -Raw | ConvertFrom-Json
$files=@($files)

$allowed=@(
    'dfhack-config/scripts/gui/worldmap-zoom.lua'
    'dfhack-config/scripts/worldmap-zoom.lua'
    'hack/lua/plugins/worldmap-zoom-render.lua'
    'hack/lua/worldmap-zoom/camera.lua'
    'hack/lua/worldmap-zoom/context.lua'
    'hack/lua/worldmap-zoom/gesture.lua'
    'hack/lua/worldmap-zoom/input.lua'
    'hack/plugins/worldmap-zoom-render.plug.dll'
)
if ($files.Count -ne $allowed.Count -or @($files | Select-Object -Unique).Count -ne $allowed.Count -or
        @($files | Where-Object { $allowed -cnotcontains $_ }).Count) {
    throw 'Invalid World Map Zoom payload manifest.'
}
$prior=$null
if (Test-Path -LiteralPath $recordPath) { $prior=Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json }

if ($Uninstall) {
    if (-not $prior) { Write-Output 'No installation record found; no files removed.';return }
    $pending=@()
    foreach ($entry in $prior.files) {
        if ($files -notcontains $entry.relative) { throw 'The installation record contains an unknown package path.' }
        $target=Destination $entry.relative
        if ($entry.preserve) { continue }
        if (Test-Path -LiteralPath $target) {
            if ((Hash $target) -ne $entry.sha256) { Write-Output "Preserved modified file: $target";$pending+=$entry;continue }
            if ($PSCmdlet.ShouldProcess($target,'Remove World Map Zoom file')) { Remove-Item -LiteralPath $target }
        }
        if ($entry.backup -and -not (Test-Path -LiteralPath $target)) {
            $backup=[IO.Path]::GetFullPath($entry.backup)
            if (-not $backup.StartsWith([IO.Path]::GetFullPath($backupRoot)+'\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid backup path in installation record.' }
            if ($PSCmdlet.ShouldProcess($target,'Restore original file')) { Copy-Item -LiteralPath $backup -Destination $target }
        }
    }
    if ($pending.Count) {
        if ($PSCmdlet.ShouldProcess($recordPath,'Retain recovery record for modified files')) {
            $prior.files=$pending
            $prior | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $recordPath -Encoding UTF8
        }
    } elseif ($PSCmdlet.ShouldProcess($recordPath,'Remove installation record')) { Remove-Item -LiteralPath $recordPath }
    if($WhatIfPreference) {Write-Output 'Preview complete; no files were changed.'}
    else {Write-Output 'World Map Zoom removed. Backups were retained.'}
    return
}

$missing=@($files | Where-Object { -not (Test-Path -LiteralPath (Join-Path $package $_) -PathType Leaf) })
if ($missing.Count) {
    throw ('Incomplete World Map Zoom package: '+($missing -join ', ')+'. Download the Windows release ZIP instead of the source archive, or build the native plugin first. No files were installed.')
}

$compat=Get-Content -LiteralPath (Join-Path $package 'compatibility.json') -Raw | ConvertFrom-Json
if ((Hash (Join-Path $GamePath 'Dwarf Fortress.exe')) -ne $compat.gameSha256 -or
        (Hash (Join-Path $HackPath 'dfhack.dll')) -ne $compat.dfhackSha256) {
    throw 'This binary is for the tested Steam DF 53.16 / DFHack 53.16-r3 installation. The installed executables differ; rebuild and retest before installation.'
}
$entries=@()
$stamp=[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
foreach ($relative in $files) {
    $source=Join-Path $package $relative
    $target=Destination $relative
    $hash=Hash $source
    $old=@($prior.files | Where-Object { $_.relative -eq $relative }) | Select-Object -First 1
    $entry=[ordered]@{relative=$relative;sha256=$hash;backup=$null;preserve=$false}
    if (Test-Path -LiteralPath $target) {
        $existing=Hash $target
        if ($old -and $existing -eq $old.sha256) { $entry.backup=$old.backup;$entry.preserve=[bool]$old.preserve }
        elseif ($existing -eq $hash) { $entry.preserve=$true }
        else {
            $backup=Join-Path (Join-Path $backupRoot $stamp) $relative
            if ($PSCmdlet.ShouldProcess($target,'Back up original file')) {
                New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
                Copy-Item -LiteralPath $target -Destination $backup
            }
            $entry.backup=$backup
        }
        if ($existing -eq $hash) { $entries+=[pscustomobject]$entry;continue }
    }
    $entries+=[pscustomobject]$entry
    WriteRecord $entries $false
    if ($PSCmdlet.ShouldProcess($target,'Install World Map Zoom file')) {
        New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
        Copy-Item -LiteralPath $source -Destination $target
    }
}
WriteRecord $entries $true
if($WhatIfPreference) {Write-Output 'Preview complete; no files were changed.'}
else {Write-Output 'Installed World Map Zoom. Open a supported map and run: gui/worldmap-zoom'}
Write-Output "DFHack: $HackPath"
Write-Output "Configuration: $ConfigPath"
