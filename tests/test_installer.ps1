param([Parameter(Mandatory=$true)][string]$GameExe,
      [Parameter(Mandatory=$true)][string]$DfhackDll,
      [Parameter(Mandatory=$true)][string]$TestRoot)
$ErrorActionPreference='Stop'
if(Test-Path -LiteralPath $TestRoot) {throw 'Use a new test directory; this test does not overwrite existing directories.'}
$TestRoot=[IO.Path]::GetFullPath($TestRoot)
$package=Split-Path $PSScriptRoot
$game=Join-Path $TestRoot 'game';$hack=Join-Path $TestRoot 'hack';$config=Join-Path $game 'dfhack-config'
New-Item -ItemType Directory -Path $game,$hack,(Join-Path $config 'scripts/gui'),(Join-Path $hack 'lua/worldmap-zoom') -Force | Out-Null
Copy-Item -LiteralPath $GameExe -Destination (Join-Path $game 'Dwarf Fortress.exe')
Copy-Item -LiteralPath $DfhackDll -Destination (Join-Path $hack 'dfhack.dll')
$original=Join-Path $config 'scripts/gui/worldmap-zoom.lua'
Set-Content -LiteralPath $original -Value '-- prior user script' -Encoding UTF8
$originalHash=(Get-FileHash -LiteralPath $original).Hash
$params=@{GamePath=$game;HackPath=$hack;ConfigPath=$config}
$sourceOnly=Join-Path $TestRoot 'source-only'
New-Item -ItemType Directory -Path $sourceOnly -Force | Out-Null
$payload=Get-Content -LiteralPath (Join-Path $package 'payload.json') -Raw | ConvertFrom-Json
foreach ($relative in @('Install.ps1','compatibility.json','payload.json') + $payload) {
    if ($relative -eq 'hack/plugins/worldmap-zoom-render.plug.dll') {continue}
    $destination=Join-Path $sourceOnly $relative
    New-Item -ItemType Directory -Path (Split-Path $destination) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $package $relative) -Destination $destination
}
$missingRejected=$false
try { & (Join-Path $sourceOnly 'Install.ps1') @params }
catch {if($_.Exception.Message -notmatch 'Incomplete World Map Zoom package') {throw};$missingRejected=$true}
if(-not $missingRejected -or (Test-Path -LiteralPath (Join-Path $config 'worldmap-zoom-install.json')) -or
        (Test-Path -LiteralPath (Join-Path $hack 'lua/worldmap-zoom/input.lua')) -or
        (Get-FileHash -LiteralPath $original).Hash -ne $originalHash) {
    throw 'Source-only checkout was not rejected before writes'
}
& (Join-Path $package 'Install.ps1') @params
$recordPath=Join-Path $config 'worldmap-zoom-install.json'
$record=Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
if(-not $record.complete -or $record.files.Count -ne 8) {throw 'Incomplete installation manifest'}
$entry=$record.files | Where-Object relative -eq 'dfhack-config/scripts/gui/worldmap-zoom.lua'
if((Get-FileHash -LiteralPath $entry.backup).Hash -ne $originalHash) {throw 'Original was not backed up'}
& (Join-Path $package 'Install.ps1') @params
if(@(Get-ChildItem -LiteralPath (Join-Path $config 'worldmap-zoom-backups') -Directory).Count -ne 1) {throw 'Idempotent install created another backup'}
$modified=Join-Path $hack 'lua/worldmap-zoom/input.lua'
Add-Content -LiteralPath $modified -Value '-- user modification'
$modifiedHash=(Get-FileHash -LiteralPath $modified).Hash
& (Join-Path $sourceOnly 'Install.ps1') @params -Uninstall
if((Get-FileHash -LiteralPath $original).Hash -ne $originalHash) {throw 'Uninstall failed to restore original'}
if((Get-FileHash -LiteralPath $modified).Hash -ne $modifiedHash) {throw 'Uninstall removed a user modification'}
$pending=Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
if($pending.files.Count -ne 1) {throw 'Modified-file recovery record was lost'}
if(Test-Path -LiteralPath (Join-Path $hack 'plugins/worldmap-zoom-render.plug.dll')) {throw 'Native plugin was not removed'}
Remove-Item -LiteralPath $modified
& (Join-Path $package 'Install.ps1') @params -Uninstall
if(Test-Path -LiteralPath $recordPath) {throw 'Completed recovery record remains'}
if(-not (Test-Path -LiteralPath (Join-Path $hack 'dfhack.dll'))) {throw 'Core DFHack file was changed'}
$mismatch=Join-Path $TestRoot 'mismatch-game'
New-Item -ItemType Directory -Path $mismatch -Force | Out-Null
Set-Content -LiteralPath (Join-Path $mismatch 'Dwarf Fortress.exe') -Value 'not the supported executable'
$rejected=$false
try { & (Join-Path $package 'Install.ps1') -GamePath $mismatch -HackPath $hack -ConfigPath $config }
catch { if($_.Exception.Message -notmatch 'executables differ') {throw};$rejected=$true }
if(-not $rejected -or (Test-Path -LiteralPath $recordPath)) {throw 'Unsupported executable was not rejected before writes'}
& (Join-Path $package 'Install.ps1') @params -WhatIf
if(Test-Path -LiteralPath $recordPath) {throw 'WhatIf wrote an installation record'}
Write-Output 'PASS installer backup, idempotence, rollback, modified-file preservation, checksum rejection, dry run, missing-payload rejection, and source-only uninstall'
