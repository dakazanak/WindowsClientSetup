#requires -Version 7.0

<#
.SYNOPSIS
    Grafisches Werkzeug zur Einrichtung eines neuen Windows Clients.
.DESCRIPTION
    Duenner Launcher fuer das WindowsClientSetup-Modul (module\WindowsClientSetup).
.NOTES
    Erfordert PowerShell 7+ und Administrator-Rechte fuer vollen Funktionsumfang.
#>

$scriptPath = $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptPath

Import-Module (Join-Path $repoRoot 'module\WindowsClientSetup\WindowsClientSetup.psd1') -Force

Start-WindowsClientSetup -ScriptPath $scriptPath
